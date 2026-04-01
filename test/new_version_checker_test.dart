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
    test('公開直後のバージョンを警告する', () async {
      project.writeLockFile(_lockFile);

      // foo: 1時間前に公開
      final recentTime =
          DateTime.now().toUtc().subtract(const Duration(hours: 1));
      // bar: 10日前に公開（問題なし）
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

    test('全パッケージが古い場合 空リストを返す', () async {
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

    test('pubspec.lock がない場合 空リストを返す', () async {
      final checker = NewVersionChecker(
        projectPath: project.path,
        apiClient: PubApiClient(),
      );
      final results = await checker.run();
      expect(results, isEmpty);
    });

    test('pub.dev の不正な応答は warning として扱う', () async {
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

    test('壊れた pubspec.lock は warning として扱う', () async {
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
