import 'package:flutter/material.dart';

import '../core/models/stock_model.dart';
import '../core/models/stock_pivot_points_model.dart';
import '../core/services/stock_service.dart';
import '../widgets/ad_banner_card.dart';
import '../widgets/stock_logo_widget.dart';

class StockPivotPointsScreen extends StatefulWidget {
  final StockModel? initialStock;

  const StockPivotPointsScreen({super.key, this.initialStock});

  @override
  State<StockPivotPointsScreen> createState() => _StockPivotPointsScreenState();
}

class _StockPivotPointsScreenState extends State<StockPivotPointsScreen> {
  StockModel? _selectedStock;
  List<StockModel> _allStocks = [];
  bool _loadingStocks = true;

  String _selectedPeriod = '1d';
  String _selectedMethod = 'classic';
  bool _loadingPivots = false;
  StockPivotPointsModel? _pivotData;

  final List<Map<String, String>> _periods = const [
    {'key': '1h', 'label': 'ساعي'},
    {'key': '1d', 'label': 'يومي'},
    {'key': '1w', 'label': 'أسبوعي'},
    {'key': '1month', 'label': 'شهري'},
  ];

  final List<Map<String, String>> _methods = const [
    {'key': 'classic', 'label': 'كلاسيك'},
    {'key': 'fibonacci', 'label': 'فيبوناتشي'},
    {'key': 'camarilla', 'label': 'كاماريلا'},
    {'key': 'woodie', 'label': 'وودي'},
    {'key': 'demark', 'label': 'ديمارك'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedStock = widget.initialStock;
    _initData();
  }

  Future<void> _initData() async {
    try {
      final list = await StockService.getStocksList(perPage: 500, page: 1);
      if (mounted) {
        setState(() {
          _allStocks = list;
          _loadingStocks = false;
          if (_selectedStock == null && list.isNotEmpty) {
            // Default to COMI or first stock
            _selectedStock = list.firstWhere(
              (s) => s.symbol.contains('COMI'),
              orElse: () => list.first,
            );
          }
        });
        if (_selectedStock != null) {
          _fetchPivotPoints();
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingStocks = false);
        if (_selectedStock != null) {
          _fetchPivotPoints();
        }
      }
    }
  }

  Future<void> _fetchPivotPoints() async {
    if (_selectedStock == null) return;
    setState(() => _loadingPivots = true);

    try {
      final data = await StockService.getPivotPoints(
        symbol: _selectedStock!.symbol,
        period: _selectedPeriod,
      );
      if (mounted) {
        setState(() {
          _pivotData = data;
          _loadingPivots = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _pivotData = StockPivotPointsModel.fallback(
            symbol: _selectedStock!.symbol,
            period: _selectedPeriod,
          );
          _loadingPivots = false;
        });
      }
    }
  }

  void _onStockSelected(StockModel stock) {
    setState(() {
      _selectedStock = stock;
    });
    _fetchPivotPoints();
  }

  void _openStockSelector() {
    showModalBottomSheet<StockModel>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = _allStocks.where((s) {
              if (query.isEmpty) return true;
              final q = query.toLowerCase();
              return s.symbol.toLowerCase().contains(q) ||
                  s.displayName.toLowerCase().contains(q);
            }).toList();

            return SafeArea(
              child: Container(
                height: MediaQuery.of(context).size.height * 0.75,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'اختر السهم لحساب الدعم والمقاومة',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                        onChanged: (val) => setModalState(() => query = val),
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 13.5,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'ابحث عن اسم السهم أو رمزه...',
                          hintStyle: TextStyle(
                            fontFamily: 'Tajawal',
                            color: Color(0xFF94A3B8),
                            fontSize: 13,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: Color(0xFF94A3B8),
                            size: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text(
                                'لا توجد نتائج مطابقة',
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(
                                height: 1,
                                color: Color(0xFFF1F5F9),
                              ),
                              itemBuilder: (_, idx) {
                                final s = filtered[idx];
                                final isSelected =
                                    _selectedStock?.symbol == s.symbol;
                                return ListTile(
                                  onTap: () {
                                    Navigator.pop(ctx, s);
                                  },
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  leading: StockLogoWidget(
                                    stock: s,
                                    size: 38,
                                    borderRadius: 10,
                                  ),
                                  title: Text(
                                    s.displayName,
                                    textDirection: TextDirection.rtl,
                                    style: TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontWeight: isSelected
                                          ? FontWeight.w900
                                          : FontWeight.w700,
                                      color: isSelected
                                          ? const Color(0xFFC1121F)
                                          : const Color(0xFF1E293B),
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  subtitle: Text(
                                    s.displaySymbol,
                                    textDirection: TextDirection.rtl,
                                    style: const TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontSize: 11.5,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  trailing: Text(
                                    '${s.price.toStringAsFixed(2)} ج.م',
                                    style: const TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((selected) {
      if (selected != null) {
        _onStockSelected(selected);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEFEFE),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          color: const Color(0xFFFEFEFE),
          child: SafeArea(
            bottom: false,
            child: Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
                ),
              ),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  // Right: Back Button
                  InkWell(
                    onTap: () => Navigator.maybePop(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Center: Title
                  const Expanded(
                    child: Text(
                      'الدعم والمقاومة للأسهم',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),

                  // Left: Refresh button
                  InkWell(
                    onTap: _fetchPivotPoints,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: _loadingPivots
                          ? const Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFFC1121F),
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.refresh_rounded,
                              size: 18,
                              color: Color(0xFF1E293B),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              children: [
                // 1. Stock Selector Card
                _buildStockSelectorCard(),

                const SizedBox(height: 14),

                // 2. Period Selector Pills
                _buildPeriodSelector(),

                const SizedBox(height: 14),

                // 3. Signal & Market Trend Card
                if (_pivotData != null) _buildSignalCard(_pivotData!.signal),

                const SizedBox(height: 14),

                // 4. Method Tab Selector (كلاسيك، فيبوناتشي، كاماريلا...)
                _buildMethodSelector(),

                const SizedBox(height: 14),

                // 5. Pivots & Support / Resistance Table
                if (_loadingPivots)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFC1121F),
                      ),
                    ),
                  )
                else if (_pivotData != null)
                  _buildPivotLevelsCard(_pivotData!.getByName(_selectedMethod))
                else
                  _buildEmptyState(),

                const SizedBox(height: 16),

                // 6. Educational Info Box
                _buildEducationalInfoBox(),

                const SizedBox(height: 20),
              ],
            ),
          ),

          // Fixed Ad Banner at bottom
          const SafeArea(
            top: false,
            child: AdBannerCard(),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // WIDGETS
  // ==========================================

  Widget _buildStockSelectorCard() {
    final stock = _selectedStock;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          // Logo
          StockLogoWidget(
            stock: stock,
            size: 42,
            borderRadius: 10,
          ),
          const SizedBox(width: 12),

          // Stock Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              textDirection: TextDirection.rtl,
              children: [
                Text(
                  stock?.displayName ?? 'اختر سهماً...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        stock?.displaySymbol ?? '',
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (stock != null)
                      Text(
                        '${stock.price.toStringAsFixed(2)} ج.م',
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Change button
          InkWell(
            onTap: _loadingStocks ? null : _openStockSelector,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                textDirection: TextDirection.rtl,
                children: [
                  Icon(
                    Icons.swap_horiz_rounded,
                    size: 16,
                    color: Color(0xFFC1121F),
                  ),
                  SizedBox(width: 4),
                  Text(
                    'تغيير',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFC1121F),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        textDirection: TextDirection.rtl,
        children: _periods.map((p) {
          final isSelected = _selectedPeriod == p['key'];
          return Expanded(
            child: InkWell(
              onTap: () {
                if (_selectedPeriod != p['key']) {
                  setState(() => _selectedPeriod = p['key']!);
                  _fetchPivotPoints();
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  p['label']!,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? const Color(0xFFC1121F)
                        : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSignalCard(PivotSignal sig) {
    Color getSignalColor(String s) {
      final low = s.toLowerCase();
      if (low.contains('buy') || low.contains('شراء')) {
        return const Color(0xFF16A34A);
      }
      if (low.contains('sell') || low.contains('بيع')) {
        return const Color(0xFFDC2626);
      }
      return const Color(0xFFD97706);
    }

    String getSignalArabic(String s) {
      final low = s.toLowerCase();
      if (low.contains('strong buy')) return 'شراء قوي';
      if (low.contains('strong sell')) return 'بيع قوي';
      if (low.contains('buy')) return 'شراء';
      if (low.contains('sell')) return 'بيع';
      if (low.contains('neutral')) return 'محايد';
      return s;
    }

    final sigColor = getSignalColor(sig.summary);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        textDirection: TextDirection.rtl,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ملخص المؤشرات الفنية والاتجاه',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: sigColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sigColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  getSignalArabic(sig.summary),
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: sigColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            textDirection: TextDirection.rtl,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              if (sig.trend != null)
                _buildSignalMetric(
                  label: 'الاتجاه',
                  value: sig.trend == 'Strong'
                      ? 'قوي'
                      : (sig.trend == 'Weak' ? 'ضعيف' : sig.trend!),
                ),
              if (sig.volatility != null)
                _buildSignalMetric(
                  label: 'التقلبات',
                  value: sig.volatility == 'High'
                      ? 'عالية'
                      : (sig.volatility == 'Low' ? 'منخفضة' : sig.volatility!),
                ),
              if (sig.score != null)
                _buildSignalMetric(
                  label: 'التقييم',
                  value: '${sig.score!.toStringAsFixed(1)} / 10',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSignalMetric({required String label, required String value}) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 11,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildMethodSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(
        textDirection: TextDirection.rtl,
        children: _methods.map((m) {
          final isSelected = _selectedMethod == m['key'];
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: InkWell(
              onTap: () => setState(() => _selectedMethod = m['key']!),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFC1121F) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFC1121F)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Text(
                  m['label']!,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPivotLevelsCard(PivotSet p) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            textDirection: TextDirection.rtl,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'المستوى',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
              const Text(
                'السعر المستهدف (ج.م)',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 6),

          // Resistances (Red/Rose)
          if (p.r3 != null)
            _buildLevelRow(
              label: 'مقاومة 3 (R3)',
              value: p.r3!,
              color: const Color(0xFFDC2626),
              isResistance: true,
            ),
          if (p.r2 != null)
            _buildLevelRow(
              label: 'مقاومة 2 (R2)',
              value: p.r2!,
              color: const Color(0xFFEF4444),
              isResistance: true,
            ),
          if (p.r1 != null)
            _buildLevelRow(
              label: 'مقاومة 1 (R1)',
              value: p.r1!,
              color: const Color(0xFFF87171),
              isResistance: true,
            ),

          // Central Pivot Point (Amber/Blue)
          if (p.pivot != null)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                textDirection: TextDirection.rtl,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    textDirection: TextDirection.rtl,
                    children: [
                      Icon(
                        Icons.adjust_rounded,
                        size: 16,
                        color: Color(0xFFD97706),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'نقطة الارتكاز (Pivot P)',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    p.pivot!.toStringAsFixed(2),
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ],
              ),
            ),

          // Supports (Green/Emerald)
          if (p.s1 != null)
            _buildLevelRow(
              label: 'دعم 1 (S1)',
              value: p.s1!,
              color: const Color(0xFF34D399),
              isResistance: false,
            ),
          if (p.s2 != null)
            _buildLevelRow(
              label: 'دعم 2 (S2)',
              value: p.s2!,
              color: const Color(0xFF10B981),
              isResistance: false,
            ),
          if (p.s3 != null)
            _buildLevelRow(
              label: 'دعم 3 (S3)',
              value: p.s3!,
              color: const Color(0xFF059669),
              isResistance: false,
            ),
        ],
      ),
    );
  }

  Widget _buildLevelRow({
    required String label,
    required double value,
    required Color color,
    required bool isResistance,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        textDirection: TextDirection.rtl,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            textDirection: TextDirection.rtl,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          Text(
            value.toStringAsFixed(2),
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEducationalInfoBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        textDirection: TextDirection.rtl,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: Color(0xFF64748B),
              ),
              SizedBox(width: 6),
              Text(
                'كيف تستفيد من نقاط الدعم والمقاومة؟',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            '• نقطة الارتكاز (Pivot P): السعر التوازني اليومي، التداول أعلاها يعطي إشارة إيجابية، والتداول أدناها يعطي إشارة سلبية.\n'
            '• مستويات المقاومة (R1, R2, R3): مناطق يُتوقع فيها مواجهة ضغوط بيعية قد تحد من صعود السهم.\n'
            '• مستويات الدعم (S1, S2, S3): مناطق يُتوقع فيها ظهور قوى شرائية قد تمنع السهم من مواصلة الهبوط.',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 11.5,
              height: 1.6,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Text(
          'لا تتوفر بيانات دعم ومقاومة حالياً',
          style: TextStyle(
            fontFamily: 'Tajawal',
            color: Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }
}
