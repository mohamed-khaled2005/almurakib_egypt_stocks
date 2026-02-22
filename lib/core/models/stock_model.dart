class StockModel {
  final String id;       // رقم الشركة (1010) لو أمكن
  final String symbol;   // ticker: EGX:ABUK / TADAWUL:1010 ...
  final String name;     // الاسم الإنجليزي
  final double price;
  final double change;
  final double changePercent;
  final String? arabicName;

  // ✅ NEW: logo url
  final String? selfLogo;

  // ✅ NEW (optional): currency from profile if available (EGP/SAR/...)
  final String? currency;

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
  });

  factory StockModel.fromJson(Map<String, dynamic> json) {
    final ticker = (json['ticker'] ?? json['s'] ?? json['symbol'] ?? '')
        .toString()
        .trim();

    final profile = json['profile'];
    final profileMap =
        profile is Map ? Map<String, dynamic>.from(profile as Map) : <String, dynamic>{};

    final meta = json['meta'];
    final metaMap =
        meta is Map ? Map<String, dynamic>.from(meta as Map) : <String, dynamic>{};

    final profileSymbol = (profileMap['symbol'] ?? '').toString().trim(); // e.g. 1010
    final profileName = (profileMap['name'] ?? '').toString().trim();

    final active = json['active'];
    final activeMap =
        active is Map ? Map<String, dynamic>.from(active as Map) : <String, dynamic>{};

    final price = _parseDouble(activeMap['c'] ?? json['c'] ?? json['price'] ?? json['p']);
    final change = _parseDouble(activeMap['ch'] ?? json['ch'] ?? json['change']);
    final changePercent =
        _parseDouble(activeMap['chp'] ?? json['chp'] ?? json['cp'] ?? json['change_percent']);

    // ✅ id: الأفضل رقم/رمز السهم
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
        : (json['name']?.toString().trim().isNotEmpty == true ? json['name'].toString().trim() : ticker);

    // ✅ symbol fallback لو ticker فاضي
    final finalSymbol = ticker.isNotEmpty
        ? ticker
        : (json['symbol']?.toString().trim() ??
            json['s']?.toString().trim() ??
            json['ticker']?.toString().trim() ??
            '');

    // ✅ currency (optional)
    final currency = (profileMap['currency'] ?? metaMap['currency'] ?? json['currency'])?.toString().trim();

    // ✅ logo: prefer meta.self_logo (full), else profile.self_logo (path)
    final rawLogo = metaMap['self_logo'] ??
        profileMap['self_logo'] ??
        json['self_logo'] ??
        metaMap['logo'] ??
        profileMap['logo'] ??
        json['logo'];

    final selfLogo = _normalizeLogoUrl(rawLogo);

    return StockModel(
      id: id,
      symbol: finalSymbol,
      name: name,
      price: price,
      change: change,
      changePercent: changePercent,
      selfLogo: selfLogo,
      currency: (currency != null && currency.isNotEmpty) ? currency : null,
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

  static String? _normalizeLogoUrl(dynamic value) {
    final s = value?.toString().trim();
    if (s == null || s.isEmpty) return null;

    if (s.startsWith('http://') || s.startsWith('https://')) return s;

    var path = s;
    if (path.startsWith('/')) path = path.substring(1);

    // لو already داخل assets/logos
    if (path.startsWith('assets/logos/')) {
      return 'https://api-v4.fcsapi.com/$path';
    }

    // لو جالك: stock/ri/...
    // أو: logos/...
    if (path.startsWith('stock/')) {
      path = 'assets/logos/$path';
      final lower = path.toLowerCase();
      final hasExt = lower.contains('.svg') ||
          lower.contains('.png') ||
          lower.contains('.jpg') ||
          lower.contains('.jpeg') ||
          lower.contains('.webp');
      if (!hasExt) path = '$path.svg';
      return 'https://api-v4.fcsapi.com/$path';
    }

    // لو Path بدون extension
    final lower = path.toLowerCase();
    final hasExt = lower.contains('.svg') ||
        lower.contains('.png') ||
        lower.contains('.jpg') ||
        lower.contains('.jpeg') ||
        lower.contains('.webp');

    if (!hasExt) path = '$path.svg';

    return 'https://api-v4.fcsapi.com/assets/logos/$path';
  }

  StockModel copyWith({
    String? arabicName,
    String? selfLogo,
    String? currency,
  }) {
    return StockModel(
      id: id,
      symbol: symbol,
      name: name,
      price: price,
      change: change,
      changePercent: changePercent,
      arabicName: arabicName ?? this.arabicName,
      selfLogo: selfLogo ?? this.selfLogo,
      currency: currency ?? this.currency,
    );
  }

  String get displayName => (arabicName != null && arabicName!.isNotEmpty) ? arabicName! : name;
  bool get hasArabicName => arabicName != null && arabicName!.isNotEmpty;
  bool get isGain => change >= 0;

  @override
  String toString() {
    return 'Stock(id: $id, symbol: $symbol, price: $price, change: $change, changePercent: $changePercent%, currency: $currency, selfLogo: $selfLogo)';
  }
}
