import '../services/live_socket_service.dart';

class StockModel {
  final String id;
  final String symbol;
  final String name;
  final double price;
  final double change;
  final double changePercent;
  final String? arabicName;
  final String? selfLogo;
  final String? currency;

  // Key Trading Values
  final double? open;
  final double? high;
  final double? low;
  final double? volume;
  final double? vwap;
  final double? previousClose;

  // Real-Time Spreads (from Socket / Quote)
  final double? bid;
  final double? ask;

  // Profile Details
  final String? sector;
  final String? isin;
  final String? delay;
  final String type;
  final String subType;

  StockModel({
    required this.id,
    required this.symbol,
    required this.name,
    required this.price,
    required this.change,
    required this.changePercent,
    this.arabicName,
    this.selfLogo,
    this.currency,
    this.open,
    this.high,
    this.low,
    this.volume,
    this.vwap,
    this.previousClose,
    this.bid,
    this.ask,
    this.sector,
    this.isin,
    this.delay,
    this.type = 'stock',
    this.subType = 'common',
  });

  factory StockModel.fromJson(Map<String, dynamic> json) {
    final ticker = (json['ticker'] ?? json['s'] ?? json['symbol'] ?? '')
        .toString()
        .trim();

    final profile = json['profile'];
    final profileMap =
        profile is Map ? Map<String, dynamic>.from(profile) : <String, dynamic>{};

    final meta = json['meta'];
    final metaMap =
        meta is Map ? Map<String, dynamic>.from(meta) : <String, dynamic>{};

    final profileSymbol = (profileMap['symbol'] ?? '').toString().trim();
    final profileName = (profileMap['name'] ?? '').toString().trim();

    final active = json['active'];
    final activeMap =
        active is Map ? Map<String, dynamic>.from(active) : <String, dynamic>{};

    final previous = json['previous'];
    final previousMap =
        previous is Map ? Map<String, dynamic>.from(previous) : <String, dynamic>{};

    final price = _parseDouble(activeMap['c'] ?? json['c'] ?? json['price'] ?? json['p']);
    final change = _parseDouble(activeMap['ch'] ?? json['ch'] ?? json['change']);
    final changePercent =
        _parseDouble(activeMap['chp'] ?? json['chp'] ?? json['cp'] ?? json['change_percent']);

    final open = _parseNullableDouble(activeMap['o'] ?? json['o'] ?? json['open']);
    final high = _parseNullableDouble(activeMap['h'] ?? json['h'] ?? json['high']);
    final low = _parseNullableDouble(activeMap['l'] ?? json['l'] ?? json['low']);
    final volume = _parseNullableDouble(activeMap['v'] ?? json['v'] ?? json['volume']);
    final vwap = _parseNullableDouble(activeMap['vw'] ?? json['vw'] ?? json['vwap']);
    final previousClose = _parseNullableDouble(previousMap['c'] ?? json['previousClose']);

    final bid = _parseNullableDouble(activeMap['b'] ?? json['b'] ?? json['bid']);
    final ask = _parseNullableDouble(activeMap['a'] ?? json['a'] ?? json['ask']);

    String id;
    if (profileSymbol.isNotEmpty) {
      id = profileSymbol;
    } else if ((json['id'] ?? '').toString().trim().isNotEmpty) {
      id = (json['id']).toString().trim();
    } else if (ticker.contains(':')) {
      id = ticker.split(':').last.trim();
    } else {
      id = ticker;
    }
    if (id.isEmpty) id = ticker;

    final name = profileName.isNotEmpty
        ? profileName
        : (json['name']?.toString().trim().isNotEmpty == true
            ? json['name'].toString().trim()
            : ticker);

    final finalSymbol = ticker.isNotEmpty
        ? ticker
        : (json['symbol']?.toString().trim() ??
            json['s']?.toString().trim() ??
            json['ticker']?.toString().trim() ??
            '');

    final currency = (profileMap['currency'] ?? metaMap['currency'] ?? json['currency'])
        ?.toString()
        .trim();

    final rawLogo = metaMap['self_logo'] ??
        profileMap['self_logo'] ??
        json['self_logo'] ??
        metaMap['logo'] ??
        profileMap['logo'] ??
        json['logo'];

    final selfLogo = _normalizeLogoUrl(rawLogo);
    final sector = (profileMap['sector'] ?? json['sector'])?.toString().trim();
    final isin = (profileMap['isin'] ?? json['isin'])?.toString().trim();
    final delay = (profileMap['delay'] ?? metaMap['delay'] ?? json['delay'])?.toString().trim();
    final type = (json['type'] ?? profileMap['type'] ?? 'stock').toString().trim();
    final subType = (json['sub_type'] ?? profileMap['sub_type'] ?? 'common').toString().trim();

    return StockModel(
      id: id,
      symbol: finalSymbol,
      name: name,
      price: price,
      change: change,
      changePercent: changePercent,
      selfLogo: selfLogo,
      currency: (currency != null && currency.isNotEmpty) ? currency : null,
      open: open,
      high: high,
      low: low,
      volume: volume,
      vwap: vwap,
      previousClose: previousClose,
      bid: bid,
      ask: ask,
      sector: sector,
      isin: isin,
      delay: delay,
      type: type.isNotEmpty ? type : 'stock',
      subType: subType.isNotEmpty ? subType : 'common',
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^\d\.-]'), '');
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }

