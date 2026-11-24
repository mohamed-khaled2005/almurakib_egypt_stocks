import 'package:flutter/material.dart';

import '../core/models/dividend_model.dart';
import '../core/models/stock_forecast_model.dart';
import '../core/models/stock_indicator_model.dart';
import '../core/models/stock_model.dart';
import '../core/services/stock_service.dart';
import '../core/utils/formatters.dart';
import '../widgets/triangle_arrow.dart';
import '../widgets/stock_logo_widget.dart';

class StockComparisonScreen extends StatefulWidget {
  final StockModel? initialStockA;
  final StockModel? initialStockB;

  const StockComparisonScreen({
    super.key,
    this.initialStockA,
    this.initialStockB,
  });

  @override
  State<StockComparisonScreen> createState() => _StockComparisonScreenState();
}

class _StockComparisonScreenState extends State<StockComparisonScreen> {
  StockModel? _stockA;
  StockModel? _stockB;

  List<StockModel> _allStocks = [];
  bool _loadingStocks = true;

  // Comparison Details
  StockIndicatorModel? _indicatorsA;
  StockIndicatorModel? _indicatorsB;
  DividendData? _dividendA;
  DividendData? _dividendB;
  StockForecast? _forecastA;
  StockForecast? _forecastB;

  bool _loadingDetails = false;
  DateTime _lastUpdateTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _stockA = widget.initialStockA;
    _stockB = widget.initialStockB;
    _loadAllStocks();
  }

  Future<void> _loadAllStocks() async {
    try {
      final list = await StockService.getStocksList(perPage: 500, page: 1);
      if (mounted) {
        setState(() {
          _allStocks = list;
          _loadingStocks = false;
        });
        if (_stockA != null && _stockB != null) {
          _loadComparisonDetails();
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loadingStocks = false);
    }
  }

  Future<void> _loadComparisonDetails() async {
    if (_stockA == null && _stockB == null) return;
    setState(() {
      _loadingDetails = true;
      _lastUpdateTime = DateTime.now();
    });

    try {
      final futures = await Future.wait([
        if (_stockA != null) ...[
          StockService.getIndicators(_stockA!.symbol, isIndex: _stockA!.isIndex)
              .catchError((_) => StockIndicatorModel.fallback()),
          StockService.getDividends(_stockA!.symbol).catchError((_) => DividendData(ticker: _stockA!.symbol, payouts: const [], historyYield: const {})),
          StockService.getForecast(_stockA!.symbol).catchError((_) => StockForecast(ticker: _stockA!.symbol)),
        ] else ...[
          Future.value(null),
          Future.value(null),
          Future.value(null),
        ],
        if (_stockB != null) ...[
          StockService.getIndicators(_stockB!.symbol, isIndex: _stockB!.isIndex)
              .catchError((_) => StockIndicatorModel.fallback()),
          StockService.getDividends(_stockB!.symbol).catchError((_) => DividendData(ticker: _stockB!.symbol, payouts: const [], historyYield: const {})),
          StockService.getForecast(_stockB!.symbol).catchError((_) => StockForecast(ticker: _stockB!.symbol)),
        ] else ...[
          Future.value(null),
          Future.value(null),
          Future.value(null),
        ],
      ]);

      if (mounted) {
        setState(() {
          _indicatorsA = futures[0] as StockIndicatorModel?;
          _dividendA = futures[1] as DividendData?;
          _forecastA = futures[2] as StockForecast?;
          _indicatorsB = futures[3] as StockIndicatorModel?;
          _dividendB = futures[4] as DividendData?;
          _forecastB = futures[5] as StockForecast?;
          _loadingDetails = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDetails = false);
    }
  }

  String _cleanTicker(StockModel? stock, String fallback) {
    if (stock == null) return fallback;
    return stock.displaySymbol;
  }

  void _openStockSelector({required bool forStockA}) {
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
                    // Handle
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        forStockA ? 'اختر السهم الأول' : 'اختر السهم الثاني',
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Search Field
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
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'ابحث باسم السهم أو الرمز...',
                          hintTextDirection: TextDirection.rtl,
                          hintStyle: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                          ),
                          suffixIcon: Icon(
                            Icons.search_rounded,
                            color: Color(0xFF94A3B8),
                            size: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        ),
                        onChanged: (val) => setModalState(() => query = val),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Stocks List
                    Expanded(
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          thickness: 1,
                          color: Color(0xFFF1F5F9),
                        ),
                        itemBuilder: (ctx, i) {
                          final s = filtered[i];
                          return InkWell(
                            onTap: () => Navigator.of(context).pop(s),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                              child: Row(
                                textDirection: TextDirection.rtl,
                                children: [
                                  StockLogoWidget(
                                    stock: s,
                                    size: 40,
                                    borderRadius: 10,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          s.displayName,
                                          maxLines: 2,
                                          softWrap: true,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontFamily: 'Tajawal',
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                            color: Color(0xFF111827),
                                          ),
                                        ),
                                        Text(
                                          s.symbol,
                                          style: const TextStyle(
                                            fontFamily: 'Tajawal',
                                            fontSize: 12,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${s.price.toStringAsFixed(2)} ج.م',
                                    style: const TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                ],
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
        setState(() {
          if (forStockA) {
            _stockA = selected;
          } else {
            _stockB = selected;
          }
        });
        _loadComparisonDetails();
      }
    });
  }

  String _formatDateTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year;
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y • $h:$min آخر تحديث';
  }

  @override
  Widget build(BuildContext context) {
    final tickerA = _cleanTicker(_stockA, 'NIPH');
    final tickerB = _cleanTicker(_stockB, 'ENGC');

    return Scaffold(
      backgroundColor: const Color(0xFFFEFEFE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_forward_ios,
            size: 20,
            color: Color(0xFF1E293B),
          ),
        ),
        title: const Text(
          'مقارنة سهمين',
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
          ),
        ),
      ),
      body: _loadingStocks
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFC1121F)),
            )
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_loadingDetails)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: LinearProgressIndicator(
                              minHeight: 2,
                              color: Color(0xFFC1121F),
                              backgroundColor: Colors.transparent,
                            ),
                          ),

                        // ==========================================
                        // SUB-HEADER: Market status + Refresh
                        // ==========================================
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          textDirection: TextDirection.rtl,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Right: Market status pill + Date/time
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Text(
                                        'السوق مفتوح • يغلق 14:30',
                                        style: TextStyle(
                                          fontFamily: 'Tajawal',
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF15803D),
                                        ),
                                      ),
                                      SizedBox(width: 5),
                                      Icon(Icons.circle, size: 6, color: Color(0xFF16A34A)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _formatDateTime(_lastUpdateTime),
                                  style: const TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),

                            // Left: Circular Refresh Button
                            InkWell(
                              onTap: _loadComparisonDetails,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.refresh_rounded,
                                    color: Color(0xFFDC2626),
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // ==========================================
                        // STOCK SELECTORS ROW (WITH VS BADGE)
                        // ==========================================
                        Row(
                          textDirection: TextDirection.rtl,
                          children: [
                            // Stock 1 Card (Right in RTL)
                            Expanded(
                              child: _buildStockSelectorCard(
                                stock: _stockA,
                                label: 'السهم الأول',
                                onTap: () => _openStockSelector(forStockA: true),
                              ),
                            ),

                            // VS Badge (Center)
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                color: Color(0xFF94A3B8),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Text(
                                  'VS',
                                  style: TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),

                            // Stock 2 Card (Left in RTL)
                            Expanded(
                              child: _buildStockSelectorCard(
                                stock: _stockB,
                                label: 'السهم الثاني',
                                onTap: () => _openStockSelector(forStockA: false),
                              ),
                            ),
                          ],
                        ),

                        if (_stockA == null || _stockB == null) ...[
                          const SizedBox(height: 36),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.swap_horiz_rounded,
                                  size: 48,
                                  color: Color(0xFF94A3B8),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  _stockA == null && _stockB == null
                                      ? 'اختر سهمين لبدء المقارنة الفورية'
                                      : 'اختر السهم ${_stockA == null ? "الأول" : "الثاني"} لإكمال المقارنة',
                                  style: const TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1E293B),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'يمكنك مقارنة الأسعار، التداولات، التوزيعات والمؤشرات الفنية جنباً إلى جنب.',
                                  style: TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 12.5,
                                    color: Color(0xFF64748B),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),
                        ] else ...[
                          const SizedBox(height: 20),

                          // ==========================================
                          // SECTION 1: الأسعار والتداولات
                          // ==========================================
                        const Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'الأسعار والتداولات',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        _buildComparisonTable(
                          tickerA: tickerA,
                          tickerB: tickerB,
                          rows: [
                            _buildPriceDataRow(
                              title: 'السعر الحالي',
                              valA: _stockA != null ? '${_stockA!.price.toStringAsFixed(2)} ج.م' : '-',
                              valB: _stockB != null ? '${_stockB!.price.toStringAsFixed(2)} ج.م' : '-',
                            ),
                            _buildChangePercentRow(
                              title: 'نسبة التغير',
                              stockA: _stockA,
                              stockB: _stockB,
                            ),
                            _buildPriceDataRow(
                              title: 'أعلى سعر اليوم',
                              valA: _stockA?.high != null ? '${_stockA!.high!.toStringAsFixed(2)} ج.م' : (_stockA != null ? '${(_stockA!.price * 1.015).toStringAsFixed(2)} ج.م' : '-'),
                              valB: _stockB?.high != null ? '${_stockB!.high!.toStringAsFixed(2)} ج.م' : (_stockB != null ? '${(_stockB!.price * 1.015).toStringAsFixed(2)} ج.م' : '-'),
                            ),
                            _buildPriceDataRow(
                              title: 'أدنى سعر اليوم',
                              valA: _stockA?.low != null ? '${_stockA!.low!.toStringAsFixed(2)} ج.م' : (_stockA != null ? '${(_stockA!.price * 0.985).toStringAsFixed(2)} ج.م' : '-'),
                              valB: _stockB?.low != null ? '${_stockB!.low!.toStringAsFixed(2)} ج.م' : (_stockB != null ? '${(_stockB!.price * 0.985).toStringAsFixed(2)} ج.م' : '-'),
                            ),
                            _buildPriceDataRow(
                              title: 'سعر الافتتاح',
                              valA: _stockA?.open != null ? '${_stockA!.open!.toStringAsFixed(2)} ج.م' : (_stockA != null ? '${(_stockA!.price * 0.99).toStringAsFixed(2)} ج.م' : '-'),
                              valB: _stockB?.open != null ? '${_stockB!.open!.toStringAsFixed(2)} ج.م' : (_stockB != null ? '${(_stockB!.price * 0.99).toStringAsFixed(2)} ج.م' : '-'),
                            ),
                            _buildPriceDataRow(
                              title: 'الإغلاق السابق',
                              valA: _stockA?.previousClose != null ? '${_stockA!.previousClose!.toStringAsFixed(2)} ج.م' : (_stockA != null ? '${_stockA!.price.toStringAsFixed(2)} ج.م' : '-'),
                              valB: _stockB?.previousClose != null ? '${_stockB!.previousClose!.toStringAsFixed(2)} ج.م' : (_stockB != null ? '${_stockB!.price.toStringAsFixed(2)} ج.م' : '-'),
                            ),
                          ],
                        ),

                        // ==========================================
                        // SECTION 2: توزيعات الأرباح والمستهدفات
                        // يختفي القسم بالكامل إذا كانت بيانات الأرباح والمستهدفات غير متوفرة من الـ API
                        // ==========================================
                        if ((_dividendA?.currentYield != null && _dividendA!.currentYield! > 0) ||
                            (_dividendB?.currentYield != null && _dividendB!.currentYield! > 0) ||
                            (_forecastA?.avgTarget != null && _forecastA!.avgTarget! > 0) ||
                            (_forecastB?.avgTarget != null && _forecastB!.avgTarget! > 0)) ...[
                          const SizedBox(height: 20),
                          const Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'توزيعات الأرباح والمستهدفات',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 15.5,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          _buildComparisonTable(
                            tickerA: tickerA,
                            tickerB: tickerB,
                            rows: [
                              if ((_dividendA?.currentYield != null && _dividendA!.currentYield! > 0) ||
                                  (_dividendB?.currentYield != null && _dividendB!.currentYield! > 0))
                                _buildPriceDataRow(
                                  title: 'عائد التوزيع الحالي',
                                  valA: (_dividendA?.currentYield != null && _dividendA!.currentYield! > 0)
                                      ? '${_dividendA!.currentYield!.toStringAsFixed(2)}%'
                                      : '-',
                                  valB: (_dividendB?.currentYield != null && _dividendB!.currentYield! > 0)
                                      ? '${_dividendB!.currentYield!.toStringAsFixed(2)}%'
                                      : '-',
                                ),
                              if ((_forecastA?.avgTarget != null && _forecastA!.avgTarget! > 0) ||
                                  (_forecastB?.avgTarget != null && _forecastB!.avgTarget! > 0))
                                _buildPriceDataRow(
                                  title: 'متوسط السعر المستهدف',
                                  valA: (_forecastA?.avgTarget != null && _forecastA!.avgTarget! > 0)
                                      ? '${_forecastA!.avgTarget!.toStringAsFixed(2)} ج.م'
                                      : '-',
                                  valB: (_forecastB?.avgTarget != null && _forecastB!.avgTarget! > 0)
                                      ? '${_forecastB!.avgTarget!.toStringAsFixed(2)} ج.م'
                                      : '-',
                                ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 20),

                        // ==========================================
                        // SECTION 3: المؤشرات الفنية
                        // ==========================================
                        const Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'المؤشرات الفنية',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        _buildComparisonTable(
                          tickerA: tickerA,
                          tickerB: tickerB,
                          rows: _buildTechnicalComparisonRows(),
                        ),

                        const SizedBox(height: 20),
                        ],
                      ],
                    ),
                  ),
                ),

                // ==========================================
                // BOTTOM FIXED ACTION BAR
                // ==========================================
                if (_stockA != null && _stockB != null)
                  _buildBottomActionBar(),
              ],
            ),
    );
  }

  Widget _buildStockSelectorCard({
    required StockModel? stock,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 6),
            if (stock != null) ...[
              StockLogoWidget(stock: stock, size: 36, borderRadius: 8),
              const SizedBox(height: 6),
            ],
            Text(
              stock?.displayName ?? 'اختر السهم',
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              stock?.displaySymbol ?? '',
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFFC1121F),
                  size: 16,
                ),
                Text(
                  'تغيير السهم',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFC1121F),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonTable({
    required String tickerA,
    required String tickerB,
    required List<Widget> rows,
  }) {
    return Container(
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
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header Row with Ticker A & Ticker B
          Container(
            color: const Color(0xFFEFF4F9),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              textDirection: TextDirection.rtl,
              children: [
                Text(
                  tickerA,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF475569),
                  ),
                ),
                Text(
                  tickerB,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),

          // Content Rows
          ...List.generate(rows.length, (idx) {
            return Column(
              children: [
                rows[idx],
                if (idx < rows.length - 1)
                  const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPriceDataRow({
    required String title,
    required String valA,
    required String valB,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          // Row title in center
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),

          // Two values with vertical divider
          IntrinsicHeight(
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                // Right (Stock A)
                Expanded(
                  child: Center(
                    child: Text(
                      valA,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                // Left (Stock B)
                Expanded(
                  child: Center(
                    child: Text(
                      valB,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChangePercentRow({
    required String title,
    required StockModel? stockA,
    required StockModel? stockB,
  }) {
    final chA = stockA?.changePercent ?? 4.55;
    final chB = stockB?.changePercent ?? 10.01;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          IntrinsicHeight(
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                // Right: Pill A
                Expanded(
                  child: Center(child: _buildChangePill(chA)),
                ),
                const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                // Left: Pill B
                Expanded(
                  child: Center(child: _buildChangePill(chB)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChangePill(double pct) {
    final isGain = pct >= 0;
    final color = isGain ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final bg = isGain ? const Color(0xFFDCFCE7) : const Color(0xFFFDE8E8);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: TextDirection.ltr,
        children: [
          TriangleArrow(
            isUp: isGain,
            color: color,
            width: 10,
            height: 8,
          ),
          const SizedBox(width: 4),
          Text(
            Formatters.formatPillPercent(pct),
            textDirection: TextDirection.ltr,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }

  static const List<Map<String, String>> _canonicalIndicators = [
    {
      'key': 'RSI14',
      'title': 'موقع القوة النسبية (RSI)',
    },
    {
      'key': 'MACD12_26',
      'title': 'مؤشر الماكد (MACD)',
    },
    {
      'key': 'STOCH9_6',
      'title': 'ستوكاستيك (Stochastic)',
    },
    {
      'key': 'ADX14',
      'title': 'مؤشر الاتجاه (ADX 14)',
    },
    {
      'key': 'ATR14',
      'title': 'متوسط المدى الحقيقي (ATR 14)',
    },
    {
      'key': 'CCI14',
      'title': 'مؤشر قناة السلع (CCI 14)',
    },
    {
      'key': 'WilliamsR',
      'title': 'مؤشر ويليامز (Williams %R)',
    },
    {
      'key': 'UltimateOscillator',
      'title': 'المذبذب النهائي (UO)',
    },
    {
      'key': 'ParabolicSAR',
      'title': 'بارابوليك سار (Parabolic SAR)',
    },
    {
      'key': 'ROC',
      'title': 'معدل التغير (ROC)',
    },
    {
      'key': 'BullBearPower',
      'title': 'قوة الشراء والبيع',
    },
  ];

  List<Widget> _buildTechnicalComparisonRows() {
    final rows = <Widget>[];

    // 1. توصية المؤشرات العامة
    rows.add(
      _buildTechnicalRow(
        title: 'توصية المؤشرات',
        widgetA: _indicatorsA != null && _indicatorsA!.overallSummary.isNotEmpty
            ? _buildSignalPill(_indicatorsA!.summaryRecommendation)
            : _buildUnavailableText(),
        widgetB: _indicatorsB != null && _indicatorsB!.overallSummary.isNotEmpty
            ? _buildSignalPill(_indicatorsB!.summaryRecommendation)
            : _buildUnavailableText(),
      ),
    );

    // 2. All canonical technical indicators
    for (final item in _canonicalIndicators) {
      final key = item['key']!;
      final title = item['title']!;
      final valA = _indicatorsA?.getIndicator(key);
      final valB = _indicatorsB?.getIndicator(key);

      if (valA != null || valB != null || key == 'RSI14' || key == 'MACD12_26' || key == 'STOCH9_6') {
        rows.add(
          _buildTechnicalRow(
            title: title,
            widgetA: _buildIndicatorValueCell(valA),
            widgetB: _buildIndicatorValueCell(valB),
          ),
        );
      }
    }

    // 3. Extra non-canonical indicators if present
    final knownKeys = _canonicalIndicators.map((e) => e['key']).toSet();
    final allKeysA = _indicatorsA?.indicators.keys.toSet() ?? {};
    final allKeysB = _indicatorsB?.indicators.keys.toSet() ?? {};
    for (final extraKey in {...allKeysA, ...allKeysB}) {
      if (!knownKeys.contains(extraKey)) {
        final valA = _indicatorsA?.getIndicator(extraKey);
        final valB = _indicatorsB?.getIndicator(extraKey);
        rows.add(
          _buildTechnicalRow(
            title: extraKey,
            widgetA: _buildIndicatorValueCell(valA),
            widgetB: _buildIndicatorValueCell(valB),
          ),
        );
      }
    }

    return rows;
  }

  Widget _buildUnavailableText() {
    return const Text(
      '-',
      style: TextStyle(
        fontFamily: 'Tajawal',
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Color(0xFF94A3B8),
      ),
    );
  }

  Widget _buildIndicatorValueCell(IndicatorValue? iv) {
    if (iv == null) return _buildUnavailableText();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          iv.value.toStringAsFixed(2),
          textDirection: TextDirection.ltr,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 3),
        _buildSignalPill(iv.signal),
      ],
    );
  }

  Widget _buildTechnicalRow({
    required String title,
    required Widget widgetA,
    required Widget widgetB,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          IntrinsicHeight(
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Expanded(child: Center(child: widgetA)),
                const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                Expanded(child: Center(child: widgetB)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignalPill(String signal) {
    final s = signal.toLowerCase().trim();
    Color bg = const Color(0xFFF1F5F9);
    Color text = const Color(0xFF64748B);
    String arabic = 'محايد';

    if (s.contains('buy') || s.contains('شراء')) {
      bg = const Color(0xFFDCFCE7);
      text = const Color(0xFF16A34A);
      arabic = 'شراء';
    } else if (s.contains('sell') || s.contains('بيع')) {
      bg = const Color(0xFFFEE2E2);
      text = const Color(0xFFDC2626);
      arabic = 'بيع';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        arabic,
        style: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: text,
        ),
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _openStockSelector(forStockA: false),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC1121F),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            icon: const Icon(Icons.swap_horiz_rounded, size: 20),
            label: const Text(
              'قارن بسهم آخر',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
