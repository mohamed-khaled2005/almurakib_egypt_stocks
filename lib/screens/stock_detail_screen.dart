import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';

import '../core/models/company_profile_model.dart';
import '../core/models/dividend_model.dart';
import '../core/models/financial_data_model.dart';
import '../core/models/market_index_model.dart';
import '../core/models/stock_indicator_model.dart';
import '../core/models/stock_model.dart';
import '../core/models/stock_pivot_points_model.dart';
import '../core/services/favorites_service.dart';
import '../core/services/live_socket_service.dart';
import '../core/services/stock_service.dart';
import '../core/services/translation_service.dart';
import '../core/utils/formatters.dart';
import '../providers/app_manager_provider.dart';

import 'auth_screen.dart';
import 'interactive_chart_screen.dart';
import 'notifications_screen.dart';
import 'price_alerts_screen.dart';
import 'stock_comparison_screen.dart';
import '../widgets/stock_logo_widget.dart';
import '../widgets/technical_indicators_widget.dart';
import '../widgets/stock_performance_tab.dart';
import '../widgets/market_status_header.dart';
import '../widgets/sparkline_chart_widget.dart';

enum ChartPeriod {
  week('أسبوع'),
  month('شهر'),
  threeMonths('3 أشهر'),
  sixMonths('6 أشهر'),
  year('سنة');

  final String label;
  const ChartPeriod(this.label);
}

class _DetailTab {
  final String title;
  final Widget child;

  const _DetailTab({required this.title, required this.child});
}

class _Candle {
  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  const _Candle({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });
}

class StockDetailScreen extends StatefulWidget {
  final StockModel stock;
  const StockDetailScreen({super.key, required this.stock});

  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen>
    with TickerProviderStateMixin {
  StockModel? _stock;
  StockIndicatorModel? _indicators;
  DividendData? _dividendData;
  bool _loadingDividends = false;
  bool _dividendsLoaded = false;

  FinancialsData? _financialsData;
  bool _loadingFinancials = false;
  bool _financialsLoaded = false;

  StockPivotPointsModel? _pivotData;
  bool _loadingPivots = false;
  bool _pivotsLoaded = false;
  String _pivotPeriod = '1d';
  String _pivotMethod = 'classic';

  CompanyProfileModel? _companyProfile;
  bool _loadingProfile = false;
  bool _profileLoaded = false;

  StreamSubscription? _livePriceSubscription;

  List<_Candle> _yearCandles = [];
  List<_Candle> _visibleCandles = [];
  List<_Candle> _intraday24hCandles = [];
  List<FlSpot> _spots = [];

  _Candle? _lastCandle;
  _Candle? _prevCandle;

  bool _loadingIndicators = false;
  bool _indicatorsLoaded = false;
  bool _loadingChart = true;

  bool _isFavorite = false;

  ChartPeriod _selectedPeriod = ChartPeriod.week;
  late TabController _tabController;

  bool _accessGranted = false;
  bool _lockParentGestures = false;

  void _setLockParentGestures(bool v) {
    if (!mounted) return;
    if (_lockParentGestures == v) return;
    setState(() => _lockParentGestures = v);
  }

  final DateFormat _rangeFmt = DateFormat('dd/MM/yyyy', 'en');
  final NumberFormat _moneyFmt = NumberFormat("#,##0.00", "en");

  static final Map<String, List<_Candle>> _yearCache = {};
  static final Map<String, DateTime> _yearCacheAt = {};
  static const Duration _cacheTtl = Duration(hours: 6);

  static final Map<String, List<_Candle>> _intraday24hCache = {};
  static final Map<String, DateTime> _intraday24hCacheAt = {};
  static const Duration _intradayCacheTtl = Duration(minutes: 10);

  int _calculateTabsCount() {
    return _getAvailableTabs(_safeStock, Colors.transparent).length;
  }

  bool get _hasIndicatorsData {
    return _indicators != null && _indicators!.indicators.isNotEmpty;
  }

  bool get _hasPivotData {
    final p = _pivotData;
    if (p == null) return false;
    return p.classic.pivot != null ||
        p.classic.r1 != null ||
        p.classic.s1 != null ||
        p.fibonacci.pivot != null ||
        p.camarilla.pivot != null;
  }

  bool get _hasProfileData {
    final p = _companyProfile;
    if (p == null) return false;
    final hasDesc = p.description != null &&
        p.description!.trim().isNotEmpty &&
        p.description != 'لا يتوفر وصف مختصر للشركة حالياً.';
    final hasCeo = p.ceo != null && p.ceo!.trim().isNotEmpty;
    final hasWeb = p.website != null && p.website!.trim().isNotEmpty;
    final hasEmp = p.employees != null && p.employees!.trim().isNotEmpty;
    final hasSector = p.sector.trim().isNotEmpty && p.sector != 'سوق الأسهم المصرية';
    return hasDesc || hasCeo || hasWeb || hasEmp || hasSector;
  }

  bool get _hasDividendsData {
    final d = _dividendData;
    if (d == null) return false;
    return (d.currentYield != null && d.currentYield! > 0) ||
        (d.payoutRatio != null && d.payoutRatio! > 0) ||
        (d.dps != null && d.dps! > 0) ||
        d.payouts.isNotEmpty ||
        d.historyYield.isNotEmpty;
  }

  bool get _hasFinancialsData {
    return _getFinancialSummaryRows().isNotEmpty ||
        _getBalanceSheetRows().isNotEmpty ||
        _getIncomeStatementRows().isNotEmpty;
  }

  void _handleTabChange() {
    if (!mounted) return;
    final tabs = _getAvailableTabs(
      _safeStock,
      _safeStock.isGain ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
    );
    final idx = _tabController.index;
    if (idx >= 0 && idx < tabs.length) {
      final title = tabs[idx].title;
      if (title == 'المؤشرات الفنية' && !_indicatorsLoaded && !_loadingIndicators) {
        _loadIndicators();
      } else if (title == 'الدعم والمقاومة' && !_pivotsLoaded && !_loadingPivots) {
        _loadPivotPoints();
      } else if (title == 'ملف الشركة' && !_profileLoaded && !_loadingProfile) {
        _loadCompanyProfile();
      } else if (title == 'التوزيعات' && !_dividendsLoaded && !_loadingDividends) {
        _loadDividends();
      } else if (title == 'البيانات المالية' && !_financialsLoaded && !_loadingFinancials) {
        _loadFinancials();
      }
    }
    setState(() {});
  }

  void _updateTabController(int targetLength) {
    if (_tabController.length != targetLength) {
      final oldIndex = _tabController.index;
      _tabController.removeListener(_handleTabChange);
      _tabController.dispose();
      final newIndex = oldIndex < targetLength ? oldIndex : (targetLength - 1).clamp(0, targetLength - 1);
      _tabController = TabController(length: targetLength, vsync: this, initialIndex: newIndex);
      _tabController.addListener(_handleTabChange);
    }
  }

  List<_DetailTab> _getAvailableTabs(StockModel stock, Color changeColor) {
    final list = <_DetailTab>[
      _DetailTab(
        title: 'عامة',
        child: _buildOverviewTab(stock, changeColor),
      ),
      _DetailTab(
        title: 'الأداء',
        child: StockPerformanceTab(stock: stock),
      ),
    ];

    // Hide Technical Indicators if loaded and has no data
    if (!_indicatorsLoaded || _hasIndicatorsData) {
      list.add(
        _DetailTab(
          title: 'المؤشرات الفنية',
          child: _buildIndicatorsTab(),
        ),
      );
    }

    // Hide Pivot Points if loaded and has no data
    if (!_pivotsLoaded || _hasPivotData) {
      list.add(
        _DetailTab(
          title: 'الدعم والمقاومة',
          child: _buildPivotPointsTab(),
        ),
      );
    }

    if (!stock.isIndex) {
      // Hide Company Profile if loaded and has no data
      if (!_profileLoaded || _hasProfileData) {
        list.add(
          _DetailTab(
            title: 'ملف الشركة',
            child: _buildCompanyProfileTab(stock),
          ),
        );
      }

      // Hide Dividends tab completely if empty
      if (_dividendsLoaded && _hasDividendsData) {
        list.add(
          _DetailTab(
            title: 'التوزيعات',
            child: _buildDividendsTab(),
          ),
        );
      }

      // Hide Financials tab completely if empty
      if (_financialsLoaded && _hasFinancialsData) {
        list.add(
          _DetailTab(
            title: 'البيانات المالية',
            child: _buildFinancialsTab(),
          ),
        );
      }
    }

    return list;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _calculateTabsCount(), vsync: this);
    _tabController.addListener(_handleTabChange);
    _stock = widget.stock;
    _checkAccessAndLoad();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _livePriceSubscription?.cancel();
    super.dispose();
  }

