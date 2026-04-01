import 'dart:io';
import 'package:yaml/yaml.dart';
import '../models/check_result.dart';
import '../pub_api/pub_api_client.dart';
import 'checker.dart';

/// 直近 N 日以内に公開されたバージョンを使っていたら警告する
class NewVersionChecker implements Checker {
  final String projectPath;
  final PubApiClient apiClient;
  final int thresholdDays;

  const NewVersionChecker({
    required this.projectPath,
    required this.apiClient,
    this.thresholdDays = 3,
  });

  @override
  Future<List<CheckResult>> run() async {
    final lockFile = File('$projectPath/pubspec.lock');
    if (!lockFile.existsSync()) return [];

    final results = <CheckResult>[];
    final lockedVersions = _readLockFile(lockFile, results);
    if (lockedVersions.isEmpty) return results;
    final now = DateTime.now().toUtc();

    for (final entry in lockedVersions.entries) {
      final name = entry.key;
      final version = entry.value;

      try {
        final info = await apiClient.fetchPackage(name);
        final versionInfo = info.versionOrNull(version);
        if (versionInfo == null) continue;

        final age = now.difference(versionInfo.published);
        if (age.inDays < thresholdDays) {
          results.add(CheckResult(
            package: name,
            severity: Severity.warning,
            message: 'v$version は公開から ${age.inHours} 時間しか経っていません',
            detail: '公開直後のパッケージはセキュリティ審査が十分でない可能性があります。'
                '(公開日時: ${versionInfo.published.toIso8601String()})',
          ));
        }
      } on PackageNotFoundException {
        // pubspec.lock に載っているが pub.dev に存在しない（git依存など）はスキップ
      } on PubApiException catch (e) {
        results.add(CheckResult(
          package: name,
          severity: Severity.warning,
          message: 'pub.dev からパッケージ情報を取得できませんでした',
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

  Map<String, String> _parseLockFile(String content) {
    final yaml = loadYaml(content);
    if (yaml is! YamlMap) return {};
    final packages = yaml['packages'];
    if (packages is! YamlMap) return {};

    final result = <String, String>{};
    for (final entry in packages.entries) {
      final name = entry.key as String;
      final meta = entry.value as YamlMap;
      // hosted パッケージのみ対象
      if (meta['source'] == 'hosted') {
        final version = meta['version'] as String?;
        if (version != null) result[name] = version;
      }
    }
    return result;
  }
}
