import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class GitHubApiClient {
  final http.Client _client;
  final String? _token;

  GitHubApiClient({http.Client? client, String? token})
    : _client = client ?? http.Client(),
      _token = token;

  static Future<String?> resolveToken() async {
    final envToken =
        Platform.environment['GITHUB_TOKEN'] ??
        Platform.environment['GH_TOKEN'] ??
        _readDotEnvToken();
    if (envToken != null && envToken.isNotEmpty) return envToken;

    try {
      final res = await Process.run('gh', const ['auth', 'token']);
      if (res.exitCode == 0) {
        final out = (res.stdout as String).trim();
        if (out.isNotEmpty) return out;
      }
    } on ProcessException {
      // Fallback to unauthenticated REST if `gh` is not installed.
    }
    return null;
  }

  static String? _readDotEnvToken() {
    final file = File('.env');
    if (!file.existsSync()) return null;
    for (final raw in file.readAsLinesSync()) {
      final line = raw.trim();
      if (line.startsWith('GITHUB_TOKEN=')) {
        return line.substring('GITHUB_TOKEN='.length).trim();
      }
    }
    return null;
  }

  Map<String, String> get _headers => {
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
    if (_token != null && _token.isNotEmpty) 'Authorization': 'Bearer $_token',
  };

  Future<Object?> getJson(Uri uri) async {
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode != 200) return null;
    return jsonDecode(response.body);
  }

  Future<Map<String, Object?>?> postGraphQl(
    String query, [
    Map<String, Object?> variables = const {},
  ]) async {
    if (_token == null || _token.isEmpty) return null;
    final response = await _client.post(
      Uri.parse('https://api.github.com/graphql'),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode({'query': query, 'variables': variables}),
    );
    if (response.statusCode != 200) return null;
    final decoded = jsonDecode(response.body);
    return decoded is Map ? Map<String, Object?>.from(decoded) : null;
  }
}
