// lib/screens/market_today_screen.dart
import 'package:flutter/material.dart';

import '../core/models/stock_model.dart';
import '../core/services/stock_service.dart';
import '../core/services/favorites_service.dart';
import '../core/utils/constants.dart';
import '../widgets/stock_list_item.dart';
import 'stock_detail_screen.dart';

class MarketTodayScreen extends StatefulWidget {
  const MarketTodayScreen({super.key});

  @override
  State<MarketTodayScreen> createState() => _MarketTodayScreenState();
}

class _MarketTodayScreenState extends State<MarketTodayScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<StockModel> _gainers = [];
  List<StockModel> _losers = [];
  Set<String> _favoriteSymbols = {};

  bool _loading = true;
  String? _error;

  static const int _perPage = 500;
  static const int _limit = 20;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        StockService.getStocksList(perPage: _perPage, page: 1),
        FavoritesService.getFavorites(),
      ]);

      if (!mounted) return;

      final allStocks = results[0] as List<StockModel>;
      final favs = (results[1] as List<String>).toSet();

      final gainers = allStocks.where((s) => s.changePercent > 0).toList()
        ..sort((a, b) => b.changePercent.compareTo(a.changePercent));

      final losers = allStocks.where((s) => s.changePercent < 0).toList()
        ..sort((a, b) => a.changePercent.compareTo(b.changePercent));

      setState(() {
        _gainers = gainers.take(_limit).toList();
        _losers = losers.take(_limit).toList();
        _favoriteSymbols = favs;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'فشل تحميل بيانات السوق';
        _loading = false;
      });
    }
  }

  Future<void> _toggleFavorite(StockModel stock) async {
    await FavoritesService.toggleFavorite(stock.symbol);
    final favs = await FavoritesService.getFavorites();
    if (!mounted) return;
    setState(() {
      _favoriteSymbols = favs.toSet();
    });
  }

  void _onTabTap(int index) {
    if (_tabController.index == index) return;
    _tabController.animateTo(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Widget _buildHeadingRow(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.primaryBlue,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTextStyles.headingSmall.copyWith(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // خلي الخلفية عامة أبيض (لو عندك scaffold كان بيطلع أحمر)
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildUnifiedHeader(),
            _buildSegmentedSwitch(),
            Expanded(
              child: _loading
                  ? _buildLoadingState()
                  : _error != null
                      ? _buildErrorState()
                      : TabBarView(
                          controller: _tabController,
                          physics: const BouncingScrollPhysics(),
                          children: [
                            _StockListTab(
                              stocks: _gainers,
                              isGainers: true,
                              favoriteSymbols: _favoriteSymbols,
                              onRefresh: _loadData,
                              onToggleFavorite: _toggleFavorite,
                              onTapStock: _openStockDetail,
                            ),
                            _StockListTab(
                              stocks: _losers,
                              isGainers: false,
                              favoriteSymbols: _favoriteSymbols,
                              onRefresh: _loadData,
                              onToggleFavorite: _toggleFavorite,
                              onTapStock: _openStockDetail,
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ هنا التعديل:
  // - شيلنا البراجراف
  // - شيلنا الخلفية/الكونتينر الأبيض اللي كان ورا الهيدنج
  // - خليّنا البوزيشن ثابت (20 يمين/شمال + 16 من فوق)
  Widget _buildUnifiedHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: _buildHeadingRow('تحركات السوق'),
    );
  }

  Widget _buildSegmentedSwitch() {
    const double height = 52;
    final borderRadius = BorderRadius.circular(16);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: ClipRRect(
          borderRadius: borderRadius,
          child: AnimatedBuilder(
            animation: _tabController.animation!,
            builder: (context, _) {
              final t = _tabController.animation!.value.clamp(0.0, 1.0);
              final alignment =
                  Alignment.lerp(Alignment.centerRight, Alignment.centerLeft, t)!;

              final currentIndex = (t < 0.5) ? 0 : 1;

              return Stack(
                children: [
                  Align(
                    alignment: alignment,
                    child: FractionallySizedBox(
                      widthFactor: 0.5,
                      heightFactor: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryBlue.withOpacity(0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _SegmentButton(
                          title: 'الأكثر ارتفاعاً',
                          isSelected: currentIndex == 0,
                          onTap: () => _onTabTap(0),
                        ),
                      ),
                      Expanded(
                        child: _SegmentButton(
                          title: 'الأكثر انخفاضاً',
                          isSelected: currentIndex == 1,
                          onTap: () => _onTabTap(1),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.primaryBlue,
        strokeWidth: 3,
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 40,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 16),
            Text('عذراً، حدث خطأ', style: AppTextStyles.headingSmall),
            const SizedBox(height: 8),
            Text(
              _error ?? 'لا يمكن الوصول للبيانات حالياً',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openStockDetail(StockModel stock) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StockDetailScreen(stock: stock)),
    ).then((_) async {
      final favs = await FavoritesService.getFavorites();
      if (!mounted) return;
      setState(() {
        _favoriteSymbols = favs.toSet();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

class _StockListTab extends StatefulWidget {
  final List<StockModel> stocks;
  final bool isGainers;
  final Set<String> favoriteSymbols;
  final Future<void> Function() onRefresh;
  final Function(StockModel) onToggleFavorite;
  final Function(StockModel) onTapStock;

  const _StockListTab({
    required this.stocks,
    required this.isGainers,
    required this.favoriteSymbols,
    required this.onRefresh,
    required this.onToggleFavorite,
    required this.onTapStock,
  });

  @override
  State<_StockListTab> createState() => _StockListTabState();
}

class _StockListTabState extends State<_StockListTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.stocks.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: AppColors.primaryBlue,
      backgroundColor: Colors.white,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        physics:
            const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        itemCount: widget.stocks.length,
        itemBuilder: (context, index) {
          final stock = widget.stocks[index];
          final isFav = widget.favoriteSymbols.contains(stock.symbol);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: StockListItem(
              stock: stock,
              showFavoriteButton: true,
              isFavorite: isFav,
              onFavoriteTap: () => widget.onToggleFavorite(stock),
              onTap: () => widget.onTapStock(stock),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            widget.isGainers
                ? Icons.trending_up_rounded
                : Icons.trending_down_rounded,
            size: 80,
            color: AppColors.border,
          ),
          const SizedBox(height: 16),
          Text(
            widget.isGainers ? 'لا توجد ارتفاعات مسجلة' : 'لا توجد انخفاضات مسجلة',
            style: AppTextStyles.headingSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'قد يكون السوق مغلقاً أو لم تتغير الأسعار بعد',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
