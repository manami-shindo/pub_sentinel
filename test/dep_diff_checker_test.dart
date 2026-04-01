import 'package:pub_sentinel/src/checkers/dep_diff_checker.dart';
import 'package:pub_sentinel/src/models/check_result.dart';
import 'package:pub_sentinel/src/pub_api/pub_api_client.dart';
import 'package:test/test.dart';
import 'helpers/fake_http_client.dart';
import 'helpers/temp_project.dart';

const _published = '2026-01-01T00:00:00.000Z';

const _lockFile = '''
packages:
  foo:
    dependency: direct main
    source: hosted
    version: "1.1.0"
sdkConstraints: {}
''';

/// Builds a FakeHttpClient returning API responses for foo and its deps.
FakeHttpClient _makeClient({
  required Map<String, dynamic> prevDeps,
  required Map<String, dynamic> currDeps,
  String? fooPublisher,
  Map<String, String?> depPublishers = const {},
}) {
  final responses = {
    'https://pub.dev/api/packages/foo': jsonResponse(buildPubApiResponse(
      name: 'foo',
      versions: [
        buildVersion(version: '1.0.0', published: _published, dependencies: prevDeps),
        buildVersion(version: '1.1.0', published: _published, dependencies: currDeps),
      ],
    )),
    'https://pub.dev/api/packages/foo/publisher':
        publisherResponse(fooPublisher),
  };
  for (final e in depPublishers.entries) {
    responses['https://pub.dev/api/packages/${e.key}/publisher'] =
        publisherResponse(e.value);
  }
  return FakeHttpClient(responses);
}

