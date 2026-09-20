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

    final fullChangelog = await _github.getText(
      Uri.parse('https://raw.githubusercontent.com/$repo/main/CHANGELOG.md'),
    );
    final changelogLines = fullChangelog?.split('\n') ?? const <String>[];

    final commitMaps = rawList.whereType<Map<String, Object?>>().toList();
    final sectionsByHeading =
        <String, ({List<String> bullets, List<SdkCommitRef> commits})>{};

    for (final summaryMap in commitMaps.reversed) {
      await _inspectChangelogCommit(
        repo: repo,
        summaryMap: summaryMap,
        changelogLines: changelogLines,
        sectionsByHeading: sectionsByHeading,
      );
    }

    return sectionsByHeading.entries
        .map(
          (e) => SdkChangelogSection(
            heading: e.key,
            bullets: e.value.bullets,
            touchingCommits: e.value.commits,
          ),
        )
        .toList(growable: false);
  }

  Future<void> _inspectChangelogCommit({
    required String repo,
    required Map<String, Object?> summaryMap,
    required List<String> changelogLines,
    required Map<String, ({List<String> bullets, List<SdkCommitRef> commits})>
    sectionsByHeading,
  }) async {
    final fullSha = (summaryMap['sha'] as String?) ?? '';
    if (fullSha.isEmpty) return;

    final detailJson = await _github.getJson(
      Uri.https('api.github.com', '/repos/$repo/commits/$fullSha'),
    );
    final detailMap =
        detailJson is Map ? Map<String, Object?>.from(detailJson) : summaryMap;

    final files =
        (detailMap['files'] as List?)
            ?.whereType<Map<String, Object?>>()
            .toList() ??
        const <Map<String, Object?>>[];
    final patch = _findChangelogPatchFromFiles(files);
    if (patch == null) return;

    final codeFiles =
        files
            .map((f) => (f['filename'] as String?) ?? '')
            .where((name) => name.isNotEmpty && name != 'CHANGELOG.md')
            .toList();

    final parsedSections = parseSdkChangelogPatch(
      patch,
      fullChangelogLines: changelogLines,
    );
    final allAddedBullets = parsedSections
        .expand((s) => s.bullets)
        .toList(growable: false);
    final baseRef = _parseBaseCommitRef(detailMap);
    final isCleanup = isCommitChangelogCleanup(
      patch: patch,
      addedBulletCount: allAddedBullets.length,
      nonChangelogFileCount: codeFiles.length,
      commitTitle: baseRef.title,
    );

    if (isCleanup) {
      final cleanupRef = _buildCommitRef(
        baseRef: baseRef,
        addedBullets: allAddedBullets,
        codeFiles: codeFiles,
        isChangelogCleanup: true,
      );
      final bucket = sectionsByHeading.putIfAbsent(
        '🧹 CHANGELOG-Only Cleanups / Edits',
        () => (bullets: <String>[], commits: <SdkCommitRef>[]),
      );
      bucket.commits.add(cleanupRef);
      return;
    }

    for (final section in parsedSections) {
      final commitRef = _buildCommitRef(
        baseRef: baseRef,
        addedBullets: section.bullets,
        codeFiles: codeFiles,
        isChangelogCleanup: false,
      );
      final bucket = sectionsByHeading.putIfAbsent(
        section.heading,
        () => (bullets: <String>[], commits: <SdkCommitRef>[]),
      );
      bucket.bullets.addAll(section.bullets);
      bucket.commits.add(commitRef);
    }
  }

  SdkCommitRef _buildCommitRef({
    required SdkCommitRef baseRef,
    required List<String> addedBullets,
    required List<String> codeFiles,
    required bool isChangelogCleanup,
  }) => SdkCommitRef(
    sha: baseRef.sha,
    title: baseRef.title,
    authorLogin: baseRef.authorLogin,
    url: baseRef.url,
    issueNumbers: baseRef.issueNumbers,
    addedBullets: addedBullets,
    nonChangelogFileCount: codeFiles.length,
    subsystems: extractSdkSubsystems(codeFiles),
    isChangelogCleanup: isChangelogCleanup,
  );

  SdkCommitRef _parseBaseCommitRef(Map<String, Object?> map) {
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

  String? _findChangelogPatchFromFiles(List<Map<String, Object?>> files) {
    for (final file in files) {
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
