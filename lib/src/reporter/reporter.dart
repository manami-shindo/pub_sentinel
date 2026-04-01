import '../models/check_result.dart';

abstract class Reporter {
  void report(List<CheckResult> results);
}
