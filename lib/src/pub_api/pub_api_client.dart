import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/package_info.dart';

class PubApiClient {
  static const _headers = {'Accept': 'application/vnd.pub.v2+json'};
  static const _requestTimeout = Duration(seconds: 10);

  final http.Client _client;

  PubApiClient({http.Client? client}) : _client = client ?? http.Client();

  /// Returns the publisher ID for [name], or null if not set.
  Future<String?> fetchPublisher(String name) async {
    final uri = Uri(
      scheme: 'https',
      host: 'pub.dev',
      pathSegments: ['api', 'packages', name, 'publisher'],
    );
    final response = await _get(uri);
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) return null;
    final json = _decodeJsonObject(response.body, 'publisher for $name');
    return json['publisherId'] as String?;
  }

  Future<PackageInfo> fetchPackage(String name) async {
    final uri = Uri(
      scheme: 'https',
      host: 'pub.dev',
      pathSegments: ['api', 'packages', name],
    );
    final response = await _get(uri);

    if (response.statusCode == 404) {
      throw PackageNotFoundException(name);
    }
    if (response.statusCode != 200) {
      throw PubApiException(
          'Failed to fetch package $name: HTTP ${response.statusCode}');
    }

    final json = _decodeJsonObject(response.body, 'package $name');
    final rawVersions = json['versions'];
    if (rawVersions is! List) {
      throw PubApiException(
          'Invalid package response for $name: versions is missing');
    }

    final versions = rawVersions
        .map((v) => VersionInfo.fromJson(v as Map<String, dynamic>))
        .toList();

    return PackageInfo(name: name, versions: versions);
  }

  Future<http.Response> _get(Uri uri) async {
    try {
      return await _client.get(uri, headers: _headers).timeout(_requestTimeout);
    } on TimeoutException {
      throw const PubApiException('Request to pub.dev timed out');
    } on http.ClientException catch (e) {
      throw PubApiException('Request to pub.dev failed: ${e.message}');
    }
  }

  Map<String, dynamic> _decodeJsonObject(String body, String context) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw PubApiException('Invalid JSON response for $context');
      }
      return decoded;
    } on FormatException {
      throw PubApiException('Invalid JSON response for $context');
    }
  }

  void close() => _client.close();
}

class PackageNotFoundException implements Exception {
  final String packageName;
  const PackageNotFoundException(this.packageName);

  @override
  String toString() => 'Package not found: $packageName';
}

class PubApiException implements Exception {
  final String message;
  const PubApiException(this.message);

  @override
  String toString() => message;
}
