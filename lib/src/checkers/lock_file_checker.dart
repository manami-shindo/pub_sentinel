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
          message: 'pubspec.lock が見つかりません',
          detail: 'pubspec.lock をコミットすることで依存関係のバージョンを固定してください。'
              'ファイルがない場合、異なる環境で異なるバージョンがインストールされる可能性があります。',
        ),
      ];
    }
    return [];
  }
}
