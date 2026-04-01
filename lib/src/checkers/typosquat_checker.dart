import 'dart:io';
import 'dart:math';
import 'package:yaml/yaml.dart';
import '../models/check_result.dart';
import 'checker.dart';

/// Detects potential typosquatting by comparing package names against a
/// curated list of popular pub.dev packages using OSA edit distance.
///
/// Only packages within edit distance 1 of a popular package are flagged.
/// Packages that ARE in the popular list are never flagged as typosquats.
class TyposquatChecker implements Checker {
  final String projectPath;

  const TyposquatChecker({required this.projectPath});

  /// Curated list of popular pub.dev packages used as typosquat reference.
  static const _popularPackages = {
    // State management
    'provider', 'riverpod', 'flutter_bloc', 'bloc', 'get_it',
    'injectable', 'mobx', 'redux', 'getx',
    // Networking
    'http', 'dio', 'retrofit', 'chopper', 'graphql',
    // Storage
    'shared_preferences', 'sqflite', 'hive', 'drift', 'isar',
    'floor', 'objectbox',
    // Firebase
    'firebase_core', 'firebase_auth', 'cloud_firestore',
    'firebase_storage', 'firebase_messaging', 'firebase_crashlytics',
    'firebase_analytics', 'firebase_database',
    // UI
    'cached_network_image', 'flutter_svg', 'lottie', 'shimmer',
    'google_fonts', 'flutter_animate', 'carousel_slider',
    'flutter_screenutil', 'auto_size_text',
    // Navigation
    'go_router', 'auto_route', 'beamer',
    // Code generation
    'json_serializable', 'freezed', 'build_runner', 'json_annotation',
    'source_gen',
    // Utilities
    'equatable', 'rxdart', 'logger', 'intl', 'uuid', 'crypto',
    'encrypt', 'pointycastle', 'yaml', 'pub_semver', 'args',
    // Platform
    'path_provider', 'url_launcher', 'share_plus', 'file_picker',
    'connectivity_plus', 'package_info_plus', 'device_info_plus',
    'battery_plus', 'sensors_plus', 'permission_handler',
    // Media
    'image_picker', 'camera', 'video_player', 'mobile_scanner',
    'qr_flutter',
    // Maps / Location
    'google_maps_flutter', 'flutter_map', 'geolocator', 'geocoding',
    // Security
    'flutter_secure_storage',
    // Auth
    'google_sign_in', 'sign_in_with_apple',
    // Charts
    'fl_chart',
    // Notifications
    'flutter_local_notifications', 'workmanager',
    // Web
    'webview_flutter', 'web_socket_channel',
    // Backend
    'supabase', 'supabase_flutter', 'appwrite',
    // Testing
    'mockito', 'mocktail',
    // Payments
    'in_app_purchase',
    // Misc
    'socket_io_client', 'flutter_cache_manager',
    'pin_code_fields', 'table_calendar', 'fluttertoast',
  };

  @override
  Future<List<CheckResult>> run() async {
    final lockFile = File('$projectPath/pubspec.lock');
    if (!lockFile.existsSync()) return [];

    final results = <CheckResult>[];
    final lockedVersions = _readLockFile(lockFile, results);
    if (lockedVersions.isEmpty) return results;

    for (final name in lockedVersions.keys) {
      if (_popularPackages.contains(name)) continue;
      // Short names produce too many false positives
      if (name.length < 5) continue;

      final match = _findTyposquatTarget(name);
      if (match == null) continue;

      results.add(CheckResult(
        package: name,
        severity: Severity.warning,
        message: 'Possible typosquatting: "$name" is 1 edit away from "$match"',
        detail: 'This package name closely resembles a popular package. '
            'Verify that you intended to install "$name" and not "$match".',
      ));
    }
    return results;
  }

  /// Returns the popular package name that is 1 edit away, or null if none.
  String? _findTyposquatTarget(String name) {
    for (final popular in _popularPackages) {
      // Skip short popular names — high false-positive rate
      if (popular.length < 5) continue;
      // Quick length pre-filter before running the full distance calculation
      if ((name.length - popular.length).abs() > 1) continue;
      if (_osaDistance(name, popular) == 1) return popular;
    }
    return null;
  }

  /// Optimal String Alignment (OSA) distance.
  /// Handles insertions, deletions, substitutions, and adjacent transpositions
  /// as single operations — more accurate than standard Levenshtein for typos.
  int _osaDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final d = List.generate(
      a.length + 1,
      (i) => List.generate(b.length + 1, (j) => i == 0 ? j : (j == 0 ? i : 0)),
    );

    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        d[i][j] = min(
          min(d[i - 1][j] + 1, d[i][j - 1] + 1),
          d[i - 1][j - 1] + cost,
        );
        // Transposition
        if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
          d[i][j] = min(d[i][j], d[i - 2][j - 2] + cost);
        }
      }
    }
    return d[a.length][b.length];
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
      if (meta['source'] == 'hosted') {
        final version = meta['version'] as String?;
        if (version != null) result[name] = version;
      }
    }
    return result;
  }
}
