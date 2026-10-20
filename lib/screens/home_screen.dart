import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../core/models/market_index_model.dart';
import '../core/models/stock_model.dart';
import '../core/services/stock_service.dart';
import '../core/services/favorites_service.dart';
import '../core/services/translation_service.dart';
import '../core/services/live_socket_service.dart';
import '../core/utils/constants.dart';
import '../core/utils/formatters.dart';

import '../animations/fade_animation.dart';
import '../animations/slide_animation.dart';
import '../widgets/top_stock_card.dart';
import '../widgets/stock_list_item.dart';
import '../widgets/market_status_header.dart';
import 'stock_detail_screen.dart';
import 'stock_comparison_screen.dart';
import 'currency_converter_screen.dart';
import 'price_alerts_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;
  final int allStocksTabIndex;
  final int favoritesTabIndex;
  final int? indicesTabIndex;

  const HomeScreen({
    super.key,
    this.onNavigateToTab,
    this.allStocksTabIndex = 2,
    this.favoritesTabIndex = 4,
    this.indicesTabIndex,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _homeIndicesPreview = 2;
  static const String _currency = 'ج.م';

  List<MarketIndexModel> _marketIndices = <MarketIndexModel>[];
  StockModel? _topGainer;
  StockModel? _topLoser;

  List<StockModel> _favoriteStocks = [];
  bool _loading = true;
  String? _error;
  bool _translationsAvailable = false;

  bool _busy = false;

  // ✅ Tunables
  static const int _perPage = 500;
  static const int _favoritesPreview = 5;

  VoidCallback? _favListener;
  Timer? _favDebounce;
  bool _loadingFavsOnly = false;
  StreamSubscription<LiveQuoteUpdate>? _socketSub;

  @override
  void initState() {
    super.initState();

    _favListener = () {
      _favDebounce?.cancel();
      _favDebounce = Timer(const Duration(milliseconds: 80), () {
        _refreshFavoritesOnly(FavoritesService.favoritesNotifier.value);
      });
    };
    FavoritesService.favoritesNotifier.addListener(_favListener!);

    _socketSub = LiveSocketService.instance.priceStream.listen(_onLiveQuote);

    _loadData();
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    _favDebounce?.cancel();
    if (_favListener != null) {
      FavoritesService.favoritesNotifier.removeListener(_favListener!);
    }
    super.dispose();
  }

  void _onLiveQuote(LiveQuoteUpdate update) {
    if (!mounted) return;
    bool changed = false;

    if (_topGainer != null &&
        (_topGainer!.symbol == update.symbol ||
            _topGainer!.id == update.symbol ||
            _topGainer!.symbol.endsWith(':${update.symbol}'))) {
      _topGainer = _topGainer!.applyLiveUpdate(update);
      changed = true;
    }

    if (_topLoser != null &&
        (_topLoser!.symbol == update.symbol ||
            _topLoser!.id == update.symbol ||
            _topLoser!.symbol.endsWith(':${update.symbol}'))) {
      _topLoser = _topLoser!.applyLiveUpdate(update);
      changed = true;
    }

    for (int i = 0; i < _favoriteStocks.length; i++) {
      if (_favoriteStocks[i].symbol == update.symbol ||
          _favoriteStocks[i].id == update.symbol ||
          _favoriteStocks[i].symbol.endsWith(':${update.symbol}')) {
        _favoriteStocks[i] = _favoriteStocks[i].applyLiveUpdate(update);
        changed = true;
      }
    }

    if (changed) {
      setState(() {});
    }
  }

  Future<void> _refreshFavoritesOnly(Set<String> symbols) async {
    if (!mounted) return;

    if (_loadingFavsOnly) return;
    _loadingFavsOnly = true;

    try {
      final take = symbols.take(_favoritesPreview).toList();
      List<StockModel> favStocks = [];

      if (take.isNotEmpty) {
        favStocks = await StockService.getBySymbols(take);
        if (_translationsAvailable) {
          favStocks = await StockService.attachArabicNames(favStocks);
        }
      }

      if (!mounted) return;
      setState(() {
        _favoriteStocks = favStocks;
      });
    } catch (_) {
      // تجاهل
    } finally {
      _loadingFavsOnly = false;
    }
  }

  Future<void> _loadData() async {
    if (_busy) return;
    _busy = true;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final translationsFuture = TranslationService.getTranslations();
      final indicesFuture = StockService.getMarketIndices(forceRefresh: true);

      // ✅ حمل المفضلة من notifier/SharedPreferences
      final favFuture = FavoritesService.getFavorites(forceReload: true);

      final allStocksFuture =
          StockService.getStocksList(perPage: _perPage, page: 1);

      final indices = await indicesFuture;
      final favoriteSymbolsList = await favFuture;
      final allStocks = await allStocksFuture;

      final favoriteSymbols = favoriteSymbolsList.toSet();

      final gainers = allStocks.where((s) => s.changePercent > 0).toList()
        ..sort((a, b) => b.changePercent.compareTo(a.changePercent));

      final losers = allStocks.where((s) => s.changePercent < 0).toList()
        ..sort((a, b) => a.changePercent.compareTo(b.changePercent));

      final topGainer = gainers.isNotEmpty ? gainers.first : null;
      final topLoser = losers.isNotEmpty ? losers.first : null;

      List<StockModel> favStocks = [];
      if (favoriteSymbols.isNotEmpty) {
        favStocks = await StockService.getBySymbols(
          favoriteSymbols.take(_favoritesPreview).toList(),
        );
      }

      final translations = await translationsFuture;
      _translationsAvailable = translations != null;

      if (translations != null) {
        favStocks = await StockService.attachArabicNames(favStocks);

        StockModel? g = topGainer;
        StockModel? l = topLoser;

        if (g != null) {
          final gg = await StockService.attachArabicNames([g]);
          g = gg.isNotEmpty ? gg.first : g;
        }
        if (l != null) {
          final ll = await StockService.attachArabicNames([l]);
          l = ll.isNotEmpty ? ll.first : l;
        }

        if (!mounted) return;
        setState(() {
          _marketIndices = indices;
          _topGainer = g;
          _topLoser = l;
          _favoriteStocks = favStocks;
          _loading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _marketIndices = indices;
          _topGainer = topGainer;
          _topLoser = topLoser;
          _favoriteStocks = favStocks;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    } finally {
      _busy = false;
    }
  }

  void _navigateToAllStocks() {
    if (widget.onNavigateToTab != null) {
      widget.onNavigateToTab!(widget.allStocksTabIndex);
    }
  }

  void _navigateToFavorites() {
    if (widget.onNavigateToTab != null) {
      widget.onNavigateToTab!(widget.favoritesTabIndex);
    }
  }

  bool _isMarketOpen() {
    final now = DateTime.now();
    final weekday = now.weekday;
    final isTradingDay = weekday == DateTime.sunday ||
        (weekday >= DateTime.monday && weekday <= DateTime.thursday);
    if (!isTradingDay) return false;

    final minutes = now.hour * 60 + now.minute;
    return minutes >= (9 * 60 + 30) && minutes < (14 * 60 + 30);
  }

  String _formatTickerLabel(String ticker) {
    final normalized = ticker.trim();
    if (normalized.isEmpty) return '';
    final parts = normalized.split(':');
    return parts.isEmpty ? normalized : parts.last.trim().toUpperCase();
  }

  Widget _buildIndexBlock({required MarketIndexModel index}) {
    final hasData = index.hasMarketData;
    final isGain = index.change >= 0;
    final trendColor = !hasData
        ? AppColors.neutral
        : isGain
            ? AppColors.gain
            : AppColors.loss;
    final title =
        index.name.isEmpty ? _formatTickerLabel(index.ticker) : index.name;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.55)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        textDirection: TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          _buildIndexRefreshButton(),
          const SizedBox(width: 8),
          _buildIndexChangeBadge(
            index: index,
            trendColor: trendColor,
            isGain: isGain,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11.2,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary.withValues(alpha: 0.86),
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    textDirection: TextDirection.rtl,
                    children: <Widget>[
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          hasData
                              ? Formatters.formatNumber(index.value)
                              : 'غير متاح',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: hasData ? 20 : 13,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                            height: 1.0,
                          ),
                        ),
                      ),
                      if (hasData) ...<Widget>[
                        const SizedBox(width: 5),
                        Text(
                          _currency,
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color:
                                AppColors.textSecondary.withValues(alpha: 0.86),
                            height: 1.0,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndexRefreshButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _loadData,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.isDark ? AppColors.cardLight : Colors.white,
            border: Border.all(color: AppColors.border),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.refresh_rounded,
            size: 16,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildIndexChangeBadge({
    required MarketIndexModel index,
    required Color trendColor,
    required bool isGain,
  }) {
    final hasData = index.hasMarketData;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: trendColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: TextDirection.rtl,
        children: <Widget>[
          Icon(
            !hasData
                ? Icons.remove_rounded
                : isGain
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
            size: 14,
            color: trendColor,
          ),
          const SizedBox(width: 6),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              hasData ? Formatters.formatPercent(index.changePercent) : '--',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 11.2,
                fontWeight: FontWeight.w900,
                color: trendColor,
              ),
            ),
          ),
          if (hasData) ...<Widget>[
            const SizedBox(width: 8),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                Formatters.formatChange(index.change),
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 11.2,
                  fontWeight: FontWeight.w800,
                  color: trendColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String currentDate =
        DateFormat('EEEE d MMMM y', 'ar').format(DateTime.now());
    currentDate = currentDate
        .replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9');

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: SafeArea(
        child: _loading
            ? _buildLoadingState()
            : _error != null
                ? _buildErrorState()
                : RefreshIndicator(
                    onRefresh: _loadData,
                    color: AppColors.primaryBlue,
                    backgroundColor: Colors.white,
                    child: FadeAnimation(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        children: [
                          _buildHeader(
                            date: currentDate,
                            isMarketOpen: _isMarketOpen(),
                          ),
                          const SizedBox(height: 12),
                          const MarketStatusHeader(),
                          const SizedBox(height: 12),
                          _buildQuickToolsGrid(),
                          const SizedBox(height: 14),
                          if (!_translationsAvailable) _buildTranslationAlert(),
                          if (_marketIndices.isNotEmpty) ...[
                            ...List.generate(
                              _marketIndices.take(_homeIndicesPreview).length,
                              (index) {
                                final item = _marketIndices[index];
                                return SlideAnimation(
                                  delay: Duration(milliseconds: index * 90),
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      bottom: index ==
                                              _marketIndices
                                                      .take(_homeIndicesPreview)
                                                      .length -
                                                  1
                                          ? 0
                                          : 12,
                                    ),
                                    child: _buildIndexBlock(index: item),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 20),
                          ],
                          _buildUnifiedTitle(
                            title: 'أداء السوق اليوم',
                            action: InkWell(
                              onTap: _navigateToAllStocks,
                              borderRadius: BorderRadius.circular(20),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'كل الأسهم',
                                      style: TextStyle(
                                        fontFamily: 'Tajawal',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primaryBlue,
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 16,
                                      color: AppColors.primaryBlue,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_topGainer != null || _topLoser != null)
                            Column(
                              children: [
                                if (_topGainer != null)
                                  SlideAnimation(
                                    delay: const Duration(milliseconds: 150),
                                    child: _buildLabeledStockSection(
                                      title: 'الأكثر ارتفاعاً',
                                      stock: _topGainer!,
                                      isGainer: true,
                                    ),
                                  ),
                                if (_topGainer != null && _topLoser != null)
                                  const SizedBox(height: 14),
                                if (_topLoser != null)
                                  SlideAnimation(
                                    delay: const Duration(milliseconds: 200),
                                    child: _buildLabeledStockSection(
                                      title: 'الأكثر انخفاضاً',
                                      stock: _topLoser!,
                                      isGainer: false,
                                    ),
                                  ),
                              ],
                            ),
                          const SizedBox(height: 24),
                          _buildUnifiedTitle(
                            title: 'مفضلتك',
                            action: InkWell(
                              onTap: _navigateToFavorites,
                              borderRadius: BorderRadius.circular(20),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'عرض الكل',
                                      style: TextStyle(
                                        fontFamily: 'Tajawal',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primaryBlue,
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    Icon(Icons.arrow_forward_rounded,
                                        size: 16, color: AppColors.primaryBlue),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_favoriteStocks.isNotEmpty)
                            ...List.generate(_favoriteStocks.length, (index) {
                              final stock = _favoriteStocks[index];
                              return SlideAnimation(
                                delay:
                                    Duration(milliseconds: 300 + (index * 50)),
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: StockListItem(
                                    stock: stock,
                                    showFavoriteButton: true,
                                    isFavorite: true,
                                    onFavoriteTap: () async {
                                      await FavoritesService.toggleFavorite(
                                          stock.symbol);
                                    },
                                    onTap: () => _openStockDetail(stock),
                                  ),
                                ),
                              );
                            })
                          else
                            SlideAnimation(
                              delay: const Duration(milliseconds: 250),
                              child: _buildEmptyFavoritesState(),
                            ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildHeader({
    required String date,
    required bool isMarketOpen,
  }) {
    final statusColor = isMarketOpen ? AppColors.gain : AppColors.neutral;

    return Row(
      children: [
        Expanded(
          child: Text(
            'اليوم: $date',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: statusColor.withOpacity(0.22)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isMarketOpen ? Icons.lock_open_rounded : Icons.lock_rounded,
                size: 13,
                color: statusColor,
              ),
              const SizedBox(width: 6),
              Text(
                isMarketOpen ? 'السوق مفتوح' : 'السوق مغلق',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 10.8,
                  fontWeight: FontWeight.w800,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUnifiedTitle({required String title, Widget? action}) {
    return SlideAnimation(
      delay: const Duration(milliseconds: 100),
      child: Row(
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
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.headingSmall.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Colors.black87,
              ),
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Align(alignment: Alignment.centerLeft, child: action),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLabeledStockSection({
    required String title,
    required StockModel stock,
    required bool isGainer,
  }) {
    final color = isGainer ? AppColors.gain : AppColors.loss;
    final icon =
        isGainer ? Icons.trending_up_rounded : Icons.trending_down_rounded;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, right: 4, left: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 13, color: color),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ).copyWith(color: color),
              ),
            ],
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: TopStockCard(
            stock: stock,
            isGainer: isGainer,
            onTap: () => _openStockDetail(stock),
          ),
        ),
      ],
    );
  }

  Widget _buildTranslationAlert() {
    return SlideAnimation(
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primaryGold.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryGold.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded,
                color: AppColors.primaryGold, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'يتم عرض الأسماء باللغة الإنجليزية حالياً',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFavoritesState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryGold.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.star_rounded,
              size: 34,
              color: AppColors.primaryGold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'قائمة المراقبة فارغة',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 16.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'قم بإضافة الأسهم التي تهمك لمتابعتها بشكل أسرع من هنا.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _navigateToAllStocks,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text(
                'استكشاف السوق',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
          color: AppColors.primaryBlue, strokeWidth: 2.5),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 24),
            Text('عذراً، حدث خطأ ما', style: AppTextStyles.headingSmall),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('تحديث الصفحة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickToolsGrid() {
    return Row(
      children: [
        Expanded(
          child: _QuickToolCard(
            title: 'مقارنة سهمين',
            subtitle: 'تحليل مقارن',
            icon: Icons.compare_arrows_rounded,
            color: AppColors.primaryBlue,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const StockComparisonScreen(),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickToolCard(
            title: 'محول العملات',
            subtitle: 'أسعار الصرف',
            icon: Icons.currency_exchange_rounded,
            color: const Color(0xFF16A34A),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CurrencyConverterScreen(),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickToolCard(
            title: 'تنبيهات الأسعار',
            subtitle: 'إشعارات حية',
            icon: Icons.notifications_active_outlined,
            color: const Color(0xFFD97706),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PriceAlertsScreen(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _openStockDetail(StockModel stock) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StockDetailScreen(stock: stock)),
    ).then((_) => _loadData());
  }
}

class _QuickToolCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickToolCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.18)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
