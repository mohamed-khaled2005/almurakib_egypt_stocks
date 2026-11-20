import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/market_index_model.dart';
import '../core/models/stock_model.dart';
import '../core/services/stock_service.dart';
import '../core/services/translation_service.dart';
import '../core/utils/constants.dart';
import '../core/utils/formatters.dart';
import '../providers/app_manager_provider.dart';
import '../widgets/ad_banner_card.dart';
import '../widgets/chevron_left_icon.dart';
import '../widgets/stock_logo_widget.dart';
import '../widgets/triangle_arrow.dart';
import 'stock_detail_screen.dart';

const String _currency = 'ج.م';
const String _unavailable = 'غير متاح';

enum _IndexFilterType { all, gainers, losers }

enum _IndexSortType { nameAsc, nameDesc, valueDesc, valueAsc, changeDesc, changeAsc }

class MarketIndexItem {
  final String name;
  final String ticker;
  final String category; // 'EGX'
  final MarketIndexModel? model;

  const MarketIndexItem({
    required this.name,
    required this.ticker,
    required this.category,
    this.model,
  });

  String get displayTicker {
    if (ticker.contains(':')) return ticker.split(':').last.trim();
    return ticker;
  }

  String get displayName {
    if (model != null && model!.displayName.isNotEmpty) {
      return model!.displayName;
    }
    return TranslationService.resolveIndexDisplayName(
      ticker: ticker,
      fallbackName: name,
    );
  }

  MarketIndexItem copyWith({MarketIndexModel? model, String? name}) {
    return MarketIndexItem(
      name: name ?? this.name,
      ticker: ticker,
      category: category,
      model: model ?? this.model,
    );
  }
}

class MarketIndicesScreen extends StatefulWidget {
  const MarketIndicesScreen({super.key});

  @override
  State<MarketIndicesScreen> createState() => _MarketIndicesScreenState();
}

class _MarketIndicesScreenState extends State<MarketIndicesScreen> {
  List<MarketIndexItem> _allIndices = [];
  List<StockModel> _allStocks = [];
  bool _loading = true;

