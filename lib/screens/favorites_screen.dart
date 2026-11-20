import 'package:flutter/material.dart';

import '../core/models/stock_model.dart';
import '../core/services/favorites_service.dart';
import '../core/services/stock_service.dart';
import '../core/utils/formatters.dart';
import '../widgets/triangle_arrow.dart';
import '../widgets/chevron_left_icon.dart';
import '../widgets/stock_logo_widget.dart';
import 'stock_detail_screen.dart';

enum FavoriteSortType {
  recentlyAdded('الأحدث إضافة'),
  oldestAdded('الأقدم إضافة'),
  gainers('الأكثر ارتفاعاً'),
  losers('الأكثر انخفاضاً'),
  nameAsc('الاسم (من أ إلى ي)');

  final String label;
  const FavoriteSortType(this.label);
}

class FavoritesScreen extends StatefulWidget {
  final VoidCallback? onNavigateToStocks;

  const FavoritesScreen({
    super.key,
    this.onNavigateToStocks,
  });

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final List<StockModel> _favoriteStocks = <StockModel>[];
  final List<StockModel> _suggestedStocks = <StockModel>[];
  VoidCallback? _favoritesListener;

  bool _loading = true;
  String? _error;
  FavoriteSortType _sortType = FavoriteSortType.recentlyAdded;

  @override
  void initState() {
    super.initState();
    _favoritesListener = () {
      _loadFavorites(showLoading: false);
    };
    FavoritesService.favoritesNotifier.addListener(_favoritesListener!);
    _loadFavorites();
    _loadSuggested();
  }

  @override
  void dispose() {
    if (_favoritesListener != null) {
      FavoritesService.favoritesNotifier.removeListener(_favoritesListener!);
    }
    super.dispose();
  }

  Future<void> _loadSuggested() async {
    try {
      final list = await StockService.getStocksList(perPage: 10, page: 1);
      if (list.isNotEmpty && mounted) {
        setState(() {
          _suggestedStocks
            ..clear()
            ..addAll(list.take(3));
        });
      }
    } catch (_) {
      // Fallback suggestions matching design screenshot
      if (mounted) {
        setState(() {
          _suggestedStocks
            ..clear()
            ..addAll([
              StockModel(
                id: 'EGX:DCRC',
                symbol: 'EGX:DCRC',
                name: 'Delta Construction & Rebuilding Co',
                price: 68.00,
                change: -21.98,
                changePercent: -24.44,
              ),
              StockModel(
                id: 'EGX:ALEX',
                symbol: 'EGX:ALEX',
                name: 'Alexandria Cemet Co',
                price: 21.21,
                change: -1.27,
                changePercent: -5.65,
              ),
              StockModel(
                id: 'EGX:COMI',
                symbol: 'EGX:COMI',
                name: 'Commercial International Bank',
                price: 24.50,
                change: 0.99,
                changePercent: 4.20,
              ),
            ]);
        });
      }
    }
  }

  Future<void> _loadFavorites({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final favoriteSymbols = await FavoritesService.getFavorites();

      if (favoriteSymbols.isEmpty) {
        if (!mounted) return;
        setState(() {
          _favoriteStocks.clear();
          _loading = false;
          _error = null;
        });
        return;
      }

      var stocks = await StockService.getBySymbols(favoriteSymbols);
      stocks = await StockService.attachArabicNames(stocks);

      if (!mounted) return;
      setState(() {
        _favoriteStocks
          ..clear()
          ..addAll(stocks);
        _applySort();
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل المفضلة حالياً.';
        _loading = false;
      });
    }
  }

