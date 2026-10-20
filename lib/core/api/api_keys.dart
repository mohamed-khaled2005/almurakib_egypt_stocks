class ApiKeys {
  // ====== AlMurakib API Proxy ======
  static const String almurakibBaseUrl =
      'https://api.almurakib.com/egypt-stocks-app/api.php';

  static const String almurakibToken =
      '11x2x2x4x3XXXWWs2a9w8xvVvWxVcJZNuzn9Oft';

  // ====== FCS Direct API (for deep data: dividends, forecast, financials, converter) ======
  static const String fcsBaseUrl = 'https://api-v4.fcsapi.com';
  static const String defaultFcsApiKey =
      'lBB4ZvG2m7ma9w8xvVvWxVcJZNuzn9Oft';

  static String _fcsApiKey = defaultFcsApiKey;
  static String get fcsApiKey => _fcsApiKey;
  static void setFcsApiKey(String? key) {
    if (key != null && key.trim().isNotEmpty) {
      _fcsApiKey = key.trim();
    }
  }

  // ====== LiveSocket (WebSocket v1.1) ======
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

  // ====== Translation URL ======
  static const String defaultTranslationUrl =
      'https://api.almurakib.com/egypt-stocks-app/stocks-ar-names.json';
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
  // ✅ Backward compatibility
  // ------------------------------------------------------------------
  static const String saudiCountry = defaultCountry;
  static const String tasiSymbol = egyptMainIndexTicker;
  static const String tasiIndexId = '';
}
