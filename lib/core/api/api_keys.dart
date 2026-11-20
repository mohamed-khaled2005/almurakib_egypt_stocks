class ApiKeys {
  // ====== AlMurakib Smart API Gateway (data.almurakib.com) ======
  static const String defaultAlmurakibBaseUrl =
      'https://data.almurakib.com/api/v1/smart/stock';

  static String _almurakibBaseUrl = defaultAlmurakibBaseUrl;
  static String get almurakibBaseUrl => _almurakibBaseUrl;

  static void setAlmurakibBaseUrl(String? url) {
    if (url != null && url.trim().isNotEmpty) {
      _almurakibBaseUrl = normalizeBaseUrl(url);
    }
  }

  /// Normalizes any input URL from manager into the correct Smart API gateway base
  static String normalizeBaseUrl(String rawUrl) {
    var url = rawUrl.trim();
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    // If the manager supplies "https://data.almurakib.com" or "data.almurakib.com"
    // automatically attach the smart stock gateway path
    if (url == 'https://data.almurakib.com' ||
        url == 'http://data.almurakib.com' ||
        url == 'data.almurakib.com') {
      return 'https://data.almurakib.com/api/v1/smart/stock';
    }
    if (url.contains('data.almurakib.com') &&
        !url.contains('/api/v1/smart/stock')) {
      if (url.endsWith('/api/v1/smart')) {
        return '$url/stock';
      }
      return 'https://data.almurakib.com/api/v1/smart/stock';
    }
    return url;
  }

  // ✅ Egypt Stocks API Key (Verified against Smart Gateway)
  static const String defaultAlmurakibToken =
      '9eca79ae4efefd5e32f447d52e343fc5c51afcdbd5404bc40d826a93b0b545d5';
  static String _almurakibToken = defaultAlmurakibToken;
  static String get almurakibToken => _almurakibToken;
  static void setAlmurakibToken(String? token) {
    if (token != null && token.trim().isNotEmpty) {
      _almurakibToken = token.trim();
    }
  }

  // ====== Dynamic Endpoints Map (Customizable from Manager) ======
  static Map<String, String> _endpoints = <String, String>{};
  static Map<String, String> get endpoints => _endpoints;
  static void setEndpoints(Map<String, dynamic>? map) {
    if (map != null) {
      _endpoints = map.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    }
  }

  static String resolveEndpoint(String key) => _endpoints[key] ?? key;

  // ====== AlMurakib Smart Forex / Currency Conversion Gateway ======
  static const String defaultForexBaseUrl =
      'https://data.almurakib.com/api/v1/smart/forex';
  static String _forexBaseUrl = defaultForexBaseUrl;
  static String get forexBaseUrl => _forexBaseUrl;
  static void setForexBaseUrl(String? url) {
    if (url != null && url.trim().isNotEmpty) {
      _forexBaseUrl = url.trim();
    }
  }

  // ====== LiveSocket (WebSocket v1.1 / v2.0) ======
  static const String liveSocketUrl = 'wss://livesocket.almurakib.com/ws';
  static const String defaultLiveSocketKey =
      'amk_d16f5f2b2fc3464e91c80735f76de09d_8221edc76b40a51d2ffc92d5f9c526a7cae5021a8f7b8b13deb620f35b054da9';

  static String _liveSocketKey = defaultLiveSocketKey;
  static String get liveSocketKey => _liveSocketKey;
  static void setLiveSocketKey(String? key) {
    if (key != null && key.trim().isNotEmpty) {
      _liveSocketKey = key.trim();
    }
  }

  // ====== Translation URL (Manager API) ======
  static const String defaultTranslationUrl =
      'https://amanager.almurakib.com/api/v1/stocks/translations?app_slug=almurakib_egypt_stocks';
  static String _translationUrl = defaultTranslationUrl;
  static String get translationUrl => _translationUrl;
  static void setTranslationUrl(String? url) {
    if (url != null && url.trim().isNotEmpty) {
      _translationUrl = url.trim();
    }
  }

  // ✅ Egypt
  static const String defaultCountry = 'egypt';
  static const String egyptExchange = 'EGX';

  // ✅ Main Index ticker
  static const String egyptMainIndexTicker = 'EGX:EGX30';

  // ------------------------------------------------------------------
  // ✅ Backward compatibility shims
  // ------------------------------------------------------------------
  static const String saudiCountry = defaultCountry;
  static const String tasiSymbol = egyptMainIndexTicker;
  static const String tasiIndexId = '';
  static String get currencyBaseUrl => _forexBaseUrl;
  static void setCurrencyBaseUrl(String? url) => setForexBaseUrl(url);
  static String get fcsApiKey => _almurakibToken;
  static void setFcsApiKey(String? key) => setAlmurakibToken(key);
}
