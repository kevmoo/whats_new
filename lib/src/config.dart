import 'dart:io';

import 'package:checked_yaml/checked_yaml.dart';

const defaultConfigYaml = '''
# Default configuration for `whats_new` (Dart ecosystem focus)
pub_publishers:
  - dart.dev
  - tools.dart.dev
  - labs.dart.dev

sdk:
  repo: dart-lang/sdk
  language_repo: dart-lang/language
  track_main_changelog: true
  track_stable_branches:
    - stable
    - beta

github:
  orgs:
    - dart-lang
  repos:
    - googleapis/google-cloud-dart
    - google/googleapis.dart
  exclude_repos:
    - dart-lang/sdk
  exclude_authors:
    - dependabot
    - dependabot[bot]
    - github-actions
    - github-actions[bot]
    - dart-ert
    - auto-submit
    - google-copybara
    - flutter-pub-roller-bot
    - skia-flutter-autoroll
    - engine-flutter-autoroll
  exclude_pr_title_patterns:
    - '^Bump '
    - '^Publish '
    - '^Prepare to publish'
    - '^chore\\(deps\\):'
    - '^Revert "'
''';

class WhatsNewConfig {
  final List<String> pubPublishers;
  final SdkConfig sdk;
  final GitHubConfig github;

  const WhatsNewConfig({
    required this.pubPublishers,
    required this.sdk,
    required this.github,
  });

  factory WhatsNewConfig.defaultConfig() =>
      WhatsNewConfig.fromYamlString(defaultConfigYaml);

  factory WhatsNewConfig.fromYamlString(String content, {Uri? sourceUrl}) =>
      checkedYamlDecode(
        content,
        (map) => WhatsNewConfig.fromMap(Map<String, Object?>.from(map ?? {})),
        sourceUrl: sourceUrl,
      );

  factory WhatsNewConfig.loadFile(String path) {
    final file = File(path);
    return WhatsNewConfig.fromYamlString(
      file.readAsStringSync(),
      sourceUrl: file.uri,
    );
  }

  factory WhatsNewConfig.fromMap(Map<String, Object?> map) {
    final publishers = _readStringList(map['pub_publishers']);
    final sdkMap = map['sdk'];
    final githubMap = map['github'];

    return WhatsNewConfig(
      pubPublishers: publishers,
      sdk:
          sdkMap is Map
              ? SdkConfig.fromMap(Map<String, Object?>.from(sdkMap))
              : const SdkConfig(),
      github:
          githubMap is Map
              ? GitHubConfig.fromMap(Map<String, Object?>.from(githubMap))
              : const GitHubConfig(),
    );
  }
}

class SdkConfig {
  final String repo;
  final String languageRepo;
  final bool trackMainChangelog;
  final List<String> trackStableBranches;

  const SdkConfig({
    this.repo = 'dart-lang/sdk',
    this.languageRepo = 'dart-lang/language',
    this.trackMainChangelog = true,
    this.trackStableBranches = const ['stable', 'beta'],
  });

  factory SdkConfig.fromMap(Map<String, Object?> map) => SdkConfig(
    repo: (map['repo'] as String?) ?? 'dart-lang/sdk',
    languageRepo: (map['language_repo'] as String?) ?? 'dart-lang/language',
    trackMainChangelog: (map['track_main_changelog'] as bool?) ?? true,
    trackStableBranches:
        map.containsKey('track_stable_branches')
            ? _readStringList(map['track_stable_branches'])
            : const ['stable', 'beta'],
  );
}

class GitHubConfig {
  final List<String> orgs;
  final List<String> repos;
  final List<String> excludeRepos;
  final List<String> excludeAuthors;
  final List<String> excludePrTitlePatterns;

  const GitHubConfig({
    this.orgs = const ['dart-lang'],
    this.repos = const [],
    this.excludeRepos = const ['dart-lang/sdk'],
    this.excludeAuthors = const [],
    this.excludePrTitlePatterns = const [],
  });

  factory GitHubConfig.fromMap(Map<String, Object?> map) => GitHubConfig(
    orgs: _readStringList(map['orgs']),
    repos: _readStringList(map['repos']),
    excludeRepos: _readStringList(map['exclude_repos']),
    excludeAuthors: _readStringList(map['exclude_authors']),
    excludePrTitlePatterns: _readStringList(map['exclude_pr_title_patterns']),
  );
}

List<String> _readStringList(Object? value) {
  if (value is! List) return const [];
  return value.whereType<String>().toList(growable: false);
}
