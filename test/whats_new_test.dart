import 'dart:io';

import 'package:test/test.dart';
import 'package:whats_new/whats_new.dart';

void main() {
  group('WhatsNewConfig', () {
    test('config.yaml matches embedded defaultConfigYaml and parses', () {
      final diskContent = File('config.yaml').readAsStringSync();
      expect(diskContent, defaultConfigYaml);

      final config = WhatsNewConfig.defaultConfig();
      expect(
        config.pubPublishers,
        containsAll(['dart.dev', 'tools.dart.dev', 'labs.dart.dev']),
      );
      expect(config.sdk.repo, 'dart-lang/sdk');
      expect(config.sdk.languageRepo, 'dart-lang/language');
      expect(config.github.orgs, contains('dart-lang'));
      expect(config.github.repos, contains('googleapis/google-cloud-dart'));
    });
  });

  group('Changelog & SDK Diff Parsers', () {
    test('extractChangelogVersionSection slices matching version block', () {
      const sampleChangelog = '''
## 2.16.1

- Fix incremental rebuild caching bug.
- Support workspace resolution.

## 2.16.0

- Older release note.
''';
      final section = extractChangelogVersionSection(sampleChangelog, '2.16.1');
      expect(
        section,
        '- Fix incremental rebuild caching bug.\n'
        '- Support workspace resolution.',
      );
      expect(extractChangelogVersionSection(sampleChangelog, '9.9.9'), isNull);
    });

    test('parseSdkChangelogPatch groups added bullets by subsection', () {
      const samplePatch = '''
@@ -10,4 +10,9 @@
 #### `dart:typed_data`
 
+- Added `Int32x4.splat`, which creates an `Int32x4` with the same value
+  in all four lanes.
+- Added `Int32x4.abs`.
+
+#### `dart:js_interop`
+
+- Added `JSArray.fromAsync`.
''';
      final sections = parseSdkChangelogPatch(samplePatch);
      expect(sections, hasLength(2));
      expect(sections[0].heading, '`dart:typed_data`');
      const splatBullet =
          'Added `Int32x4.splat`, which creates an `Int32x4` with the same '
          'value in all four lanes.';
      expect(sections[0].bullets, [splatBullet, 'Added `Int32x4.abs`.']);
      expect(sections[1].heading, '`dart:js_interop`');
      expect(sections[1].bullets, ['Added `JSArray.fromAsync`.']);
    });

    test(
      'resolveEnclosingChangelogHeading & isCommitChangelogCleanup work back',
      () {
        final fullChangelog = [
          '## 3.14.0',
          '### Core libraries',
          '#### `dart:typed_data`',
          '',
          '- Existing bullet 1.',
          '- Existing bullet 2.',
          '- Existing bullet 3.',
          '- Existing bullet 4.',
          '- Added `Int32x4.min` and `Int32x4.max`.',
        ];
        const patchWithDistantHeader = '''
@@ -7,2 +7,3 @@
 - Existing bullet 4.
+- Added `Int32x4.min` and `Int32x4.max`.
''';
        final parsed = parseSdkChangelogPatch(
          patchWithDistantHeader,
          fullChangelogLines: fullChangelog,
        );
        expect(parsed, hasLength(1));
        expect(parsed.first.heading, '`dart:typed_data`');

        expect(
          isCommitChangelogCleanup(
            patch: '- - Old typo text.\n+ - Fixed typo text.',
            addedBulletCount: 1,
            nonChangelogFileCount: 0,
            commitTitle: 'Fix typo in CHANGELOG.md',
          ),
          isTrue,
        );
        expect(
          isCommitChangelogCleanup(
            patch: patchWithDistantHeader,
            addedBulletCount: 1,
            nonChangelogFileCount: 4,
            commitTitle: '[typed_data] Add Int32x4.min and Int32x4.max',
          ),
          isFalse,
        );
        expect(
          extractSdkSubsystems([
            'CHANGELOG.md',
            'sdk/lib/_internal/vm/lib/simd_patch.dart',
            'tests/lib/typed_data/int32x4_test.dart',
          ]),
          ['sdk/lib', 'tests/lib'],
        );
      },
    );
  });

  group('PR Notability Scorer & Metadata Extraction', () {
    test('scorePullRequest rewards reactions, media, and P0/P1 labels', () {
      final highSignalScore = scorePullRequest(
        title: 'feat(web): support --web-content-hash',
        reactions: 4,
        comments: 15,
        additions: 350,
        deletions: 40,
        labels: const ['P1'],
        mediaUrls: const ['https://github.com/user-attachments/assets/abc.png'],
        isFirstTimeContributor: true,
      );
      final revertScore = scorePullRequest(
        title: 'Revert "feat(web): support --web-content-hash"',
        reactions: 0,
        comments: 0,
        additions: 10,
        deletions: 350,
        labels: const [],
        mediaUrls: const [],
        isFirstTimeContributor: false,
      );

      expect(highSignalScore, greaterThan(50));
      expect(revertScore, lessThan(0));
    });

    test('extractCoAuthors and extractMediaUrls parse trailers and assets', () {
      const prBody = '''
Adds new shader preview.
![Preview](https://github.com/user-attachments/assets/1234-5678)
<video src="https://example.com/demo.mp4" controls></video>

Co-authored-by: Jane Doe <jane@example.com>
Co-authored-by: dependabot[bot] <dependabot@users.noreply.github.com>
''';
      expect(extractCoAuthors(prBody), ['Jane Doe']);
      expect(
        extractMediaUrls(prBody),
        containsAll([
          'https://github.com/user-attachments/assets/1234-5678',
          'https://example.com/demo.mp4',
        ]),
      );
    });

    test('renderDigestMarkdown produces deterministic sections', () {
      final digest = WhatsNewDigest(
        since: DateTime.utc(2026, 9, 12),
        until: DateTime.utc(2026, 9, 19),
        newPackages: [
          PackageRelease(
            name: 'foo_new',
            version: '0.1.0',
            publisher: 'dart.dev',
            published: DateTime.utc(2026, 9, 15),
            description: 'A brand new package.',
            pubUrl: 'https://pub.dev/packages/foo_new/versions/0.1.0',
            isNewPackage: true,
          ),
        ],
        updatedPackages: const [],
        sdkNextStableSections: const [],
        sdkDotReleases: const [],
        languagePrs: const [],
        notablePrs: const [],
        firstTimeContributors: const [],
      );

      final md = renderDigestMarkdown(digest);
      expect(md, contains('`2026-09-12` to `2026-09-19`'));
      expect(md, contains('`package:foo_new` 0.1.0'));
    });
  });
}
