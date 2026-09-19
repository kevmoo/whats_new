import 'changelog_parser.dart';
import 'config.dart';
import 'github_client.dart';
import 'models.dart';

class SdkHarvester {
  final GitHubApiClient _github;

  const SdkHarvester(this._github);

  Future<
    ({
      List<SdkChangelogSection> nextStableSections,
      List<SdkDotRelease> dotReleases,
    })
  >
  harvest({
    required SdkConfig config,
    required DateTime since,
    required DateTime until,
  }) async {
    final nextStable =
        config.trackMainChangelog
            ? await _harvestMainChangelog(
              repo: config.repo,
              since: since,
              until: until,
            )
            : const <SdkChangelogSection>[];

    final dotReleases = <SdkDotRelease>[];
    for (final branch in config.trackStableBranches) {
      final branchCommits = await _harvestBranchCommits(
        repo: config.repo,
        branch: branch,
        since: since,
        until: until,
      );
      dotReleases.addAll(branchCommits);
    }

    return (nextStableSections: nextStable, dotReleases: dotReleases);
  }

  Future<List<SdkChangelogSection>> _harvestMainChangelog({
    required String repo,
    required DateTime since,
    required DateTime until,
  }) async {
    final commitsUri = Uri.https('api.github.com', '/repos/$repo/commits', {
      'path': 'CHANGELOG.md',
      'since': since.toUtc().toIso8601String(),
      'until': until.toUtc().toIso8601String(),
      'per_page': '50',
    });

    final rawList = await _github.getJson(commitsUri);
    if (rawList is! List || rawList.isEmpty) return const [];

    final commitMaps = rawList.whereType<Map<String, Object?>>().toList();
    final touchingCommits = commitMaps.map(_parseCommitRef).toList();

    final newestSha = commitMaps.first['sha'] as String?;
    final oldestMap = commitMaps.last;
    final baseSha =
        _extractParentSha(oldestMap) ?? (oldestMap['sha'] as String?);
    if (newestSha == null || baseSha == null) return const [];

    final compareUri = Uri.https(
      'api.github.com',
      '/repos/$repo/compare/$baseSha...$newestSha',
    );
    final compareJson = await _github.getJson(compareUri);
    if (compareJson is! Map) return const [];

    final patch = _findChangelogPatch(Map<String, Object?>.from(compareJson));
    if (patch == null) return const [];

    return parseSdkChangelogPatch(patch, touchingCommits: touchingCommits);
  }

  SdkCommitRef _parseCommitRef(Map<String, Object?> map) {
    final sha = (map['sha'] as String?) ?? '';
    final commitObj =
        (map['commit'] as Map<String, Object?>?) ?? const <String, Object?>{};
    final message = (commitObj['message'] as String?) ?? '';
    final headline = message.split('\n').first.trim();
    final authorObj = (map['author'] as Map<String, Object?>?) ?? const {};
    final login = (authorObj['login'] as String?) ?? 'unknown';
    final url = (map['html_url'] as String?) ?? '';

    return SdkCommitRef(
      sha: sha.length > 8 ? sha.substring(0, 8) : sha,
      title: headline,
      authorLogin: login,
      url: url,
      issueNumbers: extractIssueNumbers(message),
    );
  }

  String? _extractParentSha(Map<String, Object?> commitMap) {
    final parents = commitMap['parents'];
    if (parents is List && parents.isNotEmpty) {
      final first = parents.first;
      if (first is Map) return first['sha'] as String?;
    }
    return null;
  }

  String? _findChangelogPatch(Map<String, Object?> compareJson) {
    final files = compareJson['files'];
    if (files is! List) return null;
    for (final file in files.whereType<Map<String, Object?>>()) {
      if (file['filename'] == 'CHANGELOG.md') {
        return file['patch'] as String?;
      }
    }
    return null;
  }

  Future<List<SdkDotRelease>> _harvestBranchCommits({
    required String repo,
    required String branch,
    required DateTime since,
    required DateTime until,
  }) async {
    final uri = Uri.https('api.github.com', '/repos/$repo/commits', {
      'sha': branch,
      'since': since.toUtc().toIso8601String(),
      'until': until.toUtc().toIso8601String(),
      'per_page': '30',
    });

    final rawList = await _github.getJson(uri);
    if (rawList is! List || rawList.isEmpty) return const [];

    final releases = <SdkDotRelease>[];
    for (final item in rawList.whereType<Map<String, Object?>>()) {
      final commitObj =
          (item['commit'] as Map<String, Object?>?) ??
          const <String, Object?>{};
      final message = (commitObj['message'] as String?) ?? '';
      final headline = message.split('\n').first.trim();
      final committer =
          (commitObj['committer'] as Map<String, Object?>?) ?? const {};
      final dateStr = committer['date'] as String?;
      final date =
          dateStr != null ? DateTime.parse(dateStr) : DateTime.now().toUtc();
      final url = (item['html_url'] as String?) ?? '';

      releases.add(
        SdkDotRelease(
          branchOrTag: branch,
          summary: headline,
          commitUrl: url,
          date: date,
          cherryPickIssues: extractIssueNumbers(message),
        ),
      );
    }
    return releases;
  }
}
