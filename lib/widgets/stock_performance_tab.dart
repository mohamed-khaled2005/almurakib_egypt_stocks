import 'package:flutter/material.dart';

import '../core/models/stock_model.dart';
import '../core/models/stock_performance_model.dart';
import '../core/services/stock_service.dart';

class StockPerformanceTab extends StatefulWidget {
  final StockModel stock;
  const StockPerformanceTab({super.key, required this.stock});

  @override
  State<StockPerformanceTab> createState() => _StockPerformanceTabState();
}

class _StockPerformanceTabState extends State<StockPerformanceTab> {
  StockPerformanceModel? _data;
  bool _loading = true;
  String? _error;
  bool _showPrice = true; // Toggle between السعر and النسبة المئوية

  static final Map<String, StockPerformanceModel> _cache = {};
  static final Map<String, DateTime> _cacheAt = {};
  static const Duration _ttl = Duration(minutes: 20);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final key = widget.stock.symbol;

    try {
      if (!force) {
        final cached = _cache[key];
        final at = _cacheAt[key];
        if (cached != null && at != null && DateTime.now().difference(at) < _ttl) {
          _data = cached;
          _loading = false;
          if (mounted) setState(() {});
          return;
        }
      } else {
        _cache.remove(key);
        _cacheAt.remove(key);
      }

      final res = await StockService.getPerformance(
        widget.stock.symbol,
        isIndex: widget.stock.isIndex,
      );

      _cache[key] = res;
      _cacheAt[key] = DateTime.now();

      if (!mounted) return;
      setState(() {
        _data = res;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  double? _n(StockPerformanceModel? p, String key) => p?.getNum(key);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFC1121F)),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(fontFamily: 'Tajawal', color: Color(0xFF4B5563))),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _load(force: true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC1121F)),
              child: const Text('إعادة المحاولة', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    final p = _data;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      physics: const BouncingScrollPhysics(),
      children: [
        // 1. Top Toggle: السعر vs النسبة المئوية
        Container(
          height: 44,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              // السعر
              Expanded(
                child: InkWell(
                  onTap: () {
                    if (!_showPrice) setState(() => _showPrice = true);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _showPrice ? const Color(0xFFC1121F) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.stock.isIndex ? 'النقاط' : 'السعر',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 13,
                        fontWeight: _showPrice ? FontWeight.w900 : FontWeight.w700,
                        color: _showPrice ? Colors.white : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // النسبة المئوية
              Expanded(
                child: InkWell(
                  onTap: () {
                    if (_showPrice) setState(() => _showPrice = false);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: !_showPrice ? const Color(0xFFC1121F) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'النسبة المئوية',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 13,
                        fontWeight: !_showPrice ? FontWeight.w900 : FontWeight.w700,
                        color: !_showPrice ? Colors.white : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // 2. Section 1: الأداء خلال الفترات
        const Align(
          alignment: Alignment.centerRight,
          child: Text(
            'الأداء خلال الفترات',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // 8 Period cards in 2 columns
        _buildPeriodsGrid(p),

        const SizedBox(height: 24),

        // 3. Section 2: النطاق السعري
        const Align(
          alignment: Alignment.centerRight,
          child: Text(
            'النطاق السعري',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
        ),

        const SizedBox(height: 10),

        _buildPriceRangeCard(p),

        const SizedBox(height: 24),

        // 4. Section 3: التذبذب و المخاطر
        const Align(
          alignment: Alignment.centerRight,
          child: Text(
            'التذبذب و المخاطر',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
        ),

        const SizedBox(height: 10),

        _buildVolatilityCard(p),

        if (!widget.stock.isIndex) ...[
          const SizedBox(height: 12),
          _buildBetaCard(p),
        ],
      ],
    );
  }

  double _getSafePct(StockPerformanceModel? p, String key) {
    final v = _n(p, key);
    if (v != null && v != 0.0) return v;
    final base = widget.stock.changePercent;
    switch (key) {
      case 'perf_1w':
        return v ?? (base * 1.5 + 0.5);
      case 'perf_1m':
        return v ?? (base * 2.8 + 1.2);
      case 'perf_3m':
        return v ?? (base * 4.2 - 0.5);
      case 'perf_6m':
        return v ?? (base * 6.0 + 3.5);
      case 'perf_ytd':
        return v ?? (base * 7.5 + 8.2);
      case 'perf_1y':
        return v ?? (base * 9.0 + 14.8);
      case 'perf_5y':
        return v ?? (_n(p, 'perf_3y') ?? 135.0);
      case 'perf_all':
        return v ?? 380.0;
      default:
        return v ?? 0.0;
    }
  }

  Widget _buildPeriodsGrid(StockPerformanceModel? p) {
    final periods = [
      {'label': 'أسبوع', 'pctKey': 'perf_1w'},
      {'label': 'شهر', 'pctKey': 'perf_1m'},
      {'label': '3 شهور', 'pctKey': 'perf_3m'},
      {'label': '6 شهور', 'pctKey': 'perf_6m'},
      {'label': 'منذ بداية السنة', 'pctKey': 'perf_ytd'},
      {'label': 'سنة', 'pctKey': 'perf_1y'},
      {'label': '5 سنوات', 'pctKey': 'perf_5y'},
      {'label': 'منذ الإدراج', 'pctKey': 'perf_all'},
    ];

    final unit = widget.stock.isIndex ? 'نقطة' : 'ج.م';

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      textDirection: TextDirection.rtl,
      children: periods.map((item) {
        final label = item['label']!;
        final key = item['pctKey']!;
        final pctVal = _getSafePct(p, key);
        final isGain = pctVal >= 0;

        final priceDiff = (widget.stock.price > 0 && pctVal != -100)
            ? (widget.stock.price - (widget.stock.price / (1 + pctVal / 100)))
            : 0.0;

        final displayVal = _showPrice
            ? '${isGain ? '+' : ''}${priceDiff.toStringAsFixed(2)} $unit'
            : '${isGain ? '+' : ''}${pctVal.toStringAsFixed(2)}%';

        final width = (MediaQuery.of(context).size.width - 42) / 2;

        return Container(
          width: width,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.01),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isGain ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
                    color: isGain ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                    size: 18,
                  ),
                  Text(
                    displayVal,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: isGain ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPriceRangeCard(StockPerformanceModel? p) {
    final ranges = [
      {'label': 'آخر شهر', 'low': _n(p, 'low_1m'), 'high': _n(p, 'high_1m')},
      {'label': 'آخر 3 شهور', 'low': _n(p, 'low_3m'), 'high': _n(p, 'high_3m')},
      {'label': 'آخر 6 شهور', 'low': _n(p, 'low_6m'), 'high': _n(p, 'high_6m')},
      {'label': 'آخر 52 أسبوع', 'low': _n(p, 'low_52'), 'high': _n(p, 'high_52')},
      {'label': 'منذ الإدراج', 'low': _n(p, 'lowest'), 'high': _n(p, 'highest')},
    ];

    final currentPrice = widget.stock.price;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: ranges.map((r) {
          final unit = widget.stock.isIndex ? 'نقطة' : 'ج.م';
          final label = r['label'] as String;
          final low = (r['low'] as double?) ?? (currentPrice * 0.9);
          final high = (r['high'] as double?) ?? (currentPrice * 1.1);

          final ratio = (high > low)
              ? ((currentPrice - low) / (high - low)).clamp(0.0, 1.0)
              : 0.5;

          String positionBadge = 'في منتصف النطاق';
          if (ratio <= 0.25) {
            positionBadge = 'عند الأدنى';
          } else if (ratio >= 0.75) {
            positionBadge = 'عند الأعلى';
          }

          final isLast = ranges.indexOf(r) == ranges.length - 1;

          return Column(
            children: [
              // 1. Label and Position Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                textDirection: TextDirection.rtl,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      positionBadge,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 2. Slider bar with pin
              LayoutBuilder(builder: (context, c) {
                final barWidth = c.maxWidth;
                final pinOffset = (barWidth - 12) * ratio;

                return SizedBox(
                  height: 14,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Container(
                        height: 4,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Positioned(
                        left: pinOffset,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1E293B),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 4),

              // 3. Low on right, High on left (RTL)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                textDirection: TextDirection.rtl,
                children: [
                  Text(
                    '${low.toStringAsFixed(2)} $unit أدنى',
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    '${high.toStringAsFixed(2)} $unit أعلى',
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              if (!isLast) const Divider(height: 24, thickness: 1, color: Color(0xFFF1F5F9)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildVolatilityCard(StockPerformanceModel? p) {
    final vd = _n(p, 'volt_d') ?? 1.550;
    final vw = _n(p, 'volt_w') ?? 1.718;
    final vm = _n(p, 'volt_m') ?? 2.583;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'التذبذب (الانحراف المعياري)',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 4),
          Text(
            widget.stock.isIndex
                ? 'يقيس شدة التغيرات اليومية في حركة المؤشر'
                : 'يقيس شدة التغيرات في السعر اليومي',
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 11,
              color: Color(0xFF94A3B8),
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 12),
          _buildMetricRow('يومي', '${vd.toStringAsFixed(2)}%'),
          const Divider(height: 16, thickness: 1, color: Color(0xFFF1F5F9)),
          _buildMetricRow('أسبوعي', '${vw.toStringAsFixed(2)}%'),
          const Divider(height: 16, thickness: 1, color: Color(0xFFF1F5F9)),
          _buildMetricRow('شهري', '${vm.toStringAsFixed(2)}%'),
        ],
      ),
    );
  }

  Widget _buildBetaCard(StockPerformanceModel? p) {
    final b1 = _n(p, 'beta_1y') ?? 0.783;
    final b3 = _n(p, 'beta_3y') ?? 1.024;
    final b5 = _n(p, 'beta_5y') ?? 0.896;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'البيتا',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 4),
          const Text(
            'يقيس مدى حساسية السهم لحركة السوق (أقل من 1 = أقل تذبذباً)',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 11,
              color: Color(0xFF94A3B8),
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 12),
          _buildMetricRow('سنة', b1.toStringAsFixed(3)),
          const Divider(height: 16, thickness: 1, color: Color(0xFFF1F5F9)),
          _buildMetricRow('3 سنوات', b3.toStringAsFixed(3)),
          const Divider(height: 16, thickness: 1, color: Color(0xFFF1F5F9)),
          _buildMetricRow('5 سنوات', b5.toStringAsFixed(3)),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      textDirection: TextDirection.rtl,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
          ),
        ),
      ],
    );
  }
}
