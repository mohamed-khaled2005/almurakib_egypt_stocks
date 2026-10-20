// lib/screens/all_stocks_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/models/stock_model.dart';
import '../core/services/stock_service.dart';
import '../core/services/favorites_service.dart';
import '../core/services/live_socket_service.dart';
import '../core/utils/constants.dart';
import '../core/utils/formatters.dart';
import '../animations/fade_animation.dart';
import '../animations/slide_animation.dart';
import '../widgets/market_status_header.dart';
import 'stock_detail_screen.dart';
import 'stock_comparison_screen.dart';
import 'currency_converter_screen.dart';
import 'price_alerts_screen.dart';

// --- Enums ---
enum StockSortType {
  nameAsc,
  nameDesc,
  priceAsc,
  priceDesc,
  changeAsc,
  changeDesc,
}

enum StockFilterType {
  all,
  gainers,
  losers,
  favorites,
}

enum AssetCategory {
  stocks,
  reits,
  etfs,
}

class AllStocksScreen extends StatefulWidget {
  const AllStocksScreen({super.key});

  @override
  State<AllStocksScreen> createState() => _AllStocksScreenState();
}

class _AllStocksScreenState extends State<AllStocksScreen> {
  // --- Data ---
  final List<StockModel> _allStocks = [];
  List<StockModel> _filteredStocks = [];
  Set<String> _favoriteSymbols = {};

  // --- UI / State ---
  bool _loading = true;
  String? _error;
  AssetCategory _selectedCategory = AssetCategory.stocks;

  // Pagination
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;

  // Tunables
  static const int _perPage = 500;

  final TextEditingController _searchController = TextEditingController();
  StockSortType _sortType = StockSortType.nameAsc;
  StockFilterType _filterType = StockFilterType.all;

  final Map<String, String> _searchIndexCache = {};
  StreamSubscription<LiveQuoteUpdate>? _socketSub;

  // --- Lifecycle ---
  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    _socketSub = LiveSocketService.instance.priceStream.listen(_onLiveQuote);
    _loadInitial();
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();

    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onLiveQuote(LiveQuoteUpdate update) {
    if (!mounted) return;
    bool anyUpdated = false;

    for (int i = 0; i < _allStocks.length; i++) {
      if (_allStocks[i].symbol == update.symbol ||
          _allStocks[i].id == update.symbol ||
          _allStocks[i].symbol.endsWith(':${update.symbol}')) {
        _allStocks[i] = _allStocks[i].applyLiveUpdate(update);
        anyUpdated = true;
      }
    }

    if (anyUpdated) {
      for (int i = 0; i < _filteredStocks.length; i++) {
        if (_filteredStocks[i].symbol == update.symbol ||
            _filteredStocks[i].id == update.symbol ||
            _filteredStocks[i].symbol.endsWith(':${update.symbol}')) {
          _filteredStocks[i] = _filteredStocks[i].applyLiveUpdate(update);
        }
      }
      setState(() {});
    }
  }

  // --- Pagination Logic ---
  void _onScroll() {
    if (!_hasMore || _isLoadingMore || _loading) return;

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  void _selectCategory(AssetCategory category) {
    if (_selectedCategory == category) return;
    setState(() {
      _selectedCategory = category;
    });
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
      _hasMore = true;
    });

    try {
      Future<List<StockModel>> dataFuture;
      switch (_selectedCategory) {
        case AssetCategory.stocks:
          dataFuture = StockService.getStocksList(perPage: _perPage, page: 1, forceRefresh: true);
          break;
        case AssetCategory.reits:
          dataFuture = StockService.getAssetsByCategory('reits');
          break;
        case AssetCategory.etfs:
          dataFuture = StockService.getAssetsByCategory('etfs');
          break;
      }

      final results = await Future.wait([
        dataFuture,
        FavoritesService.getFavorites(),
      ]);

      if (!mounted) return;

      _allStocks
        ..clear()
        ..addAll(results[0] as List<StockModel>);

      _favoriteSymbols = (results[1] as List<String>).toSet();

      _hasMore = _selectedCategory == AssetCategory.stocks && _allStocks.length >= _perPage;
      _searchIndexCache.clear();

      setState(() {
        _loading = false;
      });

      _applyFilters();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل البيانات';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _isLoadingMore || _selectedCategory != AssetCategory.stocks) return;

    setState(() => _isLoadingMore = true);

    try {
      final nextPage = _page + 1;
      final more = await StockService.getStocksList(
        perPage: _perPage,
        page: nextPage,
      );

      if (!mounted) return;

      if (more.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoadingMore = false;
        });
        return;
      }

