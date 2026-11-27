import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../api/api_keys.dart';
import '../models/market_index_model.dart';
import '../models/stock_model.dart';
import '../models/tasi_index_model.dart';
import '../models/stock_indicator_model.dart';
import '../models/stock_performance_model.dart';
import '../models/dividend_model.dart';
import '../models/stock_forecast_model.dart';
import '../models/financial_data_model.dart';
import '../models/market_status_model.dart';
import '../models/currency_conversion_model.dart';
import '../models/stock_pivot_points_model.dart';
import '../models/company_profile_model.dart';
import 'translation_service.dart';
import 'last_update_service.dart';
import 'live_socket_service.dart';

class StockService {
  static List<MarketIndexModel>? _marketIndicesCache;
  static Future<List<MarketIndexModel>>? _marketIndicesInFlight;
  static MarketStatusModel? _cachedMarketStatus;
  static DateTime? _lastMarketStatusFetch;

  // Cached stocks list to avoid redundant API calls
  static List<StockModel>? _stocksCache;
  static DateTime? _lastStocksCacheFetch;
  static int _stocksCacheCatalogVersion = -1;

  static void clearStocksCache() {
    _stocksCache = null;
    _lastStocksCacheFetch = null;
    _stocksCacheCatalogVersion = -1;
  }

  static Future<TasiIndexModel> getTasiIndex() async {
    final indices = await getMarketIndices();
    if (indices.isEmpty) {
      throw Exception('لا توجد بيانات للمؤشر');
    }

    final mainIndex = indices.firstWhere(
      (item) => _tickerMatches(item.ticker, ApiKeys.egyptMainIndexTicker),
      orElse: () => indices.first,
    );

    return TasiIndexModel(
      value: mainIndex.value,
      change: mainIndex.change,
      changePercent: mainIndex.changePercent,
      updateTimeUtc: mainIndex.updateTimeUtc,
      indexSymbol: mainIndex.ticker,
    );
  }

  static void clearIndicesCache() {
    _marketIndicesCache = null;
  }

  static Future<List<MarketIndexModel>> getMarketIndices({
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      _marketIndicesCache = null;
    }

    if (!forceRefresh && _marketIndicesCache != null) {
      return _marketIndicesCache!;
    }

    if (!forceRefresh && _marketIndicesInFlight != null) {
      return _marketIndicesInFlight!;
    }

    _marketIndicesInFlight = _loadMarketIndices();
    try {
      final indices = await _marketIndicesInFlight!;
      _marketIndicesCache = indices;
      return indices;
    } finally {
      _marketIndicesInFlight = null;
    }
  }

