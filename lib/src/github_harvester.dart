import 'changelog_parser.dart';
import 'config.dart';
import 'github_client.dart';
import 'models.dart';

class GitHubHarvester {
  final GitHubApiClient _github;

  const GitHubHarvester(this._github);

  Future<
    ({
      List<PullRequestItem> languagePrs,
      List<PullRequestItem> notablePrs,
      List<FirstTimeContributor> firstTimeContributors,
    })
  >
  harvest({
    required GitHubConfig config,
    required String languageRepo,
    required DateTime since,
    required DateTime until,
  }) async {
    final rawPrs = await _searchMergedPrs(
      config: config,
      since: since,
      until: until,
    );

    final excludedRepos =
        config.excludeRepos.map((e) => e.toLowerCase()).toSet();
    final excludedAuthors =
        config.excludeAuthors.map((e) => e.toLowerCase()).toSet();
    final titleRegexes = config.excludePrTitlePatterns.map(RegExp.new).toList();
    final revertedTitles = _collectRevertedTitles(rawPrs);

    final languagePrs = <PullRequestItem>[];
    final notablePrs = <PullRequestItem>[];
    final firstTimers = <FirstTimeContributor>[];
    final seenFirstTimers = <String>{};

    for (final pr in rawPrs) {
      if (_shouldExcludePr(
        pr,
        excludedRepos: excludedRepos,
        excludedAuthors: excludedAuthors,
        titleRegexes: titleRegexes,
        revertedTitles: revertedTitles,
      )) {
        continue;
      }

      if (pr.repo.toLowerCase() == languageRepo.toLowerCase()) {
        languagePrs.add(pr);
      } else {
        notablePrs.add(pr);
      }

      if (pr.isFirstTimeContributor && seenFirstTimers.add(pr.authorLogin)) {
        firstTimers.add(
          FirstTimeContributor(
            login: pr.authorLogin,
            name: pr.authorName,
            repo: pr.repo,
            prNumber: pr.number,
            prTitle: pr.title,
            prUrl: pr.url,
          ),
        );
      }
    }

    languagePrs.sort((a, b) => b.score.compareTo(a.score));
    notablePrs.sort((a, b) => b.score.compareTo(a.score));

    return (
      languagePrs: languagePrs,
      notablePrs: notablePrs,
      firstTimeContributors: firstTimers,
    );
  }

  Set<String> _collectRevertedTitles(List<PullRequestItem> prs) {
    final reverted = <String>{};
    final revertPattern = RegExp('^Revert ["\'](.+)["\']\$');
    for (final pr in prs) {
      final match = revertPattern.firstMatch(pr.title.trim());
      if (match != null) {
        reverted.add(match.group(1)!.trim().toLowerCase());
      }
    }
    return reverted;
  }

  bool _shouldExcludePr(
    PullRequestItem pr, {
    required Set<String> excludedRepos,
    required Set<String> excludedAuthors,
    required List<RegExp> titleRegexes,
    required Set<String> revertedTitles,
  }) {
    if (excludedRepos.contains(pr.repo.toLowerCase())) return true;
    if (excludedAuthors.contains(pr.authorLogin.toLowerCase()) ||
        isLikelyBotAccount(pr.authorLogin)) {
      return true;
    }
    if (revertedTitles.contains(pr.title.trim().toLowerCase())) return true;
    return titleRegexes.any((re) => re.hasMatch(pr.title));
  }

  Future<List<PullRequestItem>> _searchMergedPrs({
    required GitHubConfig config,
    required DateTime since,
    required DateTime until,
  }) async {
    final sinceDate = _isoDate(since);
    final untilDate = _isoDate(until);
    final scopes = <String>[
      ...config.orgs.map((o) => 'org:$o'),
      ...config.repos.map((r) => 'repo:$r'),
    ];

    final results = <PullRequestItem>[];
    for (final scope in scopes) {
      final queryStr =
          '$scope is:pr is:merged merged:$sinceDate..$untilDate '
          'sort:updated-desc';
      final items = await _queryGraphQlScope(queryStr);
      results.addAll(items);
    }
    return results;
  }

  Future<List<PullRequestItem>> _queryGraphQlScope(String searchQuery) async {
    final response = await _github.postGraphQl(_prSearchGraphQlQuery, {
      'query': searchQuery,
    });
    if (response == null) return const [];

    final data = response['data'];
    if (data is! Map) return const [];
    final search = data['search'];
    if (search is! Map) return const [];
    final nodes = search['nodes'];
    if (nodes is! List) return const [];

    return nodes
        .whereType<Map<String, Object?>>()
        .map(_parsePrNode)
        .whereType<PullRequestItem>()
        .toList();
  }

