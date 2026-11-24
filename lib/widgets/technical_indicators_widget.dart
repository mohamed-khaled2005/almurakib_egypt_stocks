import 'package:flutter/material.dart';
import '../core/models/stock_indicator_model.dart';

class TechnicalIndicatorsWidget extends StatelessWidget {
  final StockIndicatorModel indicators;

  const TechnicalIndicatorsWidget({
    super.key,
    required this.indicators,
  });

  @override
  Widget build(BuildContext context) {
    final keys = indicators.indicators.keys.toList();

    keys.sort((a, b) {
      final ia = _indicatorPriority(a);
      final ib = _indicatorPriority(b);
      if (ia != ib) return ia.compareTo(ib);
      return a.compareTo(b);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. ملخص المؤشرات الفنية
        _buildSummaryCard(),

        const SizedBox(height: 20),

        // 2. عنوان: تفاصيل المؤشرات
        const Align(
          alignment: Alignment.centerRight,
          child: Text(
            'تفاصيل المؤشرات',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // 3. جدول تفاصيل المؤشرات
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: indicators.indicators.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'لا توجد مؤشرات متاحة حالياً',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                )
              : Column(
                  children: [
                    _buildHeaderRow(),
                    ...List.generate(keys.length, (i) {
                      final name = keys[i];
                      final v = indicators.indicators[name]!;
                      final isLast = i == keys.length - 1;

                      return _buildIndicatorRow(
                        name: name,
                        value: v.value,
                        arabicSignal: v.arabicSignal,
                        originalSignal: v.signal,
                        showDivider: !isLast,
                      );
                    }),
                  ],
                ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSummaryCard() {
    final summaryText = _translateSummary(indicators.overallSummary);
    final isBuy = indicators.overallSummary.toLowerCase().contains('buy') ||
        indicators.totalBuy > indicators.totalSell;
    final isSell = indicators.overallSummary.toLowerCase().contains('sell') ||
        indicators.totalSell > indicators.totalBuy;

    final summaryColor = isBuy
        ? const Color(0xFF16A34A)
        : (isSell ? const Color(0xFFDC2626) : const Color(0xFF64748B));

    final total = (indicators.totalBuy + indicators.totalSell + indicators.totalNeutral).clamp(1, 999);
    final buyFlex = ((indicators.totalBuy / total) * 100).toInt().clamp(5, 90);
    final neutralFlex = ((indicators.totalNeutral / total) * 100).toInt().clamp(0, 90);
    final sellFlex = ((indicators.totalSell / total) * 100).toInt().clamp(5, 90);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // عنوان الكارت
          const Text(
            'ملخص المؤشرات الفنية',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 6),

          // نص التوجه (ميل للشراء / ميل للبيع / محايد)
          Text(
            summaryText,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: summaryColor,
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 12),

          // الشريط الملون المقسم (أخضر على اليمين، رمادي في الوسط، أحمر على اليسار في RTL)
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  Expanded(
                    flex: buyFlex > 0 ? buyFlex : 1,
                    child: Container(color: const Color(0xFF16A34A)),
                  ),
                  if (indicators.totalNeutral > 0) ...[
                    const SizedBox(width: 2),
                    Expanded(
                      flex: neutralFlex > 0 ? neutralFlex : 1,
                      child: Container(color: const Color(0xFFCBD5E1)),
                    ),
                  ],
                  const SizedBox(width: 2),
                  Expanded(
                    flex: sellFlex > 0 ? sellFlex : 1,
                    child: Container(color: const Color(0xFFDC2626)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // الأرقام أسفل الشريط: شراء (يمين)، محايد (وسط)، بيع (يسار)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            textDirection: TextDirection.rtl,
            children: [
              Text(
                '${indicators.totalBuy} شراء',
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF16A34A),
                ),
              ),
              Text(
                '${indicators.totalNeutral} محايد',
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
              Text(
                '${indicators.totalSell} بيع',
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFDC2626),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Container(
      color: const Color(0xFFF1F5F9),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: const Row(
        textDirection: TextDirection.rtl,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              'المؤشر',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'القيمة',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(
              'الإشارة',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicatorRow({
    required String name,
    required double value,
    required String arabicSignal,
    required String originalSignal,
    bool showDivider = true,
  }) {
    final signalLower = originalSignal.toLowerCase().trim();

    Color pillBg = const Color(0xFFF1F5F9);
    Color pillColor = const Color(0xFF64748B);
    String signalText = 'محايد';

    if (_isBuy(signalLower)) {
      pillBg = const Color(0xFFDCFCE7);
      pillColor = const Color(0xFF16A34A);
      signalText = 'شراء';
    } else if (_isSell(signalLower)) {
      pillBg = const Color(0xFFFEE2E2);
      pillColor = const Color(0xFFDC2626);
      signalText = 'بيع';
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              // المؤشر
              Expanded(
                flex: 3,
                child: Text(
                  _formatIndicatorName(name),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
              ),

              // القيمة
              Expanded(
                flex: 2,
                child: Text(
                  value.toStringAsFixed(2),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
              ),

              // الإشارة
              SizedBox(
                width: 70,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: pillBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      signalText,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: pillColor,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
      ],
    );
  }

  String _formatIndicatorName(String raw) {
    final lower = raw.toLowerCase().trim();
    if (lower.contains('rsi')) return 'RSI (14)';
    if (lower.contains('macd')) return 'MACD';
    if (lower.contains('stoch')) return 'Stochastic';
    if (lower.contains('adx')) return 'ADX (14)';
    if (lower.contains('atr')) return 'ATR (14)';
    if (lower.contains('cci')) return 'CCI (14)';
    if (lower.contains('sar')) return 'Parabolic SAR';
    return raw;
  }

  String _translateSummary(String summary) {
    final lower = summary.toLowerCase().trim();
    if (lower.contains('strong_buy') || lower.contains('strong buy')) return 'شراء قوي';
    if (lower.contains('buy')) return 'ميل للشراء';
    if (lower.contains('strong_sell') || lower.contains('strong sell')) return 'بيع قوي';
    if (lower.contains('sell')) return 'ميل للبيع';
    return 'محايد';
  }

  int _indicatorPriority(String key) {
    final lower = key.toLowerCase();
    if (lower.contains('rsi')) return 1;
    if (lower.contains('macd')) return 2;
    if (lower.contains('stoch')) return 3;
    if (lower.contains('adx')) return 4;
    if (lower.contains('atr')) return 5;
    if (lower.contains('cci')) return 6;
    if (lower.contains('sar')) return 7;
    return 100;
  }

  bool _isBuy(String s) => s.contains('buy');
  bool _isSell(String s) => s.contains('sell');
}
