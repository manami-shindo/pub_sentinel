import 'dart:io';
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';
import '../models/check_result.dart';
import '../pub_api/pub_api_client.dart';
import 'checker.dart';

/// バージョンアップ時に突然追加された依存関係を検出する（サプライチェーン攻撃の主要パターン）
class DepDiffChecker implements Checker {
  final String projectPath;
  final PubApiClient apiClient;

  const DepDiffChecker({
    required this.projectPath,
    required this.apiClient,
  });

  /// dart-lang / flutter が管理する定番パッケージ群。
  /// これらが追加されても攻撃の兆候とは見なさない。
  static const _knownSafePackages = {
    // dart-lang core
    'async', 'collection', 'convert', 'crypto', 'ffi', 'fixnum',
    'html', 'http_parser', 'intl', 'io', 'isolate', 'js',
    'logging', 'matcher', 'meta', 'mime', 'path', 'pool',
    'pub_semver', 'shelf', 'source_map_stack_trace', 'source_maps',
    'source_span', 'stack_trace', 'stream_channel', 'string_scanner',
    'term_glyph', 'typed_data', 'watcher', 'web',
    // flutter
    'flutter', 'flutter_test', 'flutter_driver',
    // linting
    'lints', 'flutter_lints', 'pedantic',
    // testing
    'test', 'test_api', 'test_core', 'mockito', 'fake_async',
    // build
    'build', 'build_runner', 'build_config',
    // common utility
    'charcode', 'clock', 'platform', 'args',
  };

  @override
  Future<List<CheckResult>> run() async {
    final lockFile = File('$projectPath/pubspec.lock');
    if (!lockFile.existsSync()) return [];

    final results = <CheckResult>[];
    final lockedVersions = _readLockFile(lockFile, results);
    if (lockedVersions.isEmpty) return results;

    for (final entry in lockedVersions.entries) {
      final name = entry.key;
      final version = entry.value;

      try {
        final info = await apiClient.fetchPackage(name);
        final current = info.versionOrNull(version);
        if (current == null) continue;

        final previous = info.previousVersion(version);
        if (previous == null) continue;

        final addedDeps = _findAddedDependencies(
          previous.dependencies,
          current.dependencies,
        );
        if (addedDeps.isEmpty) continue;

        // フィルタリング：明らかに正当な追加を除外
        final mainPublisher = await apiClient.fetchPublisher(name);

        // まず静的ルール（リスト・命名パターン）で除外
        final candidates = addedDeps
            .where((dep) => !_isStaticallySafe(dep, name))
            .toList();
        if (candidates.isEmpty) continue;

        // 残ったものはパブリッシャーを比較して除外
        final suspicious = <String>[];
        for (final dep in candidates) {
          if (mainPublisher != null) {
            final depPublisher = await apiClient.fetchPublisher(dep);
            if (depPublisher == mainPublisher) continue;
          }
          suspicious.add(dep);
        }
        if (suspicious.isEmpty) continue;

        final severity = _severityFor(
          previous.version,
          current.version,
        );
        results.add(CheckResult(
          package: name,
          severity: severity,
          message: 'v$version で不審な依存パッケージが追加されました: ${suspicious.join(', ')}',
          detail: '前バージョン (v${previous.version}) にはなかった依存が追加されています。'
              'サプライチェーン攻撃の典型的なパターンです。変更内容を確認してください。',
        ));
      } on PackageNotFoundException {
        // git 依存など pub.dev にないパッケージはスキップ
      } on PubApiException catch (e) {
        results.add(CheckResult(
          package: name,
          severity: Severity.warning,
          message: '依存差分チェック中に pub.dev への問い合わせが失敗しました',
          detail: e.message,
        ));
      }
    }
    return results;
  }

  Map<String, String> _readLockFile(File lockFile, List<CheckResult> results) {
    try {
      return _parseLockFile(lockFile.readAsStringSync());
    } on YamlException catch (e) {
      results.add(CheckResult(
        package: '(project)',
        severity: Severity.warning,
        message: 'pubspec.lock を解析できませんでした',
        detail: '不正な YAML のため一部の検査をスキップしました: ${e.message}',
      ));
    } on FileSystemException catch (e) {
      results.add(CheckResult(
        package: '(project)',
        severity: Severity.warning,
        message: 'pubspec.lock を読み取れませんでした',
        detail: e.message,
      ));
    }
    return {};
  }

  /// 静的ルールで安全と判定できるかどうかを返す（API 呼び出し不要）
  bool _isStaticallySafe(String dep, String mainPackage) {
    // 1. 既知の安全パッケージリスト
    if (_knownSafePackages.contains(dep)) return true;

    // 2. サブパッケージ命名パターン（url_launcher_web, shared_preferences_macos など）
    if (dep.startsWith('${mainPackage}_')) return true;

    return false;
  }

  /// severity はバージョンアップの種類で決定する
  /// パッチ → CRITICAL（最も怪しい）
  /// マイナー → WARNING
  /// メジャー → INFO（大改修なので依存追加はあり得る）
  Severity _severityFor(String fromVersion, String toVersion) {
    try {
      final from = Version.parse(fromVersion);
      final to = Version.parse(toVersion);

      if (to.major > from.major) return Severity.info;
      if (to.minor > from.minor) return Severity.warning;
      return Severity.critical; // パッチ or ビルドメタデータのみの変化
    } catch (_) {
      return Severity.warning; // パースできない場合は warning にフォールバック
    }
  }

  List<String> _findAddedDependencies(
    Map<String, dynamic> prev,
    Map<String, dynamic> current,
  ) {
    return current.keys.where((dep) => !prev.containsKey(dep)).toList()..sort();
  }

  Map<String, String> _parseLockFile(String content) {
    final yaml = loadYaml(content);
    if (yaml is! YamlMap) return {};
    final packages = yaml['packages'];
    if (packages is! YamlMap) return {};

    final result = <String, String>{};
    for (final entry in packages.entries) {
      final name = entry.key as String;
      final meta = entry.value as YamlMap;
      if (meta['source'] == 'hosted') {
        final version = meta['version'] as String?;
        if (version != null) result[name] = version;
      }
    }
    return result;
  }
}