  PullRequestItem? _parsePrNode(Map<String, Object?> node) {
    final number = node['number'] as int?;
    final title = node['title'] as String?;
    final url = node['url'] as String?;
    if (number == null || title == null || url == null) return null;

    final repoMap = (node['repository'] as Map<String, Object?>?) ?? const {};
    final repoName = (repoMap['nameWithOwner'] as String?) ?? '';

    final authorMap = (node['author'] as Map<String, Object?>?) ?? const {};
    var authorLogin = (authorMap['login'] as String?) ?? 'unknown';
    final authorName = authorMap['name'] as String?;

    final body = (node['body'] as String?) ?? '';
    final coAuthors = extractCoAuthors(body);
    if (isLikelyBotAccount(authorLogin) && coAuthors.isNotEmpty) {
      authorLogin = coAuthors.first;
    }

    final reviewers = _extractHumanReviewers(node['reviews'], authorLogin);
    final labels = _extractLabelNames(node['labels']);
    final mediaUrls = extractMediaUrls(body);
    final association = (node['authorAssociation'] as String?) ?? '';
    final isFirstTime =
        association == 'FIRST_TIME_CONTRIBUTOR' || association == 'FIRST_TIMER';

    final reactionsMap =
        (node['reactions'] as Map<String, Object?>?) ?? const {};
    final commentsMap = (node['comments'] as Map<String, Object?>?) ?? const {};
    final score = scorePullRequest(
      title: title,
      reactions: (reactionsMap['totalCount'] as int?) ?? 0,
      comments: (commentsMap['totalCount'] as int?) ?? 0,
      additions: (node['additions'] as int?) ?? 0,
      deletions: (node['deletions'] as int?) ?? 0,
      labels: labels,
      mediaUrls: mediaUrls,
      isFirstTimeContributor: isFirstTime,
    );

    final mergedAtStr = node['mergedAt'] as String?;
    final mergedAt =
        mergedAtStr != null
            ? DateTime.parse(mergedAtStr)
            : DateTime.now().toUtc();

    return PullRequestItem(
      repo: repoName,
      number: number,
      title: title,
      url: url,
      authorLogin: authorLogin,
      authorName: authorName,
      coAuthors: coAuthors,
      reviewers: reviewers,
      labels: labels,
      mediaUrls: mediaUrls,
      mergedAt: mergedAt,
      score: score,
      isFirstTimeContributor: isFirstTime,
    );
  }

  List<String> _extractHumanReviewers(Object? reviewsNode, String authorLogin) {
    if (reviewsNode is! Map) return const [];
    final nodes = reviewsNode['nodes'];
    if (nodes is! List) return const [];

    final reviewers = <String>{};
    for (final r in nodes.whereType<Map<String, Object?>>()) {
      final author = r['author'];
      if (author is! Map) continue;
      final login = author['login'] as String?;
      if (login == null ||
          login.toLowerCase() == authorLogin.toLowerCase() ||
          isLikelyBotAccount(login)) {
        continue;
      }
      reviewers.add(login);
    }
    return reviewers.toList(growable: false);
  }

  List<String> _extractLabelNames(Object? labelsNode) {
    if (labelsNode is! Map) return const [];
    final nodes = labelsNode['nodes'];
    if (nodes is! List) return const [];
    return nodes
        .whereType<Map<String, Object?>>()
        .map((n) => n['name'])
        .whereType<String>()
        .toList(growable: false);
  }
}

String _isoDate(DateTime dt) => dt.toUtc().toIso8601String().substring(0, 10);

const _prSearchGraphQlQuery = r'''
query SearchMergedPrs($query: String!) {
  search(query: $query, type: ISSUE, first: 100) {
    nodes {
      ... on PullRequest {
        number
        title
        url
        body
        mergedAt
        additions
        deletions
        authorAssociation
        repository {
          nameWithOwner
        }
        author {
          login
          ... on User {
            name
          }
        }
        reactions {
          totalCount
        }
        comments {
          totalCount
        }
        labels(first: 10) {
          nodes {
            name
          }
        }
        reviews(first: 20) {
          nodes {
            author {
              login
            }
          }
        }
      }
    }
  }
}
''';
