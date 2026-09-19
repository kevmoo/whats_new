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

/// Parses a unified git patch for `dart-lang/sdk` `CHANGELOG.md` into sections.
List<SdkChangelogSection> parseSdkChangelogPatch(
  String patch, {
  List<SdkCommitRef> touchingCommits = const [],
}) {
  final state = _PatchParserState();
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

class _PatchParserState {
  final sectionMap = <String, List<String>>{};
  String currentHeading = 'General';
  String? currentBullet;

  void flushBullet() {
    final text = currentBullet?.trim();
    if (text != null && text.isNotEmpty) {
      sectionMap.putIfAbsent(currentHeading, () => []).add(text);
    }
    currentBullet = null;
  }

  void processLine(String rawLine) {
    if (rawLine.startsWith('+++') || rawLine.startsWith('@@')) {
      flushBullet();
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
