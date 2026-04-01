import 'dart:io';
import 'package:args/args.dart';
import 'package:pub_sentinel/src/checkers/constraint_checker.dart';
import 'package:pub_sentinel/src/checkers/dep_diff_checker.dart';
import 'package:pub_sentinel/src/checkers/lock_file_checker.dart';
import 'package:pub_sentinel/src/checkers/new_version_checker.dart';
import 'package:pub_sentinel/src/checkers/publisher_checker.dart';
import 'package:pub_sentinel/src/models/check_result.dart';
import 'package:pub_sentinel/src/pub_api/pub_api_client.dart';
import 'package:pub_sentinel/src/reporter/console_reporter.dart';
import 'package:pub_sentinel/src/reporter/json_reporter.dart';
import 'package:pub_sentinel/src/reporter/reporter.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('path',
        abbr: 'p',
        help: 'スキャン対象のプロジェクトディレクトリ',
        defaultsTo: '.')
    ..addOption('format',
        abbr: 'f',
        help: '出力フォーマット (console, json)',
        defaultsTo: 'console',
        allowed: ['console', 'json'])
    ..addFlag('no-color',
        help: 'カラー出力を無効化',
        negatable: false)
    ..addFlag('verbose',
        abbr: 'v',
        help: '詳細ログを表示',
        negatable: false)
    ..addFlag('help',
        abbr: 'h',
        help: 'ヘルプを表示',
        negatable: false);

  final ArgResults args;
  try {
    args = parser.parse(arguments);
  } on FormatException catch (e) {
    stderr.writeln('エラー: ${e.message}');
    stderr.writeln(parser.usage);
    exit(2);
  }

  if (args['help'] as bool) {
    print('pub-sentinel — Dart/Flutter パッケージのセキュリティスキャナ\n');
    print('使い方: pub-sentinel [オプション]\n');
    print(parser.usage);
    exit(0);
  }

  final projectPath = args['path'] as String;
  final format = args['format'] as String;
  final noColor = args['no-color'] as bool;
  final verbose = args['verbose'] as bool;

  if (!Directory(projectPath).existsSync()) {
    stderr.writeln('エラー: ディレクトリが見つかりません: $projectPath');
    exit(2);
  }

  final String resolvedPath;
  try {
    // シンボリックリンクを解決し、絶対パスに正規化する。
    resolvedPath = Directory(projectPath).resolveSymbolicLinksSync();
  } on FileSystemException catch (e) {
    stderr.writeln('エラー: スキャン対象パスを解決できません: $projectPath');
    stderr.writeln(e.message);
    exit(2);
  }

  final Reporter reporter = format == 'json'
      ? JsonReporter()
      : ConsoleReporter(useColor: !noColor && stdout.hasTerminal);

  if (verbose && format != 'json') {
    print('スキャン対象: $resolvedPath');
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
    ];

    for (final checker in checkers) {
      if (verbose && format != 'json') {
        print('実行中: ${checker.runtimeType}');
      }
      try {
        final results = await checker.run();
        allResults.addAll(results);
      } catch (e) {
        allResults.add(CheckResult(
          package: '(internal)',
          severity: Severity.critical,
          message: '${checker.runtimeType} の実行中に予期しない例外が発生しました',
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
