import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/models/stock_model.dart';
import '../core/services/favorites_service.dart';
import '../core/services/last_update_service.dart';
import '../core/services/stock_service.dart';
import '../core/services/translation_service.dart';
import '../core/utils/constants.dart';
import '../providers/app_manager_provider.dart';
import '../utils/app_lifecycle_refresh.dart';
import '../utils/first_time_hint.dart';
import '../widgets/manual_ad_banner.dart';
import 'about_screen.dart';
import 'account_screen.dart';
import 'all_stocks_screen.dart';
import 'contact_screen.dart';
import 'educational_content_screen.dart';
import 'home_screen.dart';
import 'market_today_screen.dart';
import 'market_indices_screen.dart';
import 'our_apps_screen.dart';
import 'stock_detail_screen.dart';

const String _almurakibWebsiteUrl = 'https://almurakib.com';
const Color _shellTop = Color(0xFFFFFFFF);
const Color _shellBottom = Color(0xFFFFF1F3);
const Color _shellAccent = AppColors.primaryBlue;
const Color _shellHighlight = AppColors.accentGold;

Color _o(Color color, double opacity) =>
    color.withAlpha((opacity.clamp(0.0, 1.0) * 255).round());

class AppShellScreen extends StatefulWidget {
  const AppShellScreen({super.key});

  @override
  State<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends State<AppShellScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey _refreshHintKey = GlobalKey();

  int _index = 0;
  bool _refreshing = false;
  late final bool _hideOurAppsTab;
  late List<Widget> _pages;

  int get _homeTabIndex => 0;
  int get _marketTodayTabIndex => 1;
  int get _indicesTabIndex => 2;
  int get _allStocksTabIndex => 3;
  int get _ourAppsTabIndex => 4;
  int get _educationTabIndex => _hideOurAppsTab ? 4 : 5;
  int get _aboutScreenIndex => _hideOurAppsTab ? 5 : 6;
  int get _contactScreenIndex => _hideOurAppsTab ? 6 : 7;
  int get _accountScreenIndex => _hideOurAppsTab ? 7 : 8;

