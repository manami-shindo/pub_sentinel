import 'dart:convert';
import '../models/check_result.dart';
import 'reporter.dart';

class JsonReporter implements Reporter {
  @override
  void report(List<CheckResult> results) {
    final output = {
      'issues': results.map((r) => r.toJson()).toList(),
      'summary': {
        'total': results.length,
        'critical': results.where((r) => r.severity == Severity.critical).length,
        'warning': results.where((r) => r.severity == Severity.warning).length,
        'info': results.where((r) => r.severity == Severity.info).length,
      },
    };
    print(const JsonEncoder.withIndent('  ').convert(output));
  }
}
