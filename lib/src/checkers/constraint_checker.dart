import 'dart:io';
import 'package:yaml/yaml.dart';
import '../models/check_result.dart';
import 'checker.dart';

class ConstraintChecker implements Checker {
  final String projectPath;

  const ConstraintChecker({required this.projectPath});

  @override
  Future<List<CheckResult>> run() async {
    final pubspecFile = File('$projectPath/pubspec.yaml');
    if (!pubspecFile.existsSync()) return [];

    final results = <CheckResult>[];
    final YamlMap yaml;
    try {
      final content = pubspecFile.readAsStringSync();
      final loaded = loadYaml(content);
      if (loaded is! YamlMap) {
        return [
          const CheckResult(
            package: '(project)',
            severity: Severity.warning,
            message: 'pubspec.yaml has invalid format',
            detail: 'Top-level YAML is not a map. Some checks were skipped.',
          ),
        ];
      }
      yaml = loaded;
    } on YamlException catch (e) {
      return [
        CheckResult(
          package: '(project)',
          severity: Severity.warning,
          message: 'Failed to parse pubspec.yaml',
          detail: 'Invalid YAML, cannot continue checks: ${e.message}',
        ),
      ];
    } on FileSystemException catch (e) {
      return [
        CheckResult(
          package: '(project)',
          severity: Severity.warning,
          message: 'Failed to read pubspec.yaml',
          detail: e.message,
        ),
      ];
    }

    final deps = yaml['dependencies'];
    if (deps is YamlMap) {
      for (final entry in deps.entries) {
        final name = entry.key as String;
        final constraint = entry.value;
        final issue = _checkConstraint(name, constraint);
        if (issue != null) results.add(issue);
      }
    }
    return results;
  }

  CheckResult? _checkConstraint(String name, dynamic constraint) {
    if (constraint == null) return null;
    // Non-string constraints (sdk: flutter, path: {...}) are skipped
    if (constraint is! String) return null;

    final c = constraint.trim();
    if (c == 'any' || c == '' || c == '>=0.0.0') {
      return CheckResult(
        package: name,
        severity: Severity.warning,
        message: 'No version constraint specified: "$c"',
        detail: 'Any version may be installed. '
            'Use a bounded constraint such as "^1.0.0".',
      );
    }
    return null;
  }
}
