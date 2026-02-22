class StockPerformanceModel {
  final String ticker;
  final Map<String, dynamic> perf;
  final String? serverTime;

  const StockPerformanceModel({
    required this.ticker,
    required this.perf,
    this.serverTime,
  });

  factory StockPerformanceModel.fromJson(Map<String, dynamic> json) {
    final resp = json['response'];

    Map<String, dynamic>? map;

    if (resp is List && resp.isNotEmpty && resp.first is Map) {
      map = Map<String, dynamic>.from(resp.first as Map);
    } else if (resp is Map) {
      map = Map<String, dynamic>.from(resp as Map);
    }

    if (map == null) {
      throw Exception('لا توجد بيانات أداء متاحة');
    }

    final t = (map['ticker'] ?? map['symbol'] ?? map['s'] ?? '').toString();

    final perfRaw = map['perf'];
    final perfMap =
        perfRaw is Map ? Map<String, dynamic>.from(perfRaw as Map) : <String, dynamic>{};

    final info = json['info'];
    final infoMap =
        info is Map ? Map<String, dynamic>.from(info as Map) : <String, dynamic>{};
    final serverTime = infoMap['server_time']?.toString();

    return StockPerformanceModel(
      ticker: t,
      perf: perfMap,
      serverTime: serverTime,
    );
  }

  double? getNum(String key) {
    final v = perf[key];
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final s = v.toString().trim();
    final cleaned = s.replaceAll(RegExp(r'[^\d\.\-]'), '');
    return double.tryParse(cleaned);
  }
}
