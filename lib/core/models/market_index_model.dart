class MarketIndexModel {
  const MarketIndexModel({
    required this.ticker,
    required this.name,
    required this.value,
    required this.change,
    required this.changePercent,
    this.hasMarketData = true,
    this.updateTimeUtc,
  });

  final String ticker;
  final String name;
  final double value;
  final double change;
  final double changePercent;
  final bool hasMarketData;
  final DateTime? updateTimeUtc;

  bool get isGain => change >= 0;

  MarketIndexModel copyWith({
    String? ticker,
    String? name,
    double? value,
    double? change,
    double? changePercent,
    bool? hasMarketData,
    DateTime? updateTimeUtc,
  }) {
    return MarketIndexModel(
      ticker: ticker ?? this.ticker,
      name: name ?? this.name,
      value: value ?? this.value,
      change: change ?? this.change,
      changePercent: changePercent ?? this.changePercent,
      hasMarketData: hasMarketData ?? this.hasMarketData,
      updateTimeUtc: updateTimeUtc ?? this.updateTimeUtc,
    );
  }

  factory MarketIndexModel.fromJson(Map<String, dynamic> json) {
    final active = json['active'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(json['active'] as Map<String, dynamic>)
        : json['active'] is Map
            ? Map<String, dynamic>.from(json['active'] as Map)
            : <String, dynamic>{};
    final profile = json['profile'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(json['profile'] as Map<String, dynamic>)
        : json['profile'] is Map
            ? Map<String, dynamic>.from(json['profile'] as Map)
            : <String, dynamic>{};

    final updateTimeRaw =
        (json['updateTime'] ?? json['update_time'])?.toString().trim();
    final valueRaw = active['c'] ?? json['c'];
    final changeRaw = active['ch'] ?? json['ch'];
    final changePercentRaw = active['chp'] ?? json['chp'];

    return MarketIndexModel(
      ticker: (json['ticker'] ?? json['symbol'] ?? profile['symbol'] ?? '')
          .toString()
          .trim(),
      name: (json['name'] ??
              json['index_name'] ??
              profile['name'] ??
              json['ticker'] ??
              '')
          .toString()
          .trim(),
      value: _parseDouble(valueRaw),
      change: _parseDouble(changeRaw),
      changePercent: _parseDouble(changePercentRaw),
      hasMarketData:
          valueRaw != null || changeRaw != null || changePercentRaw != null,
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
