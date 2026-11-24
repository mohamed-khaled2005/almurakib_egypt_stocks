import 'dart:convert';
import 'dart:io';

import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/models/stock_model.dart';
import '../core/services/stock_service.dart';
import '../services/push_notification_service.dart';
import 'price_alerts_screen.dart';
import 'stock_detail_screen.dart';
import '../widgets/chevron_right_icon.dart';

class AppNotificationItem {
  final String id;
  final String symbol;
  final String stockName;
  final String title;
  final String subtitle;
  final double changePercent;
  final bool isGain;
  final DateTime timestamp;
  bool isRead;

  AppNotificationItem({
    required this.id,
    required this.symbol,
    required this.stockName,
    required this.title,
    required this.subtitle,
    required this.changePercent,
    required this.isGain,
    required this.timestamp,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'symbol': symbol,
      'stockName': stockName,
      'title': title,
      'subtitle': subtitle,
      'changePercent': changePercent,
      'isGain': isGain,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
    };
  }

  factory AppNotificationItem.fromJson(Map<String, dynamic> json) {
    return AppNotificationItem(
      id: (json['id'] ?? '').toString(),
      symbol: (json['symbol'] ?? '').toString(),
      stockName: (json['stockName'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      changePercent: (json['changePercent'] as num?)?.toDouble() ?? 0.0,
      isGain: json['isGain'] == true,
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      isRead: json['isRead'] == true,
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  static final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(2);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with WidgetsBindingObserver {
  static const String _storageKey = 'saved_notifications_list_v2';
  static const String _bannerDismissedKey = 'notifications_banner_dismissed_v1';
  static const String _hasSeededKey = 'notifications_has_seeded_v1';

  List<AppNotificationItem> _notifications = [];
  bool _bannerDismissed = false;
  bool _areNotificationsEnabled = true;
  bool _loading = true;
  List<StockModel> _allStocks = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkNotificationStatus();
    }
  }

  Future<void> _checkNotificationStatus() async {
    try {
      final enabled = await PushNotificationService.instance.areNotificationsEnabled();
      if (mounted) {
        setState(() {
          _areNotificationsEnabled = enabled;
        });
      }
    } catch (_) {}
  }

  Future<void> _handleActivateNotifications() async {
    final isAlreadyGranted = await PushNotificationService.instance.areNotificationsEnabled();
    if (isAlreadyGranted) {
      if (mounted) {
        setState(() => _areNotificationsEnabled = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'الإشعارات مفعلة بالفعل في إعدادات الهاتف',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Tajawal'),
            ),
            backgroundColor: Color(0xFF16A34A),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final granted = await PushNotificationService.instance.requestNotificationPermission();
    if (granted) {
      if (mounted) {
        setState(() => _areNotificationsEnabled = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم تفعيل الإشعارات بنجاح',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Tajawal'),
            ),
            backgroundColor: Color(0xFF16A34A),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    if (mounted) {
      _showNotificationSettingsBottomSheet();
    }
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadBannerState(),
      _checkNotificationStatus(),
      _loadNotifications(),
    ]);
    _loadStocksInBackground();
  }

  Future<void> _loadBannerState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _bannerDismissed = prefs.getBool(_bannerDismissedKey) ?? false;
        });
      }
    } catch (_) {}
  }

  Future<void> _dismissBanner() async {
    setState(() {
      _bannerDismissed = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_bannerDismissedKey, true);
    } catch (_) {}
  }

  Future<void> _loadNotifications() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasSeeded = prefs.getBool(_hasSeededKey) ?? false;
      final rawList = prefs.getStringList(_storageKey);

      if (rawList != null) {
        final list = <AppNotificationItem>[];
        for (final item in rawList) {
          try {
            final decoded = jsonDecode(item);
            if (decoded is Map<String, dynamic>) {
              list.add(AppNotificationItem.fromJson(decoded));
            }
          } catch (_) {}
        }
        _notifications = list;
      } else if (!hasSeeded) {
        // Seed default initial notifications matching Image 3 & 4 only on first launch
        await prefs.setBool(_hasSeededKey, true);
        final now = DateTime.now();
        _notifications = [
          AppNotificationItem(
            id: 'notif_1',
            symbol: 'EGX:COMI',
            stockName: 'البنك التجاري الدولي',
            title: 'وصل COMI إلى هدفك',
            subtitle: 'التجاري الدولي أعلى من 24.00',
            changePercent: 24.50,
            isGain: true,
            timestamp: now.subtract(const Duration(minutes: 12)),
            isRead: false,
          ),
          AppNotificationItem(
            id: 'notif_2',
            symbol: 'EGX:ALEX',
            stockName: 'الاسكندرية للأسمنت',
            title: 'انخفض ALEX إلى هدفك',
            subtitle: 'الاسكندرية للأسمنت أقل من 22.00',
            changePercent: -21.21,
            isGain: false,
            timestamp: now.subtract(const Duration(hours: 2)),
            isRead: false,
          ),
          AppNotificationItem(
            id: 'notif_3',
            symbol: 'EGX:APPC',
            stockName: 'أبوقير للأسمدة',
            title: 'انخفض APPC إلى هدفك',
            subtitle: 'أبوقير للأسمدة أقل من 1.50',
            changePercent: -1.44,
            isGain: false,
            timestamp: now.subtract(const Duration(days: 1)).copyWith(hour: 13, minute: 15),
            isRead: true,
          ),
          AppNotificationItem(
            id: 'notif_4',
            symbol: 'EGX:TMGH',
            stockName: 'طلعت مصطفى',
            title: 'وصل TMGH إلى هدفك',
            subtitle: 'طلعت مصطفى أعلى من 80.00',
            changePercent: -1.44,
            isGain: false,
            timestamp: DateTime(2026, 10, 27, 11, 40),
            isRead: true,
          ),
        ];
        await _saveNotificationsList();
      } else {
        _notifications = [];
      }
    } catch (_) {
    } finally {
      _updateUnreadCount();
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _deleteNotification(AppNotificationItem item) async {
    setState(() {
      _notifications.removeWhere((n) => n.id == item.id);
    });
    _updateUnreadCount();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hasSeededKey, true);
    } catch (_) {}
    await _saveNotificationsList();
  }

  Future<void> _saveNotificationsList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stringList = _notifications.map((n) => jsonEncode(n.toJson())).toList();
      await prefs.setStringList(_storageKey, stringList);
    } catch (_) {}
  }

  void _updateUnreadCount() {
    final count = _notifications.where((n) => !n.isRead).length;
    NotificationsScreen.unreadCountNotifier.value = count;
  }

  Future<void> _loadStocksInBackground() async {
    try {
      final stocks = await StockService.getStocksList();
      if (mounted) {
        setState(() {
          _allStocks = stocks;
        });
      }
    } catch (_) {}
  }

  Future<void> _markAllAsRead() async {
    setState(() {
      for (final item in _notifications) {
        item.isRead = true;
      }
    });
    _updateUnreadCount();
    await _saveNotificationsList();
  }

  Future<void> _showClearAllConfirmDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'مسح جميع الإشعارات',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: Color(0xFF111827),
            ),
          ),
          content: const Text(
            'هل أنت متأكد من رغبتك في حذف جميع الإشعارات؟ لن تتمكن من استرجاعها بعد الحذف.',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF4B5563),
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'إلغاء',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                'مسح',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _notifications.clear();
      });
      _updateUnreadCount();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_hasSeededKey, true);
      } catch (_) {}
      await _saveNotificationsList();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم مسح جميع الإشعارات بنجاح',
              style: TextStyle(fontFamily: 'Tajawal'),
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _onNotificationTap(AppNotificationItem item) async {
    if (!item.isRead) {
      setState(() {
        item.isRead = true;
      });
      _updateUnreadCount();
      await _saveNotificationsList();
    }

    final cleanSymbol = item.symbol.replaceAll('EGX:', '').trim().toUpperCase();
    final matchedStock = _allStocks.firstWhere(
      (s) => s.symbol.toUpperCase().contains(cleanSymbol) || s.id.toUpperCase() == cleanSymbol,
      orElse: () => StockModel(
        id: cleanSymbol,
        symbol: item.symbol,
        name: item.stockName,
        arabicName: item.stockName,
        price: 24.50,
        change: 0.99,
        changePercent: item.changePercent,
      ),
    );

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => StockDetailScreen(stock: matchedStock)),
      );
    }
  }

  // ==========================================
  // BOTTOM SHEET (Image 2)
  // ==========================================

  void _showNotificationSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isIos = Platform.isIOS;
        final systemName = isIos ? 'الآيفون' : 'الهاتف';

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top drag pill handle
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Title
                Text(
                  'فعّل الإشعارات من إعدادات $systemName',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 17.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),

                const SizedBox(height: 8),

                // Subtitle
                const Text(
                  'سننقلك إلى الإعدادات لتفعيلها، ثم ارجع إلى التطبيق.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF4B5563),
                  ),
                ),

                const SizedBox(height: 22),

                // Step 1
                Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFFEE2E2),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '1',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'اختر "الإشعارات"',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Step 2
                Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFFEE2E2),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '2',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'فعّل "السماح بالإشعارات"',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 26),

                // Red Primary Button: فتح الإعدادات
                InkWell(
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      await AppSettings.openAppSettings(type: AppSettingsType.notification);
                    } catch (_) {
                      try {
                        await AppSettings.openAppSettings();
                      } catch (_) {
                        try {
                          final uri = Uri.parse(isIos ? 'app-settings:' : 'package:com.almurakib.egyptappstocks');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                          }
                        } catch (_) {}
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: double.infinity,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'فتح الإعدادات',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Secondary Button: لاحقاً
                InkWell(
                  onTap: () => Navigator.pop(ctx),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: double.infinity,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: const Text(
                      'لاحقاً',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
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

  // ==========================================
  // BUILD METHOD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFFEFEFE),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const ChevronRightIcon(
              color: Color(0xFF374151),
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
          title: const Text(
            'الإشعارات',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 17.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          actions: [
            if (_notifications.isNotEmpty && unreadCount > 0)
              TextButton(
                onPressed: _markAllAsRead,
                child: const Text(
                  'قراءة الكل',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ),
            if (_notifications.isNotEmpty)
              IconButton(
                onPressed: _showClearAllConfirmDialog,
                tooltip: 'مسح جميع الإشعارات',
                icon: const Icon(
                  Icons.delete_sweep_outlined,
                  color: Color(0xFF64748B),
                  size: 22,
                ),
              ),
            const SizedBox(width: 4),
          ],
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFDC2626), strokeWidth: 2),
              )
            : _notifications.isEmpty
                ? _buildEmptyState()
                : _buildNotificationsList(),
      ),
    );
  }

  // ==========================================
  // STATE A: EMPTY STATE (Image 1)
  // ==========================================

  Widget _buildEmptyState() {
    return Column(
      children: [
        if (!_bannerDismissed && !_areNotificationsEnabled) _buildWarningBanner(),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Circular Grey Bell Icon
                  Container(
                    width: 68,
                    height: 68,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFE2E8F0),
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/icons/Vector (10).png',
                        width: 32,
                        height: 32,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Title
                  const Text(
                    'لا توجد إشعارات',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Subtitle
                  const Text(
                    'ستظهر هنا عند وصول سعر أي سهم إلى هدفك.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),

                  const SizedBox(height: 26),

                  // Red Button: + إنشاء تنبيه سعر
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PriceAlertsScreen()),
                      );
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFC1121F),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '+ إنشاء تنبيه سعر',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // STATE B: NOTIFICATIONS LIST (Image 3 & 4)
  // ==========================================

  Widget _buildNotificationsList() {
    final now = DateTime.now();

    // Grouping: اليوم, أمس, أقدم
    final todayItems = <AppNotificationItem>[];
    final yesterdayItems = <AppNotificationItem>[];
    final olderItems = <AppNotificationItem>[];

    for (final item in _notifications) {
      final diff = now.difference(item.timestamp);
      final isSameDay = now.year == item.timestamp.year &&
          now.month == item.timestamp.month &&
          now.day == item.timestamp.day;

      if (isSameDay || diff.inHours < 24 && diff.inDays == 0) {
        todayItems.add(item);
      } else if (diff.inDays <= 2) {
        yesterdayItems.add(item);
      } else {
        olderItems.add(item);
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // 1. Warning Banner (Image 3)
        if (!_bannerDismissed && !_areNotificationsEnabled) _buildWarningBanner(),

        // 2. Section: اليوم
        if (todayItems.isNotEmpty) _buildSection(title: 'اليوم', items: todayItems),

        // 3. Section: أمس
        if (yesterdayItems.isNotEmpty) _buildSection(title: 'أمس', items: yesterdayItems),

        // 4. Section: أقدم
        if (olderItems.isNotEmpty) _buildSection(title: 'أقدم', items: olderItems),
      ],
    );
  }

  // ==========================================
  // WARNING BANNER (Image 3)
  // ==========================================

  Widget _buildWarningBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5), width: 1.0),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Red bell outline icon
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.notifications_none_rounded,
              color: Color(0xFFDC2626),
              size: 20,
            ),
          ),

          const SizedBox(width: 10),

          // Message & Action
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'الإشعارات متوقفة، لن تصلك تنبيهات الأسعار.',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: _handleActivateNotifications,
                  child: const Text(
                    'تفعيل',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Dismiss X Button
          InkWell(
            onTap: _dismissBanner,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.close_rounded,
                size: 18,
                color: Color(0xFF94A3B8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // GROUPED SECTION BUILDER
  // ==========================================

  Widget _buildSection({
    required String title,
    required List<AppNotificationItem> items,
  }) {
    final hasUnread = items.any((n) => !n.isRead);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 8, right: 16, left: 16),
          child: Text(
            title,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
          ),
        ),

        // Section Card Container
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: hasUnread ? const Color(0xFFFEF2F2) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasUnread ? const Color(0xFFFEE2E2) : const Color(0xFFE5E7EB),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isLast = index == items.length - 1;

              return Column(
                children: [
                  Dismissible(
                    key: Key('notif_${item.id}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      color: const Color(0xFFDC2626),
                      child: const Icon(Icons.delete_outline, color: Colors.white),
                    ),
                    onDismissed: (_) => _deleteNotification(item),
                    child: _buildNotificationItemRow(item),
                  ),
                  if (!isLast)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: hasUnread ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9),
                    ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // NOTIFICATION ITEM ROW
  // ==========================================

  Widget _buildNotificationItemRow(AppNotificationItem item) {
    final isGain = item.isGain;
    final changeSign = item.changePercent >= 0 ? '+' : '';
    final changeText = '$changeSign${item.changePercent.toStringAsFixed(2)}%';

    return InkWell(
      onTap: () => _onNotificationTap(item),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          textDirection: TextDirection.rtl,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Right: Logo Container + Unread Red Dot Indicator
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  alignment: Alignment.center,
                  child: _buildStockLogo(item.symbol),
                ),
                if (!item.isRead)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFDC2626),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(width: 12),

            // 2. Middle: Title, Subtitle, Time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formatTime(item.timestamp),
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // 3. Left: Change Percentage Pill Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isGain ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isGain ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
                    size: 15,
                    color: isGain ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                  ),
                  Text(
                    changeText,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: isGain ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // RELATIVE TIME FORMATTER
  // ==========================================

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 60) {
      final mins = diff.inMinutes.clamp(1, 59);
      return 'منذ $mins دقيقة';
    } else if (diff.inHours < 24 && now.day == time.day) {
      if (diff.inHours == 1) return 'منذ ساعة';
      if (diff.inHours == 2) return 'منذ ساعتين';
      if (diff.inHours <= 10) return 'منذ ${diff.inHours} ساعات';
      return 'منذ ${diff.inHours} ساعة';
    } else if (diff.inDays <= 2 && now.day - time.day == 1) {
      final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
      final period = time.hour >= 12 ? 'م' : 'ص';
      final min = time.minute.toString().padLeft(2, '0');
      final hourStr = hour.toString().padLeft(2, '0');
      return 'أمس . $hourStr:$min $period';
    } else {
      final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
      final period = time.hour >= 12 ? 'م' : 'ص';
      final min = time.minute.toString().padLeft(2, '0');
      final hourStr = hour.toString().padLeft(2, '0');
      final day = time.day.toString().padLeft(2, '0');
      final month = time.month.toString().padLeft(2, '0');
      return '$hourStr:$min $period . $day/$month/${time.year}';
    }
  }

  // ==========================================
  // LOGO BUILDER
  // ==========================================

  Widget _buildStockLogo(String symbol) {
    final sym = symbol.toUpperCase();

    // 1. COMI (Commercial International Bank)
    if (sym.contains('COMI')) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF003B70),
            borderRadius: BorderRadius.circular(5),
          ),
          child: const Text(
            'CIB',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
      );
    }

    // 2. ALEX (Alexandria Cement / Amreyah)
    if (sym.contains('ALEX') || sym.contains('AMR')) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'AC',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: Color(0xFF0F172A),
                height: 1.0,
              ),
            ),
            Text(
              'AMREYAH CEMENT',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.w800,
                fontSize: 4.5,
                color: Color(0xFF64748B),
                height: 1.0,
              ),
            ),
            Text(
              'أسمنت العامرية',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.w700,
                fontSize: 4.5,
                color: Color(0xFF0F172A),
                height: 1.0,
              ),
            ),
          ],
        ),
      );
    }

    // 3. APPC (Abu Qir Fertilizers)
    if (sym.contains('APPC') || sym.contains('ABUK')) {
      return Center(
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF1D4ED8), width: 1.5),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.factory_rounded, size: 14, color: Color(0xFF1D4ED8)),
              Text(
                'أبوقير',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1D4ED8),
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 4. TMGH (Talaat Moustafa Group)
    if (sym.contains('TMGH') || sym.contains('TMG')) {
      return const Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.business_rounded, size: 12, color: Color(0xFFB45309)),
            SizedBox(width: 2),
            Text(
              'TMG',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.w900,
                fontSize: 11,
                color: Color(0xFFB45309),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }

    // Fallback Monogram
    final raw = sym.contains(':') ? sym.split(':').last : sym;
    final initials = raw.length >= 2 ? raw.substring(0, 2) : raw;

    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          fontFamily: 'Tajawal',
          fontWeight: FontWeight.w900,
          color: Color(0xFFDC2626),
          fontSize: 13,
        ),
      ),
    );
  }
}
