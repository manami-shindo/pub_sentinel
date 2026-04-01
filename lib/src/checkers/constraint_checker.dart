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
            message: 'pubspec.yaml の形式が不正です',
            detail: 'YAML のトップレベルがマップではありません。解析できないため、一部の検査をスキップしました。',
          ),
        ];
      }
      yaml = loaded;
    } on YamlException catch (e) {
      return [
        CheckResult(
          package: '(project)',
          severity: Severity.warning,
          message: 'pubspec.yaml を解析できませんでした',
          detail: '不正な YAML のため検査を継続できません: ${e.message}',
        ),
      ];
    } on FileSystemException catch (e) {
      return [
        CheckResult(
          package: '(project)',
          severity: Severity.warning,
          message: 'pubspec.yaml を読み取れませんでした',
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
    // sdk: flutter や path: {...} などは文字列でない
    if (constraint is! String) return null;

    final c = constraint.trim();
    if (c == 'any' || c == '' || c == '>=0.0.0') {
      return CheckResult(
        package: name,
        severity: Severity.warning,
        message: 'バージョン制約が指定されていません: "$c"',
        detail: '任意のバージョンがインストールされる可能性があります。'
            '例: "^1.0.0" のように上限付き制約を指定してください。',
      );
    }
    return null;
  }
}
