class CompanyProfileModel {
  final String ticker;
  final String symbol;
  final String name;
  final String? nameAr;
  final String exchange;
  final String currency;
  final String sector;
  final String subType;
  final String isin;
  final String delay;
  final String? ceo;
  final String? employees;
  final String? website;
  final String? description;
  final String? currLogo;
  final String? excLogo;
  final String? selfLogo;
  final double? currentPrice;
  final double? change;
  final double? changePercent;
  final double? open;
  final double? high;
  final double? low;
  final int? volume;
  final String? updateTime;

  const CompanyProfileModel({
    required this.ticker,
    required this.symbol,
    required this.name,
    this.nameAr,
    required this.exchange,
    required this.currency,
    required this.sector,
    required this.subType,
    required this.isin,
    this.delay = '900',
    this.ceo,
    this.employees,
    this.website,
    this.description,
    this.currLogo,
    this.excLogo,
    this.selfLogo,
    this.currentPrice,
    this.change,
    this.changePercent,
    this.open,
    this.high,
    this.low,
    this.volume,
    this.updateTime,
  });

  factory CompanyProfileModel.fromJson(
    Map<String, dynamic> json, {
    required String symbol,
    String? nameAr,
  }) {
    final resp = json['response'];
    Map<String, dynamic> stockData = <String, dynamic>{};

    if (resp is List && resp.isNotEmpty && resp.first is Map) {
      stockData = Map<String, dynamic>.from(resp.first as Map);
    } else if (resp is Map) {
      if (resp.containsKey(symbol) && resp[symbol] is Map) {
        stockData = Map<String, dynamic>.from(resp[symbol] as Map);
      } else if (resp.containsKey('profile')) {
        stockData = Map<String, dynamic>.from(resp);
      } else if (resp.values.isNotEmpty && resp.values.first is Map) {
        stockData = Map<String, dynamic>.from(resp.values.first as Map);
      }
    }

    final profile = stockData['profile'] is Map
        ? Map<String, dynamic>.from(stockData['profile'] as Map)
        : stockData;

    final active = stockData['active'] is Map
        ? Map<String, dynamic>.from(stockData['active'] as Map)
        : <String, dynamic>{};

    double? parseDbl(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    int? parseInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    return CompanyProfileModel(
      ticker: (stockData['ticker'] ?? profile['ticker'] ?? symbol).toString(),
      symbol: (profile['symbol'] ?? symbol).toString(),
      name: (profile['name'] ?? symbol).toString(),
      nameAr: nameAr,
      exchange: (profile['exchange'] ?? 'EGX').toString(),
      currency: (profile['currency'] ?? 'EGP').toString(),
      sector: (profile['sector'] ?? '').toString(),
      subType: (profile['sub_type'] ?? 'common').toString(),
      isin: (profile['isin'] ?? '').toString(),
      delay: (profile['delay'] ?? '900').toString(),
      ceo: profile['ceo']?.toString(),
      employees: profile['employees']?.toString(),
      website: profile['website']?.toString(),
      description: profile['description']?.toString(),
      currLogo: profile['curr_logo']?.toString(),
      excLogo: profile['exc_logo']?.toString(),
      selfLogo: profile['self_logo']?.toString(),
      currentPrice: parseDbl(active['c'] ?? stockData['price']),
      change: parseDbl(active['ch'] ?? stockData['change']),
      changePercent: parseDbl(active['chp'] ?? stockData['change_percent']),
      open: parseDbl(active['o'] ?? stockData['open']),
      high: parseDbl(active['h'] ?? stockData['high']),
      low: parseDbl(active['l'] ?? stockData['low']),
      volume: parseInt(active['v'] ?? stockData['volume']),
      updateTime: stockData['updateTime']?.toString(),
    );
  }

  factory CompanyProfileModel.fallback(String symbol, {String? nameAr}) {
    return CompanyProfileModel(
      ticker: symbol,
      symbol: symbol,
      name: symbol,
      nameAr: nameAr,
      exchange: 'EGX',
      currency: 'EGP',
      sector: 'سوق الأسهم المصرية',
      subType: 'common',
      isin: '',
    );
  }
}
