import 'dart:io';

/// Creates and manages a temporary project directory for tests.
class TempProject {
  late Directory dir;

  Future<void> setUp() async {
    dir = await Directory.systemTemp.createTemp('pub_sentinel_test_');
  }

  Future<void> tearDown() async {
    await dir.delete(recursive: true);
  }

  String get path => dir.path;

  void writePubspec(String content) {
    File('${dir.path}/pubspec.yaml').writeAsStringSync(content);
  }

  void writeLockFile(String content) {
    File('${dir.path}/pubspec.lock').writeAsStringSync(content);
  }
}
