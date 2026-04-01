class VersionInfo {
  final String version;
  final DateTime published;
  final Map<String, dynamic> dependencies;
  final Map<String, dynamic> devDependencies;

  const VersionInfo({
    required this.version,
    required this.published,
    required this.dependencies,
    required this.devDependencies,
  });

  factory VersionInfo.fromJson(Map<String, dynamic> json) {
    final pubspec = json['pubspec'] as Map<String, dynamic>? ?? {};
    final deps = pubspec['dependencies'];
    final devDeps = pubspec['dev_dependencies'];
    return VersionInfo(
      version: json['version'] as String,
      published: DateTime.parse(json['published'] as String),
      dependencies: deps is Map ? Map<String, dynamic>.from(deps) : {},
      devDependencies: devDeps is Map ? Map<String, dynamic>.from(devDeps) : {},
    );
  }
}

class PackageInfo {
  final String name;
  final List<VersionInfo> versions;

  const PackageInfo({required this.name, required this.versions});

  VersionInfo? versionOrNull(String version) {
    for (final v in versions) {
      if (v.version == version) return v;
    }
    return null;
  }

  /// versions はAPIレスポンス順（古い順）なので、直前バージョンを返す
  VersionInfo? previousVersion(String version) {
    final idx = versions.indexWhere((v) => v.version == version);
    if (idx <= 0) return null;
    return versions[idx - 1];
  }
}
