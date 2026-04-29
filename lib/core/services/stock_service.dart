import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../api/api_keys.dart';
import '../models/market_index_model.dart';
import '../models/stock_model.dart';
import '../models/tasi_index_model.dart';
import '../models/stock_indicator_model.dart';
import '../models/stock_performance_model.dart';
import 'translation_service.dart';
import 'last_update_service.dart';

class StockService {
  static List<MarketIndexModel>? _marketIndicesCache;
  static Future<List<MarketIndexModel>>? _marketIndicesInFlight;

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
    return await attachArabicNames(stocks);
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
    return await attachArabicNames(stocks);
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
    return await attachArabicNames(stocks);
  }

  static String _norm(String s) {
    final t = s.trim();
    if (t.isEmpty) return t;
    return t.contains(':') ? t.split(':').last.trim() : t;
  }

  static Future<List<StockModel>> getStocksList(
      {int perPage = 500, int page = 1}) async {
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

    // ✅ حدّث آخر وقت بناءً على الاثنين
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

    return await attachArabicNames(merged);
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
    return translated.first;
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

  static Future<List<StockModel>> attachArabicNames(
      List<StockModel> stocks) async {
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
