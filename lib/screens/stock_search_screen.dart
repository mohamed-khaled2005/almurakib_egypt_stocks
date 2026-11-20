import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/models/market_index_model.dart';
import '../core/models/stock_model.dart';
import '../core/services/favorites_service.dart';
import '../core/services/stock_service.dart';
import '../core/utils/formatters.dart';
import '../widgets/triangle_arrow.dart';
import '../widgets/chevron_left_icon.dart';
import '../widgets/chevron_right_icon.dart';
import '../widgets/stock_logo_widget.dart';
import 'stock_detail_screen.dart';

enum SearchFilterCategory {
  all('الكل'),
  stocks('أسهم'),
  indices('مؤشرات'),
  funds('صناديق');

  final String label;
  const SearchFilterCategory(this.label);
}

class StockSearchScreen extends StatefulWidget {
  final String? initialQuery;

  const StockSearchScreen({
    super.key,
    this.initialQuery,
  });

  @override
  State<StockSearchScreen> createState() => _StockSearchScreenState();
}

class _StockSearchScreenState extends State<StockSearchScreen> {
  static const String _recentSearchesKey = 'recent_stock_searches';

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<String> _recentSearches = <String>[];
  List<StockModel> _allStocks = <StockModel>[];
  List<StockModel> _allIndices = <StockModel>[];
  List<StockModel> _allFunds = <StockModel>[];

