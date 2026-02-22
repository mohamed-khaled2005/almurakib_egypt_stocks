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

      String normKey(String k) {
        final kk = k.toLowerCase();
        const map = {
          'rsi': 'RSI14',
          'stoch': 'STOCH9_6',
          'stochrsi': 'STOCHRSI14',
          'macd': 'MACD12_26',
          'williamsr': 'WilliamsR',
          'cci': 'CCI14',
          'atr': 'ATR14',
          'uo': 'UltimateOscillator',
          'roc': 'ROC',
          'bullbearpower': 'BullBearPower',
          'adx': 'ADX14',
          'psar': 'ParabolicSAR',
        };
        return map[kk] ?? k;
      }

      void extract(dynamic group) {
        if (group is! Map) return;
        final g = Map<String, dynamic>.from(group as Map);
        for (final entry in g.entries) {
          final v = entry.value;
          if (v is Map) {
            final m = Map<String, dynamic>.from(v as Map);
            if (m.containsKey('v') && m.containsKey('s')) {
              final key = normKey(entry.key.toString());
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
    final response = resp is Map ? Map<String, dynamic>.from(resp as Map) : <String, dynamic>{};

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

    indicatorsData.forEach((key, value) {
      if (value is Map) {
        final m = Map<String, dynamic>.from(value as Map);
        if (m.containsKey('v') && m.containsKey('s')) {
          parsedIndicators[key.toString()] = IndicatorValue(
            value: _parseDouble(m['v']),
            signal: m['s']?.toString() ?? 'Neutral',
          );
        }
      }
    });

    int pickCount(List<String> keys) {
      for (final k in keys) {
        if (count.containsKey(k)) return _parseInt(count[k]);
      }
      return 0;
    }

    return StockIndicatorModel(
      indicators: parsedIndicators,
      overallSummary: overall,
      totalBuy: pickCount(['Total_Buy', 'total_buy', 'BUY', 'buy', 'totalBuy']),
      totalSell: pickCount(['Total_Sell', 'total_sell', 'SELL', 'sell', 'totalSell']),
      totalNeutral: pickCount(['Total_Neutral', 'total_neutral', 'NEUTRAL', 'neutral', 'totalNeutral']),
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
