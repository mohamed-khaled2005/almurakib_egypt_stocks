import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/models/stock_model.dart';
import '../core/services/favorites_service.dart';
import '../core/services/last_update_service.dart';
import '../core/services/stock_service.dart';
import '../core/services/translation_service.dart';
import '../core/utils/constants.dart';
import '../models/manual_ad_model.dart';
import '../models/remote_ui_config_model.dart';
import '../providers/app_manager_provider.dart';
import '../utils/app_lifecycle_refresh.dart';
import '../utils/first_time_hint.dart';
import '../widgets/manual_ad_banner.dart';
import 'about_screen.dart';
import 'account_screen.dart';
import 'all_stocks_screen.dart';
import 'auth_screen.dart';
import 'contact_screen.dart';
import 'educational_content_screen.dart';
import 'favorites_screen.dart';
import 'home_screen.dart';
import 'market_today_screen.dart';
import 'market_indices_screen.dart';
import 'our_apps_screen.dart';
import 'profile_completion_screen.dart';
import 'stock_detail_screen.dart';

const String _almurakibWebsiteUrl = 'https://almurakib.com';
const Color _shellTop = Color(0xFFFFFFFF);
const Color _shellBottom = Color(0xFFFFF1F3);
const Color _shellAccent = AppColors.primaryBlue;
const Color _shellHighlight = AppColors.accentGold;

Color _o(Color color, double opacity) =>
    color.withAlpha((opacity.clamp(0.0, 1.0) * 255).round());

String _stockSecondaryLabel(String symbol, String id) {
  final trimmedSymbol = symbol.trim();
  final trimmedId = id.trim();
  if (trimmedSymbol.isEmpty) {
    return trimmedId;
  }
  if (trimmedId.isEmpty) {
    return trimmedSymbol;
  }

  final normalizedSymbol = trimmedSymbol.toLowerCase();
  final normalizedId = trimmedId.toLowerCase();
  final symbolTail = normalizedSymbol.contains(':')
      ? normalizedSymbol.split(':').last
      : normalizedSymbol;

  if (normalizedSymbol == normalizedId || symbolTail == normalizedId) {
    return trimmedSymbol;
  }

  return '$trimmedSymbol - $trimmedId';
}

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
  late final bool _hideOurAppsTab;
  late final List<Widget?> _pageCache;
  final Set<int> _loadedPageIndices = <int>{0};
  int? _presentedPopupAdId;
  int? _pendingAuthTabIndex;
  int _lastNonAccountTabIndex = 0;

  int get _homeTabIndex => 0;
  int get _marketTodayTabIndex => 1;
  int get _indicesTabIndex => 2;
  int get _allStocksTabIndex => 3;
  int get _favoritesTabIndex => 4;
  int get _ourAppsTabIndex => 5;
  int get _educationTabIndex => _hideOurAppsTab ? 5 : 6;
  int get _aboutScreenIndex => _hideOurAppsTab ? 6 : 7;
  int get _contactScreenIndex => _hideOurAppsTab ? 7 : 8;
  int get _accountScreenIndex => _hideOurAppsTab ? 8 : 9;
  int get _pageCount => _accountScreenIndex + 1;

  @override
  void initState() {
    super.initState();

    _hideOurAppsTab = false;
    _pageCache = List<Widget?>.filled(_pageCount, null, growable: false);

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

  bool get _showHeaderTools => _index <= _favoritesTabIndex;

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
      return const FavoritesScreen();
    }
    if (!_hideOurAppsTab && index == _ourAppsTabIndex) {
      return const OurAppsScreen();
    }
    if (index == _educationTabIndex) {
      return const EducationalContentScreen();
    }
    if (index == _aboutScreenIndex) {
      return const AboutScreen();
    }
    if (index == _contactScreenIndex) {
      return const ContactScreen();
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
                  border: Border.all(color: AppColors.border),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 24,
                      offset: const Offset(0, 18),
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
                              color: AppColors.cardLight,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.campaign_rounded,
                                color: AppColors.primaryBlue,
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
                            style: AppTextStyles.headingSmall.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: closePopup,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.textSecondary,
                                    side: const BorderSide(
                                      color: AppColors.border,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: const Text('إغلاق'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: ad.targetUrl.trim().isEmpty
                                      ? closePopup
                                      : openPopupLink,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryBlue,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: Text(
                                    ad.targetUrl.trim().isEmpty
                                        ? 'حسنًا'
                                        : 'افتح الآن',
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
            const SizedBox(height: 10),
            _buildManagedTradingAccountButton(
              compact: compact,
              menuCta: manager.menuCta,
            ),
            const SizedBox(height: 12),
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
              : (isSubItem ? const Color(0xFFFDF6F7) : Colors.transparent),
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
          onTap: () => _launchExternalLink(menuCta.url),
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

    if (manager.initialized && manager.requiresProfileCompletion) {
      _scheduleMandatoryProfileCompletion(manager);
    }
    if (manager.initialized) {
      _maybeShowPopupAd(manager);
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.scaffold,
      appBar: _buildHeader(
        isDesktopNav: isDesktopNav,
        isAuthenticated: manager.isAuthenticated,
      ),
      drawer: isDesktopNav ? null : _buildSideDrawer(context, manager),
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

  Widget _buildHeaderLogo(BuildContext context, double logoMaxWidth) {
    return ConstrainedBox(
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
                  return const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.assessment_rounded,
                        color: AppColors.primaryBlue,
                        size: 24,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'ظ…ط±ط§ظ‚ط¨ ط§ظ„ط£ط³ظ‡ظ…',
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
    );
  }

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
                textDirection: TextDirection.rtl,
                children: <Widget>[
                  _buildHeaderLogo(context, logoMaxWidth),
                  const Spacer(),
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
                  if (!isDesktopNav &&
                      MediaQuery.sizeOf(context).width < 0) ...<Widget>[
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
                  if (currentIndex < 0) const Spacer(),
                  if (currentIndex < 0)
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
                                  return const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Icon(
                                        Icons.assessment_rounded,
                                        color: AppColors.primaryBlue,
                                        size: 24,
                                      ),
                                      SizedBox(width: 8),
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
                  const SizedBox(width: 10),
                  if (!isDesktopNav)
                    _HeaderActionButton(
                      tooltip: 'القائمة',
                      onTap: () => scaffoldKey.currentState?.openDrawer(),
                      child: const Icon(
                        Icons.menu_rounded,
                        color: _shellAccent,
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
    return const SizedBox.shrink();
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
    normalized = normalized.replaceAll(RegExp(r'["“”«»]'), '');
    normalized = normalized.replaceAll(RegExp(r"[\'`´]"), '');
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
                  const Text(
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
                              _stockSecondaryLabel(stock.symbol, stock.id),
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
