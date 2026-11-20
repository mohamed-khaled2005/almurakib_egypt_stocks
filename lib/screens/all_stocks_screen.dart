import 'dart:async';
import 'package:flutter/material.dart';

import '../core/models/stock_model.dart';
import '../core/services/stock_service.dart';
import '../core/services/favorites_service.dart';
import '../core/services/live_socket_service.dart';
import '../widgets/stock_list_item.dart';
import 'stock_detail_screen.dart';

enum StockSortType {
  nameAsc,
  nameDesc,
  priceDesc,
  priceAsc,
  changeDesc,
  changeAsc,
}

enum StockFilterType {
  all,
  gainers,
  losers,
}

enum AssetCategory {
  stocks,
  funds,
}

class AllStocksScreen extends StatefulWidget {
  const AllStocksScreen({super.key});

  @override
  State<AllStocksScreen> createState() => _AllStocksScreenState();
}

class _AllStocksScreenState extends State<AllStocksScreen> {
  final List<StockModel> _allStocks = [];
  List<StockModel> _filteredStocks = [];
  Set<String> _favoriteSymbols = {};

  bool _loading = true;
  String? _error;
  AssetCategory _selectedCategory = AssetCategory.stocks;

  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  static const int _perPage = 500;

  final TextEditingController _searchController = TextEditingController();
  StockSortType _sortType = StockSortType.nameAsc;
  StockFilterType _filterType = StockFilterType.all;

  final Map<String, String> _searchIndexCache = {};
  StreamSubscription<LiveQuoteUpdate>? _socketSub;

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
    // CRITICAL: Only Common Stocks receive WebSocket live ticks.
    if (_selectedCategory != AssetCategory.stocks) return;

    bool anyUpdated = false;

    for (int i = 0; i < _allStocks.length; i++) {
      if (_allStocks[i].canUseWebSocket &&
          (_allStocks[i].symbol == update.symbol ||
              _allStocks[i].id == update.symbol ||
              _allStocks[i].symbol.endsWith(':${update.symbol}'))) {
        _allStocks[i] = _allStocks[i].applyLiveUpdate(update);
        anyUpdated = true;
      }
    }

