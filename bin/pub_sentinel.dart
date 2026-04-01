import 'dart:io';
import 'package:args/args.dart';
import 'package:pub_sentinel/src/checkers/constraint_checker.dart';
import 'package:pub_sentinel/src/checkers/dep_diff_checker.dart';
import 'package:pub_sentinel/src/checkers/lock_file_checker.dart';
import 'package:pub_sentinel/src/checkers/new_version_checker.dart';
import 'package:pub_sentinel/src/checkers/publisher_checker.dart';
import 'package:pub_sentinel/src/checkers/typosquat_checker.dart';
import 'package:pub_sentinel/src/models/check_result.dart';
import 'package:pub_sentinel/src/pub_api/pub_api_client.dart';
import 'package:pub_sentinel/src/reporter/console_reporter.dart';
import 'package:pub_sentinel/src/reporter/json_reporter.dart';
import 'package:pub_sentinel/src/reporter/reporter.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('path',
        abbr: 'p', help: 'Project directory to scan', defaultsTo: '.')
    ..addOption('format',
        abbr: 'f',
        help: 'Output format (console, json)',
        defaultsTo: 'console',
        allowed: ['console', 'json'])
    ..addFlag('no-color', help: 'Disable colored output', negatable: false)
    ..addFlag('verbose',
        abbr: 'v', help: 'Show verbose output', negatable: false)
    ..addFlag('help', abbr: 'h', help: 'Show help', negatable: false);

  final ArgResults args;
  try {
    args = parser.parse(arguments);
  } on FormatException catch (e) {
    stderr.writeln('error: ${e.message}');
    stderr.writeln(parser.usage);
    exit(2);
  }

  if (args['help'] as bool) {
    print('pub-sentinel — security scanner for Dart/Flutter packages\n');
    print('Usage: pub-sentinel [options]\n');
    print(parser.usage);
    exit(0);
  }

  final projectPath = args['path'] as String;
  final format = args['format'] as String;
  final noColor = args['no-color'] as bool;
  final verbose = args['verbose'] as bool;

  if (!Directory(projectPath).existsSync()) {
    stderr.writeln('error: directory not found: $projectPath');
    exit(2);
  }

  final String resolvedPath;
  try {
    // Resolve symlinks and normalise to an absolute path.
    resolvedPath = Directory(projectPath).resolveSymbolicLinksSync();
  } on FileSystemException catch (e) {
    stderr.writeln('error: cannot resolve scan path: $projectPath');
    stderr.writeln(e.message);
    exit(2);
  }

  final Reporter reporter = format == 'json'
      ? JsonReporter()
      : ConsoleReporter(useColor: !noColor && stdout.hasTerminal);

  if (verbose && format != 'json') {
    print('Scanning: $resolvedPath');
  }

  final apiClient = PubApiClient();
  final allResults = <CheckResult>[];

  try {
    final checkers = [
      LockFileChecker(projectPath: resolvedPath),
      ConstraintChecker(projectPath: resolvedPath),
      NewVersionChecker(projectPath: resolvedPath, apiClient: apiClient),
      DepDiffChecker(projectPath: resolvedPath, apiClient: apiClient),
      PublisherChecker(projectPath: resolvedPath, apiClient: apiClient),
      TyposquatChecker(projectPath: resolvedPath),
    ];

    for (final checker in checkers) {
      if (verbose && format != 'json') {
        print('Running: ${checker.runtimeType}');
      }
      try {
        final results = await checker.run();
        allResults.addAll(results);
      } catch (e) {
        allResults.add(CheckResult(
          package: '(internal)',
          severity: Severity.critical,
          message: 'Unexpected error in ${checker.runtimeType}',
          detail: e.toString(),
        ));
      }
    }
  } finally {
    apiClient.close();
  }

  reporter.report(allResults);

  final hasCritical = allResults.any((r) => r.severity == Severity.critical);
  final hasWarning = allResults.any((r) => r.severity == Severity.warning);

  if (hasCritical || hasWarning) {
    exit(1);
  }
  exit(0);
}
