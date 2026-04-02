# pub_sentinel

**pub_sentinel** is a security scanner for Dart/Flutter projects that detects supply-chain attack risks and suspicious changes in dependencies.

[![pub package](https://img.shields.io/pub/v/pub_sentinel.svg)](https://pub.dev/packages/pub_sentinel)

## Features

- **Lock file check** — warns when `pubspec.lock` is missing. Without it, different versions may be installed across environments.
- **Version constraint check** — detects unconstrained dependencies such as `any`, empty string, or `>=0.0.0`. These allow any version to be resolved.
- **New version check** — warns when the locked package version was published within the last 3 days. Freshly published packages may not have been reviewed for security.
- **Dependency diff check** — compares each locked package's dependency list against the previous version and flags newly added dependencies. This is a typical supply-chain attack pattern.
- **Publisher check** — reports packages with no verified publisher and flags those whose publisher domain matches a known disposable email service.
- **Typosquat check** — detects package names within 1 edit (OSA distance) of popular pub.dev packages, catching common typosquatting attacks like character substitution, insertion, deletion, and transposition.

## Installation

```sh
dart pub global activate pub_sentinel
```

Or add as a dev dependency:

```yaml
dev_dependencies:
  pub_sentinel: ^0.2.1
```

## Usage

Run the scanner from your Dart/Flutter project root:

```sh
pub-sentinel
```

To specify a directory:

```sh
pub-sentinel --path /path/to/your/project
```

### Options

| Flag / Option | Short | Default | Description |
|---|---|---|---|
| `--path` | `-p` | `.` | Project directory to scan |
| `--format` | `-f` | `console` | Output format: `console` or `json` |
| `--ignore` | | | Exclude a package from all checks (repeatable) |
| `--min-severity` | | `info` | Minimum severity to report: `info`, `warning`, or `critical` |
| `--no-color` | | | Disable colored output |
| `--verbose` | `-v` | | Show progress messages during scan |
| `--help` | `-h` | | Show help |

### Ignoring packages

Suppress false positives for specific packages using the `--ignore` flag:

```sh
pub-sentinel --ignore objective_c --ignore riverpod_analyzer_utils
```

Or create a `.pub_sentinel.yaml` in your project root for a persistent ignore list:

```yaml
ignore:
  - objective_c
  - riverpod_analyzer_utils
```

The project's own package is always excluded automatically.

### Console output example

```
✗ CRITICAL  [some_package] Suspicious dependencies added in v1.2.3: shady_lib
             Dependencies not present in the previous version (v1.2.2) were added.…
⚠ WARNING   [another_pkg] v0.9.1 was published only 4 hour(s) ago
⚠ WARNING   [proivder] Possible typosquatting: "proivder" is 1 edit away from "provider"
ℹ INFO      [big_package] No verified publisher

4 issue(s) found (critical: 1, warning: 2, info: 1)
```

### JSON output example

```sh
pub-sentinel --format json
```

```json
[
  {
    "package": "some_package",
    "severity": "critical",
    "message": "Suspicious dependencies added in v1.2.3: shady_lib",
    "detail": "Dependencies not present in the previous version (v1.2.2) were added. ..."
  }
]
```

### Exit codes

| Code | Meaning |
|---|---|
| `0` | No issues found |
| `1` | One or more `warning` or `critical` issues found |
| `2` | Invalid arguments or project path not found |

## CI integration

```yaml
# GitHub Actions example
- name: Run pub-sentinel
  run: |
    dart pub global activate pub_sentinel
    pub-sentinel --format json > sentinel-report.json
```

## Requirements

- Dart SDK `>=3.2.0`
- Internet access to the [pub.dev](https://pub.dev) API (used by new version check, dependency diff check, and publisher check)

## Contributing

Bug reports and pull requests are welcome at [GitHub](https://github.com/manami-shindo/pub_sentinel).

## License

Released under the MIT License. See the [LICENSE](LICENSE) file for details.
