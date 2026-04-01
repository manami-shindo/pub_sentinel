import 'package:pub_sentinel/src/checkers/typosquat_checker.dart';
import 'package:pub_sentinel/src/models/check_result.dart';
import 'package:test/test.dart';
import 'helpers/temp_project.dart';

void main() {
  final project = TempProject();

  setUp(() => project.setUp());
  tearDown(() => project.tearDown());

  group('TyposquatChecker', () {
    test('flags transposition of popular package name', () async {
      // proivder: 'iv' and 'vi' are swapped (transposition of provider)
      project.writeLockFile(_lockFileWith('proivder'));

      final results = await TyposquatChecker(projectPath: project.path).run();

      expect(results, hasLength(1));
      expect(results.first.package, 'proivder');
      expect(results.first.severity, Severity.warning);
      expect(results.first.message, contains('provider'));
    });

    test('flags deletion in popular package name', () async {
      // provder: missing 'i' from provider
      project.writeLockFile(_lockFileWith('provder'));

      final results = await TyposquatChecker(projectPath: project.path).run();

      expect(results, hasLength(1));
      expect(results.first.package, 'provder');
      expect(results.first.message, contains('provider'));
    });

    test('flags extra character in popular package name', () async {
      // rriverpod: extra 'r' at the start
      project.writeLockFile(_lockFileWith('rriverpod'));

      final results = await TyposquatChecker(projectPath: project.path).run();

      expect(results, hasLength(1));
      expect(results.first.package, 'rriverpod');
      expect(results.first.message, contains('riverpod'));
    });

    test('flags substitution in popular package name', () async {
      // flutter_bl0c: 'o' replaced with '0'
      project.writeLockFile(_lockFileWith('flutter_bl0c'));

      final results = await TyposquatChecker(projectPath: project.path).run();

      expect(results, hasLength(1));
      expect(results.first.package, 'flutter_bl0c');
      expect(results.first.message, contains('flutter_bloc'));
    });

    test('does not flag the popular package itself', () async {
      project.writeLockFile(_lockFileWith('provider'));

      final results = await TyposquatChecker(projectPath: project.path).run();

      expect(results, isEmpty);
    });

    test('does not flag unrelated packages', () async {
      project.writeLockFile(_lockFileWith('my_custom_widget'));

      final results = await TyposquatChecker(projectPath: project.path).run();

      expect(results, isEmpty);
    });

    test('does not flag packages shorter than 5 characters', () async {
      // 'htpp' (4 chars) is 1 edit from 'http' but too short to check
      project.writeLockFile(_lockFileWith('htpp'));

      final results = await TyposquatChecker(projectPath: project.path).run();

      expect(results, isEmpty);
    });

    test('returns empty list when pubspec.lock is missing', () async {
      final results = await TyposquatChecker(projectPath: project.path).run();
      expect(results, isEmpty);
    });

    test('treats malformed pubspec.lock as warning', () async {
      project.writeLockFile('packages: [');

      final results = await TyposquatChecker(projectPath: project.path).run();

      expect(results, hasLength(1));
      expect(results.first.package, '(project)');
      expect(results.first.severity, Severity.warning);
      expect(results.first.message, contains('pubspec.lock'));
    });

    test('skips non-hosted packages', () async {
      project.writeLockFile('''
packages:
  proivder:
    dependency: direct main
    source: git
    version: "1.0.0"
sdkConstraints: {}
''');

      final results = await TyposquatChecker(projectPath: project.path).run();

      expect(results, isEmpty);
    });
  });
}

String _lockFileWith(String packageName) => '''
packages:
  $packageName:
    dependency: direct main
    source: hosted
    version: "1.0.0"
sdkConstraints: {}
''';