  void _applySort() {
    switch (_sortType) {
      case FavoriteSortType.recentlyAdded:
        // Already in order of addition
        break;
      case FavoriteSortType.oldestAdded:
        _favoriteStocks.setAll(0, _favoriteStocks.reversed.toList());
        break;
      case FavoriteSortType.gainers:
        _favoriteStocks.sort((a, b) => b.changePercent.compareTo(a.changePercent));
        break;
      case FavoriteSortType.losers:
        _favoriteStocks.sort((a, b) => a.changePercent.compareTo(b.changePercent));
        break;
      case FavoriteSortType.nameAsc:
        _favoriteStocks.sort((a, b) => a.displayName.compareTo(b.displayName));
        break;
    }
  }

  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Grey pill handle
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
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'ترتيب المفضلة',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Options
                ...FavoriteSortType.values.map((type) {
                  final isLast = type == FavoriteSortType.values.last;
                  return Column(
                    children: [
                      InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _sortType = type;
                            _applySort();
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              type.label,
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 14.5,
                                fontWeight: _sortType == type
                                    ? FontWeight.w900
                                    : FontWeight.w600,
                                color: _sortType == type
                                    ? const Color(0xFFC1121F)
                                    : const Color(0xFF1F2937),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (!isLast)
                        const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
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
  }

  Future<void> _toggleFavorite(StockModel stock) async {
    await FavoritesService.toggleFavorite(stock.symbol);
    _loadFavorites(showLoading: false);
  }

  void _openStockDetail(StockModel stock) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StockDetailScreen(stock: stock)),
    ).then((_) => _loadFavorites(showLoading: false));
  }



  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFC1121F), strokeWidth: 2),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 14,
                color: Color(0xFF4B5563),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _loadFavorites(showLoading: true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC1121F)),
              child: const Text('إعادة المحاولة', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    return _favoriteStocks.isEmpty
        ? _buildEmptyState()
        : _buildFilledState();
  }

  // ==========================================
  // FILLED STATE (Image 4)
  // ==========================================
  Widget _buildFilledState() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // Top Header Row: Count on right, Sort capsule on left
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          textDirection: TextDirection.rtl,
          children: [
            // Right: Count (e.g. 5 أسهم)
            Text(
              '${_favoriteStocks.length} أسهم',
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 16.5,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),

            // Left: Sort Capsule Button
            InkWell(
              onTap: _showSortBottomSheet,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.swap_vert_rounded,
                      size: 16,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _sortType.label,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Unified Card with Favorites List
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.01),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: List.generate(_favoriteStocks.length, (index) {
              final stock = _favoriteStocks[index];
              final isLast = index == _favoriteStocks.length - 1;

              return Column(
                children: [
                  _buildStockRow(stock: stock, isFavorite: true),
                  if (!isLast)
                    const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                ],
              );
            }),
          ),
        ),

        const SizedBox(height: 14),
      ],
    );
  }

  // ==========================================
  // EMPTY STATE (Image 3)
  // ==========================================
  Widget _buildEmptyState() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // 1. Big Empty Card at top
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.01),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Gold circle with star
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.star_rounded,
                    color: Color(0xFFD97706),
                    size: 32,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Title
              const Text(
                'لا توجد أسهم في مفضلتك',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 17.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),

              const SizedBox(height: 6),

              // Subtitle
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                textDirection: TextDirection.rtl,
                children: [
                  Text(
                    'اضغط  ',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  Icon(
                    Icons.star_border_rounded,
                    size: 16,
                    color: Color(0xFF64748B),
                  ),
                  Text(
                    '  بجانب أي سهم لتتابع سعره',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const Text(
                'وتغيره هنا في مكان واحد.',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 18),

              // Red Button: استكشاف الأسهم
              InkWell(
                onTap: widget.onNavigateToStocks,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC1121F),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'استكشاف الأسهم',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // 2. Section: أسهم للبدء بها
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          textDirection: TextDirection.rtl,
          children: [
            Text(
              'أسهم للبدء بها',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 15.5,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
            Text(
              'الأكثر تداولاً',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Suggestions Card
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.01),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: List.generate(_suggestedStocks.length, (index) {
              final stock = _suggestedStocks[index];
              final isLast = index == _suggestedStocks.length - 1;

              return Column(
                children: [
                  _buildStockRow(stock: stock, isFavorite: false),
                  if (!isLast)
                    const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                ],
              );
            }),
          ),
        ),

        const SizedBox(height: 14),
      ],
    );
  }

  // ==========================================
  // SHARED STOCK ROW (Matching Design Perfectly)
  // ==========================================
  Widget _buildStockRow({
    required StockModel stock,
    required bool isFavorite,
  }) {
    final isGain = stock.changePercent > 0;
    final isZero = stock.changePercent == 0;
    final changeColor = isZero
        ? const Color(0xFF64748B)
        : (isGain ? const Color(0xFF16A34A) : const Color(0xFFDC2626));
    final changeBg = isZero
        ? const Color(0xFFF1F5F9)
        : (isGain ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2));

    return InkWell(
      onTap: () => _openStockDetail(stock),
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

            // 2. Middle: Name & Symbol
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
                      color: Color(0xFF111827),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stock.displaySymbol,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // 3. Left: Price & Change Pill
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
                        fontSize: 14.5,
                        color: Color(0xFF111827),
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
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => _toggleFavorite(stock),
                  borderRadius: BorderRadius.circular(50),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                      color: isFavorite ? const Color(0xFFF59E0B) : const Color(0xFF9CA3AF),
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const ChevronLeftIcon(
                  color: Color(0xFF9CA3AF),
                  size: 18,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