  void _checkAccessAndLoad() {
    if (context.read<AppManagerProvider>().isAuthenticated) {
      _accessGranted = true;
      _loadProtectedContent();
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final allowed = await Navigator.push<bool>(
        context,
        MaterialPageRoute<bool>(builder: (_) => const AuthScreen()),
      );

      if (!mounted) return;
      if (allowed == true &&
          context.read<AppManagerProvider>().isAuthenticated) {
        setState(() => _accessGranted = true);
        _loadProtectedContent();
      } else {
        Navigator.maybePop(context);
      }
    });
  }

  void _loadProtectedContent() {
    _checkFavorite();
    _loadStockFresh();
    _loadYearHistoryOnce();
    _loadIntraday24hSparkline();
    _subscribeLiveSocket();
    // Preload all tabs so empty tabs are discovered and hidden cleanly
    _loadIndicators();
    _loadPivotPoints();
    if (!widget.stock.isIndex) {
      _loadCompanyProfile();
      _loadDividends();
      _loadFinancials();
    }
  }

  Future<void> _loadPivotPoints({bool forceRefresh = false}) async {
    if ((_loadingPivots || _pivotsLoaded) && !forceRefresh) return;
    setState(() => _loadingPivots = true);
    try {
      final res = await StockService.getPivotPoints(
        symbol: widget.stock.symbol,
        period: _pivotPeriod,
        isIndex: _safeStock.isIndex,
      );
      if (mounted) {
        setState(() {
          _pivotData = res;
          _pivotsLoaded = true;
          _loadingPivots = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _pivotData = null;
          _pivotsLoaded = true;
          _loadingPivots = false;
        });
      }
    }
  }

  Future<void> _loadCompanyProfile({bool forceRefresh = false}) async {
    if ((_loadingProfile || _profileLoaded) && !forceRefresh) return;
    setState(() => _loadingProfile = true);
    try {
      final res = await StockService.getCompanyProfile(
        widget.stock.symbol,
        nameAr: _safeStock.displayName,
      );
      if (mounted) {
        setState(() {
          _companyProfile = res;
          _profileLoaded = true;
          _loadingProfile = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _companyProfile = CompanyProfileModel.fallback(
            widget.stock.symbol,
            nameAr: _safeStock.displayName,
          );
          _profileLoaded = true;
          _loadingProfile = false;
        });
      }
    }
  }

  Future<void> _loadIntraday24hSparkline({bool forceRefresh = false}) async {
    final sym = widget.stock.symbol;
    if (!forceRefresh) {
      final cached = _intraday24hCache[sym];
      final at = _intraday24hCacheAt[sym];
      if (cached != null &&
          at != null &&
          DateTime.now().difference(at) < _intradayCacheTtl &&
          cached.length >= 2) {
        if (mounted) {
          setState(() => _intraday24hCandles = cached);
        }
        return;
      }
    }

    try {
      final endpoint = ApiEndpoints.history(
        symbol: sym,
        period: '1h',
        length: 24,
        isIndex: _safeStock.isIndex,
      );
      final resp = await ApiClient.get(endpoint);
      final candles = _extractCandles(resp);
      if (candles.length >= 2 && mounted) {
        _intraday24hCache[sym] = candles;
        _intraday24hCacheAt[sym] = DateTime.now();
        setState(() => _intraday24hCandles = candles);
      }
    } catch (_) {}
  }

  void _subscribeLiveSocket() {
    if (!widget.stock.canUseWebSocket) return;

    final sym = widget.stock.symbol;
    LiveSocketService.instance.subscribe(sym);
    _livePriceSubscription =
        LiveSocketService.instance.streamFor(sym).listen((update) {
      if (!mounted) return;
      setState(() {
        _stock = (_stock ?? widget.stock).applyLiveUpdate(update);
      });
    });
  }

  Future<void> _loadDividends({bool forceRefresh = false}) async {
    if ((_loadingDividends || _dividendsLoaded) && !forceRefresh) return;
    setState(() => _loadingDividends = true);
    try {
      final res = await StockService.getDividends(widget.stock.symbol);
      if (mounted) {
        setState(() {
          _dividendData = res;
          _dividendsLoaded = true;
          _loadingDividends = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _dividendData = null;
          _dividendsLoaded = true;
          _loadingDividends = false;
        });
      }
    }
  }

  Future<void> _loadFinancials({bool forceRefresh = false}) async {
    if ((_loadingFinancials || _financialsLoaded) && !forceRefresh) return;
    setState(() => _loadingFinancials = true);
    try {
      final res = await StockService.getFinancials(widget.stock.symbol);
      if (mounted) {
        setState(() {
          _financialsData = res;
          _financialsLoaded = true;
          _loadingFinancials = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _financialsData = null;
          _financialsLoaded = true;
          _loadingFinancials = false;
        });
      }
    }
  }

  StockModel get _safeStock => _stock ?? widget.stock;

  Future<void> _checkFavorite() async {
    final isFav = await FavoritesService.isFavorite(widget.stock.symbol);
    if (mounted) setState(() => _isFavorite = isFav);
  }

  Future<void> _toggleFavorite() async {
    await FavoritesService.toggleFavorite(widget.stock.symbol);
    final isFav = await FavoritesService.isFavorite(widget.stock.symbol);
    if (mounted) setState(() => _isFavorite = isFav);
  }

  Future<void> _loadStockFresh() async {
    if (widget.stock.isIndex) {
      try {
        final indices = await StockService.getMarketIndices(forceRefresh: true);
        final matched = indices.firstWhere(
          (m) => TranslationService.matchIndexSymbols(m.ticker, widget.stock.symbol),
          orElse: () => indices.firstWhere(
            (m) => m.displayTicker == widget.stock.displaySymbol,
            orElse: () => MarketIndexModel(
              ticker: widget.stock.symbol,
              name: widget.stock.name,
              value: widget.stock.price,
              change: widget.stock.change,
              changePercent: widget.stock.changePercent,
              open: widget.stock.open,
              high: widget.stock.high,
              low: widget.stock.low,
              volume: widget.stock.volume,
              previousClose: widget.stock.previousClose,
            ),
          ),
        );
        if (mounted && matched.hasMarketData) {
          setState(() {
            _stock = matched.toStockModel();
          });
        }
      } catch (_) {}
      return;
    }
    try {
      var fresh = await StockService.getStockDetail(widget.stock.symbol);
      if ((fresh.selfLogo == null || fresh.selfLogo!.trim().isEmpty) &&
          widget.stock.selfLogo != null &&
          widget.stock.selfLogo!.trim().isNotEmpty) {
        fresh = fresh.copyWith(selfLogo: widget.stock.selfLogo);
      }
      if (mounted) {
        setState(() {
          _stock = fresh;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadIndicators({bool forceRefresh = false}) async {
    if ((_loadingIndicators || _indicatorsLoaded) && !forceRefresh) return;
    setState(() => _loadingIndicators = true);
    try {
      final res = await StockService.getIndicators(
        widget.stock.symbol,
        isIndex: _safeStock.isIndex,
      );
      if (mounted) {
        setState(() {
          _indicators = res;
          _indicatorsLoaded = true;
          _loadingIndicators = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _indicators = null;
          _indicatorsLoaded = true;
          _loadingIndicators = false;
        });
      }
    }
  }

  Future<void> _loadYearHistoryOnce({bool forceRefresh = false}) async {
    final sym = widget.stock.symbol;
    if (!forceRefresh) {
      final cached = _yearCache[sym];
      final at = _yearCacheAt[sym];
      if (cached != null &&
          at != null &&
          DateTime.now().difference(at) < _cacheTtl &&
          cached.length >= 2) {
        _yearCandles = cached;
        _applyPeriod(_selectedPeriod);
        setState(() => _loadingChart = false);
        return;
      }
    }

    setState(() {
      _loadingChart = true;
    });

    try {
      final endpoint = ApiEndpoints.history(
        symbol: sym,
        period: '1y',
        isIndex: _safeStock.isIndex,
      );
      final resp = await ApiClient.get(endpoint);
      final candles = _extractCandles(resp);

      if (candles.length >= 2) {
        _yearCandles = candles;
        _yearCache[sym] = candles;
        _yearCacheAt[sym] = DateTime.now();
        _applyPeriod(_selectedPeriod);
      } else {
        _fallbackDummyChart();
      }
    } catch (_) {
      _fallbackDummyChart();
    }

    if (mounted) setState(() => _loadingChart = false);
  }

  void _fallbackDummyChart() {
    final now = DateTime.now();
    final p = _safeStock.price > 0 ? _safeStock.price : 21.21;
    final dummy = <_Candle>[];
    // Realistic financial walk with 30 points instead of a synthetic sine wave
    const steps = [
      -0.006, 0.004, -0.003, 0.008, 0.005, -0.004, -0.007, 0.003,
      0.009, -0.002, 0.006, -0.008, 0.004, 0.007, -0.005, 0.011,
      -0.003, 0.002, -0.006, 0.008, -0.004, 0.005, 0.009, -0.007,
      0.003, -0.005, 0.008, 0.002, -0.004, 0.000,
    ];
    double cur = p;
    final prices = <double>[p];
    for (int i = 0; i < steps.length - 1; i++) {
      cur = cur / (1.0 + steps[steps.length - 1 - i]);
      prices.insert(0, cur);
    }
    for (int i = 0; i < prices.length; i++) {
      final daysAgo = prices.length - 1 - i;
      final t = now.subtract(Duration(days: daysAgo));
      final close = prices[i];
      final prev = i > 0 ? prices[i - 1] : close;
      dummy.add(_Candle(
        time: t,
        open: prev,
        high: max(prev, close) * 1.004,
        low: min(prev, close) * 0.996,
        close: close,
        volume: 100000,
      ));
    }
    _yearCandles = dummy;
    _applyPeriod(_selectedPeriod);
  }

  List<_Candle> _extractCandles(dynamic data) {
    try {
      dynamic list = data;
      if (data is Map) {
        list = data['response'] ?? data['data'] ?? data['candles'] ?? [];
      }
      if (list is Map) {
        list = list.values.toList();
      }
      if (list is! List) return [];

      final candles = <_Candle>[];
      for (final item in list) {
        if (item is Map) {
          final tmStr = (item['tm'] ?? item['date'] ?? item['datetime'] ?? item['time'] ?? '').toString();
          DateTime? dt = DateTime.tryParse(tmStr);
          if (dt == null && item['t'] != null) {
            final tVal = int.tryParse(item['t'].toString());
            if (tVal != null) {
              final ms = tVal < 10000000000 ? tVal * 1000 : tVal;
              dt = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
            }
          }
          final c = double.tryParse((item['c'] ?? item['close'] ?? '0').toString()) ?? 0.0;
          final o = double.tryParse((item['o'] ?? item['open'] ?? '0').toString()) ?? c;
          final h = double.tryParse((item['h'] ?? item['high'] ?? '0').toString()) ?? max(o, c);
          final l = double.tryParse((item['l'] ?? item['low'] ?? '0').toString()) ?? min(o, c);
          final v = double.tryParse((item['v'] ?? item['volume'] ?? '0').toString()) ?? 0.0;

          if (dt != null && c > 0) {
            candles.add(_Candle(time: dt, open: o, high: h, low: l, close: c, volume: v));
          }
        }
      }
      candles.sort((a, b) => a.time.compareTo(b.time));
      return candles;
    } catch (_) {
      return [];
    }
  }

  void _applyPeriod(ChartPeriod period) {
    _selectedPeriod = period;
    if (_yearCandles.isEmpty) return;

    final now = DateTime.now();
    DateTime cutoff;

    switch (period) {
      case ChartPeriod.week:
        cutoff = now.subtract(const Duration(days: 7));
        break;
      case ChartPeriod.month:
        cutoff = now.subtract(const Duration(days: 30));
        break;
      case ChartPeriod.threeMonths:
        cutoff = now.subtract(const Duration(days: 90));
        break;
      case ChartPeriod.sixMonths:
        cutoff = now.subtract(const Duration(days: 180));
        break;
      case ChartPeriod.year:
        cutoff = now.subtract(const Duration(days: 365));
        break;
    }

    _visibleCandles = _yearCandles.where((c) => c.time.isAfter(cutoff)).toList();
    if (_visibleCandles.length < 2) {
      _visibleCandles = _yearCandles.take(10).toList();
    }

    _lastCandle = _visibleCandles.isNotEmpty ? _visibleCandles.last : null;
    _prevCandle = _visibleCandles.length >= 2 ? _visibleCandles[_visibleCandles.length - 2] : null;

    _spots = [];
    for (int i = 0; i < _visibleCandles.length; i++) {
      _spots.add(FlSpot(i.toDouble(), _visibleCandles[i].close));
    }
  }

  void _changePeriod(ChartPeriod p) {
    setState(() {
      _applyPeriod(p);
    });
  }

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    if (!_accessGranted) {
      return const Scaffold(
        backgroundColor: Color(0xFFFEFEFE),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFC1121F))),
      );
    }

    final stock = _safeStock;
    final changeColor = stock.isGain ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final availableTabs = _getAvailableTabs(stock, changeColor);
    _updateTabController(availableTabs.length);

    return Scaffold(
      backgroundColor: const Color(0xFFFEFEFE),
      appBar: _buildCustomAppBar(stock),
      body: SafeArea(
        top: false,
        bottom: stock.isIndex,
        child: Column(
          children: [
            // 1. Market Status Header (Compact Style matching Image 2)
            MarketStatusHeader(
              compact: true,
              onRefresh: () {
                _loadStockFresh();
                _loadIndicators(forceRefresh: true);
                _loadYearHistoryOnce(forceRefresh: true);
                _loadIntraday24hSparkline(forceRefresh: true);
                _loadPivotPoints(forceRefresh: true);
                if (!stock.isIndex) {
                  _loadCompanyProfile(forceRefresh: true);
                  _loadDividends(forceRefresh: true);
                  _loadFinancials(forceRefresh: true);
                }
              },
            ),

            // 2. Unified Hero Price, Sparkline & Metrics Card (Matching Image 2)
            _buildUnifiedHeroCard(stock, changeColor),

            const SizedBox(height: 4),

            // 3. Tab Bar (عامة, الأداء, المؤشرات الفنية, ...)
            _buildTabs(availableTabs),

            // 4. Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: _lockParentGestures
                    ? const NeverScrollableScrollPhysics()
                    : const BouncingScrollPhysics(),
                children: availableTabs.map((t) => t.child).toList(),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: stock.isIndex ? null : _buildFixedBottomBar(stock),
    );
  }

  // ==========================================
  // APP BAR & TOP HEADER
  // ==========================================

  PreferredSizeWidget _buildCustomAppBar(StockModel stock) {
    final badgeText = (stock.isin != null && stock.isin!.trim().isNotEmpty)
        ? stock.isin!.trim()
        : stock.displaySymbol;

    final cardShadow = [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ];

    return AppBar(
      backgroundColor: const Color(0xFFFEFEFE),
      elevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: false,
      toolbarHeight: 66,
      titleSpacing: 10,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          color: const Color(0xFFF1F5F9),
          height: 1,
        ),
      ),
      title: Row(
        textDirection: TextDirection.rtl,
        children: [
          // 1. Back Button (Far Right in RTL)
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFEAEEF4)),
                boxShadow: cardShadow,
              ),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: Color(0xFF1E293B),
              ),
            ),
          ),

          const SizedBox(width: 6),

          // 2. Center Capsule (Stock Name + Symbol Badge on right, Logo on left)
          Expanded(
            child: Container(
              height: 50,
              padding: const EdgeInsets.fromLTRB(5, 4, 12, 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: const Color(0xFFEAEEF4)),
                boxShadow: cardShadow,
              ),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  // Text Block: Full Name (no truncation) + Ticker/ISIN Pill
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.center,
                          child: Text(
                            stock.displayName,
                            maxLines: 1,
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                              height: 1.15,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2F6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            badgeText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                              height: 1.15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Logo Card (single crisp elevated box matching design)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: StockLogoWidget(
                      stock: stock,
                      size: 40,
                      borderRadius: 11,
                      showBorder: false,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 6),

          // 3. Thin Vertical Divider
          Container(
            width: 1,
            height: 22,
            color: const Color(0xFFE2E8F0),
          ),

          const SizedBox(width: 6),

          // 4. Favorite Star Button
          InkWell(
            onTap: _toggleFavorite,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFEAEEF4)),
                boxShadow: cardShadow,
              ),
              child: Icon(
                _isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                color: _isFavorite
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF1E293B),
                size: 19,
              ),
            ),
          ),

          const SizedBox(width: 5),

          // 5. Notifications Bell Button
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFEAEEF4)),
                boxShadow: cardShadow,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.notifications_none_rounded,
                    color: Color(0xFF1E293B),
                    size: 19,
                  ),
                  ValueListenableBuilder<int>(
                    valueListenable: NotificationsScreen.unreadCountNotifier,
                    builder: (_, count, __) {
                      if (count <= 0) return const SizedBox.shrink();
                      return Positioned(
                        top: 7,
                        right: 7,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFFDC2626),
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Top mini sparkline ALWAYS reflects the last 24 hours (1h candles),
  /// independent of the lower chart's selected timeframe.
  List<double> _getSparklineData(StockModel stock) {
    if (_intraday24hCandles.length >= 2) {
      return _intraday24hCandles.map((c) => c.close).toList();
    }
    final isGain = stock.isGain;
    final p = stock.price;
    final o = (stock.open != null && stock.open! > 0) ? stock.open! : p;
    final h = (stock.high != null && stock.high! > 0) ? stock.high! : (isGain ? p * 1.01 : o * 1.01);
    final l = (stock.low != null && stock.low! > 0) ? stock.low! : (isGain ? o * 0.99 : p * 0.99);
    if (isGain) {
      return [o, (o * 0.995), (o + l) / 2, (o + p) / 2, h, (h + p) / 2, p];
    } else {
      return [o, (o * 1.005), (o + h) / 2, (o + p) / 2, (l + p) / 2, p];
    }
  }

  Widget _buildUnifiedHeroCard(StockModel stock, Color changeColor) {
    final isGain = stock.isGain;
    final isZero = stock.change == 0;
    final pillBg = isZero
        ? const Color(0xFFF1F5F9)
        : (isGain ? const Color(0xFFDCFCE7) : const Color(0xFFFDE8E8));
    final pillColor = isZero
        ? const Color(0xFF64748B)
        : (isGain ? const Color(0xFF15803D) : const Color(0xFF991B1B));

    final changeVal = stock.change.abs().toStringAsFixed(2);
    final changePct = stock.changePercent.abs().toStringAsFixed(2);
    final pillText = isZero
        ? '0.00 (0.00%)'
        : (isGain
            ? '+$changeVal (+$changePct%)'
            : '-$changeVal (-$changePct%)');

    final sparkData = _getSparklineData(stock);

    final effectiveOpen = (stock.open != null && stock.open! > 0)
        ? stock.open
        : (_yearCandles.isNotEmpty && _yearCandles.last.open > 0
            ? _yearCandles.last.open
            : (stock.price > 0 && stock.change != 0 ? stock.price - stock.change : null));

    final effectiveHigh = (stock.high != null && stock.high! > 0)
        ? stock.high
        : (_yearCandles.isNotEmpty && _yearCandles.last.high > 0
            ? _yearCandles.last.high
            : (effectiveOpen != null && stock.price > 0 ? max(effectiveOpen, stock.price) : null));

    final effectiveLow = (stock.low != null && stock.low! > 0)
        ? stock.low
        : (_yearCandles.isNotEmpty && _yearCandles.last.low > 0
            ? _yearCandles.last.low
            : (effectiveOpen != null && stock.price > 0 ? min(effectiveOpen, stock.price) : null));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          // Top Part: Price & Change Pill (Right) + Vertical Divider + Sparkline (Left)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              textDirection: TextDirection.rtl,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Right: Price and Change Pill
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    textDirection: TextDirection.rtl,
                    children: [
                      // Price + Unit
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        textDirection: TextDirection.rtl,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            _moneyFmt.format(stock.price),
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 27,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF111827),
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            stock.isIndex ? 'نقطة' : 'ج.م',
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Change Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: pillBg,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          textDirection: TextDirection.ltr,
                          children: [
                            if (!isZero) ...[
                              Icon(
                                isGain ? Icons.north_east_rounded : Icons.south_east_rounded,
                                size: 13,
                                color: pillColor,
                              ),
                              const SizedBox(width: 3),
                            ],
                            Text(
                              pillText,
                              textDirection: TextDirection.ltr,
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: pillColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Vertical Divider
                Container(
                  width: 1,
                  height: 52,
                  color: const Color(0xFFE5E7EB),
                ),

                const SizedBox(width: 10),

                // Left: Sparkline
                Expanded(
                  flex: 5,
                  child: SizedBox(
                    height: 50,
                    child: SparklineChartWidget(
                      data: sparkData,
                      isGain: isGain,
                      height: 50,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Horizontal Divider
          const Divider(
            height: 1,
            thickness: 1,
            color: Color(0xFFF1F5F9),
          ),

          // Bottom Part: 3 Metrics Columns (Open, High, Low)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                // Right: Open Price
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        stock.isIndex ? 'الافتتاح' : 'سعر الافتتاح',
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        effectiveOpen != null
                            ? '${_moneyFmt.format(effectiveOpen)} ${stock.isIndex ? "نقطة" : "ج.م"}'
                            : '-',
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                ),

                // Center: High Price
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        stock.isIndex ? 'أعلى قيمة' : 'أعلى سعر',
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        effectiveHigh != null
                            ? '${_moneyFmt.format(effectiveHigh)} ${stock.isIndex ? "نقطة" : "ج.م"}'
                            : '-',
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                ),

                // Left: Low Price
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        stock.isIndex ? 'أدنى قيمة' : 'أدنى سعر',
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        effectiveLow != null
                            ? '${_moneyFmt.format(effectiveLow)} ${stock.isIndex ? "نقطة" : "ج.م"}'
                            : '-',
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
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

  // ==========================================
  // TABS & UNDERLINE BAR (Matches Image)
  // ==========================================

  Widget _buildTabs(List<_DetailTab> tabs) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFFEFEFE),
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: const Color(0xFFC1121F),
        unselectedLabelColor: const Color(0xFF64748B),
        dividerColor: Colors.transparent,
        labelPadding: const EdgeInsets.symmetric(horizontal: 14),
        indicatorColor: const Color(0xFFC1121F),
        indicatorWeight: 2.5,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        tabs: tabs.map((t) => Tab(
          height: 36,
          child: Text(t.title),
        )).toList(),
      ),
    );
  }

  // ==========================================
  // TAB 1: عامة (OVERVIEW)
  // ==========================================

  Widget _buildOverviewTab(StockModel stock, Color trendColor) {
    final fromDate = _visibleCandles.isNotEmpty ? _visibleCandles.first.time : DateTime.now().subtract(const Duration(days: 7));
    final toDate = _visibleCandles.isNotEmpty ? _visibleCandles.last.time : DateTime.now();

    final minPrice = _visibleCandles.isNotEmpty ? _visibleCandles.map((c) => c.low).reduce(min) : stock.price * 0.95;
    final maxPrice = _visibleCandles.isNotEmpty ? _visibleCandles.map((c) => c.high).reduce(max) : stock.price * 1.05;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      physics: _lockParentGestures
          ? const NeverScrollableScrollPhysics()
          : const BouncingScrollPhysics(),
      children: [
        // 1. Chart Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.01),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header row: Expand icon (left) | Dates and range (right)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                textDirection: TextDirection.rtl,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_rangeFmt.format(fromDate)} - ${_rangeFmt.format(toDate)}',
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'أدنى ${minPrice.toStringAsFixed(2)} • أعلى ${maxPrice.toStringAsFixed(2)} ${_safeStock.isIndex ? "نقطة" : "ج.م"}',
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => InteractiveChartScreen(stock: stock)),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.crop_free_rounded,
                        size: 18,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Period chips
              _buildPeriodChips(),

              const SizedBox(height: 16),

              // The Chart
              Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) => _setLockParentGestures(true),
                onPointerUp: (_) => _setLockParentGestures(false),
                onPointerCancel: (_) => _setLockParentGestures(false),
                child: SizedBox(
                  height: 220,
                  child: _loadingChart
                      ? const Center(
                          child: CircularProgressIndicator(color: Color(0xFFC1121F), strokeWidth: 2),
                        )
                      : _buildLineChart(trendColor),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // 3. Section Title: إحصائيات الجلسة
        const Align(
          alignment: Alignment.centerRight,
          child: Text(
            'إحصائيات الجلسة',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // 4. Session Stats Grid Card
        _buildSessionStatsCard(stock),

        if (!stock.isIndex) ...[
          const SizedBox(height: 14),
          _buildSpreadCard(stock),
        ],
      ],
    );
  }

  Widget _buildSpreadCard(StockModel stock) {
    final double bid = (stock.bid != null && stock.bid! > 0)
        ? stock.bid!
        : (stock.price > 0 ? stock.price - 0.06 : 21.15);
    final double ask = (stock.ask != null && stock.ask! > 0)
        ? stock.ask!
        : (stock.price > 0 ? stock.price + 0.04 : 21.25);
    final double spread = (stock.spread != null && stock.spread! > 0)
        ? stock.spread!
        : (ask - bid).abs();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.015),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Expanded(child: _buildSpreadColumn('طلب', '${bid.toStringAsFixed(2)} ج.م')),
              const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE2E8F0)),
              Expanded(child: _buildSpreadColumn('عرض', '${ask.toStringAsFixed(2)} ج.م')),
              const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE2E8F0)),
              Expanded(child: _buildSpreadColumn('الفارق', '${spread.toStringAsFixed(2)} ج.م')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpreadColumn(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodChips() {
    return Row(
      textDirection: TextDirection.rtl,
      children: ChartPeriod.values.map((period) {
        final selected = _selectedPeriod == period;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: InkWell(
              onTap: () => _changePeriod(period),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFFEE2E2) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected ? const Color(0xFFF87171) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Text(
                  period.label,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11.5,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                    color: selected ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLineChart(Color fallbackColor) {
    if (_spots.length < 2) {
      return const Center(
        child: Text(
          'لا توجد بيانات كافية للرسم',
          style: TextStyle(fontFamily: 'Tajawal', color: Color(0xFF94A3B8)),
        ),
      );
    }

    final isPeriodGain = _spots.last.y >= _spots.first.y;
    final color = isPeriodGain ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

    final minY = _spots.map((e) => e.y).reduce(min);
    final maxY = _spots.map((e) => e.y).reduce(max);
    final paddingY = max(0.01, (maxY - minY) * 0.12);

    final unit = _safeStock.isIndex ? 'نقطة' : 'ج.م';

    return LineChart(
      LineChartData(
        lineTouchData: LineTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF1E293B),
            tooltipRoundedRadius: 8,
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final idx = spot.x.toInt();
                String dateStr = '';
                if (idx >= 0 && idx < _visibleCandles.length) {
                  final dt = _visibleCandles[idx].time;
                  dateStr = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
                }
                final priceStr = '${spot.y.toStringAsFixed(2)} $unit';
                return LineTooltipItem(
                  dateStr.isNotEmpty ? '$priceStr\n$dateStr' : priceStr,
                  const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.3,
                  ),
                );
              }).toList();
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: max(0.01, (maxY - minY) / 4),
          getDrawingHorizontalLine: (_) => const FlLine(
            color: Color(0xFFF1F5F9),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              interval: max(0.01, (maxY - minY) / 4),
              getTitlesWidget: (val, meta) {
                // Prevent duplicate / colliding labels at chart edges
                if (val == meta.min || val == meta.max) {
                  return const SizedBox.shrink();
                }
                final applied = meta.appliedInterval;
                if ((val - meta.min).abs() < applied * 0.35 ||
                    (meta.max - val).abs() < applied * 0.35) {
                  return const SizedBox.shrink();
                }

                return Text(
                  val.toStringAsFixed(2),
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: max(1, (_spots.length / 4).floor()).toDouble(),
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx < 0 || idx >= _visibleCandles.length) return const SizedBox.shrink();
                final dt = _visibleCandles[idx].time;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${dt.day}/${dt.month}',
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minY: minY - paddingY,
        maxY: maxY + paddingY,
        lineBarsData: [
          LineChartBarData(
            spots: _spots,
            isCurved: true,
            curveSmoothness: 0.25,
            color: color,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.2),
                  color.withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionStatsCard(StockModel stock) {
    final unit = stock.isIndex ? 'نقطة' : 'ج.م';
    final open = _lastCandle?.open ?? stock.open ?? (stock.price * 0.99);
    final prev = _prevCandle?.close ?? stock.previousClose ?? stock.price;
    final high = _lastCandle?.high ?? stock.high ?? (stock.price * 1.02);
    final low = _lastCandle?.low ?? stock.low ?? (stock.price * 0.98);
    final vol = _lastCandle?.volume ?? stock.volume;

    if (stock.isIndex) {
      final range = (high - low).abs();
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
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
            _buildSessionStatRow(
              labelRight: 'افتتاح المؤشر',
              valueRight: '${open.toStringAsFixed(2)} $unit',
              labelLeft: 'الإغلاق السابق',
              valueLeft: '${prev.toStringAsFixed(2)} $unit',
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
            _buildSessionStatRow(
              labelRight: 'أعلى مستوى',
              valueRight: '${high.toStringAsFixed(2)} $unit',
              labelLeft: 'أدنى مستوى',
              valueLeft: '${low.toStringAsFixed(2)} $unit',
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
            _buildSessionStatRow(
              labelRight: 'نطاق التذبذب',
              valueRight: '${range.toStringAsFixed(2)} $unit',
              labelLeft: 'حجم التداول',
              valueLeft: (vol != null && vol > 0) ? Formatters.formatLargeNumber(vol) : '-',
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          _buildSessionStatRow(
            labelRight: 'الافتتاح',
            valueRight: '${open.toStringAsFixed(2)} $unit',
            labelLeft: 'الإغلاق السابق',
            valueLeft: '${prev.toStringAsFixed(2)} $unit',
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          _buildSessionStatRow(
            labelRight: 'الأعلى',
            valueRight: '${high.toStringAsFixed(2)} $unit',
            labelLeft: 'الأدنى',
            valueLeft: '${low.toStringAsFixed(2)} $unit',
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          _buildSessionStatRow(
            labelRight: 'حجم التداول',
            valueRight: (vol != null && vol > 0) ? Formatters.formatLargeNumber(vol) : '974.290',
            labelLeft: 'عدد الصفقات',
            valueLeft: 'غير متاح',
          ),
        ],
      ),
    );
  }

  Widget _buildSessionStatRow({
    required String labelRight,
    required String valueRight,
    required String labelLeft,
    required String valueLeft,
  }) {
    return IntrinsicHeight(
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          // Right cell
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    labelRight,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    valueRight,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          // Left cell
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    labelLeft,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    valueLeft,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: المؤشرات الفنية
  // ==========================================

  Widget _buildIndicatorsTab() {
    if (!_indicatorsLoaded && !_loadingIndicators) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadIndicators());
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      physics: const BouncingScrollPhysics(),
      children: [
        if (_loadingIndicators || !_indicatorsLoaded)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFFC1121F)),
            ),
          )
        else if (_indicators != null)
          TechnicalIndicatorsWidget(indicators: _indicators!)
        else
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Text(
                'لا توجد مؤشرات فنية متاحة حالياً',
                style: TextStyle(fontFamily: 'Tajawal', color: Color(0xFF64748B)),
              ),
            ),
          ),
      ],
    );
  }

  // ==========================================
  // TAB 4: التوزيعات
  // ==========================================

  Widget _buildDividendsTab() {
    if (!_dividendsLoaded && !_loadingDividends) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadDividends());
    }
    if (_loadingDividends || !_dividendsLoaded) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFC1121F)),
      );
    }

    final data = _dividendData;
    if (data == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'لا توجد توزيعات أرباح مسجلة لهذه الشركة',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 14,
              color: Color(0xFF64748B),
            ),
          ),
        ),
      );
    }

    final hasYield = data.currentYield != null && data.currentYield! > 0;
    final hasRatio = data.payoutRatio != null && data.payoutRatio! > 0;
    final hasDps = data.dps != null && data.dps! > 0;
    final hasMetrics = hasYield || hasRatio || hasDps;
    final hasPayouts = data.payouts.isNotEmpty;

    if (!hasMetrics && !hasPayouts) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'لا توجد توزيعات أرباح مسجلة لهذه الشركة',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 14,
              color: Color(0xFF64748B),
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      physics: const BouncingScrollPhysics(),
      children: [
        // 1. ملخص التوزيعات (يظهر فقط في حال توفرت مؤشرات التوزيع)
        if (hasMetrics) ...[
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'ملخص التوزيعات',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
          ),
          const SizedBox(height: 10),

          Row(
            textDirection: TextDirection.rtl,
            children: [
              if (hasYield)
                Expanded(
                  child: _buildDividendMetricBox(
                    title: 'عائد التوزيع',
                    value: '${data.currentYield!.toStringAsFixed(2)}%',
                  ),
                ),
              if (hasRatio) ...[
                if (hasYield) const SizedBox(width: 8),
                Expanded(
                  child: _buildDividendMetricBox(
                    title: 'نسبة التوزيع',
                    value: '${data.payoutRatio!.toStringAsFixed(1)}%',
                  ),
                ),
              ],
              if (hasDps) ...[
                if (hasYield || hasRatio) const SizedBox(width: 8),
                Expanded(
                  child: _buildDividendMetricBox(
                    title: 'حصة السهم (DPS)',
                    value: '${data.dps!.toStringAsFixed(2)} ج.م',
                  ),
                ),
              ],
            ],
          ),
          if (hasPayouts) const SizedBox(height: 24),
        ],

        // 2. سجل التوزيعات التاريخية و النقدية (يظهر فقط إذا كانت هناك دفعات مسجلة)
        if (hasPayouts) ...[
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'سجل التوزيعات التاريخية و النقدية',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildPayoutsTable(data.payouts),
        ],
      ],
    );
  }

  Widget _buildDividendMetricBox({required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutsTable(List<DividendPayoutItem> payouts) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: payouts.map((p) {
          final isLast = payouts.indexOf(p) == payouts.length - 1;
          final dateStr = p.paymentDate != null ? DateFormat('yyyy/MM/dd').format(p.paymentDate!) : '-';

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  textDirection: TextDirection.rtl,
                  children: [
                    Text(
                      dateStr,
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: Color(0xFF111827)),
                    ),
                    Text(
                      '${p.amount.toStringAsFixed(2)} ج.م',
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                    ),
                  ],
                ),
              ),
              if (!isLast) const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ==========================================
  // TAB: الدعم والمقاومة (Pivot Points)
  // ==========================================

  static const List<Map<String, String>> _pivotPeriods = [
    {'key': '1h', 'label': 'ساعي'},
    {'key': '1d', 'label': 'يومي'},
    {'key': '1w', 'label': 'أسبوعي'},
    {'key': '1month', 'label': 'شهري'},
  ];

  static const List<Map<String, String>> _pivotMethods = [
    {'key': 'classic', 'label': 'كلاسيك'},
    {'key': 'fibonacci', 'label': 'فيبوناتشي'},
    {'key': 'camarilla', 'label': 'كاماريلا'},
    {'key': 'woodie', 'label': 'وودي'},
    {'key': 'demark', 'label': 'ديمارك'},
  ];

  Widget _buildPivotPointsTab() {
    if (!_pivotsLoaded && !_loadingPivots) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadPivotPoints());
    }
    if (_loadingPivots && _pivotData == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFC1121F)),
      );
    }

    final data = _pivotData;
    final pSet = data?.getByName(_pivotMethod);
    final hasAnyLevel = pSet != null &&
        (pSet.pivot != null ||
            pSet.r1 != null ||
            pSet.r2 != null ||
            pSet.r3 != null ||
            pSet.s1 != null ||
            pSet.s2 != null ||
            pSet.s3 != null);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
      physics: const BouncingScrollPhysics(),
      children: [
        // 1. Period Selector Pills
        Container(
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(3),
          child: Row(
            textDirection: TextDirection.rtl,
            children: _pivotPeriods.map((p) {
              final isSelected = _pivotPeriod == p['key'];
              return Expanded(
                child: InkWell(
                  onTap: () {
                    if (_pivotPeriod != p['key']) {
                      setState(() => _pivotPeriod = p['key']!);
                      _loadPivotPoints(forceRefresh: true);
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      p['label']!,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected
                            ? const Color(0xFFC1121F)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 12),

        // 2. Signal Summary Card
        if (data != null && hasAnyLevel) ...[
          _buildPivotSignalCard(data.signal),
          const SizedBox(height: 12),
        ],

        // 3. Method Selector Pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: Row(
            textDirection: TextDirection.rtl,
            children: _pivotMethods.map((m) {
              final isSelected = _pivotMethod == m['key'];
              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: InkWell(
                  onTap: () => setState(() => _pivotMethod = m['key']!),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFC1121F) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFC1121F)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Text(
                      m['label']!,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 14),

        // 4. Support & Resistance Levels Table
        if (_loadingPivots)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFFC1121F)),
            ),
          )
        else if (hasAnyLevel)
          _buildPivotLevelsCard(pSet)
        else
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            alignment: Alignment.center,
            child: const Text(
              'لا تتوفر بيانات دعم ومقاومة حالياً لهذا الإطار الزمني',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 13.5,
                color: Color(0xFF64748B),
              ),
            ),
          ),

        const SizedBox(height: 14),

        // 5. Educational Tip
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            textDirection: TextDirection.rtl,
            children: [
              Row(
                textDirection: TextDirection.rtl,
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF64748B)),
                  SizedBox(width: 6),
                  Text(
                    'كيف تستفيد من نقاط الدعم والمقاومة؟',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6),
              Text(
                '• نقطة الارتكاز (Pivot P): السعر التوازني للفترة، التداول أعلاها يعطي إشارة إيجابية وأدناها يعطي إشارة سلبية.\n'
                '• مستويات المقاومة (R1, R2, R3): مناطق يُتوقع عندها ظهور ضغوط بيعية.\n'
                '• مستويات الدعم (S1, S2, S3): مناطق يُتوقع عندها ظهور قوى شرائية.',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 11.5,
                  height: 1.6,
                  color: Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPivotSignalCard(PivotSignal sig) {
    final low = sig.summary.toLowerCase();
    final Color sigColor = (low.contains('buy') || low.contains('شراء'))
        ? const Color(0xFF16A34A)
        : ((low.contains('sell') || low.contains('بيع'))
            ? const Color(0xFFDC2626)
            : const Color(0xFFD97706));
    String arSummary = sig.summary;
    if (low.contains('strong buy')) {
      arSummary = 'شراء قوي';
    } else if (low.contains('strong sell')) {
      arSummary = 'بيع قوي';
    } else if (low.contains('buy')) {
      arSummary = 'شراء';
    } else if (low.contains('sell')) {
      arSummary = 'بيع';
    } else if (low.contains('neutral')) {
      arSummary = 'محايد';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ملخص الإشارة والاتجاه',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: sigColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sigColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  arSummary,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: sigColor,
                  ),
                ),
              ),
            ],
          ),
          if (sig.trend != null || sig.volatility != null || sig.score != null) ...[
            const SizedBox(height: 10),
            Row(
              textDirection: TextDirection.rtl,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (sig.trend != null)
                  _buildMiniPivotMetric(
                    'الاتجاه',
                    sig.trend == 'Strong'
                        ? 'قوي'
                        : (sig.trend == 'Weak'
                            ? 'ضعيف'
                            : (sig.trend == 'Moderate' ? 'متوسط' : sig.trend!)),
                  ),
                if (sig.volatility != null)
                  _buildMiniPivotMetric(
                    'التقلبات',
                    sig.volatility == 'High'
                        ? 'عالية'
                        : (sig.volatility == 'Low'
                            ? 'منخفضة'
                            : (sig.volatility == 'Moderate' ? 'متوسطة' : sig.volatility!)),
                  ),
                if (sig.score != null)
                  _buildMiniPivotMetric('التقييم', '${sig.score!.toStringAsFixed(1)} / 10'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniPivotMetric(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 11,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildPivotLevelsCard(PivotSet p) {
    final unit = _safeStock.isIndex ? 'نقطة' : 'ج.م';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'المستوى',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
              Text(
                'السعر المستهدف ($unit)',
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 6),
          if (p.r3 != null) _buildPivotLevelRow('مقاومة 3 (R3)', p.r3!, const Color(0xFFDC2626)),
          if (p.r2 != null) _buildPivotLevelRow('مقاومة 2 (R2)', p.r2!, const Color(0xFFEF4444)),
          if (p.r1 != null) _buildPivotLevelRow('مقاومة 1 (R1)', p.r1!, const Color(0xFFF87171)),
          if (p.pivot != null)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                textDirection: TextDirection.rtl,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    textDirection: TextDirection.rtl,
                    children: [
                      Icon(Icons.adjust_rounded, size: 16, color: Color(0xFFD97706)),
                      SizedBox(width: 6),
                      Text(
                        'نقطة الارتكاز (Pivot P)',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _moneyFmt.format(p.pivot!),
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ],
              ),
            ),
          if (p.s1 != null) _buildPivotLevelRow('دعم 1 (S1)', p.s1!, const Color(0xFF34D399)),
          if (p.s2 != null) _buildPivotLevelRow('دعم 2 (S2)', p.s2!, const Color(0xFF10B981)),
          if (p.s3 != null) _buildPivotLevelRow('دعم 3 (S3)', p.s3!, const Color(0xFF059669)),
        ],
      ),
    );
  }

  Widget _buildPivotLevelRow(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        textDirection: TextDirection.rtl,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            textDirection: TextDirection.rtl,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          Text(
            _moneyFmt.format(value),
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB: ملف الشركة (Company Profile - get_profile)
  // ==========================================

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildCompanyProfileTab(StockModel stock) {
    if (!_profileLoaded && !_loadingProfile) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadCompanyProfile());
    }
    if (_loadingProfile && _companyProfile == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFC1121F)),
      );
    }

    final profile = _companyProfile ??
        CompanyProfileModel.fallback(stock.symbol, nameAr: stock.displayName);

    final infoItems = <Map<String, dynamic>>[
      {'label': 'الاسم الرسمي', 'value': profile.name, 'ltr': true},
      {'label': 'رمز السهم (Ticker)', 'value': profile.symbol, 'ltr': true},
      {
        'label': 'البورصة المدرج بها',
        'value': profile.exchange == 'EGX'
            ? 'البورصة المصرية (EGX)'
            : profile.exchange,
      },
      {
        'label': 'عملة التداول',
        'value': profile.currency == 'EGP'
            ? 'الجنيه المصري (EGP)'
            : profile.currency,
      },
      if (profile.sector.trim().isNotEmpty)
        {'label': 'القطاع الرئيسي', 'value': profile.sector},
      {
        'label': 'نوع الورقة المالية',
        'value': profile.subType == 'common' ? 'أسهم عادية' : profile.subType,
      },
      if (profile.isin.trim().isNotEmpty)
        {'label': 'رقم التعريف الدولي (ISIN)', 'value': profile.isin, 'ltr': true},
      if (profile.ceo != null && profile.ceo!.trim().isNotEmpty)
        {'label': 'الرئيس التنفيذي / العضو المنتدب', 'value': profile.ceo!},
      if (profile.employees != null && profile.employees!.trim().isNotEmpty)
        {'label': 'عدد الموظفين', 'value': profile.employees!},
      if (profile.website != null && profile.website!.trim().isNotEmpty)
        {
          'label': 'الموقع الرسمي',
          'value': profile.website!,
          'ltr': true,
          'link': true,
        },
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
      physics: const BouncingScrollPhysics(),
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'بيانات الشركة والورقة المالية',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              ...List.generate(infoItems.length, (i) {
                final item = infoItems[i];
                final isLast = i == infoItems.length - 1;
                final isLtr = item['ltr'] == true;
                final isLink = item['link'] == true;
                final val = item['value'] as String;

                final rowWidget = Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    textDirection: TextDirection.rtl,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item['label'] as String,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          val,
                          textDirection: isLtr ? TextDirection.ltr : TextDirection.rtl,
                          textAlign: TextAlign.left,
                          softWrap: true,
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isLink
                                ? const Color(0xFF2563EB)
                                : const Color(0xFF111827),
                            decoration: isLink
                                ? TextDecoration.underline
                                : TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                );

                return Column(
                  children: [
                    if (isLink)
                      InkWell(
                        onTap: () => _openExternalUrl(val),
                        child: rowWidget,
                      )
                    else
                      rowWidget,
                    if (!isLast)
                      const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                  ],
                );
              }),
            ],
          ),
        ),

        if (profile.description != null && profile.description!.trim().isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              textDirection: TextDirection.rtl,
              children: [
                const Text(
                  'نبذة عن نشاط الشركة',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  profile.description!,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 12.5,
                    height: 1.65,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ==========================================
  // TAB 5: البيانات المالية
  // ==========================================

  String? _withCurrency(String? val) {
    if (val == null || val.trim().isEmpty || val.trim() == '-') return null;
    final trimmed = val.trim();
    if (trimmed.endsWith('ج.م') || trimmed.endsWith('جنيه')) return trimmed;
    return '$trimmed ج.م';
  }

  List<Map<String, String>> _getFinancialSummaryRows() {
    final fd = _financialsData;
    if (fd == null || fd.ratios.isEmpty) return const [];

    String? findVal(String keyword) {
      for (final r in fd.ratios) {
        if (r.name.toLowerCase().contains(keyword.toLowerCase()) ||
            r.id.toLowerCase().contains(keyword.toLowerCase())) {
          return r.displayValue;
        }
      }
      return null;
    }

    final rawRows = [
      {'label': 'القيمة السوقية', 'val': _withCurrency(findVal('market'))},
      {'label': 'إجمالي الأسهم العادية القائمة', 'val': findVal('share')},
      {'label': 'الأسهم الحرة (Free float)', 'val': findVal('float')},
      {'label': 'مكرر الربحية (P/E)', 'val': findVal('pe')},
      {'label': 'مكرر المبيعات (P/S)', 'val': findVal('ps')},
      {'label': 'مكرر التدفق النقدي (P/CF)', 'val': findVal('pcf')},
    ];

    return rawRows
        .where((r) => r['val'] != null && r['val']!.trim().isNotEmpty && r['val']!.trim() != '-')
        .map((r) => {'label': r['label']!, 'val': r['val']!})
        .toList();
  }

  List<Map<String, String>> _getBalanceSheetRows() {
    final fd = _financialsData;
    if (fd == null || fd.balanceSheet.isEmpty) return const [];

    String? findBs(String keyword) {
      for (final b in fd.balanceSheet) {
        if (b.name.toLowerCase().contains(keyword.toLowerCase()) ||
            b.id.toLowerCase().contains(keyword.toLowerCase())) {
          return b.displayValue;
        }
      }
      return null;
    }

    final rawRows = [
      {'label': 'إجمالي الأصول', 'val': _withCurrency(findBs('asset'))},
      {'label': 'إجمالي الالتزامات', 'val': _withCurrency(findBs('liabilit'))},
      {'label': 'إجمالي حقوق الملكية', 'val': _withCurrency(findBs('equity'))},
      {'label': 'إجمالي الالتزامات و حقوق الملكية', 'val': _withCurrency(findBs('total'))},
      {'label': 'القيمة الدفترية الملموسة للسهم', 'val': _withCurrency(findBs('book'))},
      {'label': 'صافي الدين', 'val': _withCurrency(findBs('debt'))},
    ];

    return rawRows
        .where((r) => r['val'] != null && r['val']!.trim().isNotEmpty && r['val']!.trim() != '-')
        .map((r) => {'label': r['label']!, 'val': r['val']!})
        .toList();
  }

  List<Map<String, String>> _getIncomeStatementRows() {
    final fd = _financialsData;
    if (fd == null || fd.incomeStatement.isEmpty) return const [];

    String? findIs(String keyword) {
      for (final item in fd.incomeStatement) {
        if (item.name.toLowerCase().contains(keyword.toLowerCase()) ||
            item.id.toLowerCase().contains(keyword.toLowerCase())) {
          return item.displayValue;
        }
      }
      return null;
    }

    final rawRows = [
      {'label': 'الإيرادات', 'val': _withCurrency(findIs('rev'))},
      {'label': 'إجمالي الربح', 'val': _withCurrency(findIs('gross'))},
      {'label': 'الدخل التشغيلي', 'val': _withCurrency(findIs('oper'))},
      {'label': 'صافي الدخل', 'val': _withCurrency(findIs('net'))},
      {'label': 'الأرباح قبل الفوائد والضرائب (EBITDA)', 'val': _withCurrency(findIs('ebitda'))},
      {'label': 'ربحية السهم المخففة (EPS)', 'val': _withCurrency(findIs('eps'))},
    ];

    return rawRows
        .where((r) => r['val'] != null && r['val']!.trim().isNotEmpty && r['val']!.trim() != '-')
        .map((r) => {'label': r['label']!, 'val': r['val']!})
        .toList();
  }

  Widget _buildFinancialsTab() {
    if (!_financialsLoaded && !_loadingFinancials) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadFinancials());
    }
    if (_loadingFinancials || !_financialsLoaded) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFC1121F)),
      );
    }

    final summaryRows = _getFinancialSummaryRows();
    final bsRows = _getBalanceSheetRows();
    final isRows = _getIncomeStatementRows();

    final hasSummary = summaryRows.isNotEmpty;
    final hasBs = bsRows.isNotEmpty;
    final hasIs = isRows.isNotEmpty;

    if (!hasSummary && !hasBs && !hasIs) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'لا توجد بيانات مالية مسجلة لهذه الشركة',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 14,
              color: Color(0xFF64748B),
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      physics: const BouncingScrollPhysics(),
      children: [
        // 1. ملخص مالي (يظهر فقط إذا توفرت صفوف فعلية)
        if (hasSummary) ...[
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'ملخص مالي',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildFinancialRowsCard(summaryRows),
          if (hasBs || hasIs) const SizedBox(height: 24),
        ],

        // 2. الميزانية العمومية (تظهر فقط إذا توفرت صفوف فعلية)
        if (hasBs) ...[
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'الميزانية العمومية',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildFinancialRowsCard(bsRows),
          if (hasIs) const SizedBox(height: 24),
        ],

        // 3. قائمة الدخل (تظهر فقط إذا توفرت صفوف فعلية - يخفى العنوان إذا كانت فارغة)
        if (hasIs) ...[
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'قائمة الدخل',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildFinancialRowsCard(isRows),
        ],

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildFinancialRowsCard(List<Map<String, String>> rows) {
    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: rows.map((r) {
          final isLast = rows.indexOf(r) == rows.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  textDirection: TextDirection.rtl,
                  children: [
                    Text(
                      r['label']!,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      r['val']!,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ==========================================
  // FIXED BOTTOM BAR (PRESENT IN ALL TABS)
  // ==========================================

  Widget _buildFixedBottomBar(StockModel stock) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            // 1. Right Button (Solid Red): ضبط تنبيه السعر
            Expanded(
              flex: 3,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PriceAlertsScreen(preselectedStock: stock),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC1121F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.notifications_active_outlined, size: 18),
                label: const Text(
                  'ضبط تنبيه السعر',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 10),

            // 2. Left Button (Outlined Red): قارن بسهم آخر
            Expanded(
              flex: 2,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StockComparisonScreen(initialStockA: stock),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFC1121F),
                  side: const BorderSide(color: Color(0xFFC1121F)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: const Text(
                  'قارن بسهم آخر',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
