import 'dart:io';
import 'package:yaml/yaml.dart';

/// Reads the `ignore:` list from `.pub_sentinel.yaml` in [projectPath].
/// Returns an empty set if the file is absent or malformed.
Set<String> loadIgnoreConfig(String projectPath) {
  final configFile = File('$projectPath/.pub_sentinel.yaml');
  if (!configFile.existsSync()) return {};
  try {
    final yaml = loadYaml(configFile.readAsStringSync());
    if (yaml is! YamlMap) return {};
    final ignore = yaml['ignore'];
    if (ignore is! YamlList) return {};
    return ignore.whereType<String>().toSet();
  } catch (_) {
    return {};
  }
}

/// Reads the `name:` field from `pubspec.yaml` in [projectPath].
/// Returns null if the file is absent or malformed.
String? readProjectName(String projectPath) {
  final pubspecFile = File('$projectPath/pubspec.yaml');
  if (!pubspecFile.existsSync()) return null;
  try {
    final yaml = loadYaml(pubspecFile.readAsStringSync());
    if (yaml is! YamlMap) return null;
    return yaml['name'] as String?;
  } catch (_) {
    return null;
  }
}
