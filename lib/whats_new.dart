import 'src/config.dart';
import 'src/github_client.dart';
import 'src/github_harvester.dart';
import 'src/models.dart';
import 'src/pub_harvester.dart';
import 'src/sdk_harvester.dart';

export 'src/changelog_parser.dart';
export 'src/config.dart';
export 'src/github_client.dart';
export 'src/github_harvester.dart';
export 'src/markdown_renderer.dart';
export 'src/models.dart';
export 'src/pub_harvester.dart';
export 'src/sdk_harvester.dart';

Future<WhatsNewDigest> runWhatsNewHarvest({
  required WhatsNewConfig config,
  required DateTime since,
  required DateTime until,
  String? githubToken,
}) async {
  final token = githubToken ?? await GitHubApiClient.resolveToken();
  final githubClient = GitHubApiClient(token: token);

  final pubHarvester = PubHarvester();
  final sdkHarvester = SdkHarvester(githubClient);
  final githubHarvester = GitHubHarvester(githubClient);

  final pubResultFuture = pubHarvester.harvestPublishers(
    publishers: config.pubPublishers,
    since: since,
    until: until,
  );
  final sdkResultFuture = sdkHarvester.harvest(
    config: config.sdk,
    since: since,
    until: until,
  );
  final ghResultFuture = githubHarvester.harvest(
    config: config.github,
    languageRepo: config.sdk.languageRepo,
    since: since,
    until: until,
  );

  final pubResult = await pubResultFuture;
  final sdkResult = await sdkResultFuture;
  final ghResult = await ghResultFuture;

  return WhatsNewDigest(
    since: since,
    until: until,
    newPackages: pubResult.newPackages,
    updatedPackages: pubResult.updated,
    sdkNextStableSections: sdkResult.nextStableSections,
    sdkDotReleases: sdkResult.dotReleases,
    languagePrs: ghResult.languagePrs,
    notablePrs: ghResult.notablePrs,
    firstTimeContributors: ghResult.firstTimeContributors,
  );
}
