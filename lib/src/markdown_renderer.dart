import 'models.dart';

String renderDigestMarkdown(WhatsNewDigest digest) {
  final sinceStr = _shortDate(digest.since);
  final untilStr = _shortDate(digest.until);
  final buf =
      StringBuffer()
        ..writeln('# Dart Ecosystem What\'s New Digest')
        ..writeln()
        ..writeln('**Window**: `$sinceStr` to `$untilStr`')
        ..writeln();

  _writePackageSection(
    buf,
    title: '## 🆕 New Packages on pub.dev (${digest.newPackages.length})',
    packages: digest.newPackages,
  );
  _writePackageSection(
    buf,
    title:
        '## 📦 Updated Packages on pub.dev (${digest.updatedPackages.length})',
    packages: digest.updatedPackages,
  );
  _writeSdkNextStableSection(buf, digest.sdkNextStableSections);
  _writeSdkDotReleasesSection(buf, digest.sdkDotReleases);
  _writePrSection(
    buf,
    title: '## 📐 Language Spec & Feature PRs (${digest.languagePrs.length})',
    prs: digest.languagePrs,
  );
  _writePrSection(
    buf,
    title: '## 🚀 Notable Merged PRs (${digest.notablePrs.length})',
    prs: digest.notablePrs,
  );
  _writeFirstTimeContributorsSection(buf, digest.firstTimeContributors);

  return buf.toString();
}

void _writePackageSection(
  StringBuffer buf, {
  required String title,
  required List<PackageRelease> packages,
}) {
  buf
    ..writeln(title)
    ..writeln();
  if (packages.isEmpty) {
    buf.writeln('_None in this window._\n');
    return;
  }

  for (final pkg in packages) {
    final repoBit =
        pkg.repositoryUrl != null ? ' · [repo](${pkg.repositoryUrl})' : '';
    buf.writeln(
      '* **[`package:${pkg.name}` ${pkg.version}](${pkg.pubUrl})** '
      '(`publisher:${pkg.publisher}` · ${_shortDate(pkg.published)}$repoBit)',
    );
    if (pkg.description.isNotEmpty) {
      buf.writeln('  ${pkg.description}');
    }
    final excerpt = pkg.changelogExcerpt;
    if (excerpt != null && excerpt.isNotEmpty) {
      for (final line in excerpt.split('\n').take(12)) {
        buf.writeln('  > $line');
      }
    }
  }
  buf.writeln();
}

void _writeSdkNextStableSection(
  StringBuffer buf,
  List<SdkChangelogSection> sections,
) {
  buf
    ..writeln('## 🎯 Dart SDK — Next Stable (`CHANGELOG.md` Diff)')
    ..writeln();
  if (sections.isEmpty) {
    buf.writeln('_No `CHANGELOG.md` additions on `main` in this window._\n');
    return;
  }

  for (final sec in sections) {
    buf
      ..writeln('### ${sec.heading}')
      ..writeln();
    for (final bullet in sec.bullets) {
      buf.writeln('* $bullet');
    }
    buf.writeln();
  }

  final commits = sections.first.touchingCommits;
  if (commits.isNotEmpty) {
    buf
      ..writeln('#### Commits Touching SDK `CHANGELOG.md`')
      ..writeln();
    for (final c in commits) {
      buf.writeln(
        '* [`${c.sha}`](${c.url}) ${c.title} (by `@${c.authorLogin}`)',
      );
    }
    buf.writeln();
  }
}

void _writeSdkDotReleasesSection(
  StringBuffer buf,
  List<SdkDotRelease> releases,
) {
  buf
    ..writeln(
      '## 🛡️ Dart SDK — Stable & Beta Branch Commits (${releases.length})',
    )
    ..writeln();
  if (releases.isEmpty) {
    buf.writeln('_No `stable` or `beta` branch commits in this window._\n');
    return;
  }

  for (final r in releases) {
    final issueLinks = r.cherryPickIssues
        .map((i) => '[#$i](https://github.com/dart-lang/sdk/issues/$i)')
        .join(', ');
    final issuesBit = issueLinks.isNotEmpty ? ' (issues: $issueLinks)' : '';
    buf.writeln(
      '* **[`${r.branchOrTag}`](${r.commitUrl})** (${_shortDate(r.date)}): '
      '${r.summary}$issuesBit',
    );
  }
  buf.writeln();
}

void _writePrSection(
  StringBuffer buf, {
  required String title,
  required List<PullRequestItem> prs,
}) {
  buf
    ..writeln(title)
    ..writeln();
  if (prs.isEmpty) {
    buf.writeln('_None in this window._\n');
    return;
  }

  for (final pr in prs) {
    final authorLabel = pr.authorName ?? pr.authorLogin;
    final authorLink = '[$authorLabel](https://github.com/${pr.authorLogin})';
    final revLinks = pr.reviewers
        .map((r) => '[$r](https://github.com/$r)')
        .join(', ');
    final revBit = revLinks.isNotEmpty ? ' · reviewed by $revLinks' : '';
    final mediaBit =
        pr.mediaUrls.isNotEmpty ? ' · 🎬 ${pr.mediaUrls.length} media' : '';
    buf
      ..writeln(
        '* **[${pr.repo}#${pr.number}](${pr.url}) ${pr.title}** '
        '(score: `${pr.score}`$mediaBit)',
      )
      ..writeln('  * Authored by $authorLink$revBit.');
    for (final m in pr.mediaUrls) {
      buf.writeln('  * Media: $m');
    }
  }
  buf.writeln();
}

void _writeFirstTimeContributorsSection(
  StringBuffer buf,
  List<FirstTimeContributor> contributors,
) {
  buf
    ..writeln('## 🎉 First-Time Contributors (${contributors.length})')
    ..writeln();
  if (contributors.isEmpty) {
    buf.writeln('_None detected in this window._\n');
    return;
  }

  for (final c in contributors) {
    final display = c.name ?? c.login;
    buf.writeln(
      '* [$display](https://github.com/${c.login}) in '
      '[${c.repo}#${c.prNumber}](${c.prUrl}): **${c.prTitle}**',
    );
  }
  buf.writeln();
}

String _shortDate(DateTime dt) => dt.toUtc().toIso8601String().substring(0, 10);
