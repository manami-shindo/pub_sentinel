import 'dart:io';
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';
import '../models/check_result.dart';
import '../pub_api/pub_api_client.dart';
import 'checker.dart';

/// Detects dependencies suddenly added in a version upgrade (a key supply-chain attack pattern).
class DepDiffChecker implements Checker {
  final String projectPath;
  final PubApiClient apiClient;

  const DepDiffChecker({
    required this.projectPath,
    required this.apiClient,
  });

  /// Well-known packages maintained by dart-lang / Flutter.
  /// Adding these is not considered suspicious.
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

        // Filter out clearly legitimate additions
        final mainPublisher = await apiClient.fetchPublisher(name);

        // First, exclude by static rules (list + naming patterns)
        final candidates =
            addedDeps.where((dep) => !_isStaticallySafe(dep, name)).toList();
        if (candidates.isEmpty) continue;

        // Compare publishers for the remaining candidates.
        // Deps with the same publisher as the main package are skipped entirely.
        // The rest are classified by whether they have any verified publisher:
        //   - verified (non-null publisherId) → less suspicious → INFO
        //   - unverified (null publisherId)   → suspicious      → severity by version bump
        // If mainPublisher is unknown we cannot do same-publisher filtering,
        // but we still classify each dep by its own publisher status.
        final publisherUnknown = mainPublisher == null;
        final verifiedDeps = <String>[];
        final unverifiedDeps = <String>[];
        for (final dep in candidates) {
          final depPublisher = await apiClient.fetchPublisher(dep);
          if (!publisherUnknown && depPublisher == mainPublisher) continue;
          if (depPublisher != null) {
            verifiedDeps.add(dep);
          } else {
            unverifiedDeps.add(dep);
          }
        }
        if (verifiedDeps.isEmpty && unverifiedDeps.isEmpty) continue;

        final publisherNote = publisherUnknown
            ? ' $name has no verified publisher, so publisher comparison was skipped.'
            : '';

        if (unverifiedDeps.isNotEmpty) {
          results.add(CheckResult(
            package: name,
            severity: _severityFor(previous.version, current.version),
            message:
                'Suspicious dependencies added in v$version: ${unverifiedDeps.join(', ')}',
            detail:
                'Dependencies not present in the previous version (v${previous.version}) were added. '
                'This is a typical supply-chain attack pattern. Please review the changes.$publisherNote',
          ));
        }
        if (verifiedDeps.isNotEmpty) {
          results.add(CheckResult(
            package: name,
            severity: Severity.info,
            message:
                'New verified-publisher dependencies added in v$version: ${verifiedDeps.join(', ')}',
            detail:
                'Dependencies not present in the previous version (v${previous.version}) were added. '
                'Each has a verified publisher, but review is still recommended.$publisherNote',
          ));
        }
      } on PackageNotFoundException {
        // Packages not on pub.dev (e.g. git deps) are skipped
      } on PubApiException catch (e) {
        results.add(CheckResult(
          package: name,
          severity: Severity.warning,
          message: 'Failed to query pub.dev during dependency diff check',
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

  /// Returns true if the dep is statically safe (no API call needed).
  bool _isStaticallySafe(String dep, String mainPackage) {
    // 1. Known-safe package list
    if (_knownSafePackages.contains(dep)) return true;

    // 2. Sub-package naming pattern (url_launcher_web, shared_preferences_macos, etc.)
    if (dep.startsWith('${mainPackage}_')) return true;

    return false;
  }

  /// Severity is determined by the type of version bump:
  /// patch → CRITICAL (most suspicious)
  /// minor → WARNING
  /// major → INFO (large refactor; new deps are plausible)
  Severity _severityFor(String fromVersion, String toVersion) {
    try {
      final from = Version.parse(fromVersion);
      final to = Version.parse(toVersion);

      if (to.major > from.major) return Severity.info;
      if (to.minor > from.minor) return Severity.warning;
      return Severity.critical; // patch or build-metadata-only change
    } catch (_) {
      return Severity
          .warning; // fall back to warning if versions cannot be parsed
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