  static Future<List<MarketIndexModel>> _loadMarketIndices() async {
    // 1. Ensure latest translations and managed indices are loaded from Manager
    await TranslationService.getTranslations();

    // 2. Fetch live quotes from API Gateway
    final liveByNormalizedKey = <String, MarketIndexModel>{};
    try {
      final latestData = await ApiClient.get(
        ApiEndpoints.indicesLatest(exchange: ApiKeys.egyptExchange),
      );
      LastUpdateService.updateFromApi(latestData);

      final latestResponse = latestData['response'];
      if (latestResponse is List) {
        for (final entry in latestResponse.whereType<Map>()) {
          final m = MarketIndexModel.fromJson(Map<String, dynamic>.from(entry));
          final key = TranslationService.normalizeIndexKey(m.ticker);
          if (key.isNotEmpty) {
            liveByNormalizedKey[key] = m;
          }
        }
      }
    } catch (_) {
      // Proceed gracefully even if live prices endpoint is temporarily down
    }

    // 3. Dynamic binding with Manager: If manager indices exist, they are the single source of truth
    if (TranslationService.hasManagedIndices) {
      final result = <MarketIndexModel>[];
      for (final managed in TranslationService.managedIndices) {
        // Skip any blocked index
        if (TranslationService.isBlocked(managed.symbol)) {
          continue;
        }

        // Match live market data
        MarketIndexModel? matchedLive;
        for (final entry in liveByNormalizedKey.entries) {
          if (TranslationService.matchIndexSymbols(managed.symbol, entry.key)) {
            matchedLive = entry.value;
            break;
          }
        }

        final preferredName = managed.preferredName;
        final canonicalTicker = matchedLive?.ticker.isNotEmpty == true
            ? matchedLive!.ticker
            : (managed.symbol.startsWith('EGX:') ? managed.symbol : 'EGX:${managed.symbol}');

        if (matchedLive != null && matchedLive.value > 0) {
          result.add(
            matchedLive.copyWith(
              ticker: canonicalTicker,
              name: preferredName,
              hasMarketData: true,
            ),
          );
        } else {
          result.add(
            MarketIndexModel(
              ticker: canonicalTicker,
              name: preferredName,
              value: 0.0,
              change: 0.0,
              changePercent: 0.0,
              hasMarketData: false,
            ),
          );
        }
      }
      return result;
    }

    // 4. Fallback if manager has no index config: use Gateway indices list
    final listData = await ApiClient.get(
      ApiEndpoints.indicesList(
        country: ApiKeys.defaultCountry,
        exchange: ApiKeys.egyptExchange,
      ),
    );
    LastUpdateService.updateFromApi(listData);

    final listResponse = listData['response'];
    if (listResponse is! List) {
      return <MarketIndexModel>[];
    }

    final seenTickers = <String>{};
    final fallbackIndices = <MarketIndexModel>[];

    for (final entry in listResponse.whereType<Map>()) {
      final rawExchange = (entry['exchange'] ?? '').toString().trim().toUpperCase();
      if (rawExchange.isNotEmpty && !rawExchange.contains('EGX')) {
        continue;
      }
      final rawSymbol = (entry['symbol'] ?? entry['ticker'] ?? '').toString().trim().toUpperCase();
      if (rawSymbol.startsWith('FTSE:') ||
          rawSymbol.contains('AIM') ||
          rawSymbol.contains('MIB') ||
          rawSymbol.contains('ITMC')) {
        continue;
      }
      final index = MarketIndexModel.fromJson(Map<String, dynamic>.from(entry));
      final normKey = TranslationService.normalizeIndexKey(index.ticker);
      if (normKey.isEmpty || !seenTickers.add(normKey)) {
        continue;
      }
      if (TranslationService.isBlocked(index.ticker)) {
        continue;
      }

      MarketIndexModel? matchedLive;
      for (final liveEntry in liveByNormalizedKey.entries) {
        if (TranslationService.matchIndexSymbols(index.ticker, liveEntry.key)) {
          matchedLive = liveEntry.value;
          break;
        }
      }

      final resolvedName = TranslationService.resolveIndexDisplayName(
        ticker: index.ticker,
        fallbackName: index.name,
      );

      if (matchedLive != null && matchedLive.value > 0) {
        fallbackIndices.add(
          matchedLive.copyWith(
            ticker: index.ticker,
            name: resolvedName,
            hasMarketData: true,
          ),
        );
      } else {
        fallbackIndices.add(
          index.copyWith(name: resolvedName),
        );
      }
    }

    return fallbackIndices;
  }

  static bool _tickerMatches(String actual, String expected) {
    return _normalizeTicker(actual) == _normalizeTicker(expected);
  }

  static String _normalizeTicker(String value) {
    return value.trim().toUpperCase();
  }

  static Future<List<StockModel>> getTopGainers({int limit = 10}) async {
    await TranslationService.getTranslations();
    final data = await ApiClient.get(
      ApiEndpoints.latest(
        country: ApiKeys.defaultCountry,
        sortBy: 'chp_desc',
        perPage: limit * 3,
        page: 1,
        getProfile: true,
        type: 'stock',
        subType: 'common',
      ),
    );

    LastUpdateService.updateFromApi(data);

    final stocks = _parseStocks(data);
    final attached = await attachArabicNames(stocks);
    final allowed = attached
        .where((s) =>
            TranslationService.isStockAllowed(s.symbol, s.id) &&
            s.price > 0 &&
            s.changePercent > 0)
        .take(limit)
        .toList();

    // Auto-subscribe to live quotes
    LiveSocketService.instance.subscribeBatch(allowed.map((s) => s.symbol).toList());
    return allowed;
  }

