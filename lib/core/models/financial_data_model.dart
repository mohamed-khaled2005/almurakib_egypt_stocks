class FinancialMetricItem {
  final String id;
  final String name;
  final String group;
  final dynamic current;
  final Map<String, dynamic> history;

  const FinancialMetricItem({
    required this.id,
    required this.name,
    this.group = '',
    this.current,
    this.history = const {},
  });

  factory FinancialMetricItem.fromJson(Map<String, dynamic> json) {
    return FinancialMetricItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      group: (json['group'] ?? '').toString(),
      current: json['current'],
      history: (json['data'] is Map)
          ? Map<String, dynamic>.from(json['data'] as Map)
          : const {},
    );
  }

  String get displayValue {
    if (current != null && current != '-') {
      if (current is num) {
        return _formatNum(current as num);
      }
      return current.toString();
    }
    if (history.isNotEmpty) {
      final firstVal = history.values.firstWhere(
        (v) => v != null && v != '-' && v != 0,
        orElse: () => null,
      );
      if (firstVal is num) {
        return _formatNum(firstVal);
      } else if (firstVal != null) {
        return firstVal.toString();
      }
    }
    return '-';
  }

  static String _formatNum(num val) {
    final abs = val.abs();
    if (abs >= 1000000000) {
      return '${(val / 1000000000).toStringAsFixed(2)} مليار';
    } else if (abs >= 1000000) {
      return '${(val / 1000000).toStringAsFixed(2)} مليون';
    } else if (abs >= 1000) {
      return '${(val / 1000).toStringAsFixed(2)} ألف';
    }
    return val.toStringAsFixed(2);
  }
}

class FinancialsData {
  final String ticker;
  final List<FinancialMetricItem> ratios;
  final List<FinancialMetricItem> balanceSheet;
  final List<FinancialMetricItem> incomeStatement;
  final List<FinancialMetricItem> cashFlow;

  const FinancialsData({
    required this.ticker,
    this.ratios = const [],
    this.balanceSheet = const [],
    this.incomeStatement = const [],
    this.cashFlow = const [],
  });

  bool get isEmpty =>
      ratios.isEmpty &&
      balanceSheet.isEmpty &&
      incomeStatement.isEmpty &&
      cashFlow.isEmpty;

  static List<FinancialMetricItem> parseMetricsFromResponse(
    dynamic rawResponse, {
    String? subSection,
  }) {
    final list = <FinancialMetricItem>[];
    if (rawResponse is! Map) return list;

    // Structure can be { "EGX:COMI": { "statistics" / "balance_sheet" / ... : { "fy": { ... } } } }
    Map targetMap = rawResponse;
    if (rawResponse.values.isNotEmpty && rawResponse.values.first is Map) {
      final inner = rawResponse.values.first as Map;
      if (subSection != null && inner[subSection] is Map) {
        targetMap = inner[subSection] as Map;
      } else {
        targetMap = inner;
      }
    }

    final fy = targetMap['fy'] ?? targetMap;
    if (fy is Map) {
      fy.forEach((key, val) {
        if (val is Map) {
          list.add(FinancialMetricItem.fromJson(Map<String, dynamic>.from(val)));
        }
      });
    }

    return list;
  }
}
