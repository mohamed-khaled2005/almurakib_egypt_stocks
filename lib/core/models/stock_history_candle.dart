class StockHistoryCandle {
  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  StockHistoryCandle({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  static double _d(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    final s = v.toString().trim();
    if (s.isEmpty) return 0.0;
    final cleaned = s.replaceAll(RegExp(r'[^\d\.\-]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }

  static DateTime _parseTime(dynamic t) {
    if (t == null) return DateTime.now();

    // ISO string
    if (t is String) {
      final s = t.trim();
      if (s.isEmpty) return DateTime.now();

      // "YYYY-MM-DD HH:MM:SS" -> ISO
      if (RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$').hasMatch(s)) {
        final iso = s.replaceFirst(' ', 'T');
        final dt = DateTime.tryParse(iso);
        if (dt != null) return dt.toLocal();
      }

      // try int string (seconds or ms)
      final asInt = int.tryParse(s);
      if (asInt != null) return _parseTime(asInt);

      final dt = DateTime.tryParse(s);
      if (dt != null) return dt.toLocal();

      return DateTime.now();
    }

    // epoch numeric
    if (t is num) {
      final n = t.toInt();

      // ms
      if (n > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(n, isUtc: false);
      }

      // seconds
      if (n > 1000000000) {
        return DateTime.fromMillisecondsSinceEpoch(n * 1000, isUtc: false);
      }
    }

    return DateTime.now();
  }

  static StockHistoryCandle _fix({
    required DateTime time,
    required double open,
    required double high,
    required double low,
    required double close,
    required double volume,
  }) {
    // لو الـ API بيبعت OHLC ناقصين
    final c = close;
    final o = open > 0 ? open : (c > 0 ? c : 0.0);

    double h = high > 0 ? high : (o > 0 ? o : c);
    double l = low > 0 ? low : (o > 0 ? o : c);

    // ضمان الاتساق
    final maxOC = (o > c ? o : c);
    final minOC = (o < c ? o : c);

    if (h < maxOC) h = maxOC;
    if (l > minOC) l = minOC;

    return StockHistoryCandle(
      time: time,
      open: o,
      high: h,
      low: l,
      close: c,
      volume: volume,
    );
  }

  /// ✅ يدعم Map أو List
  factory StockHistoryCandle.fromDynamic(dynamic item) {
    if (item is List) return StockHistoryCandle.fromList(item);
    if (item is Map) return StockHistoryCandle.fromMap(Map<String, dynamic>.from(item));
    // fallback
    return StockHistoryCandle(
      time: DateTime.now(),
      open: 0,
      high: 0,
      low: 0,
      close: 0,
      volume: 0,
    );
  }

  /// ✅ Format: [time, open, high, low, close, volume?]
  factory StockHistoryCandle.fromList(List arr) {
    final time = _parseTime(arr.isNotEmpty ? arr[0] : null);
    final open = _d(arr.length > 1 ? arr[1] : 0);
    final high = _d(arr.length > 2 ? arr[2] : 0);
    final low = _d(arr.length > 3 ? arr[3] : 0);
    final close = _d(arr.length > 4 ? arr[4] : 0);
    final vol = _d(arr.length > 5 ? arr[5] : 0);

    return _fix(
      time: time,
      open: open,
      high: high,
      low: low,
      close: close,
      volume: vol,
    );
  }

  /// ✅ يدعم مفاتيح متعددة: t/time/timestamp/date + o/open + ...
  factory StockHistoryCandle.fromMap(Map<String, dynamic> m) {
    final t = m['t'] ?? m['time'] ?? m['timestamp'] ?? m['date'] ?? m['datetime'] ?? m['ts'];

    final time = _parseTime(t);

    final open = _d(m['o'] ?? m['open']);
    final high = _d(m['h'] ?? m['high']);
    final low = _d(m['l'] ?? m['low']);
    final close = _d(m['c'] ?? m['close']);
    final vol = _d(m['v'] ?? m['volume'] ?? m['vol']);

    return _fix(
      time: time,
      open: open,
      high: high,
      low: low,
      close: close,
      volume: vol,
    );
  }
}