      final existingSymbols = _allStocks.map((e) => e.symbol).toSet();
      final deduped =
          more.where((s) => !existingSymbols.contains(s.symbol)).toList();

      _allStocks.addAll(deduped);
      _page = nextPage;

      if (more.length < _perPage) _hasMore = false;

      _searchIndexCache.clear();

      setState(() => _isLoadingMore = false);
      _applyFilters();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  // --- Search / Filter / Sort ---
  void _onSearchChanged() => _applyFilters();

  void _updateFilter(StockFilterType type) {
    setState(() => _filterType = type);
    _applyFilters();
  }

  String _normalizeForSearch(String input) {
    var s = input.toLowerCase();

    s = s.replaceAll(
      RegExp(r'[\u200E\u200F\u202A-\u202E\u2066-\u2069]'),
      '',
    );

    s = s.replaceAll(RegExp(r'[\"""„‟«»‹›]'), '');
    s = s.replaceAll(RegExp(r"[\''`´]"), '');

    s = s.replaceAll(
      RegExp(r'[^a-z0-9\u0621-\u064A\u0660-\u0669\u06F0-\u06F9]+'),
      ' ',
    );

    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

    return s;
  }

  String _cacheKey(StockModel s) => (s.symbol.isNotEmpty ? s.symbol : s.id);

  String _searchIndexFor(StockModel s) {
    final key = _cacheKey(s);
    return _searchIndexCache.putIfAbsent(key, () {
      final raw = '${s.displayName} ${s.symbol} ${s.id}';
      return _normalizeForSearch(raw);
    });
  }

  bool _matchesQuery(StockModel s, String normalizedQuery) {
    if (normalizedQuery.isEmpty) return true;

    final idx = _searchIndexFor(s);

    if (idx.contains(normalizedQuery)) return true;

    final compactIdx = idx.replaceAll(' ', '');
    final compactQ = normalizedQuery.replaceAll(' ', '');
    if (compactQ.isNotEmpty && compactIdx.contains(compactQ)) return true;

    final tokens =
        normalizedQuery.split(' ').where((t) => t.trim().isNotEmpty).toList();
    if (tokens.isEmpty) return true;
    return tokens.every((t) => idx.contains(t));
  }

  void _applyFilters() {
    List<StockModel> temp = List.from(_allStocks);

    switch (_filterType) {
      case StockFilterType.gainers:
        temp = temp.where((s) => s.changePercent > 0).toList();
        break;
      case StockFilterType.losers:
        temp = temp.where((s) => s.changePercent < 0).toList();
        break;
      case StockFilterType.favorites:
        temp = temp.where((s) => _favoriteSymbols.contains(s.symbol)).toList();
        break;
      case StockFilterType.all:
        break;
    }

    final normalizedQuery = _normalizeForSearch(_searchController.text.trim());
    if (normalizedQuery.isNotEmpty) {
      temp = temp.where((s) => _matchesQuery(s, normalizedQuery)).toList();
    }

    switch (_sortType) {
      case StockSortType.nameAsc:
        temp.sort((a, b) => a.displayName.compareTo(b.displayName));
        break;
      case StockSortType.nameDesc:
        temp.sort((a, b) => b.displayName.compareTo(a.displayName));
        break;
      case StockSortType.priceAsc:
        temp.sort((a, b) => a.price.compareTo(b.price));
        break;
      case StockSortType.priceDesc:
        temp.sort((a, b) => b.price.compareTo(a.price));
        break;
      case StockSortType.changeAsc:
        temp.sort((a, b) => a.changePercent.compareTo(b.changePercent));
        break;
      case StockSortType.changeDesc:
        temp.sort((a, b) => b.changePercent.compareTo(a.changePercent));
        break;
    }

    setState(() {
      _filteredStocks = temp;
    });
  }

