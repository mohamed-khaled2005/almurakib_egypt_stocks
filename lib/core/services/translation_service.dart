import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../api/api_client.dart';
import '../api/api_keys.dart';

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

    return null;
  }

  String? getArabicIndexName({required String ticker, required String name}) {
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

    return null;
  }
}

class TranslationService {
  /// ✅ Session cache فقط (طول ما التطبيق شغال)
  static StockTranslations? _cache;

  /// يمنع تعدد الطلبات بنفس الوقت
  static Future<StockTranslations?>? _inFlight;

  static bool isTranslationAvailable = false;

  /// ✅ لا TTL — لا 24 ساعة — لا أي صلاحية زمنية
  static Future<StockTranslations?> getTranslations(
      {bool forceRefresh = false}) async {
    if (!forceRefresh && _cache != null) return _cache;
    if (!forceRefresh && _inFlight != null) return _inFlight;

    _inFlight = _load();
    final res = await _inFlight;
    _inFlight = null;
    return res;
  }

  static Future<StockTranslations?> _load() async {
    try {
      final map = <String, Map<String, String>>{};

      // 1. Load local bundled Egyptian stock translations asset first (Guaranteed instant offline data)
      try {
        final localJsonStr =
            await rootBundle.loadString('assets/data/egx_stocks_ar.json');
        final localData = jsonDecode(localJsonStr);
        final rawLocal =
            localData['stocks_by_id'] ?? localData['stocksById'] ?? localData;
        if (rawLocal is Map) {
          _populateMap(map, rawLocal);
        }
      } catch (e) {
        // Local asset fallback failed, will try remote
      }

      // 2. Try to fetch remote translations (from Manager or API server)
      try {
        final url = ApiKeys.translationUrl;
        if (url.isNotEmpty) {
          final remoteData = await ApiClient.get(url);
          final rawRemote = remoteData['stocks_by_id'] ??
              remoteData['stocksById'] ??
              remoteData;

          if (rawRemote is Map && rawRemote.isNotEmpty) {
            // Check if remote data has Egyptian stocks or EGX tickers
            final hasEgyptianData = rawRemote.keys.any((k) {
              final keyStr = k.toString().toUpperCase();
              return keyStr.contains('EGX') ||
                  keyStr.contains('COMI') ||
                  !keyStr.contains('TADAWUL');
            });

            if (hasEgyptianData) {
              _populateMap(map, rawRemote);
            }
          }
        }
      } catch (e) {
        // Remote fetch failed, fallback already in map
      }

      if (map.isEmpty) {
        isTranslationAvailable = false;
        return null;
      }

      _cache = StockTranslations(map);
      isTranslationAvailable = true;
      return _cache;
    } catch (e) {
      isTranslationAvailable = false;
      return null;
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
    isTranslationAvailable = false;
  }
}
