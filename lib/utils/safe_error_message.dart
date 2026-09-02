class SafeErrorMessage {
  static const String serviceUpdating = 'قيد التحديث ويرجى المحاولة بعد قليل.';

  static const String operationFailed =
      'تعذر إكمال العملية الآن. يرجى المحاولة بعد قليل.';

  static final List<RegExp> _sensitivePatterns = <RegExp>[
    RegExp(
      r'\b(bearer|authorization|access[_-]?token|refresh[_-]?token|id[_-]?token|api[_-]?key|apikey|secret|jwt|token)\b',
      caseSensitive: false,
    ),
    RegExp(r'eyJ[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]*'),
    RegExp(
        r'([?&](token|key|api_key|apikey|access_token|refresh_token)=)[^&\s]+',
        caseSensitive: false),
    RegExp(r'\b[A-Za-z0-9_-]{32,}\b'),
  ];

  static final List<RegExp> _technicalPatterns = <RegExp>[
    RegExp(
        r'\b(exception|stack trace|socketexception|httpexception|timeoutexception)\b',
        caseSensitive: false),
    RegExp(r'\b(unsupported http|request failed|unexpected request)\b',
        caseSensitive: false),
    RegExp(r'\b(500|502|503|504)\b'),
  ];

  static String forApiFailure([Object? error]) {
    return serviceUpdating;
  }

  static String forUser(
    Object? error, {
    String fallback = operationFailed,
  }) {
    final raw = error?.toString().trim() ?? '';
    if (raw.isEmpty) return fallback;

    if (_containsSensitiveData(raw) || _looksTechnical(raw)) {
      return fallback;
    }

    return _stripExceptionPrefix(raw);
  }

  static String sanitizeText(
    Object? value, {
    String fallback = serviceUpdating,
  }) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return fallback;
    if (_containsSensitiveData(raw) || _looksTechnical(raw)) return fallback;
    return _stripExceptionPrefix(raw);
  }

  static String redactedForLog(Object? value) {
    var text = value?.toString() ?? '';
    if (text.isEmpty) return text;
    text = text.replaceAllMapped(
      RegExp(
          r'([?&](token|key|api_key|apikey|access_token|refresh_token)=)[^&\s]+',
          caseSensitive: false),
      (match) => '${match.group(1)}[REDACTED]',
    );
    text = text.replaceAllMapped(
      RegExp(r'\b(Bearer\s+)[A-Za-z0-9._-]+', caseSensitive: false),
      (match) => '${match.group(1)}[REDACTED]',
    );
    return text.replaceAllMapped(
      RegExp(r'\b[A-Za-z0-9_-]{32,}\b'),
      (_) => '[REDACTED]',
    );
  }

  static bool _containsSensitiveData(String value) {
    return _sensitivePatterns.any((pattern) => pattern.hasMatch(value));
  }

  static bool _looksTechnical(String value) {
    return _technicalPatterns.any((pattern) => pattern.hasMatch(value));
  }

  static String _stripExceptionPrefix(String value) {
    return value
        .replaceFirst(RegExp(r'^Exception:\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^AppManagerApiException:\s*'), '')
        .trim();
  }
}