  static double? _parseNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^\d\.-]'), '');
      return double.tryParse(cleaned);
    }
    return null;
  }

  static String? _normalizeLogoUrl(dynamic value) {
    final s = value?.toString().trim();
    if (s == null || s.isEmpty) return null;

    if (s.startsWith('http://') || s.startsWith('https://')) return s;

    return null;
  }

  StockModel copyWith({
    String? arabicName,
    String? selfLogo,
    String? currency,
    double? price,
    double? change,
    double? changePercent,
    double? open,
    double? high,
    double? low,
    double? volume,
    double? vwap,
    double? previousClose,
    double? bid,
    double? ask,
    String? sector,
    String? isin,
    String? delay,
    String? type,
    String? subType,
  }) {
    return StockModel(
      id: id,
      symbol: symbol,
      name: name,
      price: price ?? this.price,
      change: change ?? this.change,
      changePercent: changePercent ?? this.changePercent,
      arabicName: arabicName ?? this.arabicName,
      selfLogo: selfLogo ?? this.selfLogo,
      currency: currency ?? this.currency,
      open: open ?? this.open,
      high: high ?? this.high,
      low: low ?? this.low,
      volume: volume ?? this.volume,
      vwap: vwap ?? this.vwap,
      previousClose: previousClose ?? this.previousClose,
      bid: bid ?? this.bid,
      ask: ask ?? this.ask,
      sector: sector ?? this.sector,
      isin: isin ?? this.isin,
      delay: delay ?? this.delay,
      type: type ?? this.type,
      subType: subType ?? this.subType,
    );
  }

  StockModel applyLiveUpdate(LivePriceUpdate update) {
    return copyWith(
      price: update.price,
      change: update.change ?? change,
      changePercent: update.changePercent ?? changePercent,
      previousClose: update.previousClose ?? previousClose,
      bid: update.bid ?? bid,
      ask: update.ask ?? ask,
    );
  }

  bool get hasSpread => bid != null && ask != null && bid! > 0 && ask! > 0;
  double? get spread => hasSpread ? (ask! - bid!) : null;
  double? get spreadPercent =>
      hasSpread && bid! > 0 ? (((ask! - bid!) / bid!) * 100.0) : null;

  String get displayName =>
      (arabicName != null && arabicName!.isNotEmpty) ? arabicName! : name;
  bool get hasArabicName => arabicName != null && arabicName!.isNotEmpty;
  bool get isGain => change >= 0;

  bool get isReit => subType.toLowerCase() == 'reit';
  bool get isEtf => subType.toLowerCase() == 'etf';
  bool get isFund => type.toLowerCase() == 'fund';

  @override
  String toString() {
    return 'Stock(id: $id, symbol: $symbol, price: $price, change: $change, changePercent: $changePercent%, currency: $currency, bid: $bid, ask: $ask)';
  }
}
