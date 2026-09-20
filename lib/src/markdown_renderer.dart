import 'changelog_parser.dart';
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

  _writeRepoGroupedSummary(buf, digest);
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
    if (sec.touchingCommits.isNotEmpty) {
      _writeSdkSectionCommits(buf, sec.touchingCommits);
    } else {
      for (final bullet in sec.bullets) {
        buf.writeln('* $bullet');
      }
    }
    buf.writeln();
  }
}

void _writeSdkSectionCommits(StringBuffer buf, List<SdkCommitRef> commits) {
  for (final c in commits) {
    for (final bullet in c.addedBullets) {
      buf.writeln('* $bullet');
    }
    buf.writeln('  * ↳ ${_formatSdkCommitWorkback(c)}');
  }
}

String _formatSdkCommitWorkback(SdkCommitRef c) {
  final scopeTag =
      c.isChangelogCleanup
          ? '🧹 `CHANGELOG.md`-only edit/cleanup'
          : c.nonChangelogFileCount > 0
          ? '🛠️ ${c.nonChangelogFileCount} code/test files '
              '(${c.subsystems.map((s) => '`$s`').join(', ')})'
          : '📝 standalone `CHANGELOG.md` entry';
  return '[`${c.sha}`](${c.url}) ${c.title} '
      '(by `@${c.authorLogin}` · $scopeTag)';
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

typedef _RepoRow =
    ({String type, String target, String ref, String summary, String author});

void _writeRepoGroupedSummary(StringBuffer buf, WhatsNewDigest digest) {
  final byRepo = <String, List<_RepoRow>>{};
  _addSdkRowsByRepo(byRepo, digest);
  _addPackageRowsByRepo(byRepo, digest.newPackages, isNew: true);
  _addPackageRowsByRepo(byRepo, digest.updatedPackages, isNew: false);
  _addPrRowsByRepo(byRepo, digest.languagePrs, typeLabel: '📐 Language Spec');
  _addPrRowsByRepo(
    byRepo,
    digest.notablePrs.where((p) => p.score >= 10),
    typeLabel: '🚀 Merged PR',
  );

  if (byRepo.isEmpty) return;

  buf
    ..writeln('## 🗂️ Highlights by Repository')
    ..writeln();
  for (final entry in byRepo.entries) {
    final repo = entry.key;
    final repoHeader =
        repo.contains('/') ? '[$repo](https://github.com/$repo)' : '`$repo`';
    buf
      ..writeln('### $repoHeader')
      ..writeln()
      ..writeln('| Type | Target | Version / Ref | Summary | Author |')
      ..writeln('| :--- | :--- | :--- | :--- | :--- |');
    for (final r in entry.value) {
      buf.writeln(
        '| ${r.type} | ${r.target} | ${r.ref} | ${r.summary} | ${r.author} |',
      );
    }
    buf.writeln();
  }
}

void _addSdkRowsByRepo(
  Map<String, List<_RepoRow>> byRepo,
  WhatsNewDigest digest,
) {
  final sdkRows = byRepo.putIfAbsent('dart-lang/sdk', () => []);
  for (final dot in digest.sdkDotReleases) {
    sdkRows.add((
      type: '🛡️ SDK (`${dot.branchOrTag}`)',
      target: dot.summary,
      ref: '[commit](${dot.commitUrl})',
      summary: dot.summary,
      author: '`dart-lang/sdk`',
    ));
  }
  for (final sec in digest.sdkNextStableSections) {
    for (final c in sec.touchingCommits) {
      if (c.isChangelogCleanup) continue;
      sdkRows.add((
        type: '🎯 SDK (`main`)',
        target: sec.heading,
        ref: '[`${c.sha}`](${c.url})',
        summary: '${c.title} (`🛠️ ${c.nonChangelogFileCount} files`)',
        author: '`@${c.authorLogin}`',
      ));
    }
  }
  if (sdkRows.isEmpty) byRepo.remove('dart-lang/sdk');
}

void _addPackageRowsByRepo(
  Map<String, List<_RepoRow>> byRepo,
  List<PackageRelease> packages, {
  required bool isNew,
}) {
  final typeLabel = isNew ? '🆕 New Package' : '📦 Updated Package';
  for (final p in packages) {
    final repo = extractGitHubRepoSlug(p.repositoryUrl) ?? p.publisher;
    final summary = _firstChangelogLine(p.changelogExcerpt) ?? p.description;
    byRepo.putIfAbsent(repo, () => []).add((
      type: typeLabel,
      target: '[`package:${p.name}`](${p.pubUrl})',
      ref: '`${p.version}`',
      summary: summary.replaceAll('|', r'\|'),
      author: '`${p.publisher}`',
    ));
  }
}

void _addPrRowsByRepo(
  Map<String, List<_RepoRow>> byRepo,
  Iterable<PullRequestItem> prs, {
  required String typeLabel,
}) {
  for (final pr in prs) {
    final author = pr.authorName ?? '@${pr.authorLogin}';
    byRepo.putIfAbsent(pr.repo, () => []).add((
      type: typeLabel,
      target: '[${pr.repo}#${pr.number}](${pr.url})',
      ref: 'score `${pr.score}`',
      summary: pr.title.replaceAll('|', r'\|'),
      author: '[$author](https://github.com/${pr.authorLogin})',
    ));
  }
}

String? _firstChangelogLine(String? excerpt) {
  if (excerpt == null || excerpt.isEmpty) return null;
  for (final raw in excerpt.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    if (line.startsWith('- ') || line.startsWith('* ')) {
      return line.substring(2).trim();
    }
    return line;
  }
  return null;
}

String _shortDate(DateTime dt) => dt.toUtc().toIso8601String().substring(0, 10);
