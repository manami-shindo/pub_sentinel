import '../models/check_result.dart';

abstract class Checker {
  Future<List<CheckResult>> run();
}
