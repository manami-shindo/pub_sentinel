import 'dart:io';
import 'package:pub_sentinel/src/config/ignore_config.dart';
import 'package:test/test.dart';
import 'helpers/temp_project.dart';

void main() {
  final project = TempProject();

  setUp(() => project.setUp());
  tearDown(() => project.tearDown());

  group('loadIgnoreConfig', () {
    test('returns empty set when .pub_sentinel.yaml is absent', () {
      expect(loadIgnoreConfig(project.path), isEmpty);
    });

    test('returns listed packages', () {
      File('${project.path}/.pub_sentinel.yaml').writeAsStringSync('''
ignore:
  - objective_c
  - riverpod_analyzer_utils
''');
      expect(loadIgnoreConfig(project.path),
          equals({'objective_c', 'riverpod_analyzer_utils'}));
    });

    test('returns empty set for malformed yaml', () {
      File('${project.path}/.pub_sentinel.yaml')
          .writeAsStringSync(': bad: yaml: [');
      expect(loadIgnoreConfig(project.path), isEmpty);
    });

    test('returns empty set when ignore key is missing', () {
      File('${project.path}/.pub_sentinel.yaml')
          .writeAsStringSync('other_key: value\n');
      expect(loadIgnoreConfig(project.path), isEmpty);
    });
  });

  group('readProjectName', () {
    test('returns null when pubspec.yaml is absent', () {
      expect(readProjectName(project.path), isNull);
    });

    test('returns the name field', () {
      project.writePubspec('name: my_app\n');
      expect(readProjectName(project.path), equals('my_app'));
    });

    test('returns null for malformed pubspec', () {
      project.writePubspec(': bad: yaml: [');
      expect(readProjectName(project.path), isNull);
    });
  });
}
