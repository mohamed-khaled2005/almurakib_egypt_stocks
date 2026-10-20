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

  static Future<List<MarketIndexModel>> getMarketIndices({
    bool forceRefresh = false,
  }) async {
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
    final listData = await ApiClient.get(
      ApiEndpoints.indicesList(country: ApiKeys.defaultCountry),
    );

    LastUpdateService.updateFromApi(listData);

    final listResponse = listData['response'];
    if (listResponse is! List) {
      throw Exception('صيغة المؤشرات غير متوقعة');
    }

    final seenTickers = <String>{};
    final listedIndices = <MarketIndexModel>[];
    for (final entry in listResponse.whereType<Map>()) {
      final index = MarketIndexModel.fromJson(
        Map<String, dynamic>.from(entry),
      );
      final normalizedTicker = _normalizeTicker(index.ticker);
      if (normalizedTicker.isEmpty || !seenTickers.add(normalizedTicker)) {
        continue;
      }
      listedIndices.add(index);
    }

    if (listedIndices.isEmpty) return <MarketIndexModel>[];

    final latestByTicker = <String, MarketIndexModel>{};
    try {
      final latestData = await ApiClient.get(
        ApiEndpoints.indicesLatest(
          symbol: listedIndices.map((item) => item.ticker).join(','),
        ),
      );
      LastUpdateService.updateFromApi(latestData);

      final latestResponse = latestData['response'];
      if (latestResponse is List) {
        for (final entry in latestResponse.whereType<Map>()) {
          final index = MarketIndexModel.fromJson(
            Map<String, dynamic>.from(entry),
          );
          final normalizedTicker = _normalizeTicker(index.ticker);
          if (normalizedTicker.isEmpty) continue;
          latestByTicker[normalizedTicker] = index;
        }
      }
    } catch (_) {
      // Keep the index list visible even if live prices are temporarily unavailable.
    }

    var indices = listedIndices.map((listed) {
      final latest = latestByTicker[_normalizeTicker(listed.ticker)];
      if (latest == null) return listed;

      return latest.copyWith(
        ticker: listed.ticker,
        name: listed.name.isNotEmpty ? listed.name : latest.name,
      );
    }).toList();

    final translations = await TranslationService.getTranslations();
    if (translations != null) {
      indices = indices.map((item) {
        final arabicName = translations.getArabicIndexName(
          ticker: item.ticker,
          name: item.name,
        );
        if (arabicName == null || arabicName.trim().isEmpty) {
          return item;
        }
        return item.copyWith(name: arabicName.trim());
      }).toList();
    }

    return indices;
  }

  static bool _tickerMatches(String actual, String expected) {
    return _normalizeTicker(actual) == _normalizeTicker(expected);
  }

  static String _normalizeTicker(String value) {
    return value.trim().toUpperCase();
  }

  static Future<List<StockModel>> getTopGainers({int limit = 10}) async {
    final data = await ApiClient.get(
      ApiEndpoints.latest(
        country: ApiKeys.defaultCountry,
        sortBy: 'chp_desc',
        perPage: limit,
        page: 1,
        getProfile: true,
        type: 'stock',
        subType: 'common',
      ),
    );

    LastUpdateService.updateFromApi(data);

    final stocks = _parseStocks(data);
    final attached = await attachArabicNames(stocks);

    // Auto-subscribe to live quotes
    LiveSocketService.instance.subscribeBatch(attached.map((s) => s.symbol).toList());
    return attached;
  }

  static Future<List<StockModel>> getTopLosers({int limit = 10}) async {
    final data = await ApiClient.get(
      ApiEndpoints.latest(
        country: ApiKeys.defaultCountry,
        sortBy: 'chp_asc',
        perPage: limit,
        page: 1,
        getProfile: true,
        type: 'stock',
        subType: 'common',
      ),
    );

    LastUpdateService.updateFromApi(data);

    final stocks = _parseStocks(data);
    final attached = await attachArabicNames(stocks);

    // Auto-subscribe to live quotes
    LiveSocketService.instance.subscribeBatch(attached.map((s) => s.symbol).toList());
    return attached;
  }

  static Future<List<StockModel>> getBySymbols(List<String> symbols) async {
    if (symbols.isEmpty) return [];
    final joined = symbols.join(',');
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

    LiveSocketService.instance.subscribeBatch(symbols);
    return attached;
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
    final now = DateTime.now();
    if (!forceRefresh &&
        _stocksCache != null &&
        _lastStocksCacheFetch != null &&
        now.difference(_lastStocksCacheFetch!) < const Duration(minutes: 1)) {
      return _stocksCache!;
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
    _stocksCache = result;
    _lastStocksCacheFetch = DateTime.now();

    // Subscribe all stocks in batch
    LiveSocketService.instance.subscribeBatch(result.map((s) => s.symbol).toList());

    return result;
  }

  /// ✅ Fetch REITs, ETFs, or Stocks Category
  static Future<List<StockModel>> getAssetsByCategory(String category) async {
    final cat = category.toLowerCase().trim();
    if (cat == 'reits' || cat == 'reit') {
      final data = await ApiClient.get(
        ApiEndpoints.latest(
          country: ApiKeys.defaultCountry,
          getProfile: true,
          type: 'fund',
          subType: 'reit',
          perPage: 100,
        ),
      );
      final stocks = _parseStocks(data);
      final attached = await attachArabicNames(stocks);
      LiveSocketService.instance.subscribeBatch(attached.map((s) => s.symbol).toList());
      return attached;
    } else if (cat == 'etfs' || cat == 'etf') {
      final data = await ApiClient.get(
        ApiEndpoints.latest(
          country: ApiKeys.defaultCountry,
          getProfile: true,
          type: 'fund',
          subType: 'etf',
          perPage: 100,
        ),
      );
      final stocks = _parseStocks(data);
      final attached = await attachArabicNames(stocks);
      LiveSocketService.instance.subscribeBatch(attached.map((s) => s.symbol).toList());
      return attached;
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
    final result = translated.first;

    // Subscribe single symbol for fast streaming
    LiveSocketService.instance.subscribe(result.symbol);

    return result;
  }

  static Future<StockIndicatorModel> getIndicators(String symbol) async {
    final data = await ApiClient.get(ApiEndpoints.indicators(symbol: symbol));
    LastUpdateService.updateFromApi(data);
    return StockIndicatorModel.fromJson(data);
  }

  static Future<StockPerformanceModel> getPerformance(String symbol) async {
    final data = await ApiClient.get(ApiEndpoints.performance(symbol: symbol));
    LastUpdateService.updateFromApi(data);
    return StockPerformanceModel.fromJson(data);
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