  static Future<List<StockModel>> getTopLosers({int limit = 10}) async {
    await TranslationService.getTranslations();
    final data = await ApiClient.get(
      ApiEndpoints.latest(
        country: ApiKeys.defaultCountry,
        sortBy: 'chp_asc',
        perPage: limit * 3,
        page: 1,
        getProfile: true,
        type: 'stock',
        subType: 'common',
      ),
    );

    LastUpdateService.updateFromApi(data);

    final stocks = _parseStocks(data);
    final attached = await attachArabicNames(stocks);
    final allowed = attached
        .where((s) =>
            TranslationService.isStockAllowed(s.symbol, s.id) &&
            s.price > 0 &&
            s.changePercent < 0)
        .take(limit)
        .toList();

    // Auto-subscribe to live quotes
    LiveSocketService.instance.subscribeBatch(allowed.map((s) => s.symbol).toList());
    return allowed;
  }

  static bool _matchesSymbolOrId(StockModel a, String query) {
    final q = query.trim().toUpperCase();
    final nq = _norm(q).toUpperCase();
    final aSym = a.symbol.trim().toUpperCase();
    final anSym = _norm(aSym).toUpperCase();
    final aId = a.id.trim().toUpperCase();
    final anId = _norm(aId).toUpperCase();
    return aSym == q || anSym == nq || aId == q || anId == nq || anSym == q || aSym == nq;
  }

  static Future<List<StockModel>> getBySymbols(List<String> symbols) async {
    if (symbols.isEmpty) return [];
    await TranslationService.getTranslations();
    final allowedSymbols = symbols
        .where((s) => TranslationService.isStockAllowed(s))
        .toList();
    if (allowedSymbols.isEmpty) return [];

    // Ensure stocks cache exists so logos and details are available
    if (_stocksCache == null || _stocksCache!.isEmpty) {
      try {
        await getStocksList();
      } catch (_) {}
    }

    final joined = allowedSymbols.join(',');
    final data = await ApiClient.get(
      ApiEndpoints.latest(
        symbol: joined,
        getProfile: true,
        type: 'stock',
        subType: 'common',
      ),
    );

    LastUpdateService.updateFromApi(data);

    final stocks = _parseStocks(data);
    final attached = await attachArabicNames(stocks);

    // Enrich with selfLogo from _stocksCache if missing
    final enriched = attached.map((s) {
      if (s.selfLogo != null && s.selfLogo!.trim().isNotEmpty) return s;
      if (_stocksCache != null && _stocksCache!.isNotEmpty) {
        for (final cached in _stocksCache!) {
          if (_matchesSymbolOrId(cached, s.symbol) || _matchesSymbolOrId(cached, s.id)) {
            if (cached.selfLogo != null && cached.selfLogo!.trim().isNotEmpty) {
              return s.copyWith(selfLogo: cached.selfLogo);
            }
          }
        }
      }
      return s;
    }).toList();

    final allowed = enriched
        .where((s) => TranslationService.isStockAllowed(s.symbol, s.id))
        .toList();

    LiveSocketService.instance.subscribeBatch(allowed.map((s) => s.symbol).toList());
    return allowed;
  }

  static String _norm(String s) {
    final t = s.trim();
    if (t.isEmpty) return t;
    return t.contains(':') ? t.split(':').last.trim() : t;
  }

