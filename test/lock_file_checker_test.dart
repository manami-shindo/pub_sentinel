import 'package:pub_sentinel/src/checkers/lock_file_checker.dart';
import 'package:pub_sentinel/src/models/check_result.dart';
import 'package:test/test.dart';
import 'helpers/temp_project.dart';

void main() {
  final project = TempProject();

  setUp(() => project.setUp());
  tearDown(() => project.tearDown());

  group('LockFileChecker', () {
    test('returns critical when pubspec.lock is missing', () async {
      final checker = LockFileChecker(projectPath: project.path);
      final results = await checker.run();

      expect(results, hasLength(1));
      expect(results.first.severity, Severity.critical);
      expect(results.first.package, '(project)');
    });

    test('returns empty list when pubspec.lock exists', () async {
      project.writeLockFile('# dummy lock file\npackages: {}\n');

      final checker = LockFileChecker(projectPath: project.path);
      final results = await checker.run();

      expect(results, isEmpty);
    });
  });
}