    if (anyUpdated) {
      for (int i = 0; i < _filteredStocks.length; i++) {
        if (_filteredStocks[i].canUseWebSocket &&
            (_filteredStocks[i].symbol == update.symbol ||
                _filteredStocks[i].id == update.symbol ||
                _filteredStocks[i].symbol.endsWith(':${update.symbol}'))) {
          _filteredStocks[i] = _filteredStocks[i].applyLiveUpdate(update);
        }
      }
      setState(() {});
    }
  }

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
        case AssetCategory.funds:
          dataFuture = StockService.getAssetsByCategory('funds');
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
    final nextPage = _page + 1;

    try {
      final more = await StockService.getStocksList(perPage: _perPage, page: nextPage);
      if (!mounted) return;

      if (more.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoadingMore = false;
        });
        return;
      }

      final existingSymbols = _allStocks.map((e) => e.symbol).toSet();
      final deduped = more.where((s) => !existingSymbols.contains(s.symbol)).toList();

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

  void _onSearchChanged() => _applyFilters();

  void _updateFilter(StockFilterType type) {
    if (_filterType == type) return;
    setState(() {
      _filterType = type;
      if (type == StockFilterType.gainers) {
        _sortType = StockSortType.changeDesc;
      } else if (type == StockFilterType.losers) {
        _sortType = StockSortType.changeAsc;
      }
    });
    _applyFilters();
  }

  String _normalizeForSearch(String input) {
    var s = input.toLowerCase();
    s = s.replaceAll(RegExp(r'[\u200E\u200F\u202A-\u202E\u2066-\u2069]'), '');
    s = s.replaceAll(RegExp(r'[\"""„‟«»‹›]'), '');
    s = s.replaceAll(RegExp(r"[\''`´]"), '');
    s = s.replaceAll(RegExp(r'[^a-z0-9\u0621-\u064A\u0660-\u0669\u06F0-\u06F9]+'), ' ');
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
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
    final tokens = normalizedQuery.split(' ').where((t) => t.trim().isNotEmpty).toList();
    if (tokens.isEmpty) return true;
    return tokens.every((t) => idx.contains(t));
  }

  void _applyFilters() {
    List<StockModel> temp = List.from(_allStocks);

    switch (_filterType) {
      case StockFilterType.gainers:
        temp = temp.where((s) => s.price > 0 && s.changePercent > 0).toList();
        break;
      case StockFilterType.losers:
        temp = temp.where((s) => s.price > 0 && s.changePercent < 0).toList();
        break;
      case StockFilterType.all:
        break;
    }

    final query = _normalizeForSearch(_searchController.text);
    if (query.isNotEmpty) {
      temp = temp.where((s) => _matchesQuery(s, query)).toList();
    }

    switch (_sortType) {
      case StockSortType.nameAsc:
        temp.sort((a, b) => a.displayName.compareTo(b.displayName));
        break;
      case StockSortType.nameDesc:
        temp.sort((a, b) => b.displayName.compareTo(a.displayName));
        break;
      case StockSortType.priceDesc:
        temp.sort((a, b) => b.price.compareTo(a.price));
        break;
      case StockSortType.priceAsc:
        temp.sort((a, b) => a.price.compareTo(b.price));
        break;
      case StockSortType.changeDesc:
        temp.sort((a, b) => b.changePercent.compareTo(a.changePercent));
        break;
      case StockSortType.changeAsc:
        temp.sort((a, b) => a.changePercent.compareTo(b.changePercent));
        break;
    }

    setState(() {
      _filteredStocks = temp;
    });
  }

  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final options = [
              {'type': StockSortType.nameAsc, 'title': 'الاسم (أ-ي)'},
              {'type': StockSortType.nameDesc, 'title': 'الاسم (ي-أ)'},
              {'type': StockSortType.priceDesc, 'title': 'السعر (الأعلى أولاً)'},
              {'type': StockSortType.priceAsc, 'title': 'السعر (الأقل أولاً)'},
              {'type': StockSortType.changeDesc, 'title': 'الأكثر ارتفاعاً'},
              {'type': StockSortType.changeAsc, 'title': 'الأكثر انخفاضاً'},
            ];

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Grey pill drag handle
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
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'ترتيب النتائج حسب',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB), indent: 16, endIndent: 16),

                    // Options list separated by Dividers
                    ...List.generate(options.length, (i) {
                      final opt = options[i];
                      final type = opt['type'] as StockSortType;
                      final title = opt['title'] as String;
                      final isSelected = _sortType == type;

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () {
                              setModalState(() {
                                _sortType = type;
                              });
                              Navigator.pop(context);
                              _applyFilters();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              child: Row(
                                textDirection: TextDirection.rtl,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    title,
                                    style: TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontSize: 15,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      color: isSelected ? const Color(0xFFC1121F) : const Color(0xFF1F2937),
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: Color(0xFFC1121F),
                                      size: 20,
                                    )
                                  else
                                    const SizedBox(width: 20),
                                ],
                              ),
                            ),
                          ),
                          if (i < options.length - 1)
                            const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB), indent: 16, endIndent: 16),
                        ],
                      );
                    }),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatCountTitle() {
    final count = _filteredStocks.length;
    if (_selectedCategory == AssetCategory.stocks) {
      return '$count شركة';
    } else {
      return '$count صندوق';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top Fixed Controls Section
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Item Count Header (e.g. 295 شركة or 1 صندوق)
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _formatCountTitle(),
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // 2. Primary 2-Segment Control (الأسهم | صناديق الاستثمار)
              Container(
                height: 48,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    _buildSegmentTab(
                      title: 'الأسهم',
                      category: AssetCategory.stocks,
                    ),
                    const SizedBox(width: 4),
                    _buildSegmentTab(
                      title: 'صناديق الاستثمار',
                      category: AssetCategory.funds,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 3. Search and Sort Row
              Row(
                textDirection: TextDirection.rtl,
                children: [
                  // Search Box (Right side in RTL)
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
                        decoration: const InputDecoration(
                          hintText: 'ابحث بأسم السهم أو الرمز',
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
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Filter/Sort Button (Far left in RTL)
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

              // 4. Secondary Filter Pills (الكل / الأكثر ارتفاعاً / الأكثر انخفاضاً)
              Row(
                textDirection: TextDirection.rtl,
                children: [
                  _buildFilterPill('الكل', StockFilterType.all),
                  const SizedBox(width: 8),
                  _buildFilterPill('الأكثر ارتفاعاً', StockFilterType.gainers),
                  const SizedBox(width: 8),
                  _buildFilterPill('الأكثر انخفاضاً', StockFilterType.losers),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),

        // List View Section
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFC1121F)),
                )
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.wifi_off_rounded, size: 48, color: Color(0xFF9CA3AF)),
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: const TextStyle(fontFamily: 'Tajawal', color: Color(0xFF4B5563)),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _loadInitial,
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC1121F)),
                            child: const Text('إعادة المحاولة', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    )
                  : _filteredStocks.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              _searchController.text.trim().isNotEmpty
                                  ? 'لا توجد نتائج مطابقة للبحث أو الفلتر'
                                  : (_selectedCategory == AssetCategory.funds
                                      ? 'لا توجد صناديق استثمار مدرجة متاحة حالياً في البورصة المصرية'
                                      : 'لا توجد نتائج مطابقة للبحث أو الفلتر'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 14,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          itemCount: _filteredStocks.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _filteredStocks.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFC1121F),
                                  ),
                                ),
                              );
                            }

                            final stock = _filteredStocks[index];
                            final isFav = _favoriteSymbols.contains(stock.symbol);

                            return StockListItem(
                              stock: stock,
                              isFavorite: isFav,
                              customBadgeText: _selectedCategory == AssetCategory.funds
                                  ? (stock.isReit ? 'ريت' : 'صندوق استثمار')
                                  : null,
                              customBadgeIcon: _selectedCategory == AssetCategory.funds
                                  ? (stock.isReit ? Icons.apartment_rounded : Icons.account_balance_rounded)
                                  : null,
                              customBadgeColor: _selectedCategory == AssetCategory.funds
                                  ? const Color(0xFF0284C7)
                                  : null,
                              customBadgeBgColor: _selectedCategory == AssetCategory.funds
                                  ? const Color(0xFFE0F2FE)
                                  : null,
                              onFavoriteTap: () async {
                                await FavoritesService.toggleFavorite(stock.symbol);
                                final favs = await FavoritesService.getFavorites();
                                if (mounted) {
                                  setState(() {
                                    _favoriteSymbols = favs.toSet();
                                  });
                                }
                              },
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => StockDetailScreen(stock: stock),
                                  ),
                                );
                              },
                            );
                          },
                        ),
        ),
      ],
    );
  }

  Widget _buildSegmentTab({
    required String title,
    required AssetCategory category,
  }) {
    final isSelected = _selectedCategory == category;

    return Expanded(
      child: InkWell(
        onTap: () => _selectCategory(category),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFC1121F) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 13.5,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterPill(String title, StockFilterType type) {
    final isSelected = _filterType == type;

    return InkWell(
      onTap: () => _updateFilter(type),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFEE2E2) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFFF87171) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? const Color(0xFFDC2626) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}
