import 'models.dart';

final _versionHeaderPattern = RegExp(r'^##\s+\[?v?([^\s\]]+)\]?');
final _h3OrH4Pattern = RegExp(r'^#{3,4}\s+(.+)$');
final _coAuthorPattern = RegExp(
  r'Co-authored-by:\s*([^<\r\n]+)\s*<([^>\r\n]+)>',
  caseSensitive: false,
);
final _markdownMediaPattern = RegExp(
  r'!\[[^\]]*\]\((https?://[^\s)]+)\)',
  caseSensitive: false,
);
final _htmlMediaPattern = RegExp(
  r'<(?:img|video)\s+[^>]*src=["\x27](https?://[^"\x27]+)["\x27]',
  caseSensitive: false,
);
final _issueRefPattern = RegExp(r'#(\d{4,6})\b');

/// Extracts the release notes block for [targetVersion] from [changelog].
String? extractChangelogVersionSection(String changelog, String targetVersion) {
  final buffer = <String>[];
  var capturing = false;

  for (final rawLine in changelog.split('\n')) {
    final line = rawLine.trimRight();
    final headerVersion = _matchVersionHeader(line);
    if (headerVersion != null) {
      if (capturing) break;
      capturing = headerVersion == targetVersion;
      continue;
    }
    if (capturing) buffer.add(line);
  }

  final joined = buffer.join('\n').trim();
  return joined.isEmpty ? null : joined;
}

String? _matchVersionHeader(String line) =>
    _versionHeaderPattern.firstMatch(line)?.group(1)?.trim();

final _hunkHeaderPattern = RegExp(r'^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@');

/// Parses a unified git patch for `dart-lang/sdk` `CHANGELOG.md` into sections.
List<SdkChangelogSection> parseSdkChangelogPatch(
  String patch, {
  List<SdkCommitRef> touchingCommits = const [],
  List<String> fullChangelogLines = const [],
}) {
  final state = _PatchParserState(fullChangelogLines: fullChangelogLines);
  for (final rawLine in patch.split('\n')) {
    state.processLine(rawLine);
  }
  state.flushBullet();

  return state.sectionMap.entries
      .map(
        (e) => SdkChangelogSection(
          heading: e.key,
          bullets: e.value,
          touchingCommits: touchingCommits,
        ),
      )
      .toList(growable: false);
}

/// Counts how many markdown bullets (`- ` or `* `) were removed in [patch].
int countRemovedChangelogBullets(String patch) {
  var count = 0;
  for (final line in patch.split('\n')) {
    if (!line.startsWith('-') || line.startsWith('---')) continue;
    final trimmed = line.substring(1).trimLeft();
    if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
      count++;
    }
  }
  return count;
}

/// Classifies whether a `CHANGELOG.md` commit is a copy-edit/cleanup rather
/// than a net-new SDK feature or bugfix.
bool isCommitChangelogCleanup({
  required String patch,
  required int addedBulletCount,
  required int nonChangelogFileCount,
  required String commitTitle,
}) {
  if (nonChangelogFileCount > 0) return false;
  if (addedBulletCount == 0) return true;
  final removedBulletCount = countRemovedChangelogBullets(patch);
  if (removedBulletCount >= addedBulletCount) return true;
  final lowerTitle = commitTitle.toLowerCase();
  return lowerTitle.contains('typo') ||
      lowerTitle.contains('format') ||
      lowerTitle.contains('spelling');
}

/// Extracts up to 3 concise SDK subsystem paths from modified file paths.
List<String> extractSdkSubsystems(Iterable<String> filenames) {
  final subsystems = <String>{};
  for (final file in filenames) {
    if (file == 'CHANGELOG.md') continue;
    final parts = file.split('/');
    if (parts.length >= 2) {
      subsystems.add('${parts[0]}/${parts[1]}');
    } else if (parts.isNotEmpty) {
      subsystems.add(parts.first);
    }
    if (subsystems.length >= 3) break;
  }
  return subsystems.toList(growable: false);
}

final _githubRepoSlugPattern = RegExp(
  r'github\.com/([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)',
);

/// Extracts `owner/repo` from a GitHub URL, stripping `.git` suffixes.
String? extractGitHubRepoSlug(String? url) {
  if (url == null || url.isEmpty) return null;
  final match = _githubRepoSlugPattern.firstMatch(url);
  if (match == null) return null;
  final slug = match.group(1)!;
  return slug.endsWith('.git') ? slug.substring(0, slug.length - 4) : slug;
}

class _PatchParserState {
  final List<String> fullChangelogLines;
  final sectionMap = <String, List<String>>{};
  String currentHeading = 'General';
  String? currentBullet;

  _PatchParserState({this.fullChangelogLines = const []});

  void flushBullet() {
    final text = currentBullet?.trim();
    if (text != null && text.isNotEmpty) {
      sectionMap.putIfAbsent(currentHeading, () => []).add(text);
    }
    currentBullet = null;
  }

