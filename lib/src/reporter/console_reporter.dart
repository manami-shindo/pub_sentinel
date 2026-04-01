import '../models/check_result.dart';
import 'reporter.dart';

class ConsoleReporter implements Reporter {
  final bool useColor;

  const ConsoleReporter({this.useColor = true});

  @override
  void report(List<CheckResult> results) {
    if (results.isEmpty) {
      _print('${_green('✓')} 問題は見つかりませんでした。');
      return;
    }

    final criticals = results.where((r) => r.severity == Severity.critical);
    final warnings = results.where((r) => r.severity == Severity.warning);
    final infos = results.where((r) => r.severity == Severity.info);

    for (final r in [...criticals, ...warnings, ...infos]) {
      final icon = switch (r.severity) {
        Severity.critical => _red('✗ CRITICAL'),
        Severity.warning => _yellow('⚠ WARNING'),
        Severity.info => _cyan('ℹ INFO'),
      };
      print('$icon  [${_sanitize(r.package)}] ${_sanitize(r.message)}');
      if (r.detail != null) {
        print('          ${_sanitize(r.detail!)}');
      }
    }

    print('');
    print(
        '${results.length} 件の問題が見つかりました '
        '(critical: ${criticals.length}, warning: ${warnings.length}, info: ${infos.length})');
  }

  void _print(String msg) => print(msg);

  String _sanitize(String input) =>
      input.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ' ');

  String _red(String s) => useColor ? '\x1B[31m$s\x1B[0m' : s;
  String _yellow(String s) => useColor ? '\x1B[33m$s\x1B[0m' : s;
  String _green(String s) => useColor ? '\x1B[32m$s\x1B[0m' : s;
  String _cyan(String s) => useColor ? '\x1B[36m$s\x1B[0m' : s;
}
