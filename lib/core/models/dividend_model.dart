class DividendPayoutItem {
  final DateTime? exDate;
  final DateTime? recordDate;
  final DateTime? paymentDate;
  final double amount;
  final String type;

  const DividendPayoutItem({
    this.exDate,
    this.recordDate,
    this.paymentDate,
    required this.amount,
    required this.type,
  });

  factory DividendPayoutItem.fromJson(Map<String, dynamic> json) {
    return DividendPayoutItem(
      exDate: _parseTimestamp(json['ex-date'] ?? json['ex_date']),
      recordDate: _parseTimestamp(json['record-date'] ?? json['record_date']),
      paymentDate: _parseTimestamp(json['payment-date'] ?? json['payment_date']),
      amount: _parseDouble(json['amount']),
      type: (json['type'] ?? 'annual').toString(),
    );
  }

  static DateTime? _parseTimestamp(dynamic val) {
    if (val == null) return null;
    if (val is num) {
      final sec = val.toInt();
      return DateTime.fromMillisecondsSinceEpoch(sec * 1000);
    }
    if (val is String) {
      final parsedNum = int.tryParse(val);
      if (parsedNum != null) {
        return DateTime.fromMillisecondsSinceEpoch(parsedNum * 1000);
      }
      return DateTime.tryParse(val);
    }
    return null;
  }

  static double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) {
      final clean = val.replaceAll(RegExp(r'[^\d\.-]'), '');
      return double.tryParse(clean) ?? 0.0;
    }
    return 0.0;
  }
}

class DividendData {
  final String ticker;
  final List<DividendPayoutItem> payouts;
  final double? currentYield;
  final double? payoutRatio;
  final double? dps;
  final Map<String, double> historyYield;

  const DividendData({
    required this.ticker,
    required this.payouts,
    this.currentYield,
    this.payoutRatio,
    this.dps,
    required this.historyYield,
  });

  bool get hasPayouts => payouts.isNotEmpty;

  factory DividendData.fromJson(Map<String, dynamic> json) {
    final ticker = (json['ticker'] ?? '').toString();
    final dividends = json['dividends'];
    if (dividends is! Map<String, dynamic>) {
      return DividendData(
        ticker: ticker,
        payouts: const [],
        historyYield: const {},
      );
    }

    final rawPayouts = dividends['dividend_payout'];
    final payoutsList = <DividendPayoutItem>[];
    if (rawPayouts is List) {
      for (final item in rawPayouts.whereType<Map>()) {
        payoutsList.add(DividendPayoutItem.fromJson(Map<String, dynamic>.from(item)));
      }
    }

    double? currentYield;
    double? payoutRatio;
    double? dps;
    final historyYield = <String, double>{};

    final fy = dividends['fy'];
    if (fy is Map) {
      final yieldObj = fy['Dividend yield %'];
      if (yieldObj is Map) {
        final cur = yieldObj['current'];
        if (cur is num) {
          currentYield = cur.toDouble();
        } else if (cur is String && cur != '-') {
          currentYield = double.tryParse(cur);
        }

        final data = yieldObj['data'];
        if (data is Map) {
          data.forEach((k, v) {
            if (v is num) historyYield[k.toString()] = v.toDouble();
            if (currentYield == null && v is num) currentYield = v.toDouble();
          });
        }
      }

      final ratioObj = fy['Dividend payout ratio %'];
      if (ratioObj is Map) {
        final cur = ratioObj['current'];
        if (cur is num) {
          payoutRatio = cur.toDouble();
        } else if (cur is String && cur != '-') {
          payoutRatio = double.tryParse(cur);
        }

        if (payoutRatio == null && ratioObj['data'] is Map) {
          final data = ratioObj['data'] as Map;
          for (final v in data.values) {
            if (v is num && v > 0) {
              payoutRatio = v.toDouble();
              break;
            }
          }
        }
      }

      final dpsObj = fy['Dividends per share - common stock primary issue'];
      if (dpsObj is Map) {
        final cur = dpsObj['current'];
        if (cur is num) {
          dps = cur.toDouble();
        } else if (cur is String && cur != '-') {
          dps = double.tryParse(cur);
        }

        if (dps == null && dpsObj['data'] is Map) {
          final data = dpsObj['data'] as Map;
          for (final v in data.values) {
            if (v is num && v > 0) {
              dps = v.toDouble();
              break;
            }
          }
        }
      }
    }

    return DividendData(
      ticker: ticker,
      payouts: payoutsList,
      currentYield: currentYield,
      payoutRatio: payoutRatio,
      dps: dps,
      historyYield: historyYield,
    );
  }
}
