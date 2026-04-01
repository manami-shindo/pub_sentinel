import 'dart:async';
import 'package:pub_sentinel/src/models/check_result.dart';
import 'package:pub_sentinel/src/reporter/console_reporter.dart';
import 'package:test/test.dart';

void main() {
  test('sanitizes terminal control characters in output', () {
    final reporter = ConsoleReporter(useColor: false);
    final lines = <String>[];

    runZoned(
      () {
        reporter.report([
          const CheckResult(
            package: 'evil\x1b[31mname',
            severity: Severity.warning,
            message: 'line1\rline2',
            detail: 'tab\tand\nnewline',
          ),
        ]);
      },
      zoneSpecification: ZoneSpecification(
        print: (_, __, ___, String line) => lines.add(line),
      ),
    );

    expect(lines.first, contains('[evil [31mname]'));
    expect(lines.first, isNot(contains('\x1b')));
    expect(lines[1], isNot(contains('\n')));
    expect(lines[1], isNot(contains('\r')));
  });
}
