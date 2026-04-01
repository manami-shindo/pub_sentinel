import 'dart:io';
import '../models/check_result.dart';
import 'checker.dart';

class LockFileChecker implements Checker {
  final String projectPath;

  const LockFileChecker({required this.projectPath});

  @override
  Future<List<CheckResult>> run() async {
    final lockFile = File('$projectPath/pubspec.lock');
    if (!lockFile.existsSync()) {
      return [
        const CheckResult(
          package: '(project)',
          severity: Severity.critical,
          message: 'pubspec.lock not found',
          detail: 'Commit pubspec.lock to pin your dependency versions. '
              'Without it, different versions may be installed across environments.',
        ),
      ];
    }
    return [];
  }
}
