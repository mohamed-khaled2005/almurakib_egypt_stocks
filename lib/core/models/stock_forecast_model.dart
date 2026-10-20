class StockForecast {
  final String ticker;
  final double? highTarget;
  final double? avgTarget;
  final double? medianTarget;
  final double? lowTarget;

  const StockForecast({
    required this.ticker,
    this.highTarget,
    this.avgTarget,
    this.medianTarget,
    this.lowTarget,
  });

  bool get hasForecast =>
      highTarget != null || avgTarget != null || lowTarget != null;

  factory StockForecast.fromJson(Map<String, dynamic> json) {
    final ticker = (json['ticker'] ?? '').toString();
    final forecast = json['forecast'];
    if (forecast is! Map<String, dynamic>) {
      return StockForecast(ticker: ticker);
    }

    double? extractValue(dynamic field) {
      if (field is List && field.isNotEmpty) {
        final first = field.first;
        if (first is Map && first.containsKey('data')) {
          final d = first['data'];
          if (d is num) return d.toDouble();
          if (d is String) return double.tryParse(d);
        }
      } else if (field is num) {
        return field.toDouble();
      }
      return null;
    }

    return StockForecast(
      ticker: ticker,
      highTarget: extractValue(forecast['price_target_high']),
      avgTarget: extractValue(forecast['price_target_average']),
      medianTarget: extractValue(forecast['price_target_median']),
      lowTarget: extractValue(forecast['price_target_low']),
    );
  }
}
