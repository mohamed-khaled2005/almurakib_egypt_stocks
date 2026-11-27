import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/managed_app_user.dart';
import '../models/remote_ui_config_model.dart';
import '../providers/app_manager_provider.dart';
import '../widgets/chevron_left_icon.dart';
import 'account_screen.dart';
import 'auth_screen.dart';
import 'contact_screen.dart';
import 'currency_converter_screen.dart';
import 'educational_content_screen.dart';
import 'our_apps_screen.dart';
import 'price_alerts_screen.dart';
import 'profile_completion_screen.dart';
import 'stock_comparison_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_use_screen.dart';
import 'disclaimer_screen.dart';

class MoreScreen extends StatelessWidget {
  final ValueChanged<int>? onNavigateToTab;
  final int? allStocksTabIndex;
  final int? favoritesTabIndex;
  final int? indicesTabIndex;
  final int? educationTabIndex;
  final int? ourAppsTabIndex;
  final int? aboutTabIndex;
  final int? contactTabIndex;
  final int? accountTabIndex;

  const MoreScreen({
    super.key,
    this.onNavigateToTab,
    this.allStocksTabIndex,
    this.favoritesTabIndex,
    this.indicesTabIndex,
    this.educationTabIndex,
    this.ourAppsTabIndex,
    this.aboutTabIndex,
    this.contactTabIndex,
    this.accountTabIndex,
  });

