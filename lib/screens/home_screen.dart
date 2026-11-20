import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../core/models/market_index_model.dart';
import '../core/models/market_status_model.dart';
import '../core/models/stock_model.dart';
import '../core/services/stock_service.dart';
import '../core/services/translation_service.dart';
import '../core/services/favorites_service.dart';
import '../core/services/live_socket_service.dart';
import '../core/utils/formatters.dart';
import '../providers/app_manager_provider.dart';
import '../widgets/sparkline_chart_widget.dart';
import 'stock_detail_screen.dart';
import 'stock_comparison_screen.dart';
import 'currency_converter_screen.dart';
import '../widgets/triangle_arrow.dart';
import '../widgets/chevron_left_icon.dart';

class HomeScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;
  final int allStocksTabIndex;
  final int favoritesTabIndex;
  final int? indicesTabIndex;

  const HomeScreen({
    super.key,
    this.onNavigateToTab,
    this.allStocksTabIndex = 1,
    this.favoritesTabIndex = 3,
    this.indicesTabIndex = 2,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<MarketIndexModel> _marketIndices = <MarketIndexModel>[];
  List<StockModel> _allStocks = <StockModel>[];
  List<StockModel> _gainers = <StockModel>[];
  List<StockModel> _losers = <StockModel>[];
  List<StockModel> _favoriteStocks = <StockModel>[];

  bool _loading = true;
  String? _error;
  bool _showGainers = true; // Toggle between الأكثر ارتفاعاً / الأكثر انخفاضاً

  VoidCallback? _favListener;
  Timer? _favDebounce;
  StreamSubscription<LiveQuoteUpdate>? _socketSub;

  @override
  void initState() {
    super.initState();

    _favListener = () {
      _favDebounce?.cancel();
      _favDebounce = Timer(const Duration(milliseconds: 100), () {
        _loadFavorites();
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

    for (int i = 0; i < _gainers.length; i++) {
      if (_gainers[i].canUseWebSocket &&
          (_gainers[i].symbol == update.symbol ||
              _gainers[i].id == update.symbol ||
              _gainers[i].symbol.endsWith(':${update.symbol}'))) {
        _gainers[i] = _gainers[i].applyLiveUpdate(update);
        changed = true;
      }
    }

    for (int i = 0; i < _losers.length; i++) {
      if (_losers[i].canUseWebSocket &&
          (_losers[i].symbol == update.symbol ||
              _losers[i].id == update.symbol ||
              _losers[i].symbol.endsWith(':${update.symbol}'))) {
        _losers[i] = _losers[i].applyLiveUpdate(update);
        changed = true;
      }
    }

    for (int i = 0; i < _favoriteStocks.length; i++) {
      if (_favoriteStocks[i].canUseWebSocket &&
          (_favoriteStocks[i].symbol == update.symbol ||
              _favoriteStocks[i].id == update.symbol ||
              _favoriteStocks[i].symbol.endsWith(':${update.symbol}'))) {
        _favoriteStocks[i] = _favoriteStocks[i].applyLiveUpdate(update);
        changed = true;
      }
    }

    if (changed) {
      setState(() {});
    }
  }

  Future<void> _loadFavorites() async {
    try {
      final favoriteSymbols = await FavoritesService.getFavorites();
      if (favoriteSymbols.isEmpty) {
        if (mounted) setState(() => _favoriteStocks = []);
        return;
      }

      var favStocks = await StockService.getBySymbols(
        favoriteSymbols.take(4).toList(),
      );
      favStocks = await StockService.attachArabicNames(favStocks);

      if (mounted) {
        setState(() => _favoriteStocks = favStocks);
      }
    } catch (_) {}
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final indicesFuture = StockService.getMarketIndices(forceRefresh: true);
      final allStocksFuture =
          StockService.getStocksList(perPage: 500, page: 1, forceRefresh: true);
      final favFuture = FavoritesService.getFavorites();

      final results = await Future.wait([
        indicesFuture,
        allStocksFuture,
        favFuture,
      ]);

      var indices = results[0] as List<MarketIndexModel>;
      var allStocks = results[1] as List<StockModel>;
      final favSymbols = (results[2] as List<String>).toSet();

      // Separate gainers and losers (price > 0 to avoid zero-price anomalies)
      final gainers = allStocks.where((s) => s.price > 0 && s.changePercent > 0).toList()
        ..sort((a, b) => b.changePercent.compareTo(a.changePercent));
      final losers = allStocks.where((s) => s.price > 0 && s.changePercent < 0).toList()
        ..sort((a, b) => a.changePercent.compareTo(b.changePercent));

      List<StockModel> favStocks = [];
      if (favSymbols.isNotEmpty) {
        favStocks = await StockService.getBySymbols(
          favSymbols.take(4).toList(),
        );
        favStocks = await StockService.attachArabicNames(favStocks);
      }

      if (!mounted) return;

      setState(() {
        _marketIndices = indices;
        _allStocks = allStocks;
        _gainers = gainers;
        _losers = losers;
        _favoriteStocks = favStocks;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل بيانات السوق';
      });
    }
  }

  static String _formatPillPercent(double percent) {
    if (percent == 0) return '0.00%';
    final absVal = percent.abs().toStringAsFixed(2);
    final sign = percent > 0 ? '+' : '-';
    return '$sign$absVal%';
  }

  static String _formatWithCommas(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    final whole = parts[0];
    final dec = parts[1];
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final formattedWhole = whole.replaceAllMapped(reg, (Match m) => '${m[1]},');
    return '$formattedWhole.$dec';
  }

  // --- Mock curve data for EGX 30 sparkline ---
  List<double> _getSparklinePoints(MarketIndexModel? index) {
    if (index == null) {
      return [50, 48, 49, 45, 42, 40, 38, 35, 30, 28, 25];
    }
    final isGain = index.changePercent >= 0;
    if (isGain) {
      return [30, 32, 31, 35, 38, 40, 42, 45, 48, 52, 55];
    } else {
      return [55, 52, 50, 48, 45, 42, 40, 36, 34, 30, 28];
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch manager so dynamic Arabic index/stock names update immediately when loaded
    context.watch<AppManagerProvider>();

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFC1121F),
        ),
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
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF4B5563),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC1121F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('إعادة المحاولة', style: TextStyle(fontFamily: 'Tajawal')),
            ),
          ],
        ),
      );
    }

    // Index resolution (EGX30 only per specification)
    MarketIndexModel? egx30;

    for (final idx in _marketIndices) {
      final sym = idx.ticker.toUpperCase();
      if (sym == 'EGX30' ||
          sym.contains('EGX 30') ||
          sym == 'CASE30' ||
          TranslationService.matchIndexSymbols('EGX30', idx.ticker)) {
        egx30 = idx;
        break;
      }
    }

    egx30 ??= _marketIndices.isNotEmpty
        ? _marketIndices.first
        : const MarketIndexModel(
            ticker: 'EGX30',
            name: 'Egyptian Exchange EGX30 Index',
            value: 50903.40,
            change: -32.90,
            changePercent: -0.06,
          );

    // Sentiment counts
    final gCount = _allStocks.where((s) => s.changePercent > 0).length;
    final lCount = _allStocks.where((s) => s.changePercent < 0).length;
    final nCount = _allStocks.where((s) => s.changePercent == 0).length;
    final totalCount = (gCount + lCount + nCount) > 0 ? (gCount + lCount + nCount) : 1;

    final isMarketOpen = MarketStatusModel.calculateCurrentStatus().isOpen;

    return RefreshIndicator(
      color: const Color(0xFFC1121F),
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // 1. Main Index Card (EGX 30)
          _buildIndicesCard(egx30, isMarketOpen),

          const SizedBox(height: 14),

          // 2. Market Sentiment Bar (صاعد / ثابت / هابط)
          _buildSentimentBar(gCount, nCount, lCount, totalCount),

          const SizedBox(height: 16),

          // 3. Quick Tools Row (مقارنة سهمين & محول العملات)
          _buildQuickToolsRow(),

          const SizedBox(height: 20),

          // 4. "أداء السوق اليوم" Section
          _buildMarketPerformanceSection(),

          const SizedBox(height: 20),

          // 5. "مفضلتك" Section
          _buildFavoritesSection(),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // --- Sub-widgets matching screenshot exactly ---

  Widget _buildIndicesCard(MarketIndexModel egx30, bool isMarketOpen) {
    final bool egx30Gain = egx30.changePercent >= 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => StockDetailScreen(stock: egx30.toStockModel()),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- EGX 30 Header (Dynamic Arabic Name from Manager + Subtitle + status) ---
                Row(
                  textDirection: TextDirection.rtl,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            egx30.displayName,
                            softWrap: true,
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            (egx30.name.trim().isNotEmpty &&
                                    egx30.name.trim() != egx30.displayName.trim())
                                ? '${egx30.name.trim()} • ${egx30.displayTicker}'
                                : egx30.displayTicker,
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isMarketOpen) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'إغلاق',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        const ChevronLeftIcon(
                          size: 18,
                          color: Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // --- EGX 30 Value + Unit & Change Pill ---
                Row(
                  textDirection: TextDirection.rtl,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Value & Unit
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          _formatWithCommas(egx30.value),
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'نقطة',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),

                    // Change Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: egx30Gain ? const Color(0xFFDCFCE7) : const Color(0xFFFDE8E8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        textDirection: TextDirection.ltr,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TriangleArrow(
                            isUp: egx30Gain,
                            color: egx30Gain ? const Color(0xFF15803D) : const Color(0xFF991B1B),
                            width: 10,
                            height: 8,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${egx30Gain ? '+' : ''}${egx30.change.toStringAsFixed(2)} (${egx30Gain ? '+' : ''}${egx30.changePercent.toStringAsFixed(2)}%)',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: egx30Gain ? const Color(0xFF15803D) : const Color(0xFF991B1B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Sparkline Chart
                SparklineChartWidget(
                  data: _getSparklinePoints(egx30),
                  isGain: egx30Gain,
                  height: 48,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSentimentBar(int gCount, int nCount, int lCount, int total) {
    final gFlex = (gCount * 100 / total).clamp(5, 90).toInt();
    final nFlex = (nCount * 100 / total).clamp(5, 90).toInt();
    final lFlex = (lCount * 100 / total).clamp(5, 90).toInt();

    return Column(
      children: [
        // Multi-color segmented bar (Red on left, Grey in middle, Green on right in RTL)
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 6,
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Expanded(
                  flex: gFlex > 0 ? gFlex : 1,
                  child: Container(color: const Color(0xFF16A34A)),
                ),
                const SizedBox(width: 2),
                Expanded(
                  flex: nFlex > 0 ? nFlex : 1,
                  child: Container(color: const Color(0xFF9CA3AF)),
                ),
                const SizedBox(width: 2),
                Expanded(
                  flex: lFlex > 0 ? lFlex : 1,
                  child: Container(color: const Color(0xFFDC2626)),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 6),

        // Labels underneath:
        // Right in RTL: ▲ صاعد (arrow before text in RTL)
        // Center: — ثابت
        // Left in RTL: ▼ هابط (arrow before text in RTL)
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          textDirection: TextDirection.rtl,
          children: [
            // Right: ▲ صاعد
            Row(
              textDirection: TextDirection.rtl,
              mainAxisSize: MainAxisSize.min,
              children: [
                TriangleArrow(
                  isUp: true,
                  color: Color(0xFF16A34A),
                  width: 10,
                  height: 8,
                ),
                SizedBox(width: 4),
                Text(
                  'صاعد',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
            // Center: — ثابت
            Text(
              '— ثابت',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
            // Left: ▼ هابط
            Row(
              textDirection: TextDirection.rtl,
              mainAxisSize: MainAxisSize.min,
              children: [
                TriangleArrow(
                  isUp: false,
                  color: Color(0xFFDC2626),
                  width: 10,
                  height: 8,
                ),
                SizedBox(width: 4),
                Text(
                  'هابط',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickToolsRow() {
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        // 1. مقارنة سهمين (Right in RTL)
        Expanded(
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StockComparisonScreen()),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFFC5C5C5),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Image.asset(
                      'assets/icons/Vec3tor (1).png',
                      width: 16,
                      height: 12,
                      color: const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'مقارنة سهمين',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Chevron pointing to the LEFT (الشمال) <
                  const ChevronLeftIcon(
                    color: Color(0xFF9CA3AF),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(width: 10),

        // 2. محول العملات (Left in RTL)
        Expanded(
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CurrencyConverterScreen()),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFFC5C5C5),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Image.asset(
                      'assets/icons/Vec3tor.png',
                      width: 11,
                      height: 16,
                      color: const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'محول العملات',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Chevron pointing to the LEFT (الشمال) <
                  const ChevronLeftIcon(
                    color: Color(0xFF9CA3AF),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMarketPerformanceSection() {
    final displayedStocks = _showGainers ? _gainers.take(3).toList() : _losers.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section Header: Right is "أداء السوق اليوم", Left is "عرض الكل <"
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          textDirection: TextDirection.rtl,
          children: [
            const Text(
              'أداء السوق اليوم',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            InkWell(
              onTap: () {
                widget.onNavigateToTab?.call(widget.allStocksTabIndex);
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                textDirection: TextDirection.rtl,
                children: [
                  Text(
                    'عرض الكل',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFC1121F),
                    ),
                  ),
                  SizedBox(width: 4),
                  // Chevron pointing to the LEFT (الشمال) <
                  ChevronLeftIcon(
                    color: Color(0xFFC1121F),
                    size: 20,
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Full-Width Unified Segmented Tab Bar (الأكثر ارتفاعاً vs الأكثر انخفاضاً)
        Container(
          height: 46,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              // الأكثر ارتفاعاً (Right tab in RTL)
              Expanded(
                child: InkWell(
                  onTap: () {
                    if (!_showGainers) setState(() => _showGainers = true);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _showGainers ? const Color(0xFFC1121F) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'الأكثر ارتفاعاً',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 13.5,
                        fontWeight: _showGainers ? FontWeight.w800 : FontWeight.w700,
                        color: _showGainers ? Colors.white : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // الأكثر انخفاضاً (Left tab in RTL)
              Expanded(
                child: InkWell(
                  onTap: () {
                    if (_showGainers) setState(() => _showGainers = false);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: !_showGainers ? const Color(0xFFC1121F) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'الأكثر انخفاضاً',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 13.5,
                        fontWeight: !_showGainers ? FontWeight.w800 : FontWeight.w700,
                        color: !_showGainers ? Colors.white : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Unified Card with Stock list items separated by hairlines
        if (displayedStocks.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Center(
              child: Text(
                'لا توجد أسهم متاحة حالياً',
                style: TextStyle(fontFamily: 'Tajawal', color: Color(0xFF6B7280)),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
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
              children: [
                for (int i = 0; i < displayedStocks.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
                  _buildStockItemRow(displayedStocks[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStockLogo(StockModel stock) {
    final url = stock.selfLogo?.trim();
    if (url == null || url.isEmpty) {
      final raw = (stock.symbol.isNotEmpty ? stock.symbol : stock.id).trim();
      final cleaned = raw.contains(':') ? raw.split(':').last.trim() : raw;
      final initials = cleaned.length >= 2 ? cleaned.substring(0, 2) : (cleaned.isNotEmpty ? cleaned : '?');
      return Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontWeight: FontWeight.w900,
            color: Color(0xFFC1121F),
            fontSize: 15,
          ),
        ),
      );
    }

    if (url.toLowerCase().contains('.svg')) {
      return SvgPicture.network(
        url,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => const Center(
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFC1121F)),
          ),
        ),
      );
    }

    return Image.network(
      url,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Center(
        child: Text(
          stock.symbol.split(':').last,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontWeight: FontWeight.w900,
            color: Color(0xFFC1121F),
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildStockItemRow(StockModel stock) {
    final isGain = stock.changePercent > 0;
    final isZero = stock.changePercent == 0;
    // Exactly matching media_1793882914942_b4a2fac7.png
    final changeBg = isZero
        ? const Color(0xFFF1F5F9)
        : (isGain ? const Color(0xFFDCFCE7) : const Color(0xFFFDE8E8));
    final changeColor = isZero
        ? const Color(0xFF64748B)
        : (isGain ? const Color(0xFF15803D) : const Color(0xFF991B1B));
    final isFav = FavoritesService.isFavoriteSync(stock.symbol);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => StockDetailScreen(stock: stock)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            // 1. Right: Company Logo Container
            Container(
              width: 44,
              height: 44,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              clipBehavior: Clip.antiAlias,
              child: _buildStockLogo(stock),
            ),

            const SizedBox(width: 12),

            // 2. Middle: Name (with full multi-line wrapping) and Symbol
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
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: Color(0xFF111827),
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stock.displaySymbol,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontWeight: FontWeight.w500,
                      fontSize: 11.5,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // 3. Price & Pill Underneath (100% matching media_1793882914942_b4a2fac7.png)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Price row: e.g. "68.00 ج.م" (68.00 on right, ج.م on left)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  textDirection: TextDirection.rtl,
                  children: [
                    Text(
                      Formatters.formatNumber(stock.price),
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Text(
                      'ج.م',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.w500,
                        fontSize: 11.5,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                // Pill under price: capsule rounded with bold solid triangle and percentage
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
                        _formatPillPercent(stock.changePercent),
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

            // 4. Far Left: Star Button & Chevron pointing LEFT (الشمال)
            const SizedBox(width: 12),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () async {
                    await FavoritesService.toggleFavorite(stock.symbol);
                    if (mounted) setState(() {});
                  },
                  borderRadius: BorderRadius.circular(50),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      isFav ? Icons.star_rounded : Icons.star_border_rounded,
                      color: isFav ? const Color(0xFFF59E0B) : const Color(0xFF9CA3AF),
                      size: 19,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // Chevron pointing to the LEFT (الشمال) <
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

  Widget _buildFavoritesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section Header: Right is "مفضلتك", Left is "عرض الكل <"
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          textDirection: TextDirection.rtl,
          children: [
            const Text(
              'مفضلتك',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            InkWell(
              onTap: () {
                widget.onNavigateToTab?.call(widget.favoritesTabIndex);
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                textDirection: TextDirection.rtl,
                children: [
                  Text(
                    'عرض الكل',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFC1121F),
                    ),
                  ),
                  SizedBox(width: 4),
                  // Chevron pointing to the LEFT (الشمال) <
                  ChevronLeftIcon(
                    color: Color(0xFFC1121F),
                    size: 20,
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        if (_favoriteStocks.isEmpty)
          InkWell(
            onTap: () {
              widget.onNavigateToTab?.call(widget.allStocksTabIndex);
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFDE68A),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      size: 22,
                      color: Color(0xFFCA8A04),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'لا توجد أسهم مفضلة',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'اضغط ☆ علي أي سهم لمتابعته هنا.',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Chevron pointing to the LEFT (الشمال) <
                  const ChevronLeftIcon(
                    color: Color(0xFF9CA3AF),
                    size: 20,
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
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
              children: [
                for (int i = 0; i < _favoriteStocks.take(2).length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
                  _buildStockItemRow(_favoriteStocks[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
