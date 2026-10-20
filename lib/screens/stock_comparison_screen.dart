import 'package:flutter/material.dart';

import '../core/models/stock_model.dart';
import '../core/models/dividend_model.dart';
import '../core/models/stock_forecast_model.dart';
import '../core/models/stock_indicator_model.dart';
import '../core/services/stock_service.dart';
import '../core/utils/constants.dart';

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

  // Comparison Data
  StockIndicatorModel? _indicatorsA;
  StockIndicatorModel? _indicatorsB;
  DividendData? _dividendA;
  DividendData? _dividendB;
  StockForecast? _forecastA;
  StockForecast? _forecastB;

  bool _loadingDetails = false;

  @override
  void initState() {
    super.initState();
    _stockA = widget.initialStockA;
    _stockB = widget.initialStockB;
    _loadAllStocks();
    if (_stockA != null || _stockB != null) {
      _loadComparisonDetails();
    }
  }

  Future<void> _loadAllStocks() async {
    try {
      final list = await StockService.getStocksList();
      if (mounted) {
        setState(() {
          _allStocks = list;
          _loadingStocks = false;
          if (_stockA == null && list.isNotEmpty) {
            _stockA = list.first;
          }
          if (_stockB == null && list.length > 1) {
            _stockB = list[1];
          }
        });
        _loadComparisonDetails();
      }
    } catch (_) {
      if (mounted) setState(() => _loadingStocks = false);
    }
  }

  Future<void> _loadComparisonDetails() async {
    if (_stockA == null && _stockB == null) return;
    setState(() => _loadingDetails = true);

    try {
      final futures = await Future.wait([
        if (_stockA != null) ...[
          StockService.getIndicators(_stockA!.symbol).catchError((_) => StockIndicatorModel.fallback()),
          StockService.getDividends(_stockA!.symbol).catchError((_) => DividendData(ticker: _stockA!.symbol, payouts: const [], historyYield: const {})),
          StockService.getForecast(_stockA!.symbol).catchError((_) => StockForecast(ticker: _stockA!.symbol)),
        ] else ...[
          Future.value(null),
          Future.value(null),
          Future.value(null),
        ],
        if (_stockB != null) ...[
          StockService.getIndicators(_stockB!.symbol).catchError((_) => StockIndicatorModel.fallback()),
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

  void _openStockSelector({required bool forStockA}) {
    showModalBottomSheet<StockModel>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    forStockA ? 'اختر السهم الأول' : 'اختر السهم الثاني',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    style: TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'ابحث باسم السهم أو الرمز...',
                      hintStyle: TextStyle(color: AppColors.textSecondary),
                      prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (val) => setModalState(() => query = val),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final s = filtered[i];
                        return ListTile(
                          title: Text(
                            s.displayName,
                            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            s.symbol,
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                          trailing: Text(
                            '${s.price.toStringAsFixed(2)} ج.م',
                            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                          ),
                          onTap: () => Navigator.of(context).pop(s),
                        );
                      },
                    ),
                  ),
                ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('مقارنة سهمين', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      body: _loadingStocks
          ? Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  // Selectors Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildStockCard(
                          stock: _stockA,
                          label: 'السهم الأول',
                          onTap: () => _openStockSelector(forStockA: true),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'VS',
                          style: TextStyle(
                            color: AppColors.primaryBlue,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _buildStockCard(
                          stock: _stockB,
                          label: 'السهم الثاني',
                          onTap: () => _openStockSelector(forStockA: false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (_loadingDetails)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: CircularProgressIndicator(color: AppColors.primaryBlue),
                    )
                  else ...[
                    // Price & Performance Comparison
                    _buildSectionHeader('الأسعار والتداولات'),
                    _buildComparisonRow(
                      'السعر الحالي',
                      _stockA != null ? '${_stockA!.price.toStringAsFixed(2)} ج.م' : '-',
                      _stockB != null ? '${_stockB!.price.toStringAsFixed(2)} ج.م' : '-',
                    ),
                    _buildComparisonRow(
                      'نسبة التغير',
                      _stockA != null ? '${_stockA!.changePercent >= 0 ? '+' : ''}${_stockA!.changePercent.toStringAsFixed(2)}%' : '-',
                      _stockB != null ? '${_stockB!.changePercent >= 0 ? '+' : ''}${_stockB!.changePercent.toStringAsFixed(2)}%' : '-',
                      highlightA: _stockA != null && _stockB != null && _stockA!.changePercent > _stockB!.changePercent,
                      highlightB: _stockA != null && _stockB != null && _stockB!.changePercent > _stockA!.changePercent,
                    ),
                    _buildComparisonRow(
                      'أعلى سعر اليوم',
                      _stockA?.high != null ? '${_stockA!.high!.toStringAsFixed(2)} ج.م' : '-',
                      _stockB?.high != null ? '${_stockB!.high!.toStringAsFixed(2)} ج.م' : '-',
                    ),
                    _buildComparisonRow(
                      'أدنى سعر اليوم',
                      _stockA?.low != null ? '${_stockA!.low!.toStringAsFixed(2)} ج.م' : '-',
                      _stockB?.low != null ? '${_stockB!.low!.toStringAsFixed(2)} ج.م' : '-',
                    ),
                    _buildComparisonRow(
                      'سعر الافتتاح',
                      _stockA?.open != null ? '${_stockA!.open!.toStringAsFixed(2)} ج.م' : '-',
                      _stockB?.open != null ? '${_stockB!.open!.toStringAsFixed(2)} ج.م' : '-',
                    ),
                    _buildComparisonRow(
                      'الإغلاق السابق',
                      _stockA?.previousClose != null ? '${_stockA!.previousClose!.toStringAsFixed(2)} ج.م' : '-',
                      _stockB?.previousClose != null ? '${_stockB!.previousClose!.toStringAsFixed(2)} ج.م' : '-',
                    ),
                    _buildComparisonRow(
                      'فارق الشراء/البيع (Spread)',
                      _stockA?.spread != null ? '${_stockA!.spread!.toStringAsFixed(2)} ج.م' : '-',
                      _stockB?.spread != null ? '${_stockB!.spread!.toStringAsFixed(2)} ج.م' : '-',
                    ),

                    const SizedBox(height: 16),
                    _buildSectionHeader('توزيعات الأرباح والمستهدفات'),
                    _buildComparisonRow(
                      'عائد التوزيع الحالي',
                      _dividendA?.currentYield != null ? '${_dividendA!.currentYield!.toStringAsFixed(2)}%' : 'غير متوفر',
                      _dividendB?.currentYield != null ? '${_dividendB!.currentYield!.toStringAsFixed(2)}%' : 'غير متوفر',
                      highlightA: (_dividendA?.currentYield ?? 0) > (_dividendB?.currentYield ?? 0) && (_dividendA?.currentYield ?? 0) > 0,
                      highlightB: (_dividendB?.currentYield ?? 0) > (_dividendA?.currentYield ?? 0) && (_dividendB?.currentYield ?? 0) > 0,
                    ),
                    _buildComparisonRow(
                      'نسبة التوزيع من الأرباح',
                      _dividendA?.payoutRatio != null ? '${_dividendA!.payoutRatio!.toStringAsFixed(1)}%' : 'غير متوفر',
                      _dividendB?.payoutRatio != null ? '${_dividendB!.payoutRatio!.toStringAsFixed(1)}%' : 'غير متوفر',
                    ),
                    _buildComparisonRow(
                      'متوسط السعر المستهدف',
                      _forecastA?.avgTarget != null ? '${_forecastA!.avgTarget!.toStringAsFixed(2)} ج.م' : 'غير متوفر',
                      _forecastB?.avgTarget != null ? '${_forecastB!.avgTarget!.toStringAsFixed(2)} ج.م' : 'غير متوفر',
                    ),
                    _buildComparisonRow(
                      'أعلى سعر مستهدف',
                      _forecastA?.highTarget != null ? '${_forecastA!.highTarget!.toStringAsFixed(2)} ج.م' : 'غير متوفر',
                      _forecastB?.highTarget != null ? '${_forecastB!.highTarget!.toStringAsFixed(2)} ج.م' : 'غير متوفر',
                    ),

                    const SizedBox(height: 16),
                    _buildSectionHeader('المؤشرات الفنية'),
                    _buildComparisonRow(
                      'مؤشر القوة النسبية (RSI)',
                      _indicatorsA?.rsi != null ? _indicatorsA!.rsi!.value.toStringAsFixed(1) : '-',
                      _indicatorsB?.rsi != null ? _indicatorsB!.rsi!.value.toStringAsFixed(1) : '-',
                    ),
                    _buildComparisonRow(
                      'توصية المؤشرات',
                      _indicatorsA != null ? _indicatorsA!.summaryRecommendation : '-',
                      _indicatorsB != null ? _indicatorsB!.summaryRecommendation : '-',
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildStockCard({
    required StockModel? stock,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            const SizedBox(height: 8),
            Text(
              stock?.displayName ?? 'اضغط للاختيار',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              stock?.symbol ?? '',
              style: TextStyle(color: AppColors.textSecondary.withOpacity(0.8), fontSize: 11),
            ),
            const SizedBox(height: 6),
            Icon(Icons.arrow_drop_down_circle_outlined, size: 18, color: AppColors.primaryBlue),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(width: 4, height: 16, color: AppColors.primaryBlue),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(
    String label,
    String valA,
    String valB, {
    bool highlightA = false,
    bool highlightB = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              valA,
              style: TextStyle(
                color: highlightA ? AppColors.gain : AppColors.textPrimary,
                fontWeight: highlightA ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              valB,
              style: TextStyle(
                color: highlightB ? AppColors.gain : AppColors.textPrimary,
                fontWeight: highlightB ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
