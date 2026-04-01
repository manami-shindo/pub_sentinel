// Scans the top N popular pub.dev packages and lists
// suspicious dependency additions that pass the filter.
import 'dart:io';
import 'package:pub_sentinel/src/checkers/dep_diff_checker.dart';
import 'package:pub_sentinel/src/pub_api/pub_api_client.dart';

const _packages = [
  'http',
  'uuid',
  'shared_preferences',
  'path_provider',
  'url_launcher',
  'crypto',
  'flutter_svg',
  'dio',
  'image_picker',
  'google_fonts',
  'provider',
  'get',
  'rxdart',
  'bloc',
  'flutter_bloc',
  'equatable',
  'json_annotation',
  'freezed',
  'hive',
  'sqflite',
  'firebase_core',
  'firebase_auth',
  'cloud_firestore',
  'firebase_storage',
  'intl',
  'yaml',
  'args',
  'logger',
  'cached_network_image',
  'permission_handler',
  'connectivity_plus',
];

Future<void> main() async {
  final apiClient = PubApiClient();
  final tempDir = await Directory.systemTemp.createTemp('pub_sentinel_scan_');
  var totalFindings = 0;

  print('Scanning ${_packages.length} packages (with filtering)...\n');

  try {
    for (final name in _packages) {
      // Fetch the latest version of each package
      final info = await _fetchLatestVersion(apiClient, name);
      if (info == null) {
        print('[$name] skipped (fetch failed)');
        continue;
      }

      // Write a temporary pubspec.lock and run DepDiffChecker
      final lockFile = File('${tempDir.path}/pubspec.lock');
      lockFile.writeAsStringSync(_buildLockFile(name, info));

      final checker = DepDiffChecker(
        projectPath: tempDir.path,
        apiClient: apiClient,
      );
      final results = await checker.run();

      if (results.isEmpty) {
        print('[$name@$info] ✓ no issues');
      } else {
        for (final r in results) {
          print(
              '[$name@$info] ⚠️  ${r.severity.name.toUpperCase()}: ${r.message}');
          totalFindings++;
        }
      }
    }
  } finally {
    apiClient.close();
    await tempDir.delete(recursive: true);
  }

  print('\n=== Summary ===');
  print('Scanned: ${_packages.length} packages');
  print('Findings after filtering: $totalFindings');
  if (totalFindings == 0) {
    print('No suspicious dependency additions detected in this package set.');
  }
}

String _buildLockFile(String name, String version) => '''
packages:
  $name:
    dependency: direct main
    source: hosted
    version: "$version"
sdkConstraints: {}
''';

Future<String?> _fetchLatestVersion(PubApiClient client, String name) async {
  try {
    final info = await client.fetchPackage(name);
    if (info.versions.isEmpty) return null;
    return info.versions.last.version;
  } on Object {
    return null;
  }
}
