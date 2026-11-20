class StockIndicatorModel {
  final Map<String, IndicatorValue> indicators;
  final String overallSummary;
  final int totalBuy;
  final int totalSell;
  final int totalNeutral;

  StockIndicatorModel({
    required this.indicators,
    required this.overallSummary,
    required this.totalBuy,
    required this.totalSell,
    required this.totalNeutral,
  });

  factory StockIndicatorModel.fallback() {
    return StockIndicatorModel(
      indicators: const {},
      overallSummary: 'Neutral',
      totalBuy: 0,
      totalSell: 0,
      totalNeutral: 0,
    );
  }

  IndicatorValue? get rsi => getIndicator('RSI14');
  IndicatorValue? get macd => getIndicator('MACD12_26');
  IndicatorValue? get stoch => getIndicator('STOCH9_6');
  IndicatorValue? get adx => getIndicator('ADX14');
  IndicatorValue? get atr => getIndicator('ATR14');
  IndicatorValue? get cci => getIndicator('CCI14');
  IndicatorValue? get parabolicSar => getIndicator('ParabolicSAR');
  IndicatorValue? get williamsR => getIndicator('WilliamsR');
  IndicatorValue? get uo => getIndicator('UltimateOscillator');
  IndicatorValue? get roc => getIndicator('ROC');
  IndicatorValue? get bullBearPower => getIndicator('BullBearPower');

  String get summaryRecommendation => overallSummary;

  IndicatorValue? getIndicator(String nameOrKey) {
    final norm = normalizeKey(nameOrKey);
    return indicators[norm] ?? indicators[nameOrKey];
  }

  static String normalizeKey(String k) {
    final clean = k.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (clean.contains('stochrsi')) return 'STOCHRSI14';
    if (clean.contains('stoch')) return 'STOCH9_6';
    if (clean.contains('rsi')) return 'RSI14';
    if (clean.contains('macd')) return 'MACD12_26';
    if (clean.contains('williams')) return 'WilliamsR';
    if (clean.contains('cci')) return 'CCI14';
    if (clean.contains('atr')) return 'ATR14';
    if (clean.contains('uo') || clean.contains('ultimate')) return 'UltimateOscillator';
    if (clean.contains('roc')) return 'ROC';
    if (clean.contains('bull') || clean.contains('bear')) return 'BullBearPower';
    if (clean.contains('adx')) return 'ADX14';
    if (clean.contains('sar') || clean.contains('psar')) return 'ParabolicSAR';
    return k;
  }

  factory StockIndicatorModel.fromJson(Map<String, dynamic> json) {
    final resp = json['response'];

    // =========================
    // ✅ Format A: response is List<Map>
    // =========================
    if (resp is List && resp.isNotEmpty && resp.first is Map) {
      final first = Map<String, dynamic>.from(resp.first as Map);

      final signalMap = first['signal'] is Map
          ? Map<String, dynamic>.from(first['signal'])
          : <String, dynamic>{};

      final overall = (signalMap['summary'] ?? signalMap['signal'] ?? 'Neutral').toString();

      final parsed = <String, IndicatorValue>{};
      int buy = 0, sell = 0, neutral = 0;

      void addSignalCount(String s) {
        final v = s.toLowerCase().trim();
        if (v.contains('buy')) {
          buy++;
        } else if (v.contains('sell')) {
          sell++;
        } else {
          neutral++;
        }
      }

      void extract(dynamic group) {
        if (group is! Map) return;
        final g = Map<String, dynamic>.from(group);
        for (final entry in g.entries) {
          final v = entry.value;
          if (v is Map) {
            final m = Map<String, dynamic>.from(v);
            if (m.containsKey('v') && m.containsKey('s')) {
              final key = normalizeKey(entry.key.toString());
              final val = _parseDouble(m['v']);
              final sig = m['s']?.toString() ?? 'Neutral';
              parsed[key] = IndicatorValue(value: val, signal: sig);
              addSignalCount(sig);
            }
          }
        }
      }

      extract(first['oscillators']);
      extract(first['moving_averages']);

      return StockIndicatorModel(
        indicators: parsed,
        overallSummary: overall,
        totalBuy: buy,
        totalSell: sell,
        totalNeutral: neutral,
      );
    }

    // =========================
    // ✅ Format B: response is Map
    // =========================
    final response = resp is Map ? Map<String, dynamic>.from(resp) : <String, dynamic>{};

    final indicatorsData = response['indicators'] is Map
        ? Map<String, dynamic>.from(response['indicators'] as Map)
        : <String, dynamic>{};

    final count = response['count'] is Map
        ? Map<String, dynamic>.from(response['count'] as Map)
        : <String, dynamic>{};

    String overall = 'Neutral';
    final overallObj = response['overall'];
    if (overallObj is Map) {
      overall = (overallObj['summary'] ?? overallObj['signal'] ?? 'Neutral').toString();
    } else if (overallObj is String) {
      overall = overallObj;
    }

    final parsedIndicators = <String, IndicatorValue>{};
    int bCount = 0, sCount = 0, nCount = 0;

    indicatorsData.forEach((key, value) {
      if (value is Map) {
        final m = Map<String, dynamic>.from(value);
        if (m.containsKey('v') && m.containsKey('s')) {
          final norm = normalizeKey(key.toString());
          final sig = m['s']?.toString() ?? 'Neutral';
          final sLower = sig.toLowerCase().trim();
          if (sLower.contains('buy')) {
            bCount++;
          } else if (sLower.contains('sell')) {
            sCount++;
          } else {
            nCount++;
          }
          parsedIndicators[norm] = IndicatorValue(
            value: _parseDouble(m['v']),
            signal: sig,
          );
        }
      }
    });

    int pickCount(List<String> keys, int fallback) {
      for (final k in keys) {
        if (count.containsKey(k)) return _parseInt(count[k]);
      }
      return fallback;
    }

    return StockIndicatorModel(
      indicators: parsedIndicators,
      overallSummary: overall,
      totalBuy: pickCount(['Total_Buy', 'total_buy', 'BUY', 'buy', 'totalBuy'], bCount),
      totalSell: pickCount(['Total_Sell', 'total_sell', 'SELL', 'sell', 'totalSell'], sCount),
      totalNeutral: pickCount(['Total_Neutral', 'total_neutral', 'NEUTRAL', 'neutral', 'totalNeutral'], nCount),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleaned = value.trim().replaceAll(RegExp(r'[^\d\.\-]'), '');
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }
}

class IndicatorValue {
  final double value;
  final String signal;

  IndicatorValue({required this.value, required this.signal});

  String get arabicSignal {
    final s = signal.toLowerCase().trim();
    if (s == 'buy' || s == 'strong buy') return 'شراء';
    if (s == 'sell' || s == 'strong sell') return 'بيع';
    return 'محايد';
  }
}