  bool _loading = true;
  SearchFilterCategory _selectedCategory = SearchFilterCategory.all;
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      _currentQuery = widget.initialQuery!;
    }

    _loadRecentSearches();
    _loadAllMarketData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // ==========================================
  // DATA LOADING & PERSISTENCE
  // ==========================================

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_recentSearchesKey) ?? <String>[];
      if (mounted) {
        setState(() {
          _recentSearches = list;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveRecentSearch(String term) async {
    final clean = term.trim();
    if (clean.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_recentSearchesKey) ?? <String>[];
      list.removeWhere((e) => e.trim().toLowerCase() == clean.toLowerCase());
      list.insert(0, clean);
      if (list.length > 10) {
        list.removeRange(10, list.length);
      }
      await prefs.setStringList(_recentSearchesKey, list);
      if (mounted) {
        setState(() {
          _recentSearches = list;
        });
      }
    } catch (_) {}
  }

  Future<void> _clearRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_recentSearchesKey);
      if (mounted) {
        setState(() {
          _recentSearches = <String>[];
        });
      }
    } catch (_) {}
  }

  Future<void> _loadAllMarketData() async {
    setState(() => _loading = true);

    try {
      final results = await Future.wait([
        StockService.getStocksList(perPage: 500).catchError((_) => <StockModel>[]),
        StockService.getMarketIndices().catchError((_) => <MarketIndexModel>[]),
        StockService.getAssetsByCategory('reits').catchError((_) => <StockModel>[]),
      ]);

      final stocks = results[0] as List<StockModel>;
      final indicesRaw = results[1] as List<MarketIndexModel>;
      final funds = results[2] as List<StockModel>;

      final indices = indicesRaw.map((idx) {
        return StockModel(
          id: idx.ticker,
          symbol: idx.ticker,
          name: idx.name,
          arabicName: idx.name,
          price: idx.value,
          change: idx.change,
          changePercent: idx.changePercent,
          type: 'index',
        );
      }).toList();

      if (mounted) {
        setState(() {
          _allStocks = stocks;
          _allIndices = indices;
          _allFunds = funds;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ==========================================
  // NORMALIZATION & SEARCH LOGIC
  // ==========================================

  String _normalizeForSearch(String input) {
    var normalized = input.toLowerCase();
    normalized = normalized.replaceAll(
      RegExp(r'[\u200E\u200F\u202A-\u202E\u2066-\u2069]'),
      '',
    );
    normalized = normalized.replaceAll(RegExp(r'["“”«»]'), '');
    normalized = normalized.replaceAll(RegExp(r"[\'`´]"), '');
    // Replace Arabic variants
    normalized = normalized.replaceAll(RegExp(r'[أإآ]'), 'ا');
    normalized = normalized.replaceAll('ة', 'ه');
    normalized = normalized.replaceAll('ى', 'ي');
    normalized = normalized.replaceAll(
      RegExp(r'[^a-z0-9\u0621-\u064A\u0660-\u0669\u06F0-\u06F9]+'),
      ' ',
    );
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized;
  }

  List<StockModel> _getFilteredResults() {
    List<StockModel> sourceList;
    switch (_selectedCategory) {
      case SearchFilterCategory.all:
        sourceList = <StockModel>[..._allStocks, ..._allIndices, ..._allFunds];
        break;
      case SearchFilterCategory.stocks:
        sourceList = _allStocks
            .where((s) => s.type.toLowerCase() == 'stock' && !s.isFund && !s.isReit && !s.isEtf)
            .toList();
        break;
      case SearchFilterCategory.indices:
        sourceList = _allIndices;
        break;
      case SearchFilterCategory.funds:
        sourceList = <StockModel>[
          ..._allFunds,
          ..._allStocks.where((s) => s.isFund || s.isReit || s.isEtf || s.type.toLowerCase() == 'fund'),
        ];
        break;
    }

    final query = _normalizeForSearch(_currentQuery);
    if (query.isEmpty) {
      return sourceList.take(30).toList();
    }

    final tokens = query.split(' ').where((t) => t.trim().isNotEmpty).toList();
    final compactQuery = query.replaceAll(' ', '');

    return sourceList.where((stock) {
      final raw = '${stock.name} ${stock.displayName} ${stock.symbol} ${stock.id}';
      final indexed = _normalizeForSearch(raw);

      if (indexed.contains(query)) return true;

      final compactIndex = indexed.replaceAll(' ', '');
      if (compactQuery.isNotEmpty && compactIndex.contains(compactQuery)) {
        return true;
      }

      return tokens.every(indexed.contains);
    }).toList();
  }

  List<StockModel> _getMostSearchedStocks() {
    // If live stocks are loaded, look for CIB and Souhag National Foods or Egyptian blue-chips
    final comi = _allStocks.firstWhere(
      (s) => s.symbol.toUpperCase().contains('COMI'),
      orElse: () => StockModel(
        id: 'COMI',
        symbol: 'EGX:COMI',
        name: 'Commercial International Bank',
        arabicName: 'البنك التجاري الدولي',
        price: 24.50,
        change: 0.99,
        changePercent: 4.20,
      ),
    );

    final snfi = _allStocks.firstWhere(
      (s) => s.symbol.toUpperCase().contains('SNFI'),
      orElse: () => StockModel(
        id: 'SNFI',
        symbol: 'EGX:SNFI',
        name: 'Souhag National Food Industries',
        arabicName: 'صناعات سوهاج الوطنية الغذائية',
        price: 10.03,
        change: -0.47,
        changePercent: -4.48,
      ),
    );

    return <StockModel>[comi, snfi];
  }

  void _onStockSelected(StockModel stock) {
    _saveRecentSearch(stock.displayName);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StockDetailScreen(stock: stock)),
    );
  }

  void _onRecentSearchTapped(String query) {
    _searchController.text = query;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: query.length),
    );
    setState(() {
      _currentQuery = query;
    });
  }

  // ==========================================
  // BUILD METHOD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final queryTrimmed = _currentQuery.trim();
    final isSearching = queryTrimmed.isNotEmpty;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFFEFEFE),
        body: SafeArea(
          child: Column(
            children: [
              // 1. Top Header with Back button and Red-bordered Search Capsule
              _buildHeader(),

              if (_loading)
                const LinearProgressIndicator(
                  color: Color(0xFFDC2626),
                  backgroundColor: Color(0xFFFEE2E2),
                  minHeight: 2,
                ),

              // 2. Body based on Search State:
              // - State 4: Query active but 0 results (Image 1)
              // - State 1: Query empty with recent searches (Image 2)
              // - State 2: Query empty with no recent searches (Image 3)
              // - State 3: Query active with matching results and filter tabs (Image 4)
              Expanded(
                child: isSearching
                    ? _buildActiveSearchResults()
                    : _buildInitialSearchState(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TOP HEADER (Pixel-Perfect Match)
  // ==========================================

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          // Back button on the right in RTL (pointing >)
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: ChevronRightIcon(
                color: Color(0xFF374151),
                size: 20,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Red-Bordered Capsule Input
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFDC2626),
                  width: 1.5,
                ),
              ),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.search_rounded,
                    color: Color(0xFFDC2626),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      autofocus: true,
                      cursorColor: const Color(0xFFDC2626),
                      cursorWidth: 2.0,
                      cursorHeight: 20.0,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: '... ابحث باسم السهم أو الرمز',
                        hintStyle: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF94A3B8),
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _currentQuery = val;
                        });
                      },
                      onSubmitted: (val) {
                        if (val.trim().isNotEmpty) {
                          _saveRecentSearch(val.trim());
                        }
                      },
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() {
                          _currentQuery = '';
                        });
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Icon(
                          Icons.close_rounded,
                          color: Color(0xFF94A3B8),
                          size: 18,
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // INITIAL STATE (Query is Empty)
  // Shows State 1 (Recent + Most Searched) OR State 2 (Empty hint)
  // ==========================================

  Widget _buildInitialSearchState() {
    if (_recentSearches.isEmpty) {
      // State 2: Image 3 (Clean initial empty state)
      return _buildEmptyInitialHint();
    }

    // State 1: Image 2 (Recent searches + Most searched)
    final mostSearched = _getMostSearchedStocks();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 14),
      children: [
        // 1. Recent Searches Section Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            textDirection: TextDirection.rtl,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'عمليات بحث حديثة',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
              InkWell(
                onTap: _clearRecentSearches,
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Text(
                    'مسح الكل',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Recent Searches Card Container
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: List.generate(_recentSearches.length, (index) {
              final term = _recentSearches[index];
              final isLast = index == _recentSearches.length - 1;

              return Column(
                children: [
                  InkWell(
                    onTap: () => _onRecentSearchTapped(term),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 18,
                            color: Color(0xFF1E293B),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              term,
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!isLast)
                    const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                ],
              );
            }),
          ),
        ),

        const SizedBox(height: 24),

        // 2. Most Searched Section Header
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'الأكثر بحثاً',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Most Searched Card Container
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: List.generate(mostSearched.length, (index) {
              final stock = mostSearched[index];
              final isLast = index == mostSearched.length - 1;

              return Column(
                children: [
                  _buildStockItemRow(stock),
                  if (!isLast)
                    const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // STATE 2: EMPTY INITIAL HINT (Image 3)
  // ==========================================

  Widget _buildEmptyInitialHint() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFE2E8F0),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.search_rounded,
                  size: 32,
                  color: Color(0xFF475569),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'ابحث عن سهم',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 17.5,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'اكتب اسم السهم أو الرمز للبحث السريع.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // ACTIVE SEARCH RESULTS (State 3 or State 4)
  // ==========================================

  Widget _buildActiveSearchResults() {
    final results = _getFilteredResults();

    return Column(
      children: [
        // Filter Tabs (الكل, أسهم, مؤشرات, صناديق)
        _buildFilterTabs(),

        // If results are empty -> State 4 (Image 1)
        // If results exist -> State 3 (Image 4)
        Expanded(
          child: results.isEmpty
              ? _buildNoResultsState()
              : _buildResultsList(results),
        ),
      ],
    );
  }

  // ==========================================
  // FILTER TABS (Image 4)
  // ==========================================

  Widget _buildFilterTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        textDirection: TextDirection.rtl,
        children: SearchFilterCategory.values.map((cat) {
          final isSelected = cat == _selectedCategory;

          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedCategory = cat;
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFFEE2E2) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFF87171)
                        : const Color(0xFFE2E8F0),
                    width: 1.0,
                  ),
                ),
                child: Text(
                  cat.label,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 13.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                    color: isSelected
                        ? const Color(0xFFDC2626)
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

  // ==========================================
  // RESULTS LIST (Image 4)
  // ==========================================

  Widget _buildResultsList(List<StockModel> results) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: List.generate(results.length, (index) {
              final stock = results[index];
              final isLast = index == results.length - 1;

              return Column(
                children: [
                  _buildStockItemRow(stock),
                  if (!isLast)
                    const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // STATE 4: NO RESULTS (Image 1)
  // ==========================================

  Widget _buildNoResultsState() {
    final queryText = _currentQuery.trim();

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFE2E8F0),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.search_rounded,
                  size: 32,
                  color: Color(0xFF475569),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'لا توجد نتائج لـ "$queryText"',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 17.5,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'تأكد من الإملاء أو جرب اسم الشركة أو رمز السهم.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // SHARED STOCK ITEM ROW (Pixel-Perfect)
  // ==========================================

  Widget _buildStockItemRow(StockModel stock) {
    final isGain = stock.changePercent > 0;
    final isZero = stock.changePercent == 0;
    final changeColor = isZero
        ? const Color(0xFF64748B)
        : (isGain ? const Color(0xFF16A34A) : const Color(0xFFDC2626));
    final changeBg = isZero
        ? const Color(0xFFF1F5F9)
        : (isGain ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2));

    final tickerLabel = stock.displaySymbol;

    return InkWell(
      onTap: () => _onStockSelected(stock),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            // 1. Right: Company Logo Container
            StockLogoWidget(
              stock: stock,
              size: 44,
              borderRadius: 10,
            ),

            const SizedBox(width: 12),

            // 2. Middle: Name & Ticker
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    stock.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: Color(0xFF1E293B),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tickerLabel,
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

            // 3. Price & Change Pill
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      Formatters.formatNumber(stock.price),
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Text(
                      'ج.م',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                // Pill under price: capsule rounded with bold solid triangle and percentage (e.g. 5.06%-)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
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
                          width: 10,
                          height: 8,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        Formatters.formatPillPercent(stock.changePercent),
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: changeColor,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(width: 10),

            // 4. Far Left: Star icon & chevron pointing strictly LEFT
            ValueListenableBuilder<Set<String>>(
              valueListenable: FavoritesService.favoritesNotifier,
              builder: (context, favorites, _) {
                final isFavorite = favorites.contains(stock.symbol.trim().toUpperCase());

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => FavoritesService.toggleFavorite(stock.symbol),
                      borderRadius: BorderRadius.circular(50),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                          color: isFavorite
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF94A3B8),
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const ChevronLeftIcon(
                      color: Color(0xFF94A3B8),
                      size: 18,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

}
