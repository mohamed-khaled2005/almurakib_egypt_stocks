import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_keys.dart';

class ManagedIndexData {
  final String symbol;
  final String nameEn;
  final String nameAr;

  const ManagedIndexData({
    required this.symbol,
    required this.nameEn,
    required this.nameAr,
  });

  /// The preferred display name: Arabic if present, else English, else symbol
  String get preferredName {
    if (nameAr.trim().isNotEmpty) return nameAr.trim();
    if (nameEn.trim().isNotEmpty) return nameEn.trim();
    return symbol;
  }

  factory ManagedIndexData.fromJson(Map<String, dynamic> json) {
    return ManagedIndexData(
      symbol: (json['symbol'] ?? '').toString().trim(),
      nameEn: (json['name_en'] ?? '').toString().trim(),
      nameAr: (json['name_ar'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'name_en': nameEn,
    'name_ar': nameAr,
  };
}

class StockTranslations {
  final Map<String, Map<String, String>> byId;

  StockTranslations(this.byId);

  String _norm(String v) {
    if (v.isEmpty) return v;
    String out = v.trim();
    try {
      out = Uri.decodeComponent(out);
    } catch (_) {}
    return out.toUpperCase();
  }

  String? _getAr(String key) {
    final v = byId[key];
    if (v == null) return null;
    final ar = (v['ar'] ?? '').trim();
    return ar.isEmpty ? null : ar;
  }

  String? getArabicName({required String id, required String symbol}) {
    final sym = _norm(symbol);
    final sid = _norm(id);

    // 1. Direct match on symbol (e.g. EGX:COMI or COMI)
    final v1 = _getAr(sym);
    if (v1 != null) return v1;

    // 2. Direct match on id
    final v2 = _getAr(sid);
    if (v2 != null) return v2;

    // 3. EGX prefixed lookup
    if (!sid.contains(':') && sid.isNotEmpty) {
      final v3 = _getAr('EGX:$sid');
      if (v3 != null) return v3;
    }

    if (!sym.contains(':') && sym.isNotEmpty) {
      final v4 = _getAr('EGX:$sym');
      if (v4 != null) return v4;
    }

    // 4. Split prefix (EGX:XYZ -> XYZ)
    if (sym.contains(':')) {
      final parts = sym.split(':');
      if (parts.length >= 2) {
        final shortSym = parts.last.trim();
        final v5 = _getAr(shortSym);
        if (v5 != null) return v5;
      }
    }

    // 5. Handle dash suffixes (e.g. EGS3E071C013-EGP -> EGS3E071C013)
    if (sym.contains('-')) {
      final baseSym = sym.split('-').first.trim();
      final v6 = _getAr(baseSym) ?? _getAr('EGX:$baseSym');
      if (v6 != null) return v6;
    }
    if (sid.contains('-')) {
      final baseSid = sid.split('-').first.trim();
      final v7 = _getAr(baseSid) ?? _getAr('EGX:$baseSid');
      if (v7 != null) return v7;
    }

    // 6. Built-in fallback for known symbols
    final cleanSym = sym.replaceAll('EGX:', '').trim();
    final cleanSid = sid.replaceAll('EGX:', '').trim();
    const fallbacks = {
      'BQDC': 'بنك القاهرة',
      'APPF': 'الأمل الشريف للبلاستيك',
      'EGS3A0Y1C018': 'الأمل الشريف للبلاستيك',
      'GBIM': 'جي بي كورب',
    };
    if (fallbacks.containsKey(cleanSym)) return fallbacks[cleanSym];
    if (fallbacks.containsKey(cleanSid)) return fallbacks[cleanSid];

    return null;
  }

  String? getArabicIndexName({required String ticker, required String name}) {
    // 1. Check in managed indices list first
    for (final m in TranslationService.managedIndices) {
      if (TranslationService.matchIndexSymbols(m.symbol, ticker) ||
          TranslationService.matchIndexSymbols(m.symbol, name)) {
        if (m.nameAr.trim().isNotEmpty) {
          return m.nameAr.trim();
        }
        if (m.nameEn.trim().isNotEmpty) {
          return m.nameEn.trim();
        }
      }
    }

    final normalizedTicker = _norm(ticker);
    final normalizedName = _norm(name);

    final byTicker = _getAr(normalizedTicker);
    if (byTicker != null) return byTicker;

    final byName = _getAr(normalizedName);
    if (byName != null) return byName;

    if (normalizedTicker.contains(':')) {
      final shortTicker = normalizedTicker.split(':').last.trim();
      final byShortTicker = _getAr(shortTicker);
      if (byShortTicker != null) return byShortTicker;
    }

    if (normalizedName.contains(':')) {
      final shortName = normalizedName.split(':').last.trim();
      final byShortName = _getAr(shortName);
      if (byShortName != null) return byShortName;
    }

    final normTickerKey = TranslationService.normalizeIndexKey(ticker);
    if (normTickerKey.isNotEmpty) {
      final byNorm = _getAr(normTickerKey);
      if (byNorm != null) return byNorm;
    }

    return null;
  }
}

class TranslationService {
  static const String _prefsKey = 'manager_cached_stock_translations';
  static const String _blockedPrefsKey = 'manager_blocked_symbols';
  static const String _allowedPrefsKey = 'manager_allowed_symbols';
  static const String _indicesPrefsKey = 'manager_allowed_indices';
  static const String _managedIndicesJsonPrefsKey = 'manager_managed_indices_json';

  /// ✅ Session cache فقط (طول ما التطبيق شغال)
  static StockTranslations? _cache;

  /// يمنع تعدد الطلبات بنفس الوقت
  static Future<StockTranslations?>? _inFlight;

  static bool isTranslationAvailable = false;

  static int catalogVersion = 0;
  static DateTime? _lastSyncAt;
  static final Set<String> _blockedSymbols = <String>{};
  static final Set<String> _allowedStockSymbols = <String>{};
  static List<ManagedIndexData> _managedIndicesList = <ManagedIndexData>[];

  static List<ManagedIndexData> get managedIndices =>
      List<ManagedIndexData>.unmodifiable(_managedIndicesList);

  static bool get hasManagedIndices => _managedIndicesList.isNotEmpty;
  static bool get hasManagedStocks => _allowedStockSymbols.isNotEmpty;

  /// تطبيع رمز المؤشر للمقارنة بدون بادئات أو لواحق
  static String normalizeIndexKey(String s) {
    var norm = s.trim().toUpperCase();
    try {
      norm = Uri.decodeComponent(norm);
    } catch (_) {}
    if (norm.contains(':')) {
      norm = norm.split(':').last.trim();
    }
    norm = norm.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (norm.endsWith('EWI')) {
      norm = norm.substring(0, norm.length - 3);
    }
    return norm;
  }

  /// فحص تطابق رمزي مؤشر بذكاء ومرونة
  static bool matchIndexSymbols(String a, String b) {
    final na = normalizeIndexKey(a);
    final nb = normalizeIndexKey(b);
    if (na.isEmpty || nb.isEmpty) return false;
    if (na == nb) return true;
    if (na.contains('SHARIAH') && nb.contains('SHARIAH')) return true;
    if (na.contains('ESG') && nb.contains('ESG')) return true;
    return false;
  }

  /// فحص إذا كان السهم أو المؤشر محظوراً
  static bool isBlocked(String? symbol, [String? id]) {
    if (_blockedSymbols.isEmpty) return false;
    String norm(String s) {
      String out = s.trim().toUpperCase();
      try {
        out = Uri.decodeComponent(out);
      } catch (_) {}
      return out;
    }

    for (final b in _blockedSymbols) {
      if (symbol != null && symbol.trim().isNotEmpty) {
        final s = norm(symbol);
        if (s == b || matchIndexSymbols(s, b)) return true;
        if (s.contains(':')) {
          final short = s.split(':').last.trim();
          if (short == b || matchIndexSymbols(short, b)) return true;
        }
      }
      if (id != null && id.trim().isNotEmpty) {
        final i = norm(id);
        if (i == b || matchIndexSymbols(i, b)) return true;
        if (i.contains(':')) {
          final short = i.split(':').last.trim();
          if (short == b || matchIndexSymbols(short, b)) return true;
        }
      }
    }
    return false;
  }

  /// فحص إذا كان المؤشر مسموحاً به
  static bool isIndexAllowed(String ticker) {
    if (_managedIndicesList.isEmpty) return true;
    return _managedIndicesList.any((m) => matchIndexSymbols(m.symbol, ticker));
  }

  /// فحص إذا كان السهم/الصندوق معتمداً ومفعلاً في المانجر (Single Source of Truth)
  static bool isStockAllowed(String? symbol, [String? id]) {
    if (isBlocked(symbol, id)) return false;
    // If manager catalog hasn't loaded yet (e.g. offline first launch), allow unblocked stocks.
    if (_allowedStockSymbols.isEmpty) return true;

    bool matchesAllowed(String? raw) {
      if (raw == null || raw.trim().isEmpty) return false;
      var norm = raw.trim().toUpperCase();
      try {
        norm = Uri.decodeComponent(norm);
      } catch (_) {}
      if (_allowedStockSymbols.contains(norm)) return true;
      if (norm.contains(':')) {
        final short = norm.split(':').last.trim();
        if (short.isNotEmpty && _allowedStockSymbols.contains(short)) return true;
      } else {
        if (_allowedStockSymbols.contains('EGX:$norm')) return true;
      }
      if (norm.contains('-')) {
        final base = norm.split('-').first.trim();
        if (base.isNotEmpty &&
            (_allowedStockSymbols.contains(base) ||
                _allowedStockSymbols.contains('EGX:$base'))) {
          return true;
        }
      }
      return false;
    }

    return matchesAllowed(symbol) || matchesAllowed(id);
  }

  /// حل الاسم المعروض للمؤشر مع إعطاء الأولوية للترجمة المرفوعة بالمانجر
  static String resolveIndexDisplayName({
    required String ticker,
    String? fallbackName,
  }) {
    // 1. فحص في قائمة المؤشرات المدارة بالمانجر
    for (final m in _managedIndicesList) {
      if (matchIndexSymbols(m.symbol, ticker) ||
          (fallbackName != null && matchIndexSymbols(m.symbol, fallbackName))) {
        return m.preferredName;
      }
    }

    // 2. فحص في قاموس الترجمات المخزن
    final direct = _cache?.getArabicIndexName(
      ticker: ticker,
      name: fallbackName ?? '',
    );
    if (direct != null && direct.trim().isNotEmpty) {
      return direct.trim();
    }

    // 3. الاسم الافتراضي
    if (fallbackName != null && fallbackName.trim().isNotEmpty) {
      return fallbackName.trim();
    }

    return ticker;
  }

  static String? getArabicNameDirect({required String id, required String symbol}) {
    return _cache?.getArabicName(id: id, symbol: symbol);
  }

  static String? getArabicIndexNameDirect({required String ticker, required String name}) {
    return _cache?.getArabicIndexName(ticker: ticker, name: name);
  }

  /// ✅ إرجاع التعريب المحفوظ من المانجر مع تحميله إن لم يكن موجوداً
  static Future<StockTranslations?> getTranslations(
      {bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cache != null &&
        _managedIndicesList.isNotEmpty &&
        _allowedStockSymbols.isNotEmpty) {
      return _cache;
    }
    if (!forceRefresh && _inFlight != null) return _inFlight;

    _inFlight = _load(forceRefresh: forceRefresh);
    final res = await _inFlight;
    _inFlight = null;
    return res;
  }

  /// مزامنة مباشرة وديناميكية مع المانجر (تجلب كتالوج الأسهم الكامل + التعريب + الحظر + المؤشرات)
  static Future<void> syncWithManager({bool force = false}) async {
    if (!force &&
        _lastSyncAt != null &&
        DateTime.now().difference(_lastSyncAt!) < const Duration(seconds: 25) &&
        _allowedStockSymbols.isNotEmpty) {
      return;
    }

    try {
      // 1. Primary source: dedicated Manager stocks catalog & translations endpoint
      // This returns ALL active stocks/REITs/funds/indices (even untranslated ones).
      final translationsUri = Uri.parse(ApiKeys.translationUrl);
      final resp = await http.get(translationsUri, headers: {
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 12));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data is Map<String, dynamic>) {
          final rawCatalog = data['stocks_by_id'] is Map
              ? Map<String, dynamic>.from(data['stocks_by_id'] as Map)
              : (data['stock_translations'] is Map
                  ? Map<String, dynamic>.from(data['stock_translations'] as Map)
                  : <String, dynamic>{});

          final blocked = data['blocked_symbols'] is List
              ? (data['blocked_symbols'] as List).map((e) => e.toString()).toList()
              : <String>[];

          final managed = data['managed_indices'] is List
              ? (data['managed_indices'] as List)
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList()
              : <Map<String, dynamic>>[];

          await applyManagerTranslations(
            rawCatalog,
            blocked: blocked,
            managedIndices: managed,
            replaceCatalog: true,
          );
          _lastSyncAt = DateTime.now();
          return;
        }
      }
    } catch (_) {
      // Fall through to ui/config fallback below
    }

    try {
      // 2. Fallback: /ui/config endpoint (has translations, blocked_symbols, managed_indices)
      final uri = Uri.parse(
        'https://amanager.almurakib.com/api/v1/ui/config?app_slug=almurakib_egypt_stocks',
      );
      final resp = await http.get(uri, headers: {
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data is Map<String, dynamic>) {
          final rawTrans = data['stock_translations'] is Map
              ? Map<String, dynamic>.from(data['stock_translations'] as Map)
              : <String, dynamic>{};
          final blocked = data['blocked_symbols'] is List
              ? (data['blocked_symbols'] as List).map((e) => e.toString()).toList()
              : <String>[];
          final managed = data['managed_indices'] is List
              ? (data['managed_indices'] as List)
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList()
              : <Map<String, dynamic>>[];

          await applyManagerTranslations(
            rawTrans,
            blocked: blocked,
            managedIndices: managed,
            replaceCatalog: false,
          );
          _lastSyncAt = DateTime.now();
        }
      }
    } catch (_) {
      // Keep cached data
    }
  }

  static Future<StockTranslations?> _load({bool forceRefresh = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // تحميل الرموز المحظورة
      final cachedBlocked = prefs.getStringList(_blockedPrefsKey);
      if (cachedBlocked != null && cachedBlocked.isNotEmpty) {
        _blockedSymbols.clear();
        _blockedSymbols.addAll(cachedBlocked);
      }

      // تحميل الرموز المسموحة من المانجر
      final cachedAllowed = prefs.getStringList(_allowedPrefsKey);
      if (cachedAllowed != null && cachedAllowed.isNotEmpty) {
        _allowedStockSymbols.clear();
        _allowedStockSymbols.addAll(cachedAllowed);
      }

      // تحميل المؤشرات المدارة بصيغتها الكاملة
      final cachedManagedJson = prefs.getString(_managedIndicesJsonPrefsKey);
      if (cachedManagedJson != null && cachedManagedJson.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(cachedManagedJson);
          if (decoded is List) {
            _managedIndicesList = decoded
                .whereType<Map>()
                .map((e) => ManagedIndexData.fromJson(Map<String, dynamic>.from(e)))
                .where((e) => e.symbol.isNotEmpty)
                .toList();
          }
        } catch (_) {}
      }

      if (_managedIndicesList.isEmpty) {
        final cachedIndices = prefs.getStringList(_indicesPrefsKey);
        if (cachedIndices != null && cachedIndices.isNotEmpty) {
          _managedIndicesList = cachedIndices
              .map((s) => ManagedIndexData(symbol: s, nameEn: s, nameAr: ''))
              .toList();
        }
      }

      // تحميل قاموس التعريب المخزن محلياً
      final cachedJsonStr = prefs.getString(_prefsKey);
      if (cachedJsonStr != null && cachedJsonStr.trim().isNotEmpty) {
        final decoded = jsonDecode(cachedJsonStr);
        if (decoded is Map && decoded.isNotEmpty) {
          final map = <String, Map<String, String>>{};
          _populateMap(map, decoded);
          for (final m in _managedIndicesList) {
            final sym = m.symbol.toUpperCase();
            final payload = {'ar': m.nameAr, 'en': m.nameEn};
            map[sym] = payload;
            map['EGX:$sym'] = payload;
            final norm = normalizeIndexKey(sym);
            if (norm.isNotEmpty) map[norm] = payload;
          }
          if (map.isNotEmpty) {
            _cache = StockTranslations(map);
            isTranslationAvailable = true;
          }
        }
      }

      // إذا كان مطلوب تحديث إجباري أو الكاش فارغ، نجلب فوراً من المانجر
      if (forceRefresh ||
          _cache == null ||
          _managedIndicesList.isEmpty ||
          _allowedStockSymbols.isEmpty) {
        await syncWithManager(force: forceRefresh);
      }

      return _cache;
    } catch (_) {
      isTranslationAvailable = false;
      return null;
    }
  }