  Future<void> _toggleFavorite(StockModel stock) async {
    await FavoritesService.toggleFavorite(stock.symbol);
    final newFavs = await FavoritesService.getFavorites();
    if (!mounted) return;

    setState(() {
      _favoriteSymbols = newFavs.toSet();
    });

    if (_filterType == StockFilterType.favorites) {
      _applyFilters();
    }
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
      _applyFilters();
    });
  }

  // ✅ هيدنج موحد (نفس الشكل)
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

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        // ✅ شيلنا الخلفية اللي بتطلع حمراء
        backgroundColor: Colors.white,
        body: SafeArea(
          child: FadeAnimation(
            child: Column(
              children: [
                _buildTopControlPanel(),
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _categoryTitle() {
    switch (_selectedCategory) {
      case AssetCategory.stocks:
        return 'جميع الأسهم';
      case AssetCategory.reits:
        return 'صناديق ريت العقارية';
      case AssetCategory.etfs:
        return 'صناديق المؤشرات ETF';
    }
  }

  Widget _buildTopControlPanel() {
    return SlideAnimation(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Market Status
            const MarketStatusHeader(),
            const SizedBox(height: 12),

            // Quick Action Shortcuts
            Row(
              children: [
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.compare_arrows_rounded,
                    label: 'مقارنة سهمين',
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
                  child: _QuickActionButton(
                    icon: Icons.currency_exchange_rounded,
                    label: 'محول العملات',
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
                  child: _QuickActionButton(
                    icon: Icons.notifications_active_outlined,
                    label: 'تنبيهات الأسعار',
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
            ),
            const SizedBox(height: 12),

            // Asset Category Selector (الأسهم | صناديق ريت | صناديق المؤشرات)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _CategoryPill(
                      title: 'الأسهم',
                      icon: Icons.show_chart_rounded,
                      isSelected: _selectedCategory == AssetCategory.stocks,
                      onTap: () => _selectCategory(AssetCategory.stocks),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _CategoryPill(
                      title: 'صناديق ريت',
                      icon: Icons.apartment_rounded,
                      isSelected: _selectedCategory == AssetCategory.reits,
                      onTap: () => _selectCategory(AssetCategory.reits),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _CategoryPill(
                      title: 'صناديق المؤشرات',
                      icon: Icons.pie_chart_outline_rounded,
                      isSelected: _selectedCategory == AssetCategory.etfs,
                      onTap: () => _selectCategory(AssetCategory.etfs),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeadingRow(_categoryTitle()),
                Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        _error != null ? '' : '${_filteredStocks.length} شركة',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _CircleIconButton(
                      onTap: _loading ? null : _loadInitial,
                      child: _loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primaryBlue,
                              ),
                            )
                          : const Icon(
                              Icons.refresh_rounded,
                              color: AppColors.primaryBlue,
                              size: 20,
                            ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SearchField(
              controller: _searchController,
              onClear: () {
                _searchController.clear();
                FocusScope.of(context).unfocus();
                _applyFilters();
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _FilterPill(
                          label: 'الكل',
                          isSelected: _filterType == StockFilterType.all,
                          onTap: () => _updateFilter(StockFilterType.all),
                        ),
                        const SizedBox(width: 8),
                        _FilterPill(
                          label: 'الأكثر ربحاً',
                          isSelected: _filterType == StockFilterType.gainers,
                          color: AppColors.gain,
                          onTap: () => _updateFilter(StockFilterType.gainers),
                        ),
                        const SizedBox(width: 8),
                        _FilterPill(
                          label: 'الأكثر خسارة',
                          isSelected: _filterType == StockFilterType.losers,
                          color: AppColors.loss,
                          onTap: () => _updateFilter(StockFilterType.losers),
                        ),
                        const SizedBox(width: 8),
                        _FilterPill(
                          label: 'المفضلة',
                          icon: Icons.star_rounded,
                          isSelected: _filterType == StockFilterType.favorites,
                          color: Colors.amber,
                          onTap: () => _updateFilter(StockFilterType.favorites),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _SortButton(
                  currentSort: _sortType,
                  onTap: _showSortBottomSheet,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryBlue),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(_error!, style: AppTextStyles.bodyLarge),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loadInitial,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );
    }

    if (_filteredStocks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: AppColors.border),
            const SizedBox(height: 16),
            Text(
              'لا توجد نتائج مطابقة',
              style: AppTextStyles.headingSmall
                  .copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInitial,
      color: AppColors.primaryBlue,
      child: ListView.separated(
        controller: _scrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: _filteredStocks.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == _filteredStocks.length) {
            if (!_hasMore) return const SizedBox(height: 10);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: _isLoadingMore
                    ? const CircularProgressIndicator(
                        color: AppColors.primaryBlue,
                        strokeWidth: 2.5,
                      )
                    : const SizedBox.shrink(),
              ),
            );
          }

          final stock = _filteredStocks[index];
          final isFav = _favoriteSymbols.contains(stock.symbol);

          return SlideAnimation(
            delay: Duration(milliseconds: 50 + (index.clamp(0, 10) * 30)),
            child: _StockCard(
              stock: stock,
              isFavorite: isFav,
              onTap: () => _openStockDetail(stock),
              onFavoriteToggle: () => _toggleFavorite(stock),
            ),
          );
        },
      ),
    );
  }

  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child:
                  Text('ترتيب النتائج حسب', style: AppTextStyles.headingSmall),
            ),
            _SortOption(
              label: 'الاسم (أ - ي)',
              isSelected: _sortType == StockSortType.nameAsc,
              onTap: () {
                setState(() => _sortType = StockSortType.nameAsc);
                _applyFilters();
                Navigator.pop(context);
              },
            ),
            _SortOption(
              label: 'الاسم (ي - أ)',
              isSelected: _sortType == StockSortType.nameDesc,
              onTap: () {
                setState(() => _sortType = StockSortType.nameDesc);
                _applyFilters();
                Navigator.pop(context);
              },
            ),
            _SortOption(
              label: 'السعر (الأعلى أولاً)',
              isSelected: _sortType == StockSortType.priceDesc,
              onTap: () {
                setState(() => _sortType = StockSortType.priceDesc);
                _applyFilters();
                Navigator.pop(context);
              },
            ),
            _SortOption(
              label: 'السعر (الأقل أولاً)',
              isSelected: _sortType == StockSortType.priceAsc,
              onTap: () {
                setState(() => _sortType = StockSortType.priceAsc);
                _applyFilters();
                Navigator.pop(context);
              },
            ),
            _SortOption(
              label: 'الأكثر ربحاً',
              isSelected: _sortType == StockSortType.changeDesc,
              onTap: () {
                setState(() => _sortType = StockSortType.changeDesc);
                _applyFilters();
                Navigator.pop(context);
              },
            ),
            _SortOption(
              label: 'الأكثر خسارة',
              isSelected: _sortType == StockSortType.changeAsc,
              onTap: () {
                setState(() => _sortType = StockSortType.changeAsc);
                _applyFilters();
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// --- Helper Widgets ---

class _CircleIconButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _CircleIconButton({
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFF4F6F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black.withOpacity(0.04)),
          ),
          child: IconTheme(
            data: IconThemeData(color: AppColors.textPrimary),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onClear;

  const _SearchField({required this.controller, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.isDark ? AppColors.cardLight : const Color(0xFFF4F6F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final hasText = value.text.trim().isNotEmpty;
          return TextField(
            controller: controller,
            textInputAction: TextInputAction.done,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
            textAlignVertical: TextAlignVertical.center,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              hintText: 'ابحث باسم السهم أو الرمز...',
              hintStyle: TextStyle(
                fontFamily: 'Tajawal',
                color: AppColors.textSecondary.withOpacity(0.7),
                fontSize: 14,
              ),
              prefixIcon: Icon(Icons.search_rounded,
                  color: AppColors.textSecondary),
              suffixIcon: hasText
                  ? IconButton(
                      onPressed: onClear,
                      icon: const Icon(Icons.clear_rounded, size: 18),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          );
        },
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;
  final IconData? icon;

  const _FilterPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.color = AppColors.primaryBlue,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? color : AppColors.border, width: 1),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 16,
                  color: isSelected ? Colors.white : AppColors.textSecondary),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  final StockSortType currentSort;
  final VoidCallback onTap;

  const _SortButton({required this.currentSort, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primaryBlue.withOpacity(0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primaryBlue.withOpacity(0.18)),
        ),
        child: const Icon(Icons.sort_rounded,
            color: AppColors.primaryBlue, size: 22),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.18)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryPill({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryBlue.withOpacity(0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockCard extends StatelessWidget {
  final StockModel stock;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;

  const _StockCard({
    required this.stock,
    required this.isFavorite,
    required this.onTap,
    required this.onFavoriteToggle,
  });

  static const String _currency = 'ج.م';

  bool _isSvg(String url) => url.toLowerCase().contains('.svg');

  String _fmtEgp(double v) {
    final n = Formatters.formatNumber(v);
    return '$n $_currency';
  }

  String _secondaryLabel() {
    final symbol = stock.symbol.trim();
    final id = stock.id.trim();
    if (symbol.isEmpty) {
      return id;
    }
    if (id.isEmpty) {
      return symbol;
    }

    final normalizedSymbol = symbol.toLowerCase();
    final normalizedId = id.toLowerCase();
    final symbolTail = normalizedSymbol.contains(':')
        ? normalizedSymbol.split(':').last
        : normalizedSymbol;

    if (normalizedSymbol == normalizedId || symbolTail == normalizedId) {
      return symbol;
    }

    return '$symbol • $id';
  }

  Widget _fallbackAvatar() {
    final txt = stock.symbol.isNotEmpty
        ? (stock.symbol.length > 2
            ? stock.symbol.substring(0, 2)
            : stock.symbol)
        : (stock.id.length > 2 ? stock.id.substring(0, 2) : stock.id);

    return Center(
      child: Text(
        txt,
        style: const TextStyle(
          fontFamily: 'Tajawal',
          fontWeight: FontWeight.w900,
          color: AppColors.primaryBlue,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _logoWidget() {
    final url = stock.selfLogo?.trim();
    if (url == null || url.isEmpty) return _fallbackAvatar();

    if (_isSvg(url)) {
      return SvgPicture.network(
        url,
        fit: BoxFit.cover,
        placeholderBuilder: (_) => const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.primaryBlue),
          ),
        ),
      );
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _fallbackAvatar(),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.primaryBlue),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isGain = stock.changePercent >= 0;
    final color = isGain ? AppColors.gain : AppColors.loss;
    final sign = isGain ? '+' : '';

    final screenW = MediaQuery.of(context).size.width;
    final double priceColMaxW = screenW < 360 ? 112 : 140;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _logoWidget(),
                    ),
                    const SizedBox(width: 12),

                    // Name & Badges
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stock.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            softWrap: true,
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  _secondaryLabel(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary.withOpacity(0.8),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              if (stock.isReit) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0D9488).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'ريت',
                                    style: TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0D9488),
                                    ),
                                  ),
                                ),
                              ] else if (stock.isEtf) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF7C3AED).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'ETF',
                                    style: TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF7C3AED),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Price Column
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: priceColMaxW),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _fmtEgp(stock.price),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyLarge
                                .copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$sign${stock.changePercent.toStringAsFixed(2)}%',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    IconButton(
                      onPressed: onFavoriteToggle,
                      icon: Icon(
                        isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                        color: isFavorite ? Colors.amber : AppColors.border,
                        size: 26,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),

                // Bid / Ask Spreads row if available
                if (stock.bid != null && stock.ask != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.black.withOpacity(0.04)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              'شراء: ',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              stock.bid!.toStringAsFixed(2),
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.gain,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'بيع: ',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              stock.ask!.toStringAsFixed(2),
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.loss,
                              ),
                            ),
                          ],
                        ),
                        if (stock.spread != null)
                          Text(
                            'الفارق: ${stock.spread!.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 10.5,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SortOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SortOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Text(
        label,
        style: TextStyle(
          fontFamily: 'Tajawal',
          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
          color: isSelected ? AppColors.primaryBlue : AppColors.textPrimary,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: AppColors.primaryBlue)
          : null,
    );
  }
}
