## 0.2.2

- `DepDiffChecker`: newly added dependencies with a verified publisher are now reported as `INFO` instead of `WARNING`/`CRITICAL`, reducing noise for low-risk additions (e.g. `objective_c` by `dart.dev`)

## 0.2.1

- Add `--ignore` flag (repeatable) and `.pub_sentinel.yaml` ignore list to exclude specific packages from all checks
- Auto-exclude the scanned project's own package from results
- Add `--min-severity` flag (`info`/`warning`/`critical`) to suppress low-signal findings
- Fix `DepDiffChecker`: when main package has no verified publisher, results now include a note explaining that publisher comparison was skipped

## 0.2.0

- Typosquat check: detects package names within 1 edit (OSA distance) of popular pub.dev packages (TyposquatChecker)

## 0.1.0

- Initial release
- `pubspec.lock` existence check (LockFileChecker)
- Version constraint check in `pubspec.yaml` (ConstraintChecker)
- New version check: warns when the locked version was published within 3 days (NewVersionChecker)
- Dependency diff check: detects supply-chain attacks via newly added dependencies (DepDiffChecker)
- Publisher check: flags unverified publishers and disposable email domains (PublisherChecker)
- Console output (with color support) and JSON output
- Exit code 1 when issues are found, 0 otherwise