  static void _addAllowedKeyVariants(Set<String> target, String rawKey) {
    var nk = rawKey.trim().toUpperCase();
    if (nk.isEmpty) return;
    try {
      nk = Uri.decodeComponent(nk);
    } catch (_) {}
    nk = nk.trim().toUpperCase();
    if (nk.isEmpty) return;
    target.add(nk);
    if (nk.contains(':')) {
      final short = nk.split(':').last.trim();
      if (short.isNotEmpty) target.add(short);
    } else {
      target.add('EGX:$nk');
    }
  }

  /// ✅ تطبيق وحفظ تعريب الشركات والمؤشرات والصناديق مباشرة من المانجر
  static Future<void> applyManagerTranslations(
    Map<String, dynamic> rawTranslations, {
    List<String>? blocked,
    List<Map<String, dynamic>>? managedIndices,
    bool replaceCatalog = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (blocked != null) {
      _blockedSymbols.clear();
      for (final b in blocked) {
        final s = b.trim().toUpperCase();
        if (s.isNotEmpty) {
          _blockedSymbols.add(s);
          if (s.contains(':')) {
            _blockedSymbols.add(s.split(':').last.trim());
          }
        }
      }
      try {
        await prefs.setStringList(_blockedPrefsKey, _blockedSymbols.toList());
      } catch (_) {}
    }

    if (managedIndices != null) {
      _managedIndicesList = managedIndices
          .map((m) => ManagedIndexData.fromJson(m))
          .where((m) => m.symbol.isNotEmpty)
          .toList();
      try {
        final encoded = jsonEncode(
          _managedIndicesList.map((m) => m.toJson()).toList(),
        );
        await prefs.setString(_managedIndicesJsonPrefsKey, encoded);
        await prefs.setStringList(
          _indicesPrefsKey,
          _managedIndicesList.map((m) => m.symbol).toList(),
        );
      } catch (_) {}
    }

    final map = <String, Map<String, String>>{};
    if (!replaceCatalog && _cache != null) {
      // Preserve full active catalog entries when merging partial translations from /ui/config
      map.addAll(_cache!.byId);
    }
    _populateMap(map, rawTranslations);

    // تحديث قائمة الرموز المسموحة من المانجر
    if (replaceCatalog && rawTranslations.isNotEmpty) {
      _allowedStockSymbols.clear();
      for (final key in rawTranslations.keys) {
        _addAllowedKeyVariants(_allowedStockSymbols, key.toString());
      }
      for (final m in _managedIndicesList) {
        _addAllowedKeyVariants(_allowedStockSymbols, m.symbol);
      }
      try {
        await prefs.setStringList(
          _allowedPrefsKey,
          _allowedStockSymbols.toList(),
        );
      } catch (_) {}
    } else if (_allowedStockSymbols.isNotEmpty && rawTranslations.isNotEmpty) {
      for (final key in rawTranslations.keys) {
        _addAllowedKeyVariants(_allowedStockSymbols, key.toString());
      }
    }

    // دمج المؤشرات المدارة لضمان إمكانية قراءتها فوراً
    for (final m in _managedIndicesList) {
      final sym = m.symbol.toUpperCase();
      final payload = {
        'ar': m.nameAr,
        'en': m.nameEn,
      };
      map[sym] = payload;
      map['EGX:$sym'] = payload;
      if (sym.contains(':')) {
        map[sym.split(':').last.trim()] = payload;
      }
      final normKey = normalizeIndexKey(sym);
      if (normKey.isNotEmpty) {
        map[normKey] = payload;
      }
    }

    catalogVersion++;

    if (map.isNotEmpty) {
      _cache = StockTranslations(map);
      isTranslationAvailable = true;

      if (replaceCatalog) {
        try {
          await prefs.setString(_prefsKey, jsonEncode(rawTranslations));
        } catch (_) {}
      }
    } else if (replaceCatalog) {
      _cache = null;
      isTranslationAvailable = false;
      await prefs.remove(_prefsKey);
    }
  }

  static void _populateMap(
      Map<String, Map<String, String>> targetMap, Map raw) {
    raw.forEach((key, value) {
      if (value is Map) {
        final v = Map<String, dynamic>.from(value);
        final k0 = key.toString().trim();
        if (k0.isEmpty) return;

        String nk = k0;
        try {
          nk = Uri.decodeComponent(nk);
        } catch (_) {}
        nk = nk.trim().toUpperCase();

        targetMap[nk] = {
          'ar': (v['ar'] ?? '').toString(),
          'en': (v['en'] ?? '').toString(),
        };
      } else if (value is String) {
        final k0 = key.toString().trim();
        if (k0.isEmpty) return;
        String nk = k0;
        try {
          nk = Uri.decodeComponent(nk);
        } catch (_) {}
        nk = nk.trim().toUpperCase();
        targetMap[nk] = {
          'ar': value.trim(),
          'en': '',
        };
      }
    });
  }

  /// ✅ يمسح session cache (رام فقط)
  static void clearCache() {
    _cache = null;
    _inFlight = null;
    _lastSyncAt = null;
    isTranslationAvailable = false;
  }
}
