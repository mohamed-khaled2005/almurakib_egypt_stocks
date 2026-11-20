import 'api_keys.dart';

class ApiEndpoints {
  static String _build(String endpointKey, Map<String, String> params) {
    final endpoint = ApiKeys.resolveEndpoint(endpointKey);
    final baseUrl = ApiKeys.almurakibBaseUrl.trim();
    final token = ApiKeys.almurakibToken.trim();

    final qp = <String, String>{
      if (token.isNotEmpty) 'api_key': token,
      if (baseUrl.contains('.php')) 'endpoint': endpoint,
      ...params,
    };

    if (baseUrl.contains('.php')) {
      return Uri.parse(baseUrl).replace(queryParameters: qp).toString();
    }

    // Modern Smart API gateway format e.g. https://data.almurakib.com/api/v1/smart/stock/{endpoint}
    final cleanBase =
        baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final path = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    return Uri.parse('$cleanBase$path').replace(queryParameters: qp).toString();
  }

  /// ✅ Indices Latest - Always filtered by exchange=EGX
  static String indicesLatest({
    String? exchange,
    String? symbol,
    String? symbols,
  }) {
    final safeExchange = (exchange != null && exchange.trim().isNotEmpty)
        ? exchange.trim()
        : ApiKeys.egyptExchange;

    final params = <String, String>{
      'exchange': safeExchange,
    };

    if (symbol != null && symbol.trim().isNotEmpty) {
      params['symbol'] = symbol.trim();
    } else if (symbols != null && symbols.trim().isNotEmpty) {
      params['symbol'] = symbols.trim();
    }

    return _build('indices_latest', params);
  }

  /// ✅ Indices List - Always filtered by exchange=EGX & country=egypt
  static String indicesList({String? country, String? exchange}) {
    final safeCountry = (country == null || country.trim().isEmpty)
        ? ApiKeys.defaultCountry
        : country.trim();

    final safeExchange = (exchange != null && exchange.trim().isNotEmpty)
        ? exchange.trim()
        : ApiKeys.egyptExchange;

    return _build('indices', {
      'country': safeCountry,
      'exchange': safeExchange,
    });
  }

  /// ✅ Stocks & REITs Latest / Advance
  /// In Smart API:
  /// - When symbol is passed: uses `/latest` for specific quotes.
  /// - When symbol is absent: uses `/advance` with `merge=latest,profile` for market sorting/listing.
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
    final safeExchange = (exchange != null && exchange.trim().isNotEmpty)
        ? exchange.trim()
        : ApiKeys.egyptExchange;

    final safeCountry = (country == null || country.trim().isEmpty)
        ? ApiKeys.defaultCountry
        : country.trim();

    // Specific symbol(s) quote
    if (symbol != null && symbol.trim().isNotEmpty) {
      final params = <String, String>{
        'symbol': symbol.trim(),
        'period': '1d',
        if (getProfile) 'get_profile': '1',
      };
      return _build('latest', params);
    }

    // Market query (Advance): all stocks, gainers, losers, REITs
    final params = <String, String>{
      'exchange': safeExchange,
      'country': safeCountry,
      'merge': 'latest,profile',
    };

    if (type == 'fund' || subType == 'reit' || subType == 'etf') {
      params['type'] = 'fund';
    }
    if (subType != null && subType.trim().isNotEmpty) {
      params['sub_type'] = subType.trim();
    }

    if (sortBy != null && sortBy.trim().isNotEmpty) {
      final s = sortBy.trim();
      if (s == 'chp_desc') {
        params['sort_by'] = 'active.chp_desc';
      } else if (s == 'chp_asc') {
        params['sort_by'] = 'active.chp_asc';
      } else if (s.contains('.')) {
        params['sort_by'] = s;
      } else {
        params['sort_by'] = 'active.$s';
      }
    }

    if (sector != null && sector.isNotEmpty) params['sector'] = sector;
    if (page != null) params['page'] = page.toString();
    if (perPage != null) params['per_page'] = perPage.toString();

    // If using legacy .php proxy, pass endpoint=latest
    if (ApiKeys.almurakibBaseUrl.contains('.php')) {
      params['type'] = type;
      if (subType != null) params['sub_type'] = subType;
      return _build('latest', params);
    }

