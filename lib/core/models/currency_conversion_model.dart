class CurrencyConversionResult {
  final String from;
  final String to;
  final double amount;
  final double total;
  final double rate;

  const CurrencyConversionResult({
    required this.from,
    required this.to,
    required this.amount,
    required this.total,
    required this.rate,
  });

  factory CurrencyConversionResult.fromJson({
    required Map<String, dynamic> json,
    required String from,
    required String to,
    required double amount,
  }) {
    final response = json['response'] is Map<String, dynamic>
        ? json['response'] as Map<String, dynamic>
        : <String, dynamic>{};

    final total = _parseDouble(response['total']);
    final rateKey = 'price_1x_$to';
    final altRateKey = 'price_1x_${to.toUpperCase()}';
    var rate = _parseDouble(response[rateKey] ?? response[altRateKey]);
    if (rate == 0.0 && amount > 0) {
      rate = total / amount;
    }

    return CurrencyConversionResult(
      from: from,
      to: to,
      amount: amount,
      total: total,
      rate: rate,
    );
  }

  static double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) {
      final clean = val.replaceAll(RegExp(r'[^\d\.-]'), '');
      return double.tryParse(clean) ?? 0.0;
    }
    return 0.0;
  }
}
