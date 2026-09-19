import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pool/pool.dart';

import 'changelog_parser.dart';
import 'models.dart';

class PubHarvester {
  final http.Client _client;
  final Pool _pool = Pool(8);

  PubHarvester({http.Client? client}) : _client = client ?? http.Client();

  Future<({List<PackageRelease> newPackages, List<PackageRelease> updated})>
  harvestPublishers({
    required List<String> publishers,
    required DateTime since,
    required DateTime until,
  }) async {
    final daysBack =
        DateTime.now().toUtc().difference(since.toUtc()).inDays + 2;
    final candidateNames = <String, String>{};

    for (final publisher in publishers) {
      final names = await _searchUpdatedPackages(
        publisher: publisher,
        daysBack: daysBack < 1 ? 1 : daysBack,
      );
      for (final name in names) {
        candidateNames[name] = publisher;
      }
    }

    final releases = await Future.wait(
      candidateNames.entries.map(
        (entry) => _pool.withResource(
          () => _inspectPackage(
            name: entry.key,
            publisher: entry.value,
            since: since,
            until: until,
          ),
        ),
      ),
    );

    final newPackages = <PackageRelease>[];
    final updated = <PackageRelease>[];

    for (final release in releases.whereType<PackageRelease>()) {
      if (release.isNewPackage) {
        newPackages.add(release);
      } else {
        updated.add(release);
      }
    }

    newPackages.sort((a, b) => b.published.compareTo(a.published));
    updated.sort((a, b) => b.published.compareTo(a.published));
    return (newPackages: newPackages, updated: updated);
  }

  Future<List<String>> _searchUpdatedPackages({
    required String publisher,
    required int daysBack,
  }) async {
    final packages = <String>[];
    Uri? nextUrl = Uri.parse(
      'https://pub.dev/api/search?q=publisher%3A$publisher+updated%3A${daysBack}d',
    );

    while (nextUrl != null) {
      final page = await _fetchSearchPage(nextUrl);
      if (page == null) break;
      packages.addAll(page.packages);
      nextUrl = page.nextUrl;
    }
    return packages;
  }

  Future<({List<String> packages, Uri? nextUrl})?> _fetchSearchPage(
    Uri url,
  ) async {
    final response = await _client.get(url);
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, Object?>;
    final items = data['packages'];
    final names = <String>[];
    if (items is List) {
      for (final item in items.whereType<Map<String, Object?>>()) {
        final pkg = item['package'];
        if (pkg is String) names.add(pkg);
      }
    }
    final nextStr = data['next'] as String?;
    final nextUri =
        (nextStr != null && nextStr.isNotEmpty) ? Uri.parse(nextStr) : null;
    return (packages: names, nextUrl: nextUri);
  }

  Future<PackageRelease?> _inspectPackage({
    required String name,
    required String publisher,
    required DateTime since,
    required DateTime until,
  }) async {
    final uri = Uri.parse('https://pub.dev/api/packages/$name');
    final response = await _client.get(uri);
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, Object?>;
    final versionsRaw = data['versions'];
    if (versionsRaw is! List || versionsRaw.isEmpty) return null;

    final versions = versionsRaw.whereType<Map<String, Object?>>().toList();
    final inWindow = _versionsInWindow(versions, since: since, until: until);
    if (inWindow.isEmpty) return null;

    final latestInWindow = inWindow.last;
    final versionStr = (latestInWindow['version'] as String?) ?? '';
    final publishedAt = DateTime.parse(latestInWindow['published'] as String);
    final pubspec =
        (latestInWindow['pubspec'] as Map<String, Object?>?) ?? const {};
    final description = (pubspec['description'] as String?) ?? '';
    final repoUrl = pubspec['repository'] as String?;

    final firstPublished = DateTime.parse(
      versions.first['published'] as String,
    );
    final isNew =
        !firstPublished.isBefore(since) ||
        (versionStr == '1.0.0' && versions.length > 1);

    final changelogExcerpt = await _fetchChangelogExcerpt(
      repoUrl: repoUrl,
      version: versionStr,
    );

    return PackageRelease(
      name: name,
      version: versionStr,
      publisher: publisher,
      published: publishedAt,
      description: description,
      pubUrl: 'https://pub.dev/packages/$name/versions/$versionStr',
      repositoryUrl: repoUrl,
      isNewPackage: isNew,
      changelogExcerpt: changelogExcerpt,
    );
  }

  List<Map<String, Object?>> _versionsInWindow(
    List<Map<String, Object?>> versions, {
    required DateTime since,
    required DateTime until,
  }) =>
      versions.where((v) {
        final publishedStr = v['published'];
        if (publishedStr is! String) return false;
        final dt = DateTime.tryParse(publishedStr);
        if (dt == null) return false;
        return !dt.isBefore(since) && !dt.isAfter(until);
      }).toList();

  Future<String?> _fetchChangelogExcerpt({
    required String? repoUrl,
    required String version,
  }) async {
    final rawUrls = _candidateRawChangelogUrls(repoUrl);
    for (final rawUri in rawUrls) {
      final resp = await _client.get(rawUri);
      if (resp.statusCode == 200) {
        final section = extractChangelogVersionSection(resp.body, version);
        if (section != null) return section;
      }
    }
    return null;
  }

  List<Uri> _candidateRawChangelogUrls(String? repoUrl) {
    if (repoUrl == null) return const [];
    final uri = Uri.tryParse(repoUrl);
    if (uri == null || uri.host != 'github.com') return const [];

    final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segs.length < 2) return const [];
    final owner = segs[0];
    final repo = segs[1].replaceAll(RegExp(r'\.git$'), '');

    if (segs.length >= 4 && segs[2] == 'tree') {
      final branch = segs[3];
      final subPath = segs.sublist(4).join('/');
      final prefix = subPath.isEmpty ? '' : '$subPath/';
      return [
        Uri.parse(
          'https://raw.githubusercontent.com/$owner/$repo/$branch/${prefix}CHANGELOG.md',
        ),
      ];
    }

    return [
      Uri.parse(
        'https://raw.githubusercontent.com/$owner/$repo/main/CHANGELOG.md',
      ),
      Uri.parse(
        'https://raw.githubusercontent.com/$owner/$repo/master/CHANGELOG.md',
      ),
    ];
  }
}
