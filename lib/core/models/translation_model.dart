class TranslationModel {
  final Map<String, String> stocksById;
  final Map<String, String> stocksBySymbol;
  final String version;
  final String updatedAt;

  TranslationModel({
    required this.stocksById,
    required this.stocksBySymbol,
    required this.version,
    required this.updatedAt,
  });

  factory TranslationModel.fromJson(Map<String, dynamic> json) {
    final Map<String, String> byId = {};
    final Map<String, String> bySymbol = {};

    final dynamic stocksByIdRaw = json['stocks_by_id'] ?? {};
    final dynamic stocksBySymbolRaw = json['stocks_by_symbol'] ?? {};

    if (stocksByIdRaw is Map) {
      stocksByIdRaw.forEach((key, value) {
        if (value is Map && value['ar'] != null) {
          byId[key.toString()] = value['ar'].toString();
        }
      });
    }

    if (stocksBySymbolRaw is Map) {
      stocksBySymbolRaw.forEach((key, value) {
        if (value is Map && value['ar'] != null) {
          bySymbol[key.toString()] = value['ar'].toString();
        }
      });
    }

    return TranslationModel(
      stocksById: byId,
      stocksBySymbol: bySymbol,
      version: json['meta']?['version']?.toString() ?? '1',
      updatedAt: json['meta']?['updated_at']?.toString() ?? '',
    );
  }

  String? getArabicName({String? id, String? symbol}) {
    // by id
    final i = id?.trim();
    if (i != null && i.isNotEmpty && stocksById.containsKey(i)) {
      return stocksById[i];
    }

    // by symbol exact
    final s = symbol?.trim();
    if (s != null && s.isNotEmpty && stocksBySymbol.containsKey(s)) {
      return stocksBySymbol[s];
    }

    // fallback: EGX:ABUK -> ABUK
    if (s != null && s.contains(':')) {
      final tail = s.split(':').last.trim();
      if (tail.isNotEmpty && stocksBySymbol.containsKey(tail)) {
        return stocksBySymbol[tail];
      }
    }

    return null;
  }
}
