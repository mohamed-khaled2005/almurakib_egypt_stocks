class MarketIndexModel {
  const MarketIndexModel({
    required this.ticker,
    required this.name,
    required this.value,
    required this.change,
    required this.changePercent,
    this.updateTimeUtc,
  });

  final String ticker;
  final String name;
  final double value;
  final double change;
  final double changePercent;
  final DateTime? updateTimeUtc;

  bool get isGain => change >= 0;

  factory MarketIndexModel.fromJson(Map<String, dynamic> json) {
    final active = json['active'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(json['active'] as Map<String, dynamic>)
        : json['active'] is Map
            ? Map<String, dynamic>.from(json['active'] as Map)
            : <String, dynamic>{};

    final updateTimeRaw =
        (json['updateTime'] ?? json['update_time'])?.toString().trim();

    return MarketIndexModel(
      ticker: (json['ticker'] ?? json['symbol'] ?? '').toString().trim(),
      name: (json['name'] ?? json['index_name'] ?? json['ticker'] ?? '')
          .toString()
          .trim(),
      value: _parseDouble(active['c'] ?? json['c']),
      change: _parseDouble(active['ch'] ?? json['ch']),
      changePercent: _parseDouble(active['chp'] ?? json['chp']),
      updateTimeUtc: _parseDateTime(updateTimeRaw),
    );
  }

  static DateTime? _parseDateTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final formatted =
        RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$').hasMatch(raw)
            ? raw.replaceFirst(' ', 'T')
            : raw;
    return DateTime.tryParse(formatted);
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    final cleaned =
        value.toString().trim().replaceAll(RegExp(r'[^\d\.\-]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }
}
