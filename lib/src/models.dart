class WhatsNewDigest {
  final DateTime since;
  final DateTime until;
  final List<PackageRelease> newPackages;
  final List<PackageRelease> updatedPackages;
  final List<SdkChangelogSection> sdkNextStableSections;
  final List<SdkDotRelease> sdkDotReleases;
  final List<PullRequestItem> languagePrs;
  final List<PullRequestItem> notablePrs;
  final List<FirstTimeContributor> firstTimeContributors;

  const WhatsNewDigest({
    required this.since,
    required this.until,
    required this.newPackages,
    required this.updatedPackages,
    required this.sdkNextStableSections,
    required this.sdkDotReleases,
    required this.languagePrs,
    required this.notablePrs,
    required this.firstTimeContributors,
  });

  Map<String, Object?> toJson() => {
    'since': since.toUtc().toIso8601String(),
    'until': until.toUtc().toIso8601String(),
    'newPackages': newPackages.map((e) => e.toJson()).toList(),
    'updatedPackages': updatedPackages.map((e) => e.toJson()).toList(),
    'sdkNextStableSections':
        sdkNextStableSections.map((e) => e.toJson()).toList(),
    'sdkDotReleases': sdkDotReleases.map((e) => e.toJson()).toList(),
    'languagePrs': languagePrs.map((e) => e.toJson()).toList(),
    'notablePrs': notablePrs.map((e) => e.toJson()).toList(),
    'firstTimeContributors':
        firstTimeContributors.map((e) => e.toJson()).toList(),
  };
}

class PackageRelease {
  final String name;
  final String version;
  final String publisher;
  final DateTime published;
  final String description;
  final String pubUrl;
  final String? repositoryUrl;
  final bool isNewPackage;
  final String? changelogExcerpt;

  const PackageRelease({
    required this.name,
    required this.version,
    required this.publisher,
    required this.published,
    required this.description,
    required this.pubUrl,
    this.repositoryUrl,
    required this.isNewPackage,
    this.changelogExcerpt,
  });

  Map<String, Object?> toJson() => {
    'name': name,
    'version': version,
    'publisher': publisher,
    'published': published.toUtc().toIso8601String(),
    'description': description,
    'pubUrl': pubUrl,
    if (repositoryUrl != null) 'repositoryUrl': repositoryUrl,
    'isNewPackage': isNewPackage,
    if (changelogExcerpt != null) 'changelogExcerpt': changelogExcerpt,
  };
}

class SdkChangelogSection {
  final String heading;
  final List<String> bullets;
  final List<SdkCommitRef> touchingCommits;

  const SdkChangelogSection({
    required this.heading,
    required this.bullets,
    this.touchingCommits = const [],
  });

  Map<String, Object?> toJson() => {
    'heading': heading,
    'bullets': bullets,
    'touchingCommits': touchingCommits.map((e) => e.toJson()).toList(),
  };
}

class SdkCommitRef {
  final String sha;
  final String title;
  final String authorLogin;
  final String url;
  final List<int> issueNumbers;
  final List<String> addedBullets;
  final int nonChangelogFileCount;
  final List<String> subsystems;
  final bool isChangelogCleanup;

  const SdkCommitRef({
    required this.sha,
    required this.title,
    required this.authorLogin,
    required this.url,
    this.issueNumbers = const [],
    this.addedBullets = const [],
    this.nonChangelogFileCount = 0,
    this.subsystems = const [],
    this.isChangelogCleanup = false,
  });

  Map<String, Object?> toJson() => {
    'sha': sha,
    'title': title,
    'authorLogin': authorLogin,
    'url': url,
    'issueNumbers': issueNumbers,
    if (addedBullets.isNotEmpty) 'addedBullets': addedBullets,
    'nonChangelogFileCount': nonChangelogFileCount,
    if (subsystems.isNotEmpty) 'subsystems': subsystems,
    'isChangelogCleanup': isChangelogCleanup,
  };
}

class SdkDotRelease {
  final String branchOrTag;
  final String summary;
  final String commitUrl;
  final DateTime date;
  final List<int> cherryPickIssues;

  const SdkDotRelease({
    required this.branchOrTag,
    required this.summary,
    required this.commitUrl,
    required this.date,
    this.cherryPickIssues = const [],
  });

  Map<String, Object?> toJson() => {
    'branchOrTag': branchOrTag,
    'summary': summary,
    'commitUrl': commitUrl,
    'date': date.toUtc().toIso8601String(),
    'cherryPickIssues': cherryPickIssues,
  };
}

class PullRequestItem {
  final String repo;
  final int number;
  final String title;
  final String url;
  final String authorLogin;
  final String? authorName;
  final List<String> coAuthors;
  final List<String> reviewers;
  final List<String> labels;
  final List<String> mediaUrls;
  final DateTime mergedAt;
  final int score;
  final bool isFirstTimeContributor;

  const PullRequestItem({
    required this.repo,
    required this.number,
    required this.title,
    required this.url,
    required this.authorLogin,
    this.authorName,
    this.coAuthors = const [],
    this.reviewers = const [],
    this.labels = const [],
    this.mediaUrls = const [],
    required this.mergedAt,
    required this.score,
    this.isFirstTimeContributor = false,
  });

  Map<String, Object?> toJson() => {
    'repo': repo,
    'number': number,
    'title': title,
    'url': url,
    'authorLogin': authorLogin,
    if (authorName != null) 'authorName': authorName,
    'coAuthors': coAuthors,
    'reviewers': reviewers,
    'labels': labels,
    'mediaUrls': mediaUrls,
    'mergedAt': mergedAt.toUtc().toIso8601String(),
    'score': score,
    'isFirstTimeContributor': isFirstTimeContributor,
  };
}

class FirstTimeContributor {
  final String login;
  final String? name;
  final String repo;
  final int prNumber;
  final String prTitle;
  final String prUrl;

  const FirstTimeContributor({
    required this.login,
    this.name,
    required this.repo,
    required this.prNumber,
    required this.prTitle,
    required this.prUrl,
  });

  Map<String, Object?> toJson() => {
    'login': login,
    if (name != null) 'name': name,
    'repo': repo,
    'prNumber': prNumber,
    'prTitle': prTitle,
    'prUrl': prUrl,
  };
}
