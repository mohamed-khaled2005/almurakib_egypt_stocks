import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/services/favorites_service.dart';
import '../core/services/translation_service.dart';
import '../core/utils/constants.dart';
import '../models/manual_ad_model.dart';
import '../models/remote_ui_config_model.dart';
import '../widgets/ad_banner_card.dart';
import '../providers/app_manager_provider.dart';
import '../utils/app_lifecycle_refresh.dart';
import '../utils/first_time_hint.dart';
import 'about_screen.dart';
import 'account_screen.dart';
import 'all_stocks_screen.dart';
import 'app_maintenance_screen.dart';
import 'auth_screen.dart';
import 'contact_screen.dart';
import 'currency_converter_screen.dart';
import 'educational_content_screen.dart';
import 'favorites_screen.dart';
import 'home_screen.dart';
import 'market_today_screen.dart';
import 'market_indices_screen.dart';
import 'more_screen.dart';
import 'our_apps_screen.dart';
import 'price_alerts_screen.dart';
import 'profile_completion_screen.dart';
import 'notifications_screen.dart';
import 'stock_comparison_screen.dart';
import 'stock_search_screen.dart';
import '../core/services/live_socket_service.dart';
import '../core/services/price_alerts_service.dart';
import '../widgets/app_update_dialog.dart';
import '../widgets/market_status_header.dart';
import '../widgets/chevron_left_icon.dart';

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
  bool _profileCompletionPromptActive = false;
  bool _popupDialogActive = false;
  bool _isStocksExpanded = true;
  bool _isAboutExpanded = false;
  bool _isToolsExpanded = false;
  late final bool _hideOurAppsTab;
  late final List<Widget?> _pageCache;
  final Set<int> _loadedPageIndices = <int>{0};
  int? _presentedPopupAdId;
  int? _pendingAuthTabIndex;
  int _lastNonAccountTabIndex = 0;
  String? _trackedMenuCtaImpressionKey;
  bool _hasTriggeredUpdateCheck = false;
  String? _lastCheckedUpdateVersion;
  bool _didClearUpdateDismissOnUnavailable = false;

  int get _homeTabIndex => 0;
  int get _marketTodayTabIndex => 1;
  int get _indicesTabIndex => 2;
  int get _allStocksTabIndex => 3;
  int get _favoritesTabIndex => 4;
  int get _moreTabIndex => 5;
  int get _ourAppsTabIndex => 6;
  int get _educationTabIndex => _hideOurAppsTab ? 6 : 7;
  int get _aboutScreenIndex => _hideOurAppsTab ? 7 : 8;
  int get _contactScreenIndex => _hideOurAppsTab ? 8 : 9;
  int get _accountScreenIndex => _hideOurAppsTab ? 9 : 10;
  int get _pageCount => _accountScreenIndex + 1;

  @override
  void initState() {
    super.initState();

    _hideOurAppsTab = false;
    _pageCache = List<Widget?>.filled(_pageCount, null, growable: false);

    FavoritesService.init();
    NotificationsScreen.syncUnreadCountFromStorage();
    TranslationService.getTranslations(forceRefresh: true);
    LiveSocketService.instance.init();
    PriceAlertsService.instance.init();
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

  Widget _pageForIndex(int index) {
    final cachedPage = _pageCache[index];
    if (cachedPage != null) {
      return cachedPage;
    }

    final page = _buildPageForIndex(index);
    _pageCache[index] = page;
    return page;
  }

  Widget _buildPageForIndex(int index) {
    if (index == _homeTabIndex) {
      return HomeScreen(
        onNavigateToTab: _setIndex,
        allStocksTabIndex: _allStocksTabIndex,
        favoritesTabIndex: _favoritesTabIndex,
        indicesTabIndex: _indicesTabIndex,
      );
    }
    if (index == _marketTodayTabIndex) {
      return const MarketTodayScreen();
    }
    if (index == _indicesTabIndex) {
      return const MarketIndicesScreen();
    }
    if (index == _allStocksTabIndex) {
      return const AllStocksScreen();
    }
    if (index == _favoritesTabIndex) {
      return FavoritesScreen(
        onNavigateToStocks: () => _setIndex(_allStocksTabIndex),
      );
    }
    if (index == _moreTabIndex) {
      return MoreScreen(
        onNavigateToTab: _setIndex,
        allStocksTabIndex: _allStocksTabIndex,
        favoritesTabIndex: _favoritesTabIndex,
        indicesTabIndex: _indicesTabIndex,
        educationTabIndex: _educationTabIndex,
        ourAppsTabIndex: _ourAppsTabIndex,
        aboutTabIndex: _aboutScreenIndex,
        contactTabIndex: _contactScreenIndex,
        accountTabIndex: _accountScreenIndex,
      );
    }
    if (!_hideOurAppsTab && index == _ourAppsTabIndex) {
      return const OurAppsScreen();
    }
    if (index == _educationTabIndex) {
      return const EducationalContentScreen(showFixedBanner: false);
    }
    if (index == _aboutScreenIndex) {
      return const AboutScreen();
    }
    if (index == _contactScreenIndex) {
      return const ContactScreen(showFixedBanner: false);
    }
    if (index == _accountScreenIndex) {
      return AccountScreen(onAuthSuccess: _handleAccountAuthSuccess);
    }

    return const SizedBox.shrink();
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
        context.read<AppManagerProvider>().refreshManagedContent(force: true),
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
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StockSearchScreen()),
    );
  }

  void _setIndex(int index) {
    if (index < 0 || index >= _pageCount) return;
    if (_index == index) return;

    if (_isProtectedIndex(index)) {
      _openProtectedIndex(index);
      return;
    }

    _applyIndex(index);
  }

  bool _isProtectedIndex(int index) {
    return index == _marketTodayTabIndex ||
        index == _favoritesTabIndex ||
        index == _educationTabIndex;
  }

  Future<bool> _ensureAuthenticatedForProtectedContent() async {
    final manager = context.read<AppManagerProvider>();
    if (manager.isAuthenticated) return true;

    final allowed = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(builder: (_) => const AuthScreen()),
    );

    if (!mounted) return false;
    return allowed == true &&
        context.read<AppManagerProvider>().isAuthenticated;
  }

  Future<void> _openProtectedIndex(int index) async {
    _pendingAuthTabIndex = index;
    final allowed = await _ensureAuthenticatedForProtectedContent();
    if (!mounted || !allowed || _index == index) return;
    _applyIndex(index);
  }

  void _applyIndex(int index) {
    setState(() {
      _index = index;
      _loadedPageIndices.add(index);
      if (index != _accountScreenIndex) {
        _lastNonAccountTabIndex = index;
      }
    });
    context.read<AppManagerProvider>().trackPageView(_pageNameForIndex(index));
  }

  void _scheduleMandatoryProfileCompletion(AppManagerProvider manager) {
    if (_profileCompletionPromptActive || !manager.requiresProfileCompletion) {
      return;
    }

    _profileCompletionPromptActive = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route != null && !route.isCurrent) {
        _profileCompletionPromptActive = false;
        return;
      }

      final completed = await ProfileCompletionScreen.ensureCompleted(context);
      if (!mounted) return;

      _profileCompletionPromptActive = false;
      final refreshedManager = context.read<AppManagerProvider>();
      if (!completed && refreshedManager.requiresProfileCompletion) {
        _scheduleMandatoryProfileCompletion(refreshedManager);
      }
    });
  }

  String _pageNameForIndex(int index) {
    if (index == _homeTabIndex) return 'home';
    if (index == _marketTodayTabIndex) return 'market_today';
    if (index == _indicesTabIndex) return 'market_indices';
    if (index == _allStocksTabIndex) return 'all_stocks';
    if (index == _favoritesTabIndex) return 'favorites';
    if (index == _moreTabIndex) return 'more';
    if (!_hideOurAppsTab && index == _ourAppsTabIndex) return 'our_apps';
    if (index == _educationTabIndex) return 'educational_content';
    if (index == _aboutScreenIndex) return 'about';
    if (index == _contactScreenIndex) return 'contact';
    if (index == _accountScreenIndex) return 'account';
    return 'page_$index';
  }

  Future<void> _launchExternalLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرابط غير صالح.')),
      );
      return;
    }

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح الرابط الآن.')),
      );
    }
  }

  void _maybeShowPopupAd(AppManagerProvider manager) {
    final popupAd = manager.popupAd;
    if (!mounted ||
        popupAd == null ||
        _popupDialogActive ||
        _profileCompletionPromptActive ||
        _index != _homeTabIndex ||
        _presentedPopupAdId == popupAd.id) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final currentPopup = context.read<AppManagerProvider>().popupAd;
      if (currentPopup == null ||
          currentPopup.id != popupAd.id ||
          _popupDialogActive ||
          _presentedPopupAdId == currentPopup.id) {
        return;
      }

      _popupDialogActive = true;
      _presentedPopupAdId = currentPopup.id;

      await _showPopupAdDialog(currentPopup);
      _popupDialogActive = false;
    });
  }

  Future<void> _showPopupAdDialog(ManualAdModel ad) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        Future<void> closePopup() async {
          await context.read<AppManagerProvider>().dismissPopupAd(ad);
          if (dialogContext.mounted) {
            Navigator.of(dialogContext).pop();
          }
        }

        Future<void> openPopupLink() async {
          await _launchExternalLink(ad.targetUrl);
          if (!mounted) return;
          await context.read<AppManagerProvider>().dismissPopupAd(ad);
          if (dialogContext.mounted) {
            Navigator.of(dialogContext).pop();
          }
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            await closePopup();
          },
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (ad.imageUrl.trim().isNotEmpty)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                        child: AspectRatio(
                          aspectRatio: 1.5,
                          child: Image.network(
                            ad.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFFF8FAFC),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.campaign_rounded,
                                color: Color(0xFFC1121F),
                                size: 42,
                              ),
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            ad.title.trim().isEmpty ? 'إعلان' : ad.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: closePopup,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF64748B),
                                    side: const BorderSide(
                                      color: Color(0xFFE5E7EB),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  child: const Text(
                                    'إغلاق',
                                    style: TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: ad.targetUrl.trim().isEmpty
                                      ? closePopup
                                      : openPopupLink,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFC1121F),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  child: Text(
                                    ad.targetUrl.trim().isEmpty
                                        ? 'حسنًا'
                                        : 'افتح الآن',
                                    style: const TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleAccountAuthSuccess() {
    var targetIndex = _pendingAuthTabIndex;
    _pendingAuthTabIndex = null;

    if (targetIndex == null || targetIndex == _accountScreenIndex) {
      targetIndex = _lastNonAccountTabIndex;
    }

    if (targetIndex == _accountScreenIndex) {
      targetIndex = _homeTabIndex;
    }

    if (_index == targetIndex) {
      return;
    }

    _applyIndex(targetIndex);
  }

  _SideNavItem get _homeNavItem => _SideNavItem(
        index: _homeTabIndex,
        title: 'الرئيسية',
        icon: Icons.home_outlined,
      );

  _SideNavItem get _indicesNavItem => _SideNavItem(
        index: _indicesTabIndex,
        title: 'المؤشرات',
        icon: Icons.insights_outlined,
      );

  _SideNavItem get _educationNavItem => _SideNavItem(
        index: _educationTabIndex,
        title: 'المحتوى التعليمي',
        icon: Icons.menu_book_outlined,
      );

  List<_SideNavItem> get _stocksNavItems => <_SideNavItem>[
        _SideNavItem(
          index: _favoritesTabIndex,
          title: 'المفضلة',
          icon: Icons.star_border_rounded,
        ),
        _SideNavItem(
          index: _allStocksTabIndex,
          title: 'كل الأسهم',
          icon: Icons.list_alt_outlined,
        ),
        _SideNavItem(
          index: _marketTodayTabIndex,
          title: 'الأسهم الرابحة والخاسرة',
          icon: Icons.analytics_outlined,
        ),
      ];

  List<_SideNavItem> get _aboutNavItems {
    final items = <_SideNavItem>[];

    if (!_hideOurAppsTab) {
      items.add(
        _SideNavItem(
          index: _ourAppsTabIndex,
          title: 'تطبيقاتنا',
          icon: Icons.apps_outlined,
        ),
      );
    }

    items.addAll(<_SideNavItem>[
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
    ]);

    return items;
  }

  Drawer _buildSideDrawer(
    BuildContext context,
    AppManagerProvider manager,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = screenWidth > 380 ? 320.0 : screenWidth * 0.86;

    return Drawer(
      width: drawerWidth,
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: _buildSideNavigationPanel(
        closeOnSelect: true,
        manager: manager,
      ),
    );
  }

  Widget _buildSideNavigationPanel({
    required bool closeOnSelect,
    required AppManagerProvider manager,
  }) {
    final compact = MediaQuery.of(context).size.width < 360;

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
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(10, 16, 10, 18),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _buildSideNavTile(
                item: _homeNavItem,
                closeOnSelect: closeOnSelect,
                compact: compact,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildStocksAccordion(
                closeOnSelect: closeOnSelect,
                compact: compact,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _buildSideNavTile(
                item: _indicesNavItem,
                closeOnSelect: closeOnSelect,
                compact: compact,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildToolsAccordion(
                closeOnSelect: closeOnSelect,
                compact: compact,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _buildSideNavTile(
                item: _educationNavItem,
                closeOnSelect: closeOnSelect,
                compact: compact,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildAboutAccordion(
                closeOnSelect: closeOnSelect,
                compact: compact,
              ),
            ),
            _buildManagedTradingAccountButton(
              compact: compact,
              menuCta: manager.menuCta,
            ),
            if (manager.menuAd != null) ...[
              const SizedBox(height: 10),
              AdBannerCard(ad: manager.menuAd),
            ],
            const SizedBox(height: 10),
            _buildManagedSocialMediaSection(
              compact: compact,
              socialLinks: manager.socialLinks,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSideNavTile({
    required _SideNavItem item,
    required bool closeOnSelect,
    required bool compact,
    bool isSubItem = false,
  }) {
    final isSelected = _index == item.index;
    final borderRadius = BorderRadius.circular(compact ? 12 : 14);

    return SizedBox(
      height: isSubItem ? (compact ? 42 : 46) : (compact ? 48 : 52),
      child: AnimatedContainer(
        duration: AppAnimations.buttonAnimation,
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: <Color>[
                    Color(0x1FCE1126),
                    Color(0x12C09300),
                  ],
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                )
              : null,
          color: isSelected
              ? null
              : (isSubItem
                  ? const Color(0xFFFDF6F7)
                  : Colors.transparent),
          borderRadius: borderRadius,
          border: Border.all(
            color: isSelected
                ? AppColors.primaryBlue.withValues(alpha: 0.28)
                : AppColors.border,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: borderRadius,
            onTap: () {
              if (closeOnSelect && Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
              _setIndex(item.index);
            },
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                isSubItem ? (compact ? 16 : 18) : (compact ? 12 : 14),
                0,
                compact ? 10 : 12,
                0,
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    item.icon,
                    size: isSubItem ? (compact ? 17 : 18) : (compact ? 20 : 22),
                    color: isSelected
                        ? AppColors.primaryBlue
                        : AppColors.textSecondary,
                  ),
                  SizedBox(width: compact ? 8 : 10),
                  Expanded(
                    child: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        fontSize: isSubItem
                            ? (compact ? 11.5 : 12.1)
                            : (compact ? 12.0 : 12.8),
                        color: isSelected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStocksAccordion({
    required bool closeOnSelect,
    required bool compact,
  }) {
    return _buildSideNavAccordion(
      title: 'الأسهم',
      icon: Icons.show_chart_rounded,
      items: _stocksNavItems,
      closeOnSelect: closeOnSelect,
      compact: compact,
      isExpanded: _isStocksExpanded,
      onToggle: () {
        setState(() {
          _isStocksExpanded = !_isStocksExpanded;
        });
      },
    );
  }

  Widget _buildToolsAccordion({
    required bool closeOnSelect,
    required bool compact,
  }) {
    final borderRadius = BorderRadius.circular(compact ? 12 : 14);
    return AnimatedContainer(
      duration: AppAnimations.buttonAnimation,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: borderRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: <Widget>[
            InkWell(
              borderRadius: borderRadius,
              onTap: () {
                setState(() {
                  _isToolsExpanded = !_isToolsExpanded;
                });
              },
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 12 : 14,
                  vertical: compact ? 13 : 14,
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.handyman_outlined,
                      size: compact ? 20 : 22,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: compact ? 8 : 10),
                    Expanded(
                      child: Text(
                        'أدوات السوق',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontSize: compact ? 12.0 : 12.8,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _isToolsExpanded ? 0.5 : 0,
                      duration: AppAnimations.buttonAnimation,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: AppAnimations.buttonAnimation,
              alignment: Alignment.topCenter,
              child: _isToolsExpanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: Column(
                        children: [
                          _buildActionTile(
                            title: 'مقارنة سهمين',
                            icon: Icons.compare_arrows_rounded,
                            compact: compact,
                            onTap: () {
                              if (closeOnSelect && Navigator.of(context).canPop()) {
                                Navigator.of(context).pop();
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const StockComparisonScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 6),
                          _buildActionTile(
                            title: 'محول العملات',
                            icon: Icons.currency_exchange_rounded,
                            compact: compact,
                            onTap: () {
                              if (closeOnSelect && Navigator.of(context).canPop()) {
                                Navigator.of(context).pop();
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CurrencyConverterScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 6),
                          _buildActionTile(
                            title: 'تنبيهات الأسعار',
                            icon: Icons.notifications_active_outlined,
                            compact: compact,
                            onTap: () {
                              if (closeOnSelect && Navigator.of(context).canPop()) {
                                Navigator.of(context).pop();
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const PriceAlertsScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required IconData icon,
    required bool compact,
    required VoidCallback onTap,
  }) {
    final borderRadius = BorderRadius.circular(compact ? 12 : 14);
    return SizedBox(
      height: compact ? 42 : 46,
      child: Material(
        color: const Color(0xFFFDF6F7),
        borderRadius: borderRadius,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: onTap,
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              compact ? 16 : 18,
              0,
              compact ? 10 : 12,
              0,
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  icon,
                  size: compact ? 17 : 18,
                  color: AppColors.primaryBlue,
                ),
                SizedBox(width: compact ? 8 : 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      fontSize: compact ? 11.5 : 12.1,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ChevronLeftIcon(
                  size: 14,
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAboutAccordion({
    required bool closeOnSelect,
    required bool compact,
  }) {
    return _buildSideNavAccordion(
      title: 'عنا',
      icon: Icons.info_outline_rounded,
      items: _aboutNavItems,
      closeOnSelect: closeOnSelect,
      compact: compact,
      isExpanded: _isAboutExpanded,
      onToggle: () {
        setState(() {
          _isAboutExpanded = !_isAboutExpanded;
        });
      },
    );
  }

  Widget _buildSideNavAccordion({
    required String title,
    required IconData icon,
    required List<_SideNavItem> items,
    required bool closeOnSelect,
    required bool compact,
    required bool isExpanded,
    required VoidCallback onToggle,
  }) {
    final hasSelectedItem = items.any((item) => item.index == _index);
    final borderRadius = BorderRadius.circular(compact ? 12 : 14);

    return AnimatedContainer(
      duration: AppAnimations.buttonAnimation,
      decoration: BoxDecoration(
        gradient: hasSelectedItem
            ? const LinearGradient(
                colors: <Color>[
                  Color(0x1FCE1126),
                  Color(0x12C09300),
                ],
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
              )
            : null,
        color: hasSelectedItem ? null : Colors.transparent,
        borderRadius: borderRadius,
        border: Border.all(
          color: hasSelectedItem
              ? AppColors.primaryBlue.withValues(alpha: 0.28)
              : AppColors.border,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: <Widget>[
            InkWell(
              borderRadius: borderRadius,
              onTap: onToggle,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 12 : 14,
                  vertical: compact ? 13 : 14,
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      icon,
                      size: compact ? 20 : 22,
                      color: hasSelectedItem
                          ? AppColors.primaryBlue
                          : AppColors.textSecondary,
                    ),
                    SizedBox(width: compact ? 8 : 10),
                    Expanded(
                      child: Text(
                        title,
                        style: AppTextStyles.bodySmall.copyWith(
                          fontSize: compact ? 12.0 : 12.8,
                          color: hasSelectedItem
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontWeight: hasSelectedItem
                              ? FontWeight.w800
                              : FontWeight.w700,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: AppAnimations.buttonAnimation,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: hasSelectedItem
                            ? AppColors.primaryBlue
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: AppAnimations.buttonAnimation,
              alignment: Alignment.topCenter,
              child: isExpanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: Column(
                        children: items
                            .map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: _buildSideNavTile(
                                  item: item,
                                  closeOnSelect: closeOnSelect,
                                  compact: compact,
                                  isSubItem: true,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildManagedTradingAccountButton({
    required bool compact,
    required ManagedMenuCta? menuCta,
  }) {
    if (menuCta == null || !menuCta.isUsable) {
      return const SizedBox.shrink();
    }

    final impressionKey = '${menuCta.label}_${menuCta.url}';
    if (_trackedMenuCtaImpressionKey != impressionKey) {
      _trackedMenuCtaImpressionKey = impressionKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<AppManagerProvider>().trackMenuCta(
              eventType: 'impression',
              label: menuCta.label,
              url: menuCta.url,
            );
      });
    }

    final borderRadius = BorderRadius.circular(compact ? 14 : 16);
    final backgroundColor =
        _tryParseHexColor(menuCta.backgroundColor) ?? AppColors.primaryBlue;
    final textColor = _tryParseHexColor(menuCta.textColor) ?? Colors.white;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: backgroundColor.withValues(alpha: 0.24),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: () {
            context.read<AppManagerProvider>().trackMenuCta(
                  eventType: 'click',
                  label: menuCta.label,
                  url: menuCta.url,
                );
            _launchExternalLink(menuCta.url);
          },
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 14 : 16,
              vertical: compact ? 12 : 14,
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: compact ? 34 : 38,
                  height: compact ? 34 : 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.open_in_new_rounded,
                    color: textColor,
                  ),
                ),
                SizedBox(width: compact ? 10 : 12),
                Expanded(
                  child: Text(
                    menuCta.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      fontSize: compact ? 12.3 : 13.3,
                      color: textColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_outward_rounded,
                  color: textColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildManagedSocialMediaSection({
    required bool compact,
    required List<SocialLinkModel> socialLinks,
  }) {
    if (socialLinks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 11 : 12,
        compact ? 10 : 11,
        compact ? 11 : 12,
        compact ? 11 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(compact ? 14 : 16),
        border: Border.all(color: AppColors.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '\u062a\u0627\u0628\u0639\u0646\u0627',
            style: AppTextStyles.bodySmall.copyWith(
              fontSize: compact ? 10.8 : 11.2,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: compact ? 9 : 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth =
                  constraints.maxWidth.isFinite ? constraints.maxWidth : 256.0;
              final firstRowCount =
                  socialLinks.length < 5 ? socialLinks.length : 5;
              final spacing = maxWidth < 260 ? 6.0 : 8.0;
              final rawButtonSize = firstRowCount <= 1
                  ? 44.0
                  : (maxWidth - spacing * (firstRowCount - 1)) / firstRowCount;
              final buttonSize = rawButtonSize.clamp(34.0, 44.0).toDouble();

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: socialLinks
                    .map(
                      (item) => _buildManagedSocialMediaButton(
                        item: item,
                        size: buttonSize,
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildManagedSocialMediaButton({
    required SocialLinkModel item,
    required double size,
  }) {
    final accentColor = _socialAccentColor(item.platform);
    final iconData = _socialIconData(item.platform);
    final borderRadius = BorderRadius.circular(size <= 38 ? 11 : 13);
    final isX = item.platform.trim().toLowerCase() == 'x';

    return Tooltip(
      message: item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: () => _launchExternalLink(item.url),
          child: Ink(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.10),
              borderRadius: borderRadius,
              border: Border.all(
                color: accentColor.withValues(alpha: 0.28),
              ),
            ),
            child: Center(
              child: FaIcon(
                iconData,
                size: size <= 36 ? 14.5 : (size <= 40 ? 16 : 17),
                color: isX ? AppColors.textPrimary : accentColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color? _tryParseHexColor(String? rawValue) {
    final value = (rawValue ?? '').trim();
    if (value.isEmpty) {
      return null;
    }

    final normalized = value.startsWith('#') ? value.substring(1) : value;
    if (normalized.length != 6 && normalized.length != 8) {
      return null;
    }

    final parsed = int.tryParse(normalized, radix: 16);
    if (parsed == null) {
      return null;
    }

    return Color(normalized.length == 6 ? (0xFF000000 | parsed) : parsed);
  }

  Color _socialAccentColor(String platform) {
    switch (platform.trim().toLowerCase()) {
      case 'telegram':
        return const Color(0xFF27A7E7);
      case 'facebook':
        return const Color(0xFF1877F2);
      case 'instagram':
        return const Color(0xFFE75A8D);
      case 'whatsapp':
        return const Color(0xFF25D366);
      case 'x':
        return const Color(0xFF1E1E1E);
      default:
        return AppColors.primaryBlue;
    }
  }

  FaIconData _socialIconData(String platform) {
    switch (platform.trim().toLowerCase()) {
      case 'telegram':
        return FontAwesomeIcons.telegram;
      case 'facebook':
        return FontAwesomeIcons.facebookF;
      case 'instagram':
        return FontAwesomeIcons.instagram;
      case 'whatsapp':
        return FontAwesomeIcons.whatsapp;
      case 'x':
        return FontAwesomeIcons.xTwitter;
      default:
        return FontAwesomeIcons.link;
    }
  }

  Widget _buildBody(bool isDesktopNav) {
    final pages = IndexedStack(
      index: _index,
      children: List<Widget>.generate(_pageCount, (index) {
        if (!_loadedPageIndices.contains(index)) {
          return const SizedBox.shrink();
        }
        return _pageForIndex(index);
      }),
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
            child: _buildSideNavigationPanel(
              closeOnSelect: false,
              manager: context.read<AppManagerProvider>(),
            ),
          ),
          Expanded(child: pages),
        ],
      ),
    );
  }

  int _navBarIndexForShellIndex(int shellIndex) {
    if (shellIndex == _homeTabIndex) return 0;
    if (shellIndex == _allStocksTabIndex) return 1;
    if (shellIndex == _indicesTabIndex) return 2;
    if (shellIndex == _favoritesTabIndex) return 3;
    if (shellIndex == _moreTabIndex) return 4;
    return 0;
  }

  void _onBottomNavTap(int navIndex) {
    switch (navIndex) {
      case 0:
        _setIndex(_homeTabIndex);
        break;
      case 1:
        _setIndex(_allStocksTabIndex);
        break;
      case 2:
        _setIndex(_indicesTabIndex);
        break;
      case 3:
        _setIndex(_favoritesTabIndex);
        break;
      case 4:
        _setIndex(_moreTabIndex);
        break;
    }
  }

  PreferredSizeWidget _buildHeader({
    required bool isDesktopNav,
    required bool isAuthenticated,
  }) {
    final bool isMoreScreen = _index == _moreTabIndex;
    return PreferredSize(
      preferredSize: Size.fromHeight(isMoreScreen ? 62.0 : 115.0),
      child: Container(
        color: const Color(0xFFFEFEFE),
        child: SafeArea(
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Row: Logo & App Title (Right in RTL) and Search + Notification Bell (Left in RTL)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                child: Row(
                  textDirection: TextDirection.rtl,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Right: Logo
                    Image.asset(
                      'assets/images/logo.png',
                      height: 42,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Text(
                        'مراقب الأسهم المصرية',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),

                    // Left: Search Button + Notification Bell Button
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      textDirection: TextDirection.rtl,
                      children: [
                        // Search Button (Towards center)
                        InkWell(
                          onTap: _onQuickSearch,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.search_rounded,
                              color: Color(0xFF374151),
                              size: 20,
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Notification Bell Button with red dot badge (On far left edge)
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const NotificationsScreen(),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                const Icon(
                                  Icons.notifications_none_rounded,
                                  color: Color(0xFF374151),
                                  size: 20,
                                ),
                                ValueListenableBuilder<int>(
                                  valueListenable: NotificationsScreen.unreadCountNotifier,
                                  builder: (_, count, __) {
                                    if (count <= 0) return const SizedBox.shrink();
                                    return Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        width: 7,
                                        height: 7,
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
                  ],
                ),
              ),

              // Sub-Header Row: Market Status Pill + Refresh Pill
              if (!isMoreScreen)
                MarketStatusHeader(
                  onRefresh: () => _onRefresh(showSnackBar: true),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<AppManagerProvider>();
    final isDesktopNav = _isDesktopNav(context);

    if (manager.isMarketClosedByManager) {
      return AppMaintenanceScreen(
        title: 'التطبيق تحت الصيانة',
        message: manager.marketClosedMessage.isNotEmpty
            ? manager.marketClosedMessage
            : 'نقوم حالياً بتحسين الخدمة وسنعود قريباً.',
        onRetry: () => manager.refreshRemoteUiConfig(),
      );
    }

    final updateVer = manager.appUpdate.latestVersion;
    if (manager.hasLoadedRemoteUiConfig && !manager.appUpdate.updateAvailable) {
      _hasTriggeredUpdateCheck = false;
      _lastCheckedUpdateVersion = null;
      if (!_didClearUpdateDismissOnUnavailable) {
        _didClearUpdateDismissOnUnavailable = true;
        AppUpdateDialog.clearDismissed();
      }
    } else if (manager.appUpdate.updateAvailable &&
        (!_hasTriggeredUpdateCheck || _lastCheckedUpdateVersion != updateVer)) {
      _didClearUpdateDismissOnUnavailable = false;
      _hasTriggeredUpdateCheck = true;
      _lastCheckedUpdateVersion = updateVer;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          AppUpdateDialog.showIfAvailable(context, manager.appUpdate);
        }
      });
    }

    if (manager.initialized && manager.requiresProfileCompletion) {
      _scheduleMandatoryProfileCompletion(manager);
    }
    if (manager.initialized) {
      _maybeShowPopupAd(manager);
    }

    final currentNavIndex = _navBarIndexForShellIndex(_index);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFFEFEFE),
      appBar: _buildHeader(
        isDesktopNav: isDesktopNav,
        isAuthenticated: manager.isAuthenticated,
      ),
      drawer: isDesktopNav ? null : _buildSideDrawer(context, manager),
      bottomNavigationBar: isDesktopNav
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_index != _moreTabIndex)
                  Container(
                    color: const Color(0xFFFEFEFE),
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
                    child: const AdBannerCard(),
                  ),
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEFEFE),
                    border: Border(
                      top: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                    ),
                  ),
                  child: BottomNavigationBar(
                    currentIndex: currentNavIndex,
                    onTap: _onBottomNavTap,
                    type: BottomNavigationBarType.fixed,
                    backgroundColor: const Color(0xFFFEFEFE),
                    selectedItemColor: const Color(0xFFC1121F),
                    unselectedItemColor: const Color(0xFF64748B),
                    selectedLabelStyle: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                    elevation: 0,
                    items: [
                      BottomNavigationBarItem(
                        icon: Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Image.asset(
                            'assets/icons/Vector (8).png',
                            width: 20,
                            height: 20,
                            color: currentNavIndex == 0 ? const Color(0xFFC1121F) : const Color(0xFF64748B),
                          ),
                        ),
                        label: 'الرئيسية',
                      ),
                      BottomNavigationBarItem(
                        icon: Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Image.asset(
                            'assets/icons/Vector (7).png',
                            width: 18,
                            height: 18,
                            color: currentNavIndex == 1 ? const Color(0xFFC1121F) : const Color(0xFF64748B),
                          ),
                        ),
                        label: 'الأسهم',
                      ),
                      BottomNavigationBarItem(
                        icon: Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Image.asset(
                            'assets/icons/Vector (6).png',
                            width: 22,
                            height: 16,
                            color: currentNavIndex == 2 ? const Color(0xFFC1121F) : const Color(0xFF64748B),
                          ),
                        ),
                        label: 'المؤشرات',
                      ),
                      BottomNavigationBarItem(
                        icon: Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Icon(
                            Icons.star_outline_rounded,
                            size: 22,
                            color: currentNavIndex == 3 ? const Color(0xFFC1121F) : const Color(0xFF64748B),
                          ),
                        ),
                        label: 'المفضلة',
                      ),
                      BottomNavigationBarItem(
                        icon: Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Icon(
                            Icons.more_horiz_rounded,
                            size: 22,
                            color: currentNavIndex == 4 ? const Color(0xFFC1121F) : const Color(0xFF64748B),
                          ),
                        ),
                        label: 'المزيد',
                      ),
                    ],
                  ),
                ),
              ],
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

