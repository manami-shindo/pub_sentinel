import 'package:http/http.dart' as http;
import 'package:pub_sentinel/src/checkers/publisher_checker.dart';
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
    version: "1.0.0"
  bar:
    dependency: direct main
    source: hosted
    version: "2.0.0"
sdkConstraints: {}
''';

const _singlePackageLockFile = '''
packages:
  foo:
    dependency: direct main
    source: hosted
    version: "1.0.0"
sdkConstraints: {}
''';

void main() {
  final project = TempProject();

  setUp(() => project.setUp());
  tearDown(() => project.tearDown());

  group('PublisherChecker', () {
    test('検証済みパブリッシャーがない場合 info を返す', () async {
      project.writeLockFile(_singlePackageLockFile);

      final fakeClient = FakeHttpClient({
        'https://pub.dev/api/packages/foo/publisher': publisherResponse(null),
      });

      final results = await PublisherChecker(
        projectPath: project.path,
        apiClient: PubApiClient(client: fakeClient),
      ).run();

      expect(results, hasLength(1));
      expect(results.first.package, 'foo');
      expect(results.first.severity, Severity.info);
      expect(results.first.message, contains('検証済みパブリッシャー'));
    });

    test('使い捨てメールドメインのパブリッシャーは critical を返す', () async {
      project.writeLockFile(_singlePackageLockFile);

      final fakeClient = FakeHttpClient({
        'https://pub.dev/api/packages/foo/publisher':
            publisherResponse('mailinator.com'),
      });

      final results = await PublisherChecker(
        projectPath: project.path,
        apiClient: PubApiClient(client: fakeClient),
      ).run();

      expect(results, hasLength(1));
      expect(results.first.package, 'foo');
      expect(results.first.severity, Severity.critical);
      expect(results.first.message, contains('mailinator.com'));
    });

    test('サブドメインの使い捨てメールドメインも critical を返す', () async {
      project.writeLockFile(_singlePackageLockFile);

      final fakeClient = FakeHttpClient({
        'https://pub.dev/api/packages/foo/publisher':
            publisherResponse('attacker.mailinator.com'),
      });

      final results = await PublisherChecker(
        projectPath: project.path,
        apiClient: PubApiClient(client: fakeClient),
      ).run();

      expect(results, hasLength(1));
      expect(results.first.severity, Severity.critical);
      expect(results.first.message, contains('attacker.mailinator.com'));
    });

    test('正常なパブリッシャーがある場合は結果を返さない', () async {
      project.writeLockFile(_singlePackageLockFile);

      final fakeClient = FakeHttpClient({
        'https://pub.dev/api/packages/foo/publisher':
            publisherResponse('google.dev'),
      });

      final results = await PublisherChecker(
        projectPath: project.path,
        apiClient: PubApiClient(client: fakeClient),
      ).run();

      expect(results, isEmpty);
    });

    test('複数パッケージを個別に評価する', () async {
      project.writeLockFile(_lockFile);

      final fakeClient = FakeHttpClient({
        'https://pub.dev/api/packages/foo/publisher':
            publisherResponse('dart.dev'),
        'https://pub.dev/api/packages/bar/publisher': publisherResponse(null),
      });

      final results = await PublisherChecker(
        projectPath: project.path,
        apiClient: PubApiClient(client: fakeClient),
      ).run();

      expect(results, hasLength(1));
      expect(results.first.package, 'bar');
      expect(results.first.severity, Severity.info);
    });

    test('pubspec.lock がない場合 空リストを返す', () async {
      final results = await PublisherChecker(
        projectPath: project.path,
        apiClient: PubApiClient(),
      ).run();

      expect(results, isEmpty);
    });

    test('ネットワークエラーは warning を返す', () async {
      project.writeLockFile(_singlePackageLockFile);

      // send() 自体が例外を投げるクライアントで PubApiException を発生させる
      final fakeErrorClient = _ThrowingHttpClient();

      final results = await PublisherChecker(
        projectPath: project.path,
        apiClient: PubApiClient(client: fakeErrorClient),
      ).run();

      expect(results, hasLength(1));
      expect(results.first.package, 'foo');
      expect(results.first.severity, Severity.warning);
    });

    test('壊れた pubspec.lock は warning として扱う', () async {
      project.writeLockFile('packages: [');

      final results = await PublisherChecker(
        projectPath: project.path,
        apiClient: PubApiClient(),
      ).run();

      expect(results, hasLength(1));
      expect(results.first.package, '(project)');
      expect(results.first.severity, Severity.warning);
      expect(results.first.message, contains('pubspec.lock'));
    });

    test('git 依存など hosted 以外のパッケージはスキップする', () async {
      project.writeLockFile('''
packages:
  git_pkg:
    dependency: direct main
    source: git
    version: "1.0.0"
sdkConstraints: {}
''');

      final results = await PublisherChecker(
        projectPath: project.path,
        apiClient: PubApiClient(),
      ).run();

      expect(results, isEmpty);
    });
  });
}

class _ThrowingHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    throw http.ClientException('simulated network error');
  }
}