  void processLine(String rawLine) {
    if (rawLine.startsWith('+++')) {
      flushBullet();
      return;
    }
    if (rawLine.startsWith('@@')) {
      flushBullet();
      _resolveHeadingFromHunkLine(rawLine);
      return;
    }
    if (rawLine.startsWith(' ')) {
      _updateHeadingIfMatched(rawLine.substring(1));
      return;
    }
    if (!rawLine.startsWith('+')) return;

    final added = rawLine.substring(1).trimRight();
    if (_updateHeadingIfMatched(added)) return;
    _appendAddedLine(added);
  }

  void _resolveHeadingFromHunkLine(String rawLine) {
    if (fullChangelogLines.isEmpty) return;
    final match = _hunkHeaderPattern.firstMatch(rawLine);
    final startLine = int.tryParse(match?.group(1) ?? '');
    if (startLine == null) return;
    final resolved = resolveEnclosingChangelogHeading(
      fullChangelogLines,
      startLine,
    );
    if (resolved != null) currentHeading = resolved;
  }

  bool _updateHeadingIfMatched(String text) {
    final match = _h3OrH4Pattern.firstMatch(text);
    if (match == null) return false;
    flushBullet();
    currentHeading = match.group(1)!.trim();
    return true;
  }

  void _appendAddedLine(String added) {
    final trimmed = added.trim();
    if (trimmed.isEmpty || trimmed.startsWith('[#')) return;
    if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
      flushBullet();
      currentBullet = trimmed.substring(2).trim();
    } else if (currentBullet != null) {
      currentBullet = '$currentBullet $trimmed';
    }
  }
}

/// Scans upward from [oneBasedLine] in [changelogLines] to find the enclosing
/// `###` or `####` section heading.
String? resolveEnclosingChangelogHeading(
  List<String> changelogLines,
  int oneBasedLine,
) {
  if (changelogLines.isEmpty) return null;
  final startIdx = (oneBasedLine - 1).clamp(0, changelogLines.length - 1);
  for (var i = startIdx; i >= 0; i--) {
    final line = changelogLines[i];
    if (_versionHeaderPattern.hasMatch(line)) break;
    final match = _h3OrH4Pattern.firstMatch(line);
    if (match != null) return match.group(1)!.trim();
  }
  return null;
}

/// Extracts unique issue numbers (e.g. `#63811`) from a commit/PR message.
List<int> extractIssueNumbers(String text) => _issueRefPattern
    .allMatches(text)
    .map((m) => int.tryParse(m.group(1)!))
    .whereType<int>()
    .toSet()
    .toList(growable: false);

/// Extracts `Co-authored-by` names from a PR body or commit messages.
List<String> extractCoAuthors(String text) => _coAuthorPattern
    .allMatches(text)
    .map((m) => m.group(1)!.trim())
    .where((name) => !isLikelyBotAccount(name))
    .toSet()
    .toList(growable: false);

/// Extracts image and video URLs embedded in a PR body.
List<String> extractMediaUrls(String? body) {
  if (body == null || body.isEmpty) return const [];
  final urls = <String>{
    ..._markdownMediaPattern.allMatches(body).map((m) => m.group(1)!),
    ..._htmlMediaPattern.allMatches(body).map((m) => m.group(1)!),
  };
  return urls.toList(growable: false);
}

/// Heuristic check for automated rollers and bot accounts.
bool isLikelyBotAccount(String loginOrName) {
  final lower = loginOrName.toLowerCase().trim();
  if (lower.endsWith('[bot]') ||
      lower.endsWith('-bot') ||
      lower.endsWith('-roller') ||
      lower.endsWith('-autoroll')) {
    return true;
  }
  return _knownBots.contains(lower);
}

const _knownBots = {
  'auto-submit',
  'copybara',
  'dart-ert',
  'dart-internal-client',
  'dependabot',
  'engine-flutter-autoroll',
  'flutter-pub-roller-bot',
  'flutteractionsbot',
  'fluttergithubbot',
  'gemini-code-assist',
  'github-actions',
  'google-cla',
  'google-copybara',
  'renovate',
  'skia-flutter-autoroll',
};

/// Deterministic PR notability scorer adapted from `flutter-changelog`.
int scorePullRequest({
  required String title,
  required int reactions,
  required int comments,
  required int additions,
  required int deletions,
  required List<String> labels,
  required List<String> mediaUrls,
  required bool isFirstTimeContributor,
}) {
  var score = reactions * 5;
  score += _commentTierScore(comments);
  if (additions > 300 || deletions > 300) score += 10;
  if (mediaUrls.isNotEmpty) score += 20;
  if (isFirstTimeContributor) score += 2;
  score += _priorityLabelScore(labels);
  if (title.toLowerCase().contains('reland') ||
      title.toLowerCase().contains('revert')) {
    score -= 20;
  }
  return score;
}

int _commentTierScore(int comments) {
  var bonus = 0;
  if (comments > 10) bonus += 5;
  if (comments > 20) bonus += 5;
  if (comments > 40) bonus += 5;
  return bonus;
}

int _priorityLabelScore(List<String> labels) {
  final upper = labels.map((l) => l.toUpperCase()).toSet();
  if (upper.contains('P0') || upper.contains('P1') || upper.contains('P2')) {
    return 10;
  }
  if (upper.contains('P3')) return 5;
  return 0;
}
