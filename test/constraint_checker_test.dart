import 'package:pub_sentinel/src/checkers/constraint_checker.dart';
import 'package:pub_sentinel/src/models/check_result.dart';
import 'package:test/test.dart';
import 'helpers/temp_project.dart';

void main() {
  final project = TempProject();

  setUp(() => project.setUp());
  tearDown(() => project.tearDown());

  group('ConstraintChecker', () {
    test('warns on "any" constraint', () async {
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

    test('warns on ">=0.0.0" constraint', () async {
      project.writePubspec('''
name: test_app
dependencies:
  bar: ">=0.0.0"
''');
      final results = await ConstraintChecker(projectPath: project.path).run();

      expect(results, hasLength(1));
      expect(results.first.package, 'bar');
    });

    test('passes valid constraints', () async {
      project.writePubspec('''
name: test_app
dependencies:
  http: ^1.0.0
  yaml: ">=3.0.0 <4.0.0"
''');
      final results = await ConstraintChecker(projectPath: project.path).run();

      expect(results, isEmpty);
    });

    test('skips flutter SDK dependency', () async {
      project.writePubspec('''
name: test_app
dependencies:
  flutter:
    sdk: flutter
''');
      final results = await ConstraintChecker(projectPath: project.path).run();

      expect(results, isEmpty);
    });

    test('returns empty list when pubspec.yaml is missing', () async {
      final results = await ConstraintChecker(projectPath: project.path).run();
      expect(results, isEmpty);
    });

    test('treats malformed pubspec.yaml as warning', () async {
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
