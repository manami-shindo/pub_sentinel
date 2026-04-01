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
