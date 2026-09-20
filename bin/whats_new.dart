import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:whats_new/whats_new.dart';

Future<void> main(List<String> arguments) async {
  final parser =
      ArgParser()
        ..addOption(
          'config',
          abbr: 'c',
          help:
              'Path to YAML/JSON configuration file (defaults to config.yaml).',
        )
        ..addOption(
          'days',
          abbr: 'd',
          defaultsTo: '7',
          help: 'Number of days to look back when --since is omitted.',
        )
        ..addOption('since', help: 'Start date in YYYY-MM-DD format (UTC).')
        ..addOption(
          'until',
          help: 'End date in YYYY-MM-DD format (UTC, defaults to now).',
        )
        ..addOption(
          'format',
          abbr: 'f',
          allowed: const ['markdown', 'json'],
          defaultsTo: 'markdown',
          help: 'Output format (markdown or json).',
        )
        ..addOption(
          'output',
          abbr: 'o',
          help: 'Write output to a file instead of stdout.',
        )
        ..addFlag(
          'help',
          abbr: 'h',
          negatable: false,
          help: 'Print usage information.',
        );

  final ArgResults results;
  try {
    results = parser.parse(arguments);
  } on FormatException catch (e) {
    stderr
      ..writeln('Error: ${e.message}\n')
      ..writeln('Usage: whats_new [options]\n${parser.usage}');
    exitCode = 64;
    return;
  }

  if (results['help'] as bool) {
    stdout.writeln('Usage: whats_new [options]\n${parser.usage}');
    return;
  }

  final config = _loadConfig(results['config'] as String?);
  final window = _resolveTimeWindow(
    sinceStr: results['since'] as String?,
    untilStr: results['until'] as String?,
    daysStr: results['days'] as String,
  );

  final digest = await runWhatsNewHarvest(
    config: config,
    since: window.since,
    until: window.until,
  );

  final format = results['format'] as String;
  final formatted =
      format == 'json'
          ? const JsonEncoder.withIndent('  ').convert(digest.toJson())
          : renderDigestMarkdown(digest);

  final outputPath = results['output'] as String?;
  if (outputPath != null && outputPath.isNotEmpty) {
    File(outputPath).writeAsStringSync('$formatted\n');
    stderr.writeln('Wrote $format digest to $outputPath');
  } else {
    stdout.writeln(formatted);
  }
}

WhatsNewConfig _loadConfig(String? explicitPath) {
  if (explicitPath != null && explicitPath.isNotEmpty) {
    return WhatsNewConfig.loadFile(explicitPath);
  }
  if (File('config.yaml').existsSync()) {
    return WhatsNewConfig.loadFile('config.yaml');
  }
  return WhatsNewConfig.defaultConfig();
}

({DateTime since, DateTime until}) _resolveTimeWindow({
  required String? sinceStr,
  required String? untilStr,
  required String daysStr,
}) {
  final until =
      untilStr != null
          ? DateTime.parse('${untilStr}T23:59:59Z')
          : DateTime.now().toUtc();
  final days = int.tryParse(daysStr) ?? 7;
  final since =
      sinceStr != null
          ? DateTime.parse('${sinceStr}T00:00:00Z')
          : until.subtract(Duration(days: days));
  return (since: since, until: until);
}
