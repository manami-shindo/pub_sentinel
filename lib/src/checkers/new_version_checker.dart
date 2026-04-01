import 'dart:io';
import 'package:yaml/yaml.dart';
import '../models/check_result.dart';
import '../pub_api/pub_api_client.dart';
import 'checker.dart';

/// Warns when the locked version was published within the last N days.
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
            message: 'v$version was published only ${age.inHours} hour(s) ago',
            detail: 'Recently published packages may not have been reviewed for security. '
                '(published: ${versionInfo.published.toIso8601String()})',
          ));
        }
      } on PackageNotFoundException {
        // Packages in pubspec.lock but not on pub.dev (e.g. git deps) are skipped
      } on PubApiException catch (e) {
        results.add(CheckResult(
          package: name,
          severity: Severity.warning,
          message: 'Failed to fetch package info from pub.dev',
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
        message: 'Failed to parse pubspec.lock',
        detail: 'Invalid YAML; some checks were skipped: ${e.message}',
      ));
    } on FileSystemException catch (e) {
      results.add(CheckResult(
        package: '(project)',
        severity: Severity.warning,
        message: 'Failed to read pubspec.lock',
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
      // Only hosted packages
      if (meta['source'] == 'hosted') {
        final version = meta['version'] as String?;
        if (version != null) result[name] = version;
      }
    }
    return result;
  }
}
