enum Severity { info, warning, critical }

class CheckResult {
  final String package;
  final Severity severity;
  final String message;
  final String? detail;

  const CheckResult({
    required this.package,
    required this.severity,
    required this.message,
    this.detail,
  });

  Map<String, dynamic> toJson() => {
        'package': package,
        'severity': severity.name,
        'message': message,
        if (detail != null) 'detail': detail,
      };
}
