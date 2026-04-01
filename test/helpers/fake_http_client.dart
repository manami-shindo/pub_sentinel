import 'dart:convert';
import 'package:http/http.dart' as http;

/// Fake HTTP client for tests. Returns pre-configured responses per URL.
class FakeHttpClient extends http.BaseClient {
  final Map<String, http.Response> _responses;

  FakeHttpClient(this._responses);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final url = request.url.toString();
    final response = _responses[url];
    if (response == null) {
      throw Exception('Unexpected request: $url');
    }
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}

/// Builds a pub.dev API response JSON for testing.
Map<String, dynamic> buildPubApiResponse({
  required String name,
  required List<Map<String, dynamic>> versions,
}) {
  return {
    'name': name,
    'versions': versions,
  };
}

Map<String, dynamic> buildVersion({
  required String version,
  required String published,
  Map<String, dynamic>? dependencies,
  Map<String, dynamic>? devDependencies,
}) {
  return {
    'version': version,
    'published': published,
    'archive_url': 'https://pub.dev/packages/$version.tar.gz',
    'pubspec': {
      'name': 'test_package',
      'version': version,
      if (dependencies != null) 'dependencies': dependencies,
      if (devDependencies != null) 'dev_dependencies': devDependencies,
    },
  };
}

http.Response jsonResponse(Map<String, dynamic> body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'content-type': 'application/json'},
  );
}

http.Response publisherResponse(String? publisherId) {
  return jsonResponse({'publisherId': publisherId});
}

http.Response notFound() {
  return http.Response('', 404);
}