  final TextEditingController _searchController = TextEditingController();
  _IndexFilterType _filterType = _IndexFilterType.all;
  _IndexSortType _sortType = _IndexSortType.nameAsc;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() => _loading = true);
    try {
      if (forceRefresh) {
        await TranslationService.getTranslations(forceRefresh: true);
      }
      final results = await Future.wait([
        StockService.getMarketIndices(forceRefresh: forceRefresh),
        StockService.getStocksList(perPage: 500, page: 1)
            .catchError((_) => <StockModel>[]),
      ]);

      if (!mounted) return;

      final apiIndices = results[0] as List<MarketIndexModel>;
      final apiStocks = results[1] as List<StockModel>;

      final updatedList = apiIndices.map((idx) {
        return MarketIndexItem(
          name: idx.displayName,
          ticker: idx.ticker,
          category: 'EGX',
          model: idx,
        );
      }).toList();

      setState(() {
        _allIndices = updatedList;
        _allStocks = apiStocks;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  List<MarketIndexItem> _getFilteredIndices() {
    final q = _searchController.text.trim().toLowerCase();
    var list = _allIndices.where((item) {
      if (_filterType == _IndexFilterType.gainers) {
        if (item.model == null || item.model!.changePercent <= 0) return false;
      } else if (_filterType == _IndexFilterType.losers) {
        if (item.model == null || item.model!.changePercent >= 0) return false;
      }
      if (q.isEmpty) return true;
      return item.displayName.toLowerCase().contains(q) ||
          item.displayTicker.toLowerCase().contains(q) ||
          item.ticker.toLowerCase().contains(q) ||
          (item.model?.name.toLowerCase().contains(q) ?? false);
    }).toList();

    switch (_sortType) {
      case _IndexSortType.nameAsc:
        list.sort((a, b) => a.displayName.compareTo(b.displayName));
        break;
      case _IndexSortType.nameDesc:
        list.sort((a, b) => b.displayName.compareTo(a.displayName));
        break;
      case _IndexSortType.valueDesc:
        list.sort((a, b) => (b.model?.value ?? 0).compareTo(a.model?.value ?? 0));
        break;
      case _IndexSortType.valueAsc:
        list.sort((a, b) => (a.model?.value ?? 0).compareTo(b.model?.value ?? 0));
        break;
      case _IndexSortType.changeDesc:
        list.sort((a, b) =>
            (b.model?.changePercent ?? -9999).compareTo(a.model?.changePercent ?? -9999));
        break;
      case _IndexSortType.changeAsc:
        list.sort((a, b) =>
            (a.model?.changePercent ?? 9999).compareTo(b.model?.changePercent ?? 9999));
        break;
    }

    return list;
  }

  List<StockModel> _getMatchingStocks() {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return _allStocks
        .where((s) =>
            s.displayName.toLowerCase().contains(q) ||
            s.displaySymbol.toLowerCase().contains(q) ||
            s.symbol.toLowerCase().contains(q) ||
            s.name.toLowerCase().contains(q))
        .take(15)
        .toList();
  }

  void _showSortBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final options = <Map<String, dynamic>>[
          {'type': _IndexSortType.nameAsc, 'title': 'الاسم (أ-ي)'},
          {'type': _IndexSortType.nameDesc, 'title': 'الاسم (ي-أ)'},
          {'type': _IndexSortType.valueDesc, 'title': 'القيمة (الأعلى أولاً)'},
          {'type': _IndexSortType.valueAsc, 'title': 'القيمة (الأقل أولاً)'},
          {'type': _IndexSortType.changeDesc, 'title': 'الأكثر ارتفاعاً'},
          {'type': _IndexSortType.changeAsc, 'title': 'الأكثر انخفاضاً'},
        ];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF94A3B8),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'ترتيب المؤشرات حسب',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ...List.generate(options.length, (i) {
                  final opt = options[i];
                  final type = opt['type'] as _IndexSortType;
                  final title = opt['title'] as String;
                  final isSelected = _sortType == type;
                  final isLast = i == options.length - 1;

                  return Column(
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() => _sortType = type);
                          Navigator.pop(ctx);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            textDirection: TextDirection.rtl,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 14.5,
                                  fontWeight: isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: isSelected
                                      ? const Color(0xFFC1121F)
                                      : const Color(0xFF1F2937),
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(0xFFC1121F),
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (!isLast)
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: Color(0xFFF1F5F9),
                        ),
                    ],
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openDetail(MarketIndexItem item) {
    final model = item.model ??
        MarketIndexModel(
          ticker: item.ticker,
          name: item.displayName,
          value: 0,
          change: 0,
          changePercent: 0,
          hasMarketData: false,
        );

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => StockDetailScreen(stock: model.toStockModel()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppManagerProvider>();
    final filteredIndices = _getFilteredIndices();
    final matchingStocks = _getMatchingStocks();

    return Column(
      children: [
        // Top Header + Search + Filter Pills (matching AllStocksScreen layout)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Section Header: Title on right, Count on left
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                textDirection: TextDirection.rtl,
                children: [
                  const Text(
                    'مؤشرات البورصة المصرية',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  ),
                  Text(
                    '${filteredIndices.length} مؤشر',
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // 2. Search and Sort Row (searches both indices and stocks!)
              Row(
                textDirection: TextDirection.rtl,
                children: [
                  Expanded(
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: TextField(
                        controller: _searchController,
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                        decoration: InputDecoration(
                          hintText: 'ابحث باسم المؤشر أو السهم أو الرمز',
                          hintTextDirection: TextDirection.rtl,
                          hintStyle: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: Color(0xFF94A3B8),
                                    size: 18,
                                  ),
                                  onPressed: () => _searchController.clear(),
                                )
                              : const Icon(
                                  Icons.search_rounded,
                                  color: Color(0xFF94A3B8),
                                  size: 20,
                                ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  InkWell(
                    onTap: _showSortBottomSheet,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: const Icon(
                        Icons.tune_rounded,
                        color: Color(0xFF64748B),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // 3. Secondary Filter Pills (الكل / الأكثر ارتفاعاً / الأكثر انخفاضاً)
              Row(
                textDirection: TextDirection.rtl,
                children: [
                  _buildFilterPill('الكل', _IndexFilterType.all),
                  const SizedBox(width: 8),
                  _buildFilterPill('الأكثر ارتفاعاً', _IndexFilterType.gainers),
                  const SizedBox(width: 8),
                  _buildFilterPill('الأكثر انخفاضاً', _IndexFilterType.losers),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),

        // List Section
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _load(forceRefresh: true),
            color: const Color(0xFFC1121F),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
              children: [
                if (_loading && _allIndices.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: CircularProgressIndicator(color: Color(0xFFC1121F)),
                    ),
                  )
                else if (filteredIndices.isEmpty && matchingStocks.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _searchController.text.trim().isNotEmpty
                          ? 'لا توجد نتائج مطابقة للبحث'
                          : 'لا توجد مؤشرات مسجلة حالياً',
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 14,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  )
                else ...[
                  if (filteredIndices.isNotEmpty)
                    ...filteredIndices.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildIndexCardItem(item),
                        )),

                  // Matching Stocks Section when user searches for a stock
                  if (matchingStocks.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'نتائج الأسهم المطابقة',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...matchingStocks.map((stock) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildStockSearchResultCard(stock),
                        )),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterPill(String label, _IndexFilterType type) {
    final isSelected = _filterType == type;
    return InkWell(
      onTap: () => setState(() => _filterType = type),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFEF2F2) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFFECACA) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? const Color(0xFFC1121F) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // Index Card Item (Ordered like AllStocksScreen with Uniform Default Icon)
  // ==========================================
  Widget _buildIndexCardItem(MarketIndexItem item) {
    final model = item.model;
    final hasData = model != null && model.hasMarketData && model.value > 0;
    final isGain = (model?.changePercent ?? 0) > 0;
    final isZero = (model?.changePercent ?? 0) == 0;
    final changeBg = isZero
        ? const Color(0xFFF1F5F9)
        : (isGain ? const Color(0xFFDCFCE7) : const Color(0xFFFDE8E8));
    final changeColor = isZero
        ? const Color(0xFF64748B)
        : (isGain ? const Color(0xFF15803D) : const Color(0xFF991B1B));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openDetail(item),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                // 1. Right: Uniform Default Index Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.show_chart_rounded,
                    size: 22,
                    color: Color(0xFFC1121F),
                  ),
                ),

                const SizedBox(width: 12),

                // 2. Middle: Arabic Name & Ticker
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.displayName,
                        softWrap: true,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.displayTicker,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // 3. Left: Value & Change Pill
                if (hasData)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        textDirection: TextDirection.rtl,
                        children: [
                          Text(
                            Formatters.formatNumber(model.value),
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Text(
                            'نقطة',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: changeBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          textDirection: TextDirection.ltr,
                          children: [
                            if (!isZero) ...[
                              TriangleArrow(
                                isUp: isGain,
                                color: changeColor,
                                width: 9,
                                height: 7,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              Formatters.formatPillPercent(model.changePercent),
                              textDirection: TextDirection.ltr,
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: changeColor,
                                height: 1.15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  const Text(
                    _unavailable,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),

                const SizedBox(width: 6),

                const ChevronLeftIcon(
                  size: 18,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStockSearchResultCard(StockModel stock) {
    final isGain = stock.changePercent > 0;
    final isZero = stock.changePercent == 0;
    final changeBg = isZero
        ? const Color(0xFFF1F5F9)
        : (isGain ? const Color(0xFFDCFCE7) : const Color(0xFFFDE8E8));
    final changeColor = isZero
        ? const Color(0xFF64748B)
        : (isGain ? const Color(0xFF15803D) : const Color(0xFF991B1B));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => StockDetailScreen(stock: stock),
              ),
            );
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                StockLogoWidget(stock: stock, size: 42, borderRadius: 10),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        stock.displayName,
                        softWrap: true,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stock.displaySymbol,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${Formatters.formatNumber(stock.price)} ج.م',
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: changeBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        Formatters.formatPillPercent(stock.changePercent),
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: changeColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 6),
                const ChevronLeftIcon(size: 18, color: Color(0xFF94A3B8)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Market Index Detail Screen
// ============================================================================
class MarketIndexDetailScreen extends StatelessWidget {
  const MarketIndexDetailScreen({
    super.key,
    required this.index,
  });

  final MarketIndexModel index;

  Color _trendColor(MarketIndexModel model) {
    if (!model.hasMarketData) return AppColors.textSecondary;
    return model.isGain ? AppColors.gain : AppColors.loss;
  }

  IconData _trendIcon(MarketIndexModel model) {
    if (!model.hasMarketData) return Icons.remove_rounded;
    return model.isGain
        ? Icons.trending_up_rounded
        : Icons.trending_down_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final trendColor = _trendColor(index);
    final title = index.displayName;

    return Scaffold(
      backgroundColor: const Color(0xFFFEFEFE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFEFEFE),
        surfaceTintColor: Colors.transparent,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
        centerTitle: true,
        title: Text(
          title,
          maxLines: 2,
          softWrap: true,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
          // Hero Summary Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF6F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        index.displayTicker,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    if (index.hasMarketData)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: trendColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${index.change >= 0 ? '+' : ''}${index.changePercent.toStringAsFixed(2)}%',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: trendColor,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  softWrap: true,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      index.hasMarketData && index.value > 0
                          ? index.value.toStringAsFixed(2)
                          : _unavailable,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                    ),
                    if (index.hasMarketData && index.value > 0) ...[
                      const SizedBox(width: 6),
                      const Text(
                        _currency,
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Metrics Grid
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'التغير بالنقاط',
                  value: index.hasMarketData
                      ? '${index.change >= 0 ? '+' : ''}${index.change.toStringAsFixed(2)}'
                      : _unavailable,
                  icon: _trendIcon(index),
                  accentColor: trendColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  label: 'نسبة التغير',
                  value: index.hasMarketData
                      ? '${index.change >= 0 ? '+' : ''}${index.changePercent.toStringAsFixed(2)}%'
                      : _unavailable,
                  icon: Icons.percent_rounded,
                  accentColor: trendColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
              ],
            ),
          ),
          const SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: AdBannerCard(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accentColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }
}
