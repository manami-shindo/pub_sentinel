import 'package:pub_sentinel/src/checkers/new_version_checker.dart';
import 'package:pub_sentinel/src/models/check_result.dart';
import 'package:pub_sentinel/src/pub_api/pub_api_client.dart';
import 'package:test/test.dart';
import 'helpers/fake_http_client.dart';
import 'helpers/temp_project.dart';

const _lockFile = '''
packages:
  foo:
    dependency: direct main
    source: hosted
    version: "1.2.0"
  bar:
    dependency: direct main
    source: hosted
    version: "2.0.0"
sdkConstraints: {}
''';

void main() {
  final project = TempProject();

  setUp(() => project.setUp());
  tearDown(() => project.tearDown());

  group('NewVersionChecker', () {
    test('warns on recently published version', () async {
      project.writeLockFile(_lockFile);

      // foo: published 1 hour ago
      final recentTime =
          DateTime.now().toUtc().subtract(const Duration(hours: 1));
      // bar: published 10 days ago (no issue)
      final oldTime =
          DateTime.now().toUtc().subtract(const Duration(days: 10));

      final fakeClient = FakeHttpClient({
        'https://pub.dev/api/packages/foo': jsonResponse(buildPubApiResponse(
          name: 'foo',
          versions: [
            buildVersion(
                version: '1.2.0',
                published: recentTime.toIso8601String()),
          ],
        )),
        'https://pub.dev/api/packages/bar': jsonResponse(buildPubApiResponse(
          name: 'bar',
          versions: [
            buildVersion(
                version: '2.0.0', published: oldTime.toIso8601String()),
          ],
        )),
      });

      final checker = NewVersionChecker(
        projectPath: project.path,
        apiClient: PubApiClient(client: fakeClient),
        thresholdDays: 3,
      );
      final results = await checker.run();

      expect(results, hasLength(1));
      expect(results.first.package, 'foo');
      expect(results.first.severity, Severity.warning);
    });

    test('returns empty list when all packages are old', () async {
      project.writeLockFile(_lockFile);

      final oldTime = DateTime.now().toUtc().subtract(const Duration(days: 30));

      final fakeClient = FakeHttpClient({
        'https://pub.dev/api/packages/foo': jsonResponse(buildPubApiResponse(
          name: 'foo',
          versions: [
            buildVersion(
                version: '1.2.0', published: oldTime.toIso8601String()),
          ],
        )),
        'https://pub.dev/api/packages/bar': jsonResponse(buildPubApiResponse(
          name: 'bar',
          versions: [
            buildVersion(
                version: '2.0.0', published: oldTime.toIso8601String()),
          ],
        )),
      });

      final checker = NewVersionChecker(
        projectPath: project.path,
        apiClient: PubApiClient(client: fakeClient),
      );
      final results = await checker.run();

      expect(results, isEmpty);
    });

    test('returns empty list when pubspec.lock is missing', () async {
      final checker = NewVersionChecker(
        projectPath: project.path,
        apiClient: PubApiClient(),
      );
      final results = await checker.run();
      expect(results, isEmpty);
    });

    test('treats malformed pub.dev response as warning', () async {
      project.writeLockFile(_lockFile);

      final fakeClient = FakeHttpClient({
        'https://pub.dev/api/packages/foo': jsonResponse({'versions': 'broken'}),
        'https://pub.dev/api/packages/bar': jsonResponse(buildPubApiResponse(
          name: 'bar',
          versions: [],
        )),
      });

      final results = await NewVersionChecker(
        projectPath: project.path,
        apiClient: PubApiClient(client: fakeClient),
      ).run();

      expect(results, hasLength(1));
      expect(results.first.package, 'foo');
      expect(results.first.severity, Severity.warning);
      expect(results.first.message, contains('pub.dev'));
    });

    test('treats malformed pubspec.lock as warning', () async {
      project.writeLockFile('packages: [');

      final results = await NewVersionChecker(
        projectPath: project.path,
        apiClient: PubApiClient(),
      ).run();

      expect(results, hasLength(1));
      expect(results.first.package, '(project)');
      expect(results.first.severity, Severity.warning);
      expect(results.first.message, contains('pubspec.lock'));
    });
  });
}
