import 'api_keys.dart';

class ApiEndpoints {
  static String _build(String endpoint, Map<String, String> params) {
    final qp = <String, String>{
      'token': ApiKeys.almurakibToken,
      'endpoint': endpoint,
      ...params,
    };

    return Uri.parse(ApiKeys.almurakibBaseUrl)
        .replace(queryParameters: qp)
        .toString();
  }

  /// ✅ Indices Latest
  /// المؤكد أنه شغال: exchange=EGX
  /// ويدعم symbol (مفرد) حسب support_params
  /// تركنا symbols للتوافق فقط (لو السيرفر عنده نسخة تانية بتقرأها)
  static String indicesLatest({
    String? exchange,
    String? symbol,
    String? symbols, // compatibility only
  }) {
    final params = <String, String>{};

    if (exchange != null && exchange.trim().isNotEmpty) {
      params['exchange'] = exchange.trim();
    }

    if (symbol != null && symbol.trim().isNotEmpty) {
      params['symbol'] = symbol.trim();
    }

    // compatibility فقط (مش معتمد عليه)
    if (symbols != null && symbols.trim().isNotEmpty) {
      params['symbols'] = symbols.trim();
    }

    return _build('indices_latest', params);
  }

  static String indicesList({String? country}) {
    final safeCountry = (country == null || country.trim().isEmpty)
        ? ApiKeys.defaultCountry
        : country.trim();

    return _build('indices', {'country': safeCountry});
  }

  /// ✅ Stocks Latest
  static String latest({
    String? symbol,
    String? country,
    String? exchange,
    String? sector,
    String? sortBy,
    int? page,
    int? perPage,
    bool getProfile = true,
    String type = 'stock',
    String? subType,
  }) {
    final params = <String, String>{
      'get_profile': getProfile ? '1' : '0',
      'type': type,
    };

    if (subType != null && subType.isNotEmpty) params['sub_type'] = subType;
    if (symbol != null && symbol.isNotEmpty) params['symbol'] = symbol;

    // ✅ default country = egypt
    final safeCountry = (country == null || country.trim().isEmpty)
        ? ApiKeys.defaultCountry
        : country.trim();
    params['country'] = safeCountry;

    if (exchange != null && exchange.isNotEmpty) params['exchange'] = exchange;
    if (sector != null && sector.isNotEmpty) params['sector'] = sector;
    if (sortBy != null && sortBy.isNotEmpty) params['sort_by'] = sortBy;
    if (page != null) params['page'] = page.toString();
    if (perPage != null) params['per_page'] = perPage.toString();

    return _build('latest', params);
  }

  /// ✅ Stock List
  static String list({String? country, int perPage = 500, int page = 1}) {
    final safeCountry = (country == null || country.trim().isEmpty)
        ? ApiKeys.defaultCountry
        : country.trim();

    return _build('list', {
      'country': safeCountry,
      'per_page': perPage.toString(),
      'page': page.toString(),
    });
  }

  static const Set<String> _validHistoryPeriods = {
    '1m',
    '5m',
    '15m',
    '30m',
    '1h',
    '4h',
    '1d',
    '1w',
    '1month',
    '1',
    '5',
    '15',
    '30',
    '60',
    '240',
    '1440',
    '10080',
  };

  static String _sanitizeHistoryPeriod(String p) {
    final t = p.trim();
    if (t.isEmpty) return '1d';
    if (_validHistoryPeriods.contains(t)) return t;

    final low = t.toLowerCase();
    if (_validHistoryPeriods.contains(low)) return low;

    if (t == '1M' || low == '1mo' || low == '1mon') return '1month';
    return '1d';
  }

  /// ✅ History
  static String history({
    required String symbol,
    String period = '1d',
    int length = 300,
  }) {
    final safePeriod = _sanitizeHistoryPeriod(period);
    return _build('history', {
      'symbol': symbol,
      'period': safePeriod,
      'length': length.toString(),
    });
  }

  static String indicators({required String symbol}) {
    return _build('indicators', {'symbol': symbol});
  }

  static String performance({required String symbol}) {
    return _build('performance', {'symbol': symbol});
  }

  // ===================================================================
  // ✅ AlMurakib Mediated Endpoints (Profile, Financials, Converter)
  // All endpoints route through AlMurakib proxy, NEVER third-party directly.
  // ===================================================================

  static String profile({required String symbol}) {
    return _build('profile', {'symbol': symbol.trim()});
  }

  static String dividend({required String symbol}) {
    return _build('dividends', {'symbol': symbol.trim()});
  }

  static String forecast({required String symbol}) {
    return _build('forecast', {'symbol': symbol.trim()});
  }

  static String statistics({required String symbol}) {
    return _build('statistics', {'symbol': symbol.trim()});
  }

  static String balanceSheet({required String symbol}) {
    return _build('balance_sheet', {'symbol': symbol.trim()});
  }

  static String incomeStatements({required String symbol}) {
    return _build('income_statements', {'symbol': symbol.trim()});
  }

  static String cashFlow({required String symbol}) {
    return _build('cash_flow', {'symbol': symbol.trim()});
  }

  /// ✅ Currency Converter via AlMurakib Mediator
  static String currencyConverter({
    required String from,
    required String to,
    required double amount,
  }) {
    final qp = <String, String>{
      'token': ApiKeys.almurakibToken,
      'endpoint': 'converter',
      'pair1': from.trim().toUpperCase(),
      'pair2': to.trim().toUpperCase(),
      'amount': amount.toString(),
    };

    return Uri.parse(ApiKeys.currencyBaseUrl)
        .replace(queryParameters: qp)
        .toString();
  }
}
