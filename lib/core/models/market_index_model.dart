import '../services/translation_service.dart';
import 'stock_model.dart';

class MarketIndexModel {
  const MarketIndexModel({
    required this.ticker,
    required this.name,
    required this.value,
    required this.change,
    required this.changePercent,
    this.open,
    this.high,
    this.low,
    this.volume,
    this.previousClose,
    this.hasMarketData = true,
    this.updateTimeUtc,
  });

  final String ticker;
  final String name;
  final double value;
  final double change;
  final double changePercent;
  final double? open;
  final double? high;
  final double? low;
  final double? volume;
  final double? previousClose;
  final bool hasMarketData;
  final DateTime? updateTimeUtc;

  bool get isGain => change >= 0;

  String get displayTicker {
    if (ticker.contains(':')) return ticker.split(':').last.trim();
    return ticker;
  }

  String get displayName {
    return TranslationService.resolveIndexDisplayName(
      ticker: ticker,
      fallbackName: name,
    );
  }

  StockModel toStockModel() {
    return StockModel(
      id: displayTicker,
      symbol: ticker.isNotEmpty ? ticker : 'EGX:$displayTicker',
      name: name,
      arabicName: displayName,
      price: value,
      change: change,
      changePercent: changePercent,
      open: open,
      high: high,
      low: low,
      volume: volume,
      previousClose: previousClose,
      currency: 'EGP',
      type: 'index',
    );
  }

  MarketIndexModel copyWith({
    String? ticker,
    String? name,
    double? value,
    double? change,
    double? changePercent,
    double? open,
    double? high,
    double? low,
    double? volume,
    double? previousClose,
    bool? hasMarketData,
    DateTime? updateTimeUtc,
  }) {
    return MarketIndexModel(
      ticker: ticker ?? this.ticker,
      name: name ?? this.name,
      value: value ?? this.value,
      change: change ?? this.change,
      changePercent: changePercent ?? this.changePercent,
      open: open ?? this.open,
      high: high ?? this.high,
      low: low ?? this.low,
      volume: volume ?? this.volume,
      previousClose: previousClose ?? this.previousClose,
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

    final openRaw = active['o'] ?? json['o'] ?? json['open'];
    final highRaw = active['h'] ?? json['h'] ?? json['high'];
    final lowRaw = active['l'] ?? json['l'] ?? json['low'];
    final volumeRaw = active['v'] ?? json['v'] ?? json['volume'];
    final prevCloseRaw = (json['previous'] is Map ? json['previous']['c'] : null) ??
        json['previousClose'] ??
        json['prev_close'];

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
      open: _parseNullableDouble(openRaw),
      high: _parseNullableDouble(highRaw),
      low: _parseNullableDouble(lowRaw),
      volume: _parseNullableDouble(volumeRaw),
      previousClose: _parseNullableDouble(prevCloseRaw),
      hasMarketData:
          valueRaw != null || changeRaw != null || changePercentRaw != null,
      updateTimeUtc: _parseDateTime(updateTimeRaw),
    );
  }

  static double? _parseNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    final cleaned =
        value.toString().trim().replaceAll(RegExp(r'[^\d\.\-]'), '');
    return double.tryParse(cleaned);
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
