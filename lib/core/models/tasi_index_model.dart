import 'market_status_model.dart';

class TasiIndexModel {
  final double value;
  final double change;
  final double changePercent;

  // optional
  final DateTime? updateTimeUtc;

  // optional: اسم/رمز المؤشر لو الـ API رجّعه
  final String? indexSymbol;

  TasiIndexModel({
    required this.value,
    required this.change,
    required this.changePercent,
    this.updateTimeUtc,
    this.indexSymbol,
  });

  factory TasiIndexModel.fromJson(Map<String, dynamic> data) {
    final resp = data['response'];
    if (resp is! List || resp.isEmpty) {
      throw Exception('لا توجد بيانات للمؤشر');
    }

    final firstAny = resp.first;
    final first = firstAny is Map ? Map<String, dynamic>.from(firstAny) : <String, dynamic>{};

    final active = (first['active'] is Map) ? Map<String, dynamic>.from(first['active'] as Map) : <String, dynamic>{};

    final updateTimeStr = (first['updateTime'] ?? first['update_time'] ?? data['info']?['server_time'])?.toString();
    DateTime? utc;
    if (updateTimeStr != null && updateTimeStr.trim().isNotEmpty) {
      final s = updateTimeStr.trim();
      // "YYYY-MM-DD HH:MM:SS" -> ISO
      final iso = RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$').hasMatch(s)
          ? s.replaceFirst(' ', 'T')
          : s;
      utc = DateTime.tryParse(iso);
    }

    final symbol = (first['ticker'] ?? first['symbol'] ?? first['s'])?.toString().trim();

    return TasiIndexModel(
      value: _parseDouble(active['c'] ?? first['c']),
      change: _parseDouble(active['ch'] ?? first['ch']),
      changePercent: _parseDouble(active['chp'] ?? first['chp']),
      updateTimeUtc: utc,
      indexSymbol: (symbol != null && symbol.isNotEmpty) ? symbol : null,
    );
  }

  bool get isGain => change >= 0;

  /// ✅ مؤشرات البورصة قيمتها "نقاط" مش عملة
  String get unitLabel => 'نقطة';

  /// ✅ سوق مصر: حساب مباشر ودقيق لتوقيت القاهرة وجلسة التداول
  bool get isOpen {
    return MarketStatusModel.calculateCurrentStatus().isOpen;
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
}
