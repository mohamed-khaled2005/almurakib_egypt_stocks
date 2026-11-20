class PivotSet {
  final double? r4;
  final double? r3;
  final double? r2;
  final double? r1;
  final double? pivot;
  final double? s1;
  final double? s2;
  final double? s3;
  final double? s4;

  const PivotSet({
    this.r4,
    this.r3,
    this.r2,
    this.r1,
    this.pivot,
    this.s1,
    this.s2,
    this.s3,
    this.s4,
  });

  factory PivotSet.fromJson(Map<String, dynamic> json) {
    double? parseVal(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return PivotSet(
      r4: parseVal(json['R4'] ?? json['r4']),
      r3: parseVal(json['R3'] ?? json['r3']),
      r2: parseVal(json['R2'] ?? json['r2']),
      r1: parseVal(json['R1'] ?? json['r1']),
      pivot: parseVal(json['P'] ?? json['p'] ?? json['pivot'] ?? json['Pivot']),
      s1: parseVal(json['S1'] ?? json['s1']),
      s2: parseVal(json['S2'] ?? json['s2']),
      s3: parseVal(json['S3'] ?? json['s3']),
      s4: parseVal(json['S4'] ?? json['s4']),
    );
  }

  Map<String, double?> toMap() => {
        if (r3 != null) 'R3': r3,
        if (r2 != null) 'R2': r2,
        if (r1 != null) 'R1': r1,
        if (pivot != null) 'P': pivot,
        if (s1 != null) 'S1': s1,
        if (s2 != null) 'S2': s2,
        if (s3 != null) 'S3': s3,
      };
}

class PivotSignal {
  final String summary;
  final double? score;
  final String? confidence;
  final String? trend;
  final String? volatility;

  const PivotSignal({
    this.summary = 'Neutral',
    this.score,
    this.confidence,
    this.trend,
    this.volatility,
  });

  factory PivotSignal.fromJson(Map<String, dynamic> json) {
    double? parseVal(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return PivotSignal(
      summary: json['summary']?.toString() ?? 'Neutral',
      score: parseVal(json['score']),
      confidence: json['confidence']?.toString(),
      trend: json['trend']?.toString(),
      volatility: json['volatility']?.toString(),
    );
  }
}

class StockPivotPointsModel {
  final String ticker;
  final String period;
  final PivotSignal signal;
  final PivotSet classic;
  final PivotSet fibonacci;
  final PivotSet camarilla;
  final PivotSet woodie;
  final PivotSet demark;

  const StockPivotPointsModel({
    required this.ticker,
    required this.period,
    required this.signal,
    required this.classic,
    required this.fibonacci,
    required this.camarilla,
    required this.woodie,
    required this.demark,
  });

  factory StockPivotPointsModel.fromJson(
    Map<String, dynamic> json, {
    required String symbol,
    String period = '1d',
  }) {
    final resp = json['response'];
    Map<String, dynamic> itemMap = <String, dynamic>{};

    if (resp is List && resp.isNotEmpty && resp.first is Map) {
      itemMap = Map<String, dynamic>.from(resp.first as Map);
    } else if (resp is Map) {
      if (resp.containsKey(symbol) && resp[symbol] is Map) {
        itemMap = Map<String, dynamic>.from(resp[symbol] as Map);
      } else if (resp.containsKey('pivots')) {
        itemMap = Map<String, dynamic>.from(resp);
      } else if (resp.values.isNotEmpty && resp.values.first is Map) {
        itemMap = Map<String, dynamic>.from(resp.values.first as Map);
      }
    }

    final rawPivots =
        itemMap['pivots'] is Map ? itemMap['pivots'] as Map : itemMap;
    final rawSignal = itemMap['signal'] is Map
        ? itemMap['signal'] as Map
        : <String, dynamic>{};

    return StockPivotPointsModel(
      ticker: (itemMap['ticker'] ?? symbol).toString(),
      period: (json['info'] is Map ? (json['info']['period'] ?? period) : period)
          .toString(),
      signal: PivotSignal.fromJson(Map<String, dynamic>.from(rawSignal)),
      classic: PivotSet.fromJson(
        rawPivots['classic'] is Map
            ? Map<String, dynamic>.from(rawPivots['classic'] as Map)
            : <String, dynamic>{},
      ),
      fibonacci: PivotSet.fromJson(
        rawPivots['fibonacci'] is Map
            ? Map<String, dynamic>.from(rawPivots['fibonacci'] as Map)
            : <String, dynamic>{},
      ),
      camarilla: PivotSet.fromJson(
        rawPivots['camarilla'] is Map
            ? Map<String, dynamic>.from(rawPivots['camarilla'] as Map)
            : <String, dynamic>{},
      ),
      woodie: PivotSet.fromJson(
        rawPivots['woodie'] is Map
            ? Map<String, dynamic>.from(rawPivots['woodie'] as Map)
            : <String, dynamic>{},
      ),
      demark: PivotSet.fromJson(
        rawPivots['demark'] is Map
            ? Map<String, dynamic>.from(rawPivots['demark'] as Map)
            : <String, dynamic>{},
      ),
    );
  }

  factory StockPivotPointsModel.fallback({
    required String symbol,
    String period = '1d',
  }) {
    return StockPivotPointsModel(
      ticker: symbol,
      period: period,
      signal: const PivotSignal(summary: 'Neutral'),
      classic: const PivotSet(),
      fibonacci: const PivotSet(),
      camarilla: const PivotSet(),
      woodie: const PivotSet(),
      demark: const PivotSet(),
    );
  }

  PivotSet getByName(String name) {
    switch (name.toLowerCase()) {
      case 'fibonacci':
      case 'فيبوناتشي':
        return fibonacci;
      case 'camarilla':
      case 'كاماريلا':
        return camarilla;
      case 'woodie':
      case 'وودي':
        return woodie;
      case 'demark':
      case 'ديمارك':
        return demark;
      case 'classic':
      case 'كلاسيك':
      default:
        return classic;
    }
  }
}
