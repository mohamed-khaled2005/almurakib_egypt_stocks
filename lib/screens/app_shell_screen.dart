// lib/screens/app_shell_screen.dart
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/utils/constants.dart';
import '../core/services/translation_service.dart';
import '../core/services/favorites_service.dart';
import '../core/services/last_update_service.dart';

// Quick Search deps
import '../core/models/stock_model.dart';
import '../core/services/stock_service.dart';
import 'stock_detail_screen.dart';

import 'home_screen.dart';
import 'market_today_screen.dart';
import 'all_stocks_screen.dart';
import 'our_apps_screen.dart';
import 'about_screen.dart';
import 'contact_screen.dart';

import '../utils/first_time_hint.dart';
import '../utils/app_lifecycle_refresh.dart';

const String _almurakibWebsiteUrl = 'https://almurakib.com';

Color _o(Color c, double opacity) =>
    c.withAlpha((opacity.clamp(0.0, 1.0) * 255).round());

class AppShellScreen extends StatefulWidget {
  const AppShellScreen({super.key});

  @override
  State<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends State<AppShellScreen> {
  int _index = 0;
  bool _refreshing = false;
  late final bool _hideOurAppsTab;
  late final int _aboutScreenIndex;
  late final int _contactScreenIndex;
  late final List<Widget> _pages;

  final GlobalKey _refreshHintKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    _hideOurAppsTab = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    _aboutScreenIndex = _hideOurAppsTab ? 3 : 4;
    _contactScreenIndex = _hideOurAppsTab ? 4 : 5;

    _pages = <Widget>[
      HomeScreen(onNavigateToTab: (index) => setState(() => _index = index)),
      const MarketTodayScreen(),
      const AllStocksScreen(),
      if (!_hideOurAppsTab) const OurAppsScreen(),
      const AboutScreen(),
      const ContactScreen(),
    ];

    FavoritesService.init();
    TranslationService.getTranslations(forceRefresh: true);
    AppLifecycleSignals.resumeTick.addListener(_onResumeSignal);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FirstTimeHint.showRefreshHint(
        context: context,
        targetKey: _refreshHintKey,
        prefsKey: 'hint_stocks_refresh_button_v1',
        message:
            'اضغط على زر التحديث لإعادة تحميل البيانات. سيظهر هذا التنبيه مرة واحدة فقط.',
      );
    });
  }

  @override
  void dispose() {
    AppLifecycleSignals.resumeTick.removeListener(_onResumeSignal);
    super.dispose();
  }

  void _onResumeSignal() {
    if (!mounted) return;
    if (_refreshing) return;
    _onRefresh(showSnackBar: false);
  }

  Future<void> _onRefresh({bool showSnackBar = true}) async {
    if (_refreshing) return;

    setState(() => _refreshing = true);

    try {
      await TranslationService.getTranslations(forceRefresh: true);
      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;

      if (showSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'تم تحديث البيانات بنجاح',
              style: TextStyle(fontFamily: 'Tajawal'),
            ),
            backgroundColor: const Color(0xFF388E3C),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;

      if (showSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'تعذر تحديث البيانات حالياً',
              style: TextStyle(fontFamily: 'Tajawal'),
            ),
            backgroundColor: const Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (!mounted) return;
      setState(() => _refreshing = false);
    }
  }

  Future<void> _onQuickSearch() async {
    final picked = await showSearch<StockModel?>(
      context: context,
      delegate: _StockQuickSearchDelegate(perPage: 500),
    );

    if (!mounted) return;
    if (picked == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StockDetailScreen(stock: picked)),
    );
  }

  void _setIndex(int i) {
    if (i < 0 || i >= _pages.length) return;
    if (_index == i) return;
    setState(() => _index = i);
  }

  void _openAboutMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (ctx) {
        return SafeArea(
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 62,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _aboutMenuTile(
                      title: 'من نحن',
                      icon: Icons.info_outline_rounded,
                      onTap: () {
                        Navigator.pop(ctx);
                        _setIndex(_aboutScreenIndex);
                      },
                    ),
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 16,
                      endIndent: 16,
                      color: AppColors.border.withOpacity(0.5),
                    ),
                    _aboutMenuTile(
                      title: 'الإتصال بنا',
                      icon: Icons.support_agent_rounded,
                      onTap: () {
                        Navigator.pop(ctx);
                        _setIndex(_contactScreenIndex);
                      },
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _aboutMenuTile({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: AppColors.primaryBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    color: Colors.black87,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    height: 1.1,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: AppColors.textSecondary.withOpacity(0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// هل نعرض سطر "آخر تحديث" تحت الهيدر؟
  bool get _showLastUpdate => _index <= 2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      appBar: _buildHeader(),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // ── سطر آخر تحديث (منفصل عن الهيدر) ──
            if (_showLastUpdate) const _LastUpdateBar(),

            // ── محتوى الصفحات ──
            Expanded(
              child: IndexedStack(
                index: _index,
                children: _pages,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNav(
        screenIndex: _index,
        hideOurAppsTab: _hideOurAppsTab,
        onTap: _setIndex,
        onAboutMenu: _openAboutMenu,
      ),
    );
  }

  PreferredSizeWidget _buildHeader() {
    // ✅ ارتفاع ثابت بعد فصل آخر تحديث
    const headerH = 70.0;

    return PreferredSize(
      preferredSize: const Size.fromHeight(headerH),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: _o(Colors.black, 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: _HeaderContent(
            refreshKey: _refreshHintKey,
            refreshing: _refreshing,
            onRefresh: _onRefresh,
            onSearch: _onQuickSearch,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// Header (بدون آخر تحديث)
// ═══════════════════════════════════════════════

class _HeaderContent extends StatelessWidget {
  final GlobalKey refreshKey;
  final bool refreshing;
  final Future<void> Function({bool showSnackBar}) onRefresh;
  final VoidCallback onSearch;

  const _HeaderContent({
    required this.refreshKey,
    required this.refreshing,
    required this.onRefresh,
    required this.onSearch,
  });

  Future<void> _openWebsiteWithConfirm(BuildContext context) async {
    final bool? go = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              'زيارة موقع المراقب؟',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.w900,
              ),
            ),
            content: const Text(
              'هل تريد الانتقال إلى موقع المراقب الآن؟',
              style: TextStyle(
                fontFamily: 'Tajawal',
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'إلغاء',
                  style: TextStyle(fontFamily: 'Tajawal'),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'زيارة الموقع',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (go != true) return;

    final uri = Uri.parse(_almurakibWebsiteUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'تعذر فتح الموقع الآن',
            style: TextStyle(fontFamily: 'Tajawal'),
          ),
          backgroundColor: AppColors.primaryBlue,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final logoMaxW = math.min(220.0, math.max(120.0, c.maxWidth * 0.56));

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            textDirection: TextDirection.ltr,
            children: [
              KeyedSubtree(
                key: refreshKey,
                child: _HeaderRefreshButton(
                  loading: refreshing,
                  onTap: refreshing
                      ? null
                      : () async => onRefresh(showSnackBar: true),
                ),
              ),
              const SizedBox(width: 10),
              _HeaderSearchButton(onTap: onSearch),
              const Spacer(),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: logoMaxW),
                child: SizedBox(
                  height: 48,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _openWebsiteWithConfirm(context),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                          alignment: Alignment.centerRight,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (_, __, ___) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.assessment_rounded,
                                  color: AppColors.primaryBlue,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'مراقب الأسهم',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeaderRefreshButton extends StatelessWidget {
  final bool loading;
  final VoidCallback? onTap;

  const _HeaderRefreshButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _o(AppColors.primaryBlue, 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _o(AppColors.primaryBlue, 0.20)),
          ),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryBlue,
                    ),
                  )
                : const Icon(
                    Icons.refresh_rounded,
                    size: 22,
                    color: AppColors.primaryBlue,
                  ),
          ),
        ),
      ),
    );
  }
}

class _HeaderSearchButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _HeaderSearchButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _o(AppColors.primaryBlue, 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _o(AppColors.primaryBlue, 0.20)),
          ),
          child: const Center(
            child: Icon(
              Icons.search_rounded,
              size: 22,
              color: AppColors.primaryBlue,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// ✅ شريط آخر تحديث (منفصل عن الهيدر)
// ═══════════════════════════════════════════════

class _LastUpdateBar extends StatelessWidget {
  const _LastUpdateBar();

  String _two(int n) => n.toString().padLeft(2, '0');

  String _formatOneLine(DateTime localDt) {
    return '${localDt.year}/${_two(localDt.month)}/${_two(localDt.day)} '
        '${_two(localDt.hour)}:${_two(localDt.minute)}';
  }

  String _gmtOffsetLabelFrom(DateTime localDt) {
    final off = localDt.timeZoneOffset;
    final sign = off.isNegative ? '-' : '+';
    final h = off.inHours.abs();
    final m = (off.inMinutes.abs() % 60);
    return m == 0 ? 'GMT$sign$h' : 'GMT$sign$h:${_two(m)}';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTime?>(
      valueListenable: LastUpdateService.lastUpdateUtc,
      builder: (context, utc, _) {
        final local = utc?.toLocal();
        final text = (local == null)
            ? '--'
            : '${_formatOneLine(local)} (${_gmtOffsetLabelFrom(local)})';

        return Container(
          margin: const EdgeInsets.fromLTRB(20, 10, 20, 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.primaryBlue.withOpacity(0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'آخر تحديث:',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary.withOpacity(0.85),
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary.withOpacity(0.92),
                      height: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════
// Quick Search
// ═══════════════════════════════════════════════

class _StockQuickSearchDelegate extends SearchDelegate<StockModel?> {
  final int perPage;

  _StockQuickSearchDelegate({required this.perPage});

  Future<List<StockModel>>? _future;
  List<StockModel> _all = [];

  String _normalizeForSearch(String input) {
    var s = input.toLowerCase();
    s = s.replaceAll(RegExp(r'[\u200E\u200F\u202A-\u202E\u2066-\u2069]'), '');
    s = s.replaceAll(RegExp(r'[\"""„‟«»‹›]'), '');
    s = s.replaceAll(RegExp(r"[\''`´]"), '');
    s = s.replaceAll(
      RegExp(r'[^a-z0-9\u0621-\u064A\u0660-\u0669\u06F0-\u06F9]+'),
      ' ',
    );
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  String get _normalizedQuery => _normalizeForSearch(query.trim());

  List<StockModel> _filter(List<StockModel> items) {
    final q = _normalizedQuery;
    if (q.isEmpty) return items.take(30).toList();

    final tokens = q.split(' ').where((t) => t.trim().isNotEmpty).toList();
    final compactQ = q.replaceAll(' ', '');

    bool match(StockModel s) {
      final raw = '${s.displayName} ${s.symbol} ${s.id}';
      final idx = _normalizeForSearch(raw);
      if (idx.contains(q)) return true;
      final compactIdx = idx.replaceAll(' ', '');
      if (compactQ.isNotEmpty && compactIdx.contains(compactQ)) return true;
      if (tokens.isEmpty) return true;
      return tokens.every((t) => idx.contains(t));
    }

    return items.where(match).take(50).toList();
  }

  Future<List<StockModel>> _loadOnce() {
    _future ??= StockService.getStocksList(perPage: perPage, page: 1).then((v) {
      _all = v;
      return v;
    });
    return _future!;
  }

  @override
  String get searchFieldLabel => 'ابحث باسم السهم أو الرمز...';

  @override
  TextStyle? get searchFieldStyle => const TextStyle(
        fontFamily: 'Tajawal',
        fontWeight: FontWeight.w700,
      );

  @override
  ThemeData appBarTheme(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black87),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(
          fontFamily: 'Tajawal',
          color: AppColors.textSecondary.withOpacity(0.7),
        ),
        border: InputBorder.none,
      ),
      textTheme: base.textTheme.apply(fontFamily: 'Tajawal'),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.trim().isNotEmpty)
        IconButton(
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
          icon: const Icon(Icons.clear_rounded),
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () => close(context, null),
      icon: const Icon(Icons.arrow_back_rounded),
    );
  }

  @override
  Widget buildResults(BuildContext context) =>
      _buildBody(context, showEmptyHint: true);

  @override
  Widget buildSuggestions(BuildContext context) =>
      _buildBody(context, showEmptyHint: true);

  Widget _buildBody(BuildContext context, {required bool showEmptyHint}) {
    return FutureBuilder<List<StockModel>>(
      future: _loadOnce(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryBlue),
          );
        }

        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off_rounded,
                      size: 56, color: AppColors.error),
                  const SizedBox(height: 12),
                  Text(
                    'تعذر تحميل قائمة الأسهم للبحث',
                    style: AppTextStyles.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      _future = null;
                      _all = [];
                      showSuggestions(context);
                    },
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
            ),
          );
        }

        final items = snap.data ?? _all;
        final filtered = _filter(items);

        if (showEmptyHint && _normalizedQuery.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_rounded, size: 64, color: AppColors.border),
                  const SizedBox(height: 12),
                  Text(
                    'اكتب اسم السهم أو الرمز للبحث السريع',
                    style: AppTextStyles.headingSmall
                        .copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        if (filtered.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off_rounded,
                      size: 64, color: AppColors.border),
                  const SizedBox(height: 12),
                  Text(
                    'لا توجد نتائج مطابقة',
                    style: AppTextStyles.headingSmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final s = filtered[i];
            return Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => close(context, s),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          (s.symbol.isNotEmpty
                                  ? (s.symbol.length > 2
                                      ? s.symbol.substring(0, 2)
                                      : s.symbol)
                                  : (s.id.length > 2
                                      ? s.id.substring(0, 2)
                                      : s.id))
                              .toUpperCase(),
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyLarge
                                  .copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${s.symbol} • ${s.id}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodySmall.copyWith(
                                color:
                                    AppColors.textSecondary.withOpacity(0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.chevron_right_rounded,
                          color: AppColors.textSecondary.withOpacity(0.7)),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════
// Bottom Navigation Bar
// ═══════════════════════════════════════════════

class _BottomNav extends StatelessWidget {
  final int screenIndex;
  final bool hideOurAppsTab;
  final ValueChanged<int> onTap;
  final VoidCallback onAboutMenu;

  const _BottomNav({
    required this.screenIndex,
    required this.hideOurAppsTab,
    required this.onTap,
    required this.onAboutMenu,
  });

  int get _aboutTabIndex => hideOurAppsTab ? 3 : 4;

  int _screenToBar(int screen) {
    if (screen <= 2) return screen;
    return _aboutTabIndex;
  }

  @override
  Widget build(BuildContext context) {
    final int barIndex = _screenToBar(screenIndex);

    final items = <_NavItemData>[
      const _NavItemData(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
        label: 'الرئيسية',
      ),
      const _NavItemData(
        icon: Icons.trending_up_outlined,
        selectedIcon: Icons.trending_up_rounded,
        label: 'السوق',
      ),
      const _NavItemData(
        icon: Icons.list_alt_outlined,
        selectedIcon: Icons.list_alt_rounded,
        label: 'الأسهم',
      ),
      if (!hideOurAppsTab)
        const _NavItemData(
          icon: Icons.apps_outlined,
          selectedIcon: Icons.apps_rounded,
          label: 'تطبيقاتنا',
        ),
      const _NavItemData(
        icon: Icons.info_outline_rounded,
        selectedIcon: Icons.info_rounded,
        label: 'عنا',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: _o(Colors.black, 0.04),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              for (int i = 0; i < items.length; i++)
                Expanded(
                  child: _BottomNavItem(
                    data: items[i],
                    selected: barIndex == i,
                    onTap: () {
                      if (i <= 2) {
                        onTap(i);
                      } else if (!hideOurAppsTab && i == 3) {
                        onTap(3);
                      } else {
                        onAboutMenu();
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavItemData({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

class _BottomNavItem extends StatelessWidget {
  final _NavItemData data;
  final bool selected;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = selected ? AppColors.primaryBlue : Colors.transparent;
    final contentColor = selected ? Colors.white : AppColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? data.selectedIcon : data.icon,
              size: 22,
              color: contentColor,
            ),
            const SizedBox(height: 2),
            Text(
              data.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 9,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                color: contentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