  String _getUserInitials(ManagedAppUser? user) {
    if (user == null) return 'م';
    final name = (user.fullName ?? '').trim();
    if (name.isEmpty) {
      final email = user.email.trim();
      if (email.isNotEmpty) return email[0].toUpperCase();
      return 'م';
    }
    final parts =
        name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts.first[0]} ${parts.last[0]}';
    }
    return parts.first.length >= 2 ? parts.first.substring(0, 2) : parts.first;
  }

  double _calculateProfileProgress(ManagedAppUser? user) {
    if (user == null) return 0.0;
    if (user.hasPhoneNumber && user.hasTradingStatus && user.hasCountry) {
      return 1.0;
    }
    if (!user.hasPhoneNumber && !user.hasTradingStatus) {
      return 0.60;
    }
    return 0.80;
  }

  void _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _confirmLogout(
      BuildContext context, AppManagerProvider manager) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'تسجيل الخروج',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontWeight: FontWeight.w900,
              fontSize: 17,
              color: Color(0xFF111827),
            ),
          ),
          content: const Text(
            'هل أنت متأكد من رغبتك في تسجيل الخروج من حسابك؟',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 14,
              color: Color(0xFF4B5563),
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
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
              onPressed: () => Navigator.pop(dialogCtx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC1121F),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'تسجيل الخروج',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await manager.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<AppManagerProvider>();
    final isAuthenticated = manager.isAuthenticated;
    final user = manager.user;
    final progress = _calculateProfileProgress(user);
    final isProfileComplete = progress >= 1.0;

    return Scaffold(
      backgroundColor: const Color(0xFFFEFEFE),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // ==========================================
                // 1. Top User / Profile Card (Matches Image 4)
                // ==========================================
                if (!isAuthenticated)
                  _buildGuestCard(context)
                else if (isProfileComplete)
                  _buildCompleteProfileCard(context, user)
                else
                  _buildIncompleteProfileCard(context, user, progress),

                const SizedBox(height: 18),

                // ==========================================
                // 2. Section: أدوات السوق
                // ==========================================
                _buildSectionTitle('أدوات السوق'),
                const SizedBox(height: 8),
                _buildMenuCard([
                  _MenuItem(
                    title: 'تنبيهات الأسعار',
                    assetIcon: 'assets/icons/Vector (10).png',
                    onTap: () {
                      if (isAuthenticated) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PriceAlertsScreen(),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AuthScreen()),
                        );
                      }
                    },
                  ),
                  _MenuItem(
                    title: 'مقارنة سهمين',
                    assetIcon: 'assets/icons/Vector (11).png',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const StockComparisonScreen(),
                        ),
                      );
                    },
                  ),
                  _MenuItem(
                    title: 'محول العملات',
                    assetIcon: 'assets/icons/Vector (12).png',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CurrencyConverterScreen(),
                        ),
                      );
                    },
                  ),
                ]),

                const SizedBox(height: 18),

                // ==========================================
                // 3. Section: المراقب (Matches Image 4: 3 items)
                // ==========================================
                _buildSectionTitle('المراقب'),
                const SizedBox(height: 8),
                _buildMenuCard([
                  _MenuItem(
                    title: 'المحتوى التعليمي',
                    assetIcon: 'assets/icons/Vector (13).png',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EducationalContentScreen(),
                        ),
                      );
                    },
                  ),
                  _MenuItem(
                    title: 'تطبيقاتنا',
                    assetIcon: 'assets/icons/Vector (14).png',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const OurAppsScreen(),
                        ),
                      );
                    },
                  ),
                  _MenuItem(
                    title: 'اتصل بنا',
                    assetIcon: 'assets/icons/energy-icons_mail-20-bold.png',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ContactScreen(),
                        ),
                      );
                    },
                  ),
                ]),

                const SizedBox(height: 18),

                // ==========================================
                // 4. Section: قانوني (Matches Image 4: Navigates to full pages)
                // ==========================================
                _buildSectionTitle('قانوني'),
                const SizedBox(height: 8),
                _buildMenuCard([
                  _MenuItem(
                    title: 'سياسة الخصوصية',
                    assetIcon: 'assets/icons/Vector (15).png',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PrivacyPolicyScreen(),
                        ),
                      );
                    },
                  ),
                  _MenuItem(
                    title: 'شروط الاستخدام',
                    assetIcon: 'assets/icons/carbon_document.png',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TermsOfUseScreen(),
                        ),
                      );
                    },
                  ),
                  _MenuItem(
                    title: 'إخلاء المسؤولية',
                    assetIcon: 'assets/icons/Group.png',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DisclaimerScreen(),
                        ),
                      );
                    },
                  ),
                ]),

                const SizedBox(height: 18),

                // ==========================================
                // 5. Section: تابعنا (Social Icons - Matches Image 4)
                // ==========================================
                _buildSocialSection(manager),

                // ==========================================
                // 6. Logout Button (Only when authenticated)
                // ==========================================
                if (isAuthenticated) ...[
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () => _confirmLogout(context, manager),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        textDirection: TextDirection.rtl,
                        children: [
                          Text(
                            'تسجيل الخروج',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFC1121F),
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.logout_rounded,
                            size: 18,
                            color: Color(0xFFC1121F),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // ==========================================
                // 7. Copyright Footer
                // ==========================================
                const Center(
                  child: Text(
                    'جميع الحقوق محفوظة لمنصة المراقب 2026',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
          if (manager.menuCta != null && manager.menuCta!.isUsable)
            Container(
              color: const Color(0xFFFEFEFE),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: _MoreMenuCtaBanner(menuCta: manager.menuCta!),
            ),
        ],
      ),
    );
  }

  // ==========================================
  // Guest Card (Image 3)
  // ==========================================
  Widget _buildGuestCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            textDirection: TextDirection.rtl,
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFE2E8F0),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: Color(0xFF64748B),
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Title and Subtitle
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'أهلاً بك في المراقب',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'سجل دخولك لحفظ مفضلتك وتنبيهات أسعارك.',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Primary Button: تسجيل الدخول
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AuthScreen()),
              );
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFC1121F),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'تسجيل الدخول',
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

          // Secondary Outlined Button: إنشاء حساب جديد
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AuthScreen(),
                ),
              );
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Text(
                'إنشاء حساب جديد',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // Complete Profile Card (Image 1)
  // ==========================================
  Widget _buildCompleteProfileCard(
      BuildContext context, ManagedAppUser? user) {
    final initials = _getUserInitials(user);
    final name = (user?.fullName ?? '').trim().isNotEmpty
        ? user!.fullName!
        : 'مستخدم المراقب';
    final email = user?.email ?? '';

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AccountScreen()),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.015),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            // Circular Avatar with Initials
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFFE2E8F0),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF475569),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Middle: Name, Email, and Green Badge
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'بياناتك مكتملة',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: Color(0xFF16A34A),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Left Chevron
            const ChevronLeftIcon(
              size: 20,
              color: Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // Incomplete Profile Card (Image 2)
  // ==========================================
  Widget _buildIncompleteProfileCard(
    BuildContext context,
    ManagedAppUser? user,
    double progress,
  ) {
    final initials = _getUserInitials(user);
    final name = (user?.fullName ?? '').trim().isNotEmpty
        ? user!.fullName!
        : 'مستخدم المراقب';
    final email = user?.email ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Row: Avatar, Name, Email, Chevron
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AccountScreen()),
              );
            },
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE2E8F0),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Name & Email
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),

                const ChevronLeftIcon(
                  size: 20,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Completion Section
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const ProfileCompletionScreen(mandatory: false),
                ),
              );
            },
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  textDirection: TextDirection.rtl,
                  children: [
                    const Text(
                      'أكمل بيانات حسابك',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}% مكتمل',
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor:
                        const AlwaysStoppedAnimation(Color(0xFFC1121F)),
                  ),
                ),

                const SizedBox(height: 8),

                const Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'رقم الهاتف ونوع اهتمامك بالتداول (اختياري)',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 11.5,
                      color: Color(0xFF64748B),
                    ),
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
  // Section Title
  // ==========================================
  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 14.5,
          fontWeight: FontWeight.w900,
          color: Color(0xFF1E293B),
        ),
      ),
    );
  }

  // ==========================================
  // Menu Card Container
  // ==========================================
  Widget _buildMenuCard(List<_MenuItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isLast = index == items.length - 1;

          return Column(
            children: [
              InkWell(
                onTap: item.onTap,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    textDirection: TextDirection.rtl,
                    children: [
                      // Right: Icon & Title
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Image.asset(
                              item.assetIcon,
                              width: 18,
                              height: 18,
                              color: const Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),

                      // Left: Chevron
                      const ChevronLeftIcon(
                        size: 20,
                        color: Color(0xFF94A3B8),
                      ),
                    ],
                  ),
                ),
              ),
              if (!isLast)
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFF1F5F9),
                ),
            ],
          );
        }),
      ),
    );
  }

  // ==========================================
  // Section: تابعنا (Social Media Section)
  // ==========================================
  Widget _buildSocialSection(AppManagerProvider manager) {
    final links = manager.socialLinks;

    String getUrlForPlatform(String platform, String fallback) {
      for (final link in links) {
        if (link.platform.trim().toLowerCase() == platform.toLowerCase()) {
          return link.url;
        }
      }
      return fallback;
    }

    final socialPlatforms = [
      {
        'platform': 'whatsapp',
        'asset': 'assets/icons/Vector (1).png',
        'url': getUrlForPlatform(
          'whatsapp',
          'https://wa.me/201000000000',
        ),
      },
      {
        'platform': 'instagram',
        'asset': 'assets/icons/Vector (2).png',
        'url': getUrlForPlatform(
          'instagram',
          'https://instagram.com/almurakib',
        ),
      },
      {
        'platform': 'x',
        'asset': 'assets/icons/Vector (3).png',
        'url': getUrlForPlatform(
          'x',
          'https://x.com/almurakib',
        ),
      },
      {
        'platform': 'facebook',
        'asset': 'assets/icons/Vector (4).png',
        'url': getUrlForPlatform(
          'facebook',
          'https://facebook.com/almurakib',
        ),
      },
      {
        'platform': 'telegram',
        'asset': 'assets/icons/Vector (5).png',
        'url': getUrlForPlatform(
          'telegram',
          'https://t.me/almurakib',
        ),
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          const Text(
            'تابعنا',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
          ),
          const Spacer(),
          Row(
            textDirection: TextDirection.rtl,
            children: socialPlatforms.map((item) {
              final asset = item['asset'] as String;
              final url = item['url'] as String;

              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: InkWell(
                  onTap: () => _openUrl(url),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    alignment: Alignment.center,
                    child: Image.asset(
                      asset,
                      width: 18,
                      height: 18,
                      color: const Color(0xFF334155),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _MenuItem {
  final String title;
  final String assetIcon;
  final VoidCallback onTap;

  const _MenuItem({
    required this.title,
    required this.assetIcon,
    required this.onTap,
  });
}

class _MoreMenuCtaBanner extends StatefulWidget {
  final ManagedMenuCta menuCta;

  const _MoreMenuCtaBanner({required this.menuCta});

  @override
  State<_MoreMenuCtaBanner> createState() => _MoreMenuCtaBannerState();
}

class _MoreMenuCtaBannerState extends State<_MoreMenuCtaBanner> {
  String? _trackedKey;

  Color? _parseHexColor(String? raw) {
    final cleaned = (raw ?? '').trim().replaceAll('#', '');
    if (cleaned.length == 6) {
      final val = int.tryParse('FF$cleaned', radix: 16);
      if (val != null) return Color(val);
    } else if (cleaned.length == 8) {
      final val = int.tryParse(cleaned, radix: 16);
      if (val != null) return Color(val);
    }
    return null;
  }

  void _trackImpressionIfNeeded() {
    final key = '${widget.menuCta.label}_${widget.menuCta.url}';
    if (_trackedKey == key) return;
    _trackedKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppManagerProvider>().trackMenuCta(
            eventType: 'impression',
            label: widget.menuCta.label,
            url: widget.menuCta.url,
          );
    });
  }

  Future<void> _onTap() async {
    context.read<AppManagerProvider>().trackMenuCta(
          eventType: 'click',
          label: widget.menuCta.label,
          url: widget.menuCta.url,
        );
    final uri = Uri.tryParse(widget.menuCta.url.trim());
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    _trackImpressionIfNeeded();

    final backgroundColor =
        _parseHexColor(widget.menuCta.backgroundColor) ??
            const Color(0xFFC1121F);
    final textColor =
        _parseHexColor(widget.menuCta.textColor) ?? Colors.white;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withValues(alpha: 0.22),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.open_in_new_rounded,
                    color: textColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.menuCta.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_outward_rounded,
                  color: textColor,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
