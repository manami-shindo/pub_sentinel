import 'package:pub_sentinel/src/checkers/constraint_checker.dart';
import 'package:pub_sentinel/src/models/check_result.dart';
import 'package:test/test.dart';
import 'helpers/temp_project.dart';

void main() {
  final project = TempProject();

  setUp(() => project.setUp());
  tearDown(() => project.tearDown());

  group('ConstraintChecker', () {
    test('"any" 制約を警告する', () async {
      project.writePubspec('''
name: test_app
dependencies:
  foo: any
''');
      final results = await ConstraintChecker(projectPath: project.path).run();

      expect(results, hasLength(1));
      expect(results.first.package, 'foo');
      expect(results.first.severity, Severity.warning);
    });

    test('">=0.0.0" 制約を警告する', () async {
      project.writePubspec('''
name: test_app
dependencies:
  bar: ">=0.0.0"
''');
      final results = await ConstraintChecker(projectPath: project.path).run();

      expect(results, hasLength(1));
      expect(results.first.package, 'bar');
    });

    test('適切な制約はスルーする', () async {
      project.writePubspec('''
name: test_app
dependencies:
  http: ^1.0.0
  yaml: ">=3.0.0 <4.0.0"
''');
      final results = await ConstraintChecker(projectPath: project.path).run();

      expect(results, isEmpty);
    });

    test('flutter SDK 依存はスルーする', () async {
      project.writePubspec('''
name: test_app
dependencies:
  flutter:
    sdk: flutter
''');
      final results = await ConstraintChecker(projectPath: project.path).run();

      expect(results, isEmpty);
    });

    test('pubspec.yaml が存在しない場合 空リストを返す', () async {
      final results = await ConstraintChecker(projectPath: project.path).run();
      expect(results, isEmpty);
    });

    test('壊れた pubspec.yaml は warning として扱う', () async {
      project.writePubspec('''
name: test_app
dependencies:
  foo: [
''');

      final results = await ConstraintChecker(projectPath: project.path).run();

      expect(results, hasLength(1));
      expect(results.first.package, '(project)');
      expect(results.first.severity, Severity.warning);
      expect(results.first.message, contains('pubspec.yaml'));
    });
  });
}