    return _build('advance', params);
  }

  /// ✅ Stock List - Always filtered by exchange=EGX
  static String list({
    String? country,
    String? exchange,
    int perPage = 500,
    int page = 1,
  }) {
    final safeCountry = (country == null || country.trim().isEmpty)
        ? ApiKeys.defaultCountry
        : country.trim();

    final safeExchange = (exchange != null && exchange.trim().isNotEmpty)
        ? exchange.trim()
        : ApiKeys.egyptExchange;

    return _build('list', {
      'country': safeCountry,
      'exchange': safeExchange,
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

  /// ✅ History (Candles)
  static String history({
    required String symbol,
    String period = '1d',
    int length = 300,
    bool isIndex = false,
  }) {
    final cleanSymbol = symbol.trim().replaceFirst(RegExp(r'^(EGX|egx):'), '');
    final safePeriod = _sanitizeHistoryPeriod(period);
    final sym = cleanSymbol.isNotEmpty ? cleanSymbol : symbol.trim();
    return _build('history', {
      'symbol': isIndex ? '${ApiKeys.egyptExchange}:$sym' : sym,
      'period': safePeriod,
      'length': length.toString(),
      if (isIndex) 'type': 'index',
    });
  }

  static String indicators({required String symbol, bool isIndex = false}) {
    final cleanSymbol = symbol.trim().replaceFirst(RegExp(r'^(EGX|egx):'), '');
    final sym = cleanSymbol.isNotEmpty ? cleanSymbol : symbol.trim();
    return _build('indicators', {
      'symbol': isIndex ? '${ApiKeys.egyptExchange}:$sym' : sym,
      if (isIndex) 'type': 'index',
    });
  }

  static String performance({required String symbol, bool isIndex = false}) {
    final cleanSymbol = symbol.trim().replaceFirst(RegExp(r'^(EGX|egx):'), '');
    final sym = cleanSymbol.isNotEmpty ? cleanSymbol : symbol.trim();
    return _build('performance', {
      'symbol': isIndex ? '${ApiKeys.egyptExchange}:$sym' : sym,
      if (isIndex) 'type': 'index',
    });
  }

  static String profile({required String symbol}) {
    final cleanSymbol = symbol.trim().replaceFirst(RegExp(r'^(EGX|egx):'), '');
    return _build('profile', {
      'symbol': cleanSymbol.isNotEmpty ? cleanSymbol : symbol.trim(),
    });
  }

  /// ✅ Company Profile - endpoints: get_profile / profile
  static String getProfile({required String symbol}) {
    final cleanSymbol = symbol.trim().replaceFirst(RegExp(r'^(EGX|egx):'), '');
    final sym = cleanSymbol.isNotEmpty ? cleanSymbol : symbol.trim();
    final endpointKey = ApiKeys.endpoints.containsKey('get_profile')
        ? 'get_profile'
        : (ApiKeys.endpoints.containsKey('profile') ? 'profile' : 'get_profile');
    return _build(endpointKey, {
      'symbol': sym,
      'get_profile': '1',
      'merge': 'latest,profile',
    });
  }

  /// ✅ Pivot Points (الدعم والمقاومة للأسهم) - endpoint: pivot_points
  static String pivotPoints({
    required String symbol,
    String period = '1d',
    bool isIndex = false,
  }) {
    final cleanSymbol = symbol.trim().replaceFirst(RegExp(r'^(EGX|egx):'), '');
    final sym = cleanSymbol.isNotEmpty ? cleanSymbol : symbol.trim();
    final endpointKey = ApiKeys.endpoints.containsKey('pivot_points')
        ? 'pivot_points'
        : (ApiKeys.endpoints.containsKey('pivot')
            ? 'pivot'
            : (ApiKeys.endpoints.containsKey('support_resistance')
                ? 'support_resistance'
                : 'pivot_points'));
    return _build(endpointKey, {
      'symbol': isIndex ? '${ApiKeys.egyptExchange}:$sym' : sym,
      'period': period,
      if (isIndex) 'type': 'index',
    });
  }

  static String dividend({required String symbol}) {
    return _build('dividend', {
      'symbol': symbol.trim(),
    });
  }

  static String forecast({required String symbol}) {
    return _build('forecast', {
      'symbol': symbol.trim(),
    });
  }

  static String statistics({required String symbol}) {
    return _build('statistics', {
      'symbol': symbol.trim(),
    });
  }

  static String balanceSheet({required String symbol}) {
    return _build('balance_sheet', {
      'symbol': symbol.trim(),
    });
  }

  static String incomeStatements({required String symbol}) {
    return _build('income_statements', {
      'symbol': symbol.trim(),
    });
  }

  static String cashFlow({required String symbol}) {
    return _build('cash_flow', {
      'symbol': symbol.trim(),
    });
  }

  /// ✅ Currency Converter via Smart Forex Gateway
  static String currencyConverter({
    required String from,
    required String to,
    required double amount,
  }) {
    final token = ApiKeys.almurakibToken.trim();
    final qp = <String, String>{
      if (token.isNotEmpty) 'api_key': token,
      'pair1': from.trim().toUpperCase(),
      'pair2': to.trim().toUpperCase(),
      'amount': amount.toString(),
    };

    return Uri.parse('${ApiKeys.forexBaseUrl}/converter')
        .replace(queryParameters: qp)
        .toString();
  }
}