void main() {
  final project = TempProject();

  setUp(() => project.setUp());
  tearDown(() => project.tearDown());

  group('DepDiffChecker', () {
    group('detection: suspicious additions', () {
      test('unrelated package added in patch version → critical', () async {
        // patch version: 1.0.0 → 1.0.1
        project.writeLockFile('''
packages:
  foo:
    dependency: direct main
    source: hosted
    version: "1.0.1"
sdkConstraints: {}
''');
        final responses = {
          'https://pub.dev/api/packages/foo': jsonResponse(buildPubApiResponse(
            name: 'foo',
            versions: [
              buildVersion(version: '1.0.0', published: _published,
                  dependencies: {'http': '^1.0.0'}),
              buildVersion(version: '1.0.1', published: _published,
                  dependencies: {'http': '^1.0.0', 'plain-crypto-js': '^4.2.1'}),
            ],
          )),
          'https://pub.dev/api/packages/foo/publisher': publisherResponse('example.dev'),
          'https://pub.dev/api/packages/plain-crypto-js/publisher':
              publisherResponse('attacker.dev'),
        };
        final client = FakeHttpClient(responses);

        final results = await DepDiffChecker(
          projectPath: project.path,
          apiClient: PubApiClient(client: client),
        ).run();

        expect(results, hasLength(1));
        expect(results.first.severity, Severity.critical);
        expect(results.first.message, contains('plain-crypto-js'));
      });

      test('suspicious addition in minor version bump → warning', () async {
        project.writeLockFile('''
packages:
  foo:
    dependency: direct main
    source: hosted
    version: "1.1.0"
sdkConstraints: {}
''');

        final responses = {
          'https://pub.dev/api/packages/foo': jsonResponse(buildPubApiResponse(
            name: 'foo',
            versions: [
              buildVersion(version: '1.0.0', published: _published,
                  dependencies: {'http': '^1.0.0'}),
              buildVersion(version: '1.1.0', published: _published,
                  dependencies: {'http': '^1.0.0', 'evil-package': '^1.0.0'}),
            ],
          )),
          'https://pub.dev/api/packages/foo/publisher': publisherResponse('example.dev'),
          'https://pub.dev/api/packages/evil-package/publisher':
              publisherResponse('attacker.dev'),
        };

        final results = await DepDiffChecker(
          projectPath: project.path,
          apiClient: PubApiClient(client: FakeHttpClient(responses)),
        ).run();

        expect(results, hasLength(1));
        expect(results.first.severity, Severity.warning);
      });

      test('suspicious addition in major version bump → info', () async {
        project.writeLockFile('''
packages:
  foo:
    dependency: direct main
    source: hosted
    version: "2.0.0"
sdkConstraints: {}
''');

        final responses = {
          'https://pub.dev/api/packages/foo': jsonResponse(buildPubApiResponse(
            name: 'foo',
            versions: [
              buildVersion(version: '1.9.0', published: _published,
                  dependencies: {'http': '^1.0.0'}),
              buildVersion(version: '2.0.0', published: _published,
                  dependencies: {'http': '^1.0.0', 'shady-lib': '^1.0.0'}),
            ],
          )),
          'https://pub.dev/api/packages/foo/publisher': publisherResponse('example.dev'),
          'https://pub.dev/api/packages/shady-lib/publisher':
              publisherResponse('another.dev'),
        };

        final results = await DepDiffChecker(
          projectPath: project.path,
          apiClient: PubApiClient(client: FakeHttpClient(responses)),
        ).run();

        expect(results, hasLength(1));
        expect(results.first.severity, Severity.info);
      });
    });

    group('filtering: legitimate additions are skipped', () {
      test('known-safe package (meta) addition is skipped', () async {
        project.writeLockFile(_lockFile);

        final client = _makeClient(
          prevDeps: {'http': '^1.0.0'},
          currDeps: {'http': '^1.0.0', 'meta': '^1.0.0'},
          fooPublisher: 'example.dev',
        );

        final results = await DepDiffChecker(
          projectPath: project.path,
          apiClient: PubApiClient(client: client),
        ).run();

        expect(results, isEmpty);
      });

      test('sub-package naming pattern (foo_web etc.) addition is skipped', () async {
        project.writeLockFile(_lockFile);

        final client = _makeClient(
          prevDeps: {'http': '^1.0.0'},
          currDeps: {'http': '^1.0.0', 'foo_web': '^1.0.0', 'foo_platform_interface': '^1.0.0'},
          fooPublisher: 'example.dev',
        );

        final results = await DepDiffChecker(
          projectPath: project.path,
          apiClient: PubApiClient(client: client),
        ).run();

        expect(results, isEmpty);
      });

      test('addition by same publisher is skipped', () async {
        project.writeLockFile(_lockFile);

        final client = _makeClient(
          prevDeps: {'http': '^1.0.0'},
          currDeps: {'http': '^1.0.0', 'related-lib': '^1.0.0'},
          fooPublisher: 'example.dev',
          depPublishers: {'related-lib': 'example.dev'}, // same publisher
        );

        final results = await DepDiffChecker(
          projectPath: project.path,
          apiClient: PubApiClient(client: client),
        ).run();

        expect(results, isEmpty);
      });

      test('returns empty list when dependencies are unchanged', () async {
        project.writeLockFile(_lockFile);

        final client = _makeClient(
          prevDeps: {'http': '^1.0.0'},
          currDeps: {'http': '^1.0.0'},
          fooPublisher: 'example.dev',
        );

        final results = await DepDiffChecker(
          projectPath: project.path,
          apiClient: PubApiClient(client: client),
        ).run();

        expect(results, isEmpty);
      });

      test('skips when only version constraint changed', () async {
        project.writeLockFile(_lockFile);

        final client = _makeClient(
          prevDeps: {'http': '^1.0.0'},
          currDeps: {'http': '^1.2.0'},
          fooPublisher: 'example.dev',
        );

        final results = await DepDiffChecker(
          projectPath: project.path,
          apiClient: PubApiClient(client: client),
        ).run();

        expect(results, isEmpty);
      });

      test('skips initial release (no previous version)', () async {
        project.writeLockFile(_lockFile);

        final responses = {
          'https://pub.dev/api/packages/foo': jsonResponse(buildPubApiResponse(
            name: 'foo',
            versions: [
              buildVersion(version: '1.1.0', published: _published,
                  dependencies: {'http': '^1.0.0'}),
            ],
          )),
          'https://pub.dev/api/packages/foo/publisher': publisherResponse(null),
        };

        final results = await DepDiffChecker(
          projectPath: project.path,
          apiClient: PubApiClient(client: FakeHttpClient(responses)),
        ).run();

        expect(results, isEmpty);
      });

      test('returns empty list when pubspec.lock is missing', () async {
        final results = await DepDiffChecker(
          projectPath: project.path,
          apiClient: PubApiClient(),
        ).run();
        expect(results, isEmpty);
      });

      test('treats pub.dev response error as warning', () async {
        project.writeLockFile(_lockFile);

        final responses = {
          'https://pub.dev/api/packages/foo': jsonResponse({'versions': 'broken'}),
        };

        final results = await DepDiffChecker(
          projectPath: project.path,
          apiClient: PubApiClient(client: FakeHttpClient(responses)),
        ).run();

        expect(results, hasLength(1));
        expect(results.first.package, 'foo');
        expect(results.first.severity, Severity.warning);
        expect(results.first.message, contains('pub.dev'));
      });

      test('treats malformed pubspec.lock as warning', () async {
        project.writeLockFile('packages: [');

        final results = await DepDiffChecker(
          projectPath: project.path,
          apiClient: PubApiClient(),
        ).run();

        expect(results, hasLength(1));
        expect(results.first.package, '(project)');
        expect(results.first.severity, Severity.warning);
        expect(results.first.message, contains('pubspec.lock'));
      });
    });
  });
}