  static Future<List<StockModel>> getStocksList({
    int perPage = 500,
    int page = 1,
    bool forceRefresh = false,
  }) async {
    await TranslationService.getTranslations();
    final now = DateTime.now();
    if (!forceRefresh &&
        page == 1 &&
        _stocksCache != null &&
        _lastStocksCacheFetch != null &&
        _stocksCacheCatalogVersion == TranslationService.catalogVersion &&
        now.difference(_lastStocksCacheFetch!) < const Duration(minutes: 1)) {
      return perPage < _stocksCache!.length
          ? _stocksCache!.take(perPage).toList()
          : _stocksCache!;
    }

    final results = await Future.wait([
      ApiClient.get(
        ApiEndpoints.latest(
          country: ApiKeys.defaultCountry,
          perPage: perPage,
          page: page,
          getProfile: true,
          type: 'stock',
          subType: 'common',
        ),
      ),
      ApiClient.get(
        ApiEndpoints.list(
          country: ApiKeys.defaultCountry,
          perPage: perPage,
          page: page,
        ),
      ),
    ]);

    final latestData = results[0];
    final listData = results[1];

    LastUpdateService.updateFromApi(latestData);
    LastUpdateService.updateFromApi(listData);

    final latestStocks = _parseStocks(latestData);
    final listStocks = _parseStocks(listData);

    final Map<String, String> logoById = {};
    final Map<String, String> logoBySymbol = {};
    final Map<String, String> logoByNormSymbol = {};

    for (final s in listStocks) {
      final logo = s.selfLogo?.trim();
      if (logo == null || logo.isEmpty) continue;

      if (s.id.trim().isNotEmpty) {
        logoById[s.id.trim()] = logo;
        logoById[_norm(s.id)] = logo;
      }

      if (s.symbol.trim().isNotEmpty) {
        logoBySymbol[s.symbol.trim()] = logo;
        logoByNormSymbol[_norm(s.symbol)] = logo;
      }

      final nSym = _norm(s.symbol);
      if (nSym.isNotEmpty) logoByNormSymbol[nSym] = logo;
    }

    final merged = latestStocks.map((s) {
      final existing = s.selfLogo?.trim();
      if (existing != null && existing.isNotEmpty) return s;

      final id = s.id.trim();
      final sym = s.symbol.trim();
      final nId = _norm(id);
      final nSym = _norm(sym);

      final logo = logoById[id] ??
          logoById[nId] ??
          logoBySymbol[sym] ??
          logoByNormSymbol[nSym];

      if (logo == null || logo.trim().isEmpty) return s;
      return s.copyWith(selfLogo: logo);
    }).toList();

    final result = await attachArabicNames(merged);
    final allowed = result
        .where((s) => TranslationService.isStockAllowed(s.symbol, s.id))
        .toList();

    if (page == 1 && perPage >= 200) {
      _stocksCache = allowed;
      _lastStocksCacheFetch = DateTime.now();
      _stocksCacheCatalogVersion = TranslationService.catalogVersion;
    }

    // Subscribe all stocks in batch
    LiveSocketService.instance.subscribeBatch(allowed.map((s) => s.symbol).toList());

    return allowed;
  }

  /// ✅ Fetch Investment Funds (صناديق الاستثمار - تشمل كافة الصناديق والريت في البورصة المصرية مثل EGX:EGREF)
  /// CRITICAL ARCHITECTURAL RULE: Funds/REITs are strictly REST API only (never WebSocket).
  static Future<List<StockModel>> getAssetsByCategory(String category) async {
    final cat = category.toLowerCase().trim();
    if (cat == 'funds' || cat == 'fund' || cat == 'reits' || cat == 'reit' || cat == 'etfs' || cat == 'etf') {
      try {
        await TranslationService.getTranslations();
        final data = await ApiClient.get(
          ApiEndpoints.latest(
            country: ApiKeys.defaultCountry,
            exchange: ApiKeys.egyptExchange,
            getProfile: true,
            type: 'fund',
            perPage: 100,
          ),
        );
        final stocks = _parseStocks(data);
        final attached = await attachArabicNames(stocks);
        final allowed = attached
            .where((s) => TranslationService.isStockAllowed(s.symbol, s.id))
            .toList();

        if (allowed.isNotEmpty) return allowed;

        // Fallback: query with subType: 'reit' in case upstream API requires specific subType
        final fallbackData = await ApiClient.get(
          ApiEndpoints.latest(
            country: ApiKeys.defaultCountry,
            exchange: ApiKeys.egyptExchange,
            getProfile: true,
            type: 'fund',
            subType: 'reit',
            perPage: 100,
          ),
        );
        final fbStocks = _parseStocks(fallbackData);
        final fbAttached = await attachArabicNames(fbStocks);
        return fbAttached
            .where((s) => TranslationService.isStockAllowed(s.symbol, s.id))
            .toList();
      } catch (_) {
        return <StockModel>[];
      }
    }

    // Default to stocks
    return getStocksList();
  }