  @override
  void initState() {
    super.initState();

    _hideOurAppsTab = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    _rebuildPages();

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

  bool _isDesktopNav(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1080;

  bool get _showHeaderTools => _index <= _allStocksTabIndex;

  void _rebuildPages() {
    _pages = <Widget>[
      HomeScreen(
        onNavigateToTab: _setIndex,
        allStocksTabIndex: _allStocksTabIndex,
        indicesTabIndex: _indicesTabIndex,
      ),
      const MarketTodayScreen(),
      const MarketIndicesScreen(),
      const AllStocksScreen(),
      if (!_hideOurAppsTab) const OurAppsScreen(),
      const EducationalContentScreen(),
      const AboutScreen(),
      const ContactScreen(),
      const AccountScreen(),
    ];
  }

  void _onResumeSignal() {
    if (!mounted || _refreshing) return;
    _onRefresh(showSnackBar: false);
  }

  Future<void> _onRefresh({bool showSnackBar = true}) async {
    if (_refreshing) return;

    setState(() => _refreshing = true);

    try {
      await Future.wait<void>(<Future<void>>[
        TranslationService.getTranslations(forceRefresh: true),
        context.read<AppManagerProvider>().refreshAd(),
        context.read<AppManagerProvider>().refreshEducationalContent(),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      if (!mounted || !showSnackBar) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'تم تحديث البيانات بنجاح',
            style: TextStyle(fontFamily: 'Tajawal'),
          ),
          backgroundColor: const Color(0xFF388E3C),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (!mounted || !showSnackBar) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'تعذر تحديث البيانات حاليًا',
            style: TextStyle(fontFamily: 'Tajawal'),
          ),
          backgroundColor: const Color(0xFFD32F2F),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  Future<void> _onQuickSearch() async {
    final picked = await showSearch<StockModel?>(
      context: context,
      delegate: _StockQuickSearchDelegate(perPage: 500),
    );

    if (!mounted || picked == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StockDetailScreen(stock: picked)),
    );
  }

  void _setIndex(int index) {
    if (index < 0 || index >= _pages.length) return;
    if (_index == index) return;

    setState(() => _index = index);
    context.read<AppManagerProvider>().trackPageView(_pageNameForIndex(index));
  }

  String _pageNameForIndex(int index) {
    if (index == _homeTabIndex) return 'home';
    if (index == _marketTodayTabIndex) return 'market_today';
    if (index == _indicesTabIndex) return 'market_indices';
    if (index == _allStocksTabIndex) return 'all_stocks';
    if (!_hideOurAppsTab && index == _ourAppsTabIndex) return 'our_apps';
    if (index == _educationTabIndex) return 'educational_content';
    if (index == _aboutScreenIndex) return 'about';
    if (index == _contactScreenIndex) return 'contact';
    if (index == _accountScreenIndex) return 'account';
    return 'page_$index';
  }

  List<_SideNavItem> _navigationItems() {
    return <_SideNavItem>[
      const _SideNavItem(
        index: 0,
        title: 'الرئيسية',
        icon: Icons.home_outlined,
      ),
      const _SideNavItem(
        index: 1,
        title: 'السوق اليوم',
        icon: Icons.trending_up_outlined,
      ),
      const _SideNavItem(
        index: 2,
        title: 'المؤشرات',
        icon: Icons.insights_outlined,
      ),
      const _SideNavItem(
        index: 3,
        title: 'كل الأسهم',
        icon: Icons.list_alt_outlined,
      ),
      if (!_hideOurAppsTab)
        const _SideNavItem(
          index: 4,
          title: 'تطبيقاتنا',
          icon: Icons.apps_outlined,
        ),
      _SideNavItem(
        index: _educationTabIndex,
        title: 'المحتوى التعليمي',
        icon: Icons.menu_book_outlined,
      ),
      _SideNavItem(
        index: _aboutScreenIndex,
        title: 'عن التطبيق',
        icon: Icons.info_outline_rounded,
      ),
      _SideNavItem(
        index: _contactScreenIndex,
        title: 'اتصل بنا',
        icon: Icons.contact_page_outlined,
      ),
    ];
  }

  Drawer _buildSideDrawer(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = screenWidth > 380 ? 320.0 : screenWidth * 0.86;

    return Drawer(
      width: drawerWidth,
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: _buildSideNavigationPanel(closeOnSelect: true),
    );
  }

  Widget _buildSideNavigationPanel({required bool closeOnSelect}) {
    final items = _navigationItems();

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFFFFFFFF), Color(0xFFFFF5F6)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        border: Border.all(color: AppColors.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(10, 16, 10, 18),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final item = items[i];
            final bool isSelected = _index == item.index;

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: AnimatedContainer(
                duration: AppAnimations.buttonAnimation,
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: <Color>[
                            Color(0x1FCE1126),
                            Color(0x0FC09300),
                          ],
                          begin: Alignment.centerRight,
                          end: Alignment.centerLeft,
                        )
                      : null,
                  color: isSelected ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryBlue.withValues(alpha: 0.28)
                        : AppColors.border,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      if (closeOnSelect && Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                      _setIndex(item.index);
                    },
                    child: ListTile(
                      dense: true,
                      contentPadding:
                          const EdgeInsetsDirectional.fromSTEB(12, 6, 10, 6),
                      leading: Icon(
                        item.icon,
                        size: 22,
                        color: isSelected
                            ? AppColors.primaryBlue
                            : AppColors.textSecondary,
                      ),
                      title: Text(
                        item.title,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isSelected
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(bool isDesktopNav) {
    final pages = IndexedStack(
      index: _index,
      children: _pages,
    );

    if (!isDesktopNav) {
      return SafeArea(top: false, child: pages);
    }

    return SafeArea(
      top: false,
      child: Row(
        textDirection: TextDirection.rtl,
        children: <Widget>[
          SizedBox(
            width: 290,
            child: _buildSideNavigationPanel(closeOnSelect: false),
          ),
          Expanded(child: pages),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildHeader({
    required bool isDesktopNav,
    required bool isAuthenticated,
  }) {
    final headerHeight = _showHeaderTools ? 128.0 : 74.0;

    return PreferredSize(
      preferredSize: Size.fromHeight(headerHeight),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[_shellTop, _shellBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: const Border(
            bottom: BorderSide(color: AppColors.border),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: _o(Colors.black, 0.06),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: _HeaderContent(
            scaffoldKey: _scaffoldKey,
            isDesktopNav: isDesktopNav,
            refreshKey: _refreshHintKey,
            showHeaderTools: _showHeaderTools,
            currentIndex: _index,
            accountIndex: _accountScreenIndex,
            refreshing: _refreshing,
            onRefreshTap:
                _refreshing ? null : () => _onRefresh(showSnackBar: true),
            onSearch: _onQuickSearch,
            onHome: () => _setIndex(0),
            onAccount: () => _setIndex(_accountScreenIndex),
            isAuthenticated: isAuthenticated,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<AppManagerProvider>();
    final isDesktopNav = _isDesktopNav(context);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.scaffold,
      appBar: _buildHeader(
        isDesktopNav: isDesktopNav,
        isAuthenticated: manager.isAuthenticated,
      ),
      drawer: isDesktopNav ? null : _buildSideDrawer(context),
      bottomNavigationBar: ManualAdBanner(
        stickyBottom: true,
        ad: manager.activeAd,
      ),
      body: _buildBody(isDesktopNav),
    );
  }
}

class _SideNavItem {
  const _SideNavItem({
    required this.index,
    required this.title,
    required this.icon,
  });

  final int index;
  final String title;
  final IconData icon;
}

class _HeaderContent extends StatelessWidget {
  const _HeaderContent({
    required this.scaffoldKey,
    required this.isDesktopNav,
    required this.refreshKey,
    required this.showHeaderTools,
    required this.currentIndex,
    required this.accountIndex,
    required this.refreshing,
    required this.onRefreshTap,
    required this.onSearch,
    required this.onHome,
    required this.onAccount,
    required this.isAuthenticated,
  });

  final GlobalKey<ScaffoldState> scaffoldKey;
  final bool isDesktopNav;
  final GlobalKey refreshKey;
  final bool showHeaderTools;
  final int currentIndex;
  final int accountIndex;
  final bool refreshing;
  final VoidCallback? onRefreshTap;
  final VoidCallback onSearch;
  final VoidCallback onHome;
  final VoidCallback onAccount;
  final bool isAuthenticated;

  Future<void> _openWebsiteWithConfirm(BuildContext context) async {
    final bool? go = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'زيارة موقع المراقب',
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
            actions: <Widget>[
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
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final logoMaxWidth =
            math.min(220.0, math.max(120.0, constraints.maxWidth * 0.56));

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                textDirection: TextDirection.ltr,
                children: <Widget>[
                  _HeaderActionButton(
                    tooltip: 'الرئيسية',
                    onTap: onHome,
                    child: Icon(
                      currentIndex == 0
                          ? Icons.home_rounded
                          : Icons.home_outlined,
                      color: _shellAccent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _HeaderAccountButton(
                    onTap: onAccount,
                    isAuthenticated: isAuthenticated,
                    isSelected: currentIndex == accountIndex,
                  ),
                  if (!isDesktopNav) ...<Widget>[
                    const SizedBox(width: 10),
                    _HeaderActionButton(
                      tooltip: 'القائمة',
                      onTap: () => scaffoldKey.currentState?.openDrawer(),
                      child: const Icon(
                        Icons.menu_rounded,
                        color: _shellAccent,
                      ),
                    ),
                  ],
                  const Spacer(),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: logoMaxWidth),
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
                                  children: <Widget>[
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
                                      style: const TextStyle(
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
              if (showHeaderTools) ...<Widget>[
                const SizedBox(height: 10),
                Row(
                  textDirection: TextDirection.rtl,
                  children: <Widget>[
                    const Expanded(
                      child: _TopLastUpdateBanner(),
                    ),
                    const SizedBox(width: 10),
                    _HeaderSearchButton(onTap: onSearch),
                    const SizedBox(width: 8),
                    KeyedSubtree(
                      key: refreshKey,
                      child: _HeaderRefreshButton(
                        loading: refreshing,
                        onTap: onRefreshTap,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.tooltip,
    required this.onTap,
    required this.child,
  });

  final String tooltip;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _shellAccent.withValues(
                  alpha: onTap == null ? 0.12 : 0.26,
                ),
              ),
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

class _HeaderRefreshButton extends StatelessWidget {
  const _HeaderRefreshButton({
    required this.loading,
    required this.onTap,
  });

  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _HeaderActionButton(
      tooltip: 'تحديث البيانات',
      onTap: onTap,
      child: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _shellAccent,
              ),
            )
          : const Icon(
              Icons.refresh_rounded,
              size: 20,
              color: _shellAccent,
            ),
    );
  }
}

class _HeaderSearchButton extends StatelessWidget {
  const _HeaderSearchButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _HeaderActionButton(
      tooltip: 'البحث السريع',
      onTap: onTap,
      child: const Icon(
        Icons.search_rounded,
        size: 20,
        color: _shellAccent,
      ),
    );
  }
}

class _HeaderAccountButton extends StatelessWidget {
  const _HeaderAccountButton({
    required this.onTap,
    required this.isAuthenticated,
    required this.isSelected,
  });

  final VoidCallback? onTap;
  final bool isAuthenticated;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return _HeaderActionButton(
      tooltip: isAuthenticated ? 'حسابي' : 'تسجيل الدخول',
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Icon(
            isSelected
                ? Icons.account_circle_rounded
                : (isAuthenticated
                    ? Icons.person_outline_rounded
                    : Icons.account_circle_outlined),
            color: isAuthenticated ? _shellHighlight : _shellAccent,
          ),
          if (isAuthenticated)
            const Positioned(
              top: 1,
              left: -1,
              child: _AuthIndicatorDot(),
            ),
        ],
      ),
    );
  }
}

class _AuthIndicatorDot extends StatelessWidget {
  const _AuthIndicatorDot();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 8,
      height: 8,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color(0xFF22C55E),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _TopLastUpdateBanner extends StatelessWidget {
  const _TopLastUpdateBanner();

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  String _formatLocalDateTime(DateTime localDateTime) {
    return '${localDateTime.year}/${_twoDigits(localDateTime.month)}/${_twoDigits(localDateTime.day)} '
        '${_twoDigits(localDateTime.hour)}:${_twoDigits(localDateTime.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTime?>(
      valueListenable: LastUpdateService.lastUpdateUtc,
      builder: (context, lastUpdatedUtc, _) {
        final DateTime? localDateTime = lastUpdatedUtc?.toLocal();
        final String displayText =
            localDateTime == null ? '--' : _formatLocalDateTime(localDateTime);

        return Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _shellAccent.withValues(alpha: 0.22),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            textDirection: TextDirection.rtl,
            children: <Widget>[
              const Icon(
                Icons.schedule_rounded,
                size: 15,
                color: _shellAccent,
              ),
              const SizedBox(width: 6),
              Text(
                'آخر تحديث:',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                  fontSize: 10.5,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  displayText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 10.8,
                    height: 1.0,
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

class _StockQuickSearchDelegate extends SearchDelegate<StockModel?> {
  _StockQuickSearchDelegate({required this.perPage});

  final int perPage;
  Future<List<StockModel>>? _future;
  List<StockModel> _all = <StockModel>[];

  String _normalizeForSearch(String input) {
    var normalized = input.toLowerCase();
    normalized = normalized.replaceAll(
      RegExp(r'[\u200E\u200F\u202A-\u202E\u2066-\u2069]'),
      '',
    );
    normalized = normalized.replaceAll(RegExp(r'["“”«»‹›]'), '');
    normalized = normalized.replaceAll(RegExp("[\\'`´]"), '');
    normalized = normalized.replaceAll(
      RegExp(r'[^a-z0-9\u0621-\u064A\u0660-\u0669\u06F0-\u06F9]+'),
      ' ',
    );
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized;
  }

  String get _normalizedQuery => _normalizeForSearch(query.trim());

  Future<List<StockModel>> _loadOnce() {
    _future ??= StockService.getStocksList(perPage: perPage, page: 1).then((v) {
      _all = v;
      return v;
    });
    return _future!;
  }

  List<StockModel> _filter(List<StockModel> items) {
    final normalizedQuery = _normalizedQuery;
    if (normalizedQuery.isEmpty) {
      return items.take(30).toList();
    }

    final tokens = normalizedQuery
        .split(' ')
        .where((token) => token.trim().isNotEmpty)
        .toList();
    final compactQuery = normalizedQuery.replaceAll(' ', '');

    bool match(StockModel stock) {
      final raw = '${stock.displayName} ${stock.symbol} ${stock.id}';
      final index = _normalizeForSearch(raw);
      if (index.contains(normalizedQuery)) return true;

      final compactIndex = index.replaceAll(' ', '');
      if (compactQuery.isNotEmpty && compactIndex.contains(compactQuery)) {
        return true;
      }

      return tokens.every(index.contains);
    }

    return items.where(match).take(50).toList();
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
          color: AppColors.textSecondary.withValues(alpha: 0.75),
        ),
        border: InputBorder.none,
      ),
      textTheme: base.textTheme.apply(fontFamily: 'Tajawal'),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return <Widget>[
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
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryBlue),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 56,
                    color: AppColors.error,
                  ),
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
                      _all = <StockModel>[];
                      showSuggestions(context);
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('إعادة المحاولة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final items = snapshot.data ?? _all;
        final filtered = _filter(items);

        if (showEmptyHint && _normalizedQuery.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Icon(
                    Icons.search_rounded,
                    size: 64,
                    color: AppColors.border,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'اكتب اسم السهم أو الرمز للبحث السريع',
                    style: AppTextStyles.headingSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
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
                children: <Widget>[
                  const Icon(
                    Icons.search_off_rounded,
                    size: 64,
                    color: AppColors.border,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'لا توجد نتائج مطابقة',
                    style: AppTextStyles.headingSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
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
            final stock = filtered[i];
            final monogram = (stock.symbol.isNotEmpty
                    ? (stock.symbol.length > 2
                        ? stock.symbol.substring(0, 2)
                        : stock.symbol)
                    : (stock.id.length > 2
                        ? stock.id.substring(0, 2)
                        : stock.id))
                .toUpperCase();

            return Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => close(context, stock),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          monogram,
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
                          children: <Widget>[
                            Text(
                              stock.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyLarge.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${stock.symbol} • ${stock.id}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary
                                    .withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textSecondary.withValues(alpha: 0.70),
                      ),
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