  static Future<StockModel> getStockDetail(String symbol) async {
    final data = await ApiClient.get(
      ApiEndpoints.latest(
        symbol: symbol,
        getProfile: true,
        type: 'stock',
        subType: 'common',
      ),
    );

    LastUpdateService.updateFromApi(data);

    final list = _parseStocks(data);
    if (list.isEmpty) throw Exception('لم يتم العثور على بيانات السهم');

    final translated = await attachArabicNames([list.first]);
    var result = translated.first;

    if ((result.selfLogo == null || result.selfLogo!.trim().isEmpty) &&
        _stocksCache != null &&
        _stocksCache!.isNotEmpty) {
      for (final cached in _stocksCache!) {
        if (_matchesSymbolOrId(cached, result.symbol) ||
            _matchesSymbolOrId(cached, result.id)) {
          if (cached.selfLogo != null && cached.selfLogo!.trim().isNotEmpty) {
            result = result.copyWith(selfLogo: cached.selfLogo);
            break;
          }
        }
      }
    }

    // Subscribe single symbol for fast streaming ONLY if it is a common stock
    if (result.canUseWebSocket) {
      LiveSocketService.instance.subscribe(result.symbol);
    }

    return result;
  }

  static Future<StockIndicatorModel> getIndicators(
    String symbol, {
    bool isIndex = false,
  }) async {
    final data = await ApiClient.get(
      ApiEndpoints.indicators(symbol: symbol, isIndex: isIndex),
    );
    LastUpdateService.updateFromApi(data);
    return StockIndicatorModel.fromJson(data);
  }

  static Future<StockPerformanceModel> getPerformance(
    String symbol, {
    bool isIndex = false,
  }) async {
    try {
      final data = await ApiClient.get(
        ApiEndpoints.performance(symbol: symbol, isIndex: isIndex),
      );
      LastUpdateService.updateFromApi(data);
      return StockPerformanceModel.fromJson(data);
    } catch (_) {
      return StockPerformanceModel.fallback(symbol);
    }
  }

  // ===================================================================
  // ✅ Dividends (توزيعات الأرباح)
  // ===================================================================
  static Future<DividendData> getDividends(String symbol) async {
    try {
      final url = ApiEndpoints.dividend(symbol: symbol);
      final data = await ApiClient.get(url);
      final resp = data['response'];
      if (resp is Map) {
        // May be nested under symbol
        final stockMap = resp[symbol] ?? resp.values.firstWhere((v) => v is Map, orElse: () => null);
        if (stockMap is Map) {
          return DividendData.fromJson(Map<String, dynamic>.from(stockMap));
        }
      }
      return DividendData(
        ticker: symbol,
        payouts: const [],
        historyYield: const {},
      );
    } catch (_) {
      return DividendData(
        ticker: symbol,
        payouts: const [],
        historyYield: const {},
      );
    }
  }

  // ===================================================================
  // ✅ Analyst Forecasts (توقعات المحللين)
  // ===================================================================
  static Future<StockForecast> getForecast(String symbol) async {
    try {
      final url = ApiEndpoints.forecast(symbol: symbol);
      final data = await ApiClient.get(url);
      final resp = data['response'];
      if (resp is Map) {
        final stockMap = resp[symbol] ?? resp.values.firstWhere((v) => v is Map, orElse: () => null);
        if (stockMap is Map) {
          return StockForecast.fromJson(Map<String, dynamic>.from(stockMap));
        }
      }
      return StockForecast(ticker: symbol);
    } catch (_) {
      return StockForecast(ticker: symbol);
    }
  }

  // ===================================================================
  // ✅ Financial Statements & Ratios (القوائم المالية والنسب)
  // ===================================================================
  static Future<FinancialsData> getFinancials(String symbol) async {
    try {
      final futures = await Future.wait([
        ApiClient.get(ApiEndpoints.statistics(symbol: symbol)).catchError((_) => <String, dynamic>{}),
        ApiClient.get(ApiEndpoints.balanceSheet(symbol: symbol)).catchError((_) => <String, dynamic>{}),
        ApiClient.get(ApiEndpoints.incomeStatements(symbol: symbol)).catchError((_) => <String, dynamic>{}),
        ApiClient.get(ApiEndpoints.cashFlow(symbol: symbol)).catchError((_) => <String, dynamic>{}),
      ]);

      final statData = futures[0]['response'];
      final balanceData = futures[1]['response'];
      final incomeData = futures[2]['response'];
      final cashData = futures[3]['response'];

      return FinancialsData(
        ticker: symbol,
        ratios: FinancialsData.parseMetricsFromResponse(statData, subSection: 'statistics'),
        balanceSheet: FinancialsData.parseMetricsFromResponse(balanceData, subSection: 'balance_sheet'),
        incomeStatement: FinancialsData.parseMetricsFromResponse(incomeData, subSection: 'income_statement'),
        cashFlow: FinancialsData.parseMetricsFromResponse(cashData, subSection: 'cash_flow'),
      );
    } catch (_) {
      return FinancialsData(ticker: symbol);
    }
  }

  // ===================================================================
  // ✅ Market Status (حالة السوق والعد التنازلي)
  // ===================================================================
  static Future<MarketStatusModel> getMarketStatus({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedMarketStatus != null &&
        _lastMarketStatusFetch != null &&
        now.difference(_lastMarketStatusFetch!) < const Duration(minutes: 3)) {
      return _cachedMarketStatus!;
    }

    try {
      // Use benchmark stock EGX:COMI which has full EGX market hours and session profile
      final url = ApiEndpoints.profile(symbol: 'EGX:COMI');
      final data = await ApiClient.get(url);
      final resp = data['response'];
      if (resp is Map) {
        _cachedMarketStatus = MarketStatusModel.fromJson(Map<String, dynamic>.from(resp));
        _lastMarketStatusFetch = DateTime.now();
        return _cachedMarketStatus!;
      }
    } catch (_) {}

    return _cachedMarketStatus ?? MarketStatusModel.fallback();
  }

  // ===================================================================
  // ✅ Currency Converter (محول العملات)
  // ===================================================================
  static Future<CurrencyConversionResult> convertCurrency({
    required String from,
    required String to,
    required double amount,
  }) async {
    final url = ApiEndpoints.currencyConverter(from: from, to: to, amount: amount);
    final data = await ApiClient.get(url);
    return CurrencyConversionResult.fromJson(
      json: data,
      from: from,
      to: to,
      amount: amount,
    );
  }

  // ===================================================================
  // ✅ Pivot Points / Support & Resistance (الدعم والمقاومة للأسهم)
  // ===================================================================
  static Future<StockPivotPointsModel> getPivotPoints({
    required String symbol,
    String period = '1d',
    bool isIndex = false,
  }) async {
    try {
      final url = ApiEndpoints.pivotPoints(
        symbol: symbol,
        period: period,
        isIndex: isIndex,
      );
      final data = await ApiClient.get(url);
      LastUpdateService.updateFromApi(data);
      return StockPivotPointsModel.fromJson(data, symbol: symbol, period: period);
    } catch (_) {
      return StockPivotPointsModel.fallback(symbol: symbol, period: period);
    }
  }

  // ===================================================================
  // ✅ Company Profile (بروفايل الشركة)
  // ===================================================================
  static Future<CompanyProfileModel> getCompanyProfile(
    String symbol, {
    String? nameAr,
  }) async {
    // 1. Try getProfile endpoint first
    try {
      final url = ApiEndpoints.getProfile(symbol: symbol);
      final data = await ApiClient.get(url);
      if (data['status'] == true && data['response'] != null) {
        LastUpdateService.updateFromApi(data);
        return CompanyProfileModel.fromJson(data, symbol: symbol, nameAr: nameAr);
      }
    } catch (_) {}

    // 2. Fallback to latest with getProfile = true
    try {
      final fallbackUrl = ApiEndpoints.latest(symbol: symbol, getProfile: true);
      final data = await ApiClient.get(fallbackUrl);
      if (data['status'] == true && data['response'] != null) {
        LastUpdateService.updateFromApi(data);
        return CompanyProfileModel.fromJson(data, symbol: symbol, nameAr: nameAr);
      }
    } catch (_) {}

    return CompanyProfileModel.fallback(symbol, nameAr: nameAr);
  }

  static Future<List<StockModel>> attachArabicNames(List<StockModel> stocks) async {
    final translations = await TranslationService.getTranslations();
    if (translations == null) return stocks;

    return stocks.map((s) {
      final ar = translations.getArabicName(id: s.id, symbol: s.symbol);
      return s.copyWith(arabicName: ar);
    }).toList();
  }

  static List<StockModel> _parseStocks(Map<String, dynamic> data) {
    final resp = data['response'];
    if (resp is! List) throw Exception('صيغة response غير متوقعة');
    if (resp.isEmpty) return [];

    return resp
        .whereType<Map>()
        .map((e) => StockModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
