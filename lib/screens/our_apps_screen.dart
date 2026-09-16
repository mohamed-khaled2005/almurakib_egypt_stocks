import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../animations/fade_animation.dart';
import '../animations/slide_animation.dart';
import '../core/utils/constants.dart';
import '../models/remote_ui_config_model.dart';
import '../providers/app_manager_provider.dart';
import '../widgets/app_section_header.dart';

Color get _egyptAccent => AppColors.primaryBlue;

BoxDecoration buildCardDecoration({
  bool withShadow = true,
  Border? border,
  Gradient? gradient,
  Color? color,
  double radius = 22,
}) {
  return BoxDecoration(
    color: color,
    gradient: gradient,
    borderRadius: BorderRadius.circular(radius),
    border: border ??
        Border.all(
          color: Colors.black.withValues(alpha: 0.06),
        ),
    boxShadow: withShadow
        ? <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 14,
              spreadRadius: 0.4,
            ),
          ]
        : <BoxShadow>[],
  );
}

class OurAppsScreen extends StatelessWidget {
  const OurAppsScreen({super.key});

  static const List<_AppItem> _defaultApps = <_AppItem>[
    _AppItem(
      name: 'مراقب الاسهم الاماراتية',
      playStoreUrl:
          'https://play.google.com/store/apps/details?id=com.almurakib.emiratesappstocks',
      appStoreUrl:
          'https://apps.apple.com/sg/app/%D9%85%D8%B1%D8%A7%D9%82%D8%A8-%D8%A7%D9%84%D8%A7%D8%B3%D9%87%D9%85-%D8%A7%D9%84%D8%A7%D9%85%D8%A7%D8%B1%D8%A7%D8%AA%D9%8A%D8%A9/id6759033698',
      imageUrl:
          'https://play-lh.googleusercontent.com/ndvDmG-MD_KFP1ejcUg7hfsQOZh52okON9TeHVYg5WtjE5iUy6vbJfaaosQ5zEIx0RO3t4ac_uBCxzPDWNL7Qg=w480-h960-rw',
    ),
    _AppItem(
      name: 'مراقب الفضة',
      playStoreUrl:
          'https://play.google.com/store/apps/details?id=com.almurakib.silvermonitor',
      appStoreUrl:
          'https://apps.apple.com/sg/app/%D9%85%D8%B1%D8%A7%D9%82%D8%A8-%D8%A7%D9%84%D9%81%D8%B6%D8%A9/id6759033737',
      imageUrl:
          'https://play-lh.googleusercontent.com/yLohp0qB8efPmZnr4eUlNtrUUboyV7qXcm9aRWoFSM0n7-Zeb9Br4GhuHiGZSI_6flWXOqu9Vn6VT36mLfUp=w480-h960-rw',
    ),
    _AppItem(
      name: 'مراقب الاسهم الامريكية',
      playStoreUrl:
          'https://play.google.com/store/apps/details?id=com.almurakib.usaappstocks',
      appStoreUrl:
          'https://apps.apple.com/sg/app/%D9%85%D8%B1%D8%A7%D9%82%D8%A8-%D8%A7%D9%84%D8%A7%D8%B3%D9%87%D9%85-%D8%A7%D9%84%D8%A7%D9%85%D8%A7%D8%B1%D8%A7%D8%AA%D9%8A%D8%A9/id6759033724',
      imageUrl:
          'https://play-lh.googleusercontent.com/wqDKcI9Pga22rkZNzxssaiU7qVlk-36bd1EKHXV-greisW7XcQuqjdCBcm17QZVP8mgKs_-uwyvBgo6YXzRh2us=w480-h960-rw',
    ),
    _AppItem(
      name: 'مراقب الاسهم القطرية',
      playStoreUrl:
          'https://play.google.com/store/apps/details?id=com.almurakib.qatarappstocks',
      appStoreUrl:
          'https://apps.apple.com/sg/app/%D9%85%D8%B1%D8%A7%D9%82%D8%A8-%D8%A7%D9%84%D8%A7%D8%B3%D9%87%D9%85-%D8%A7%D9%84%D9%82%D8%B7%D8%B1%D9%8A/id6759033574',
      imageUrl:
          'https://play-lh.googleusercontent.com/rN4Htz4G-T7Y-5nVODMGNmmPE1vNRNsFBPQOlgYXp4-kwZMfrSKx-a0h-vRtMS9b19cx54Cfu_Y3psiVDXZ9XA4=w480-h960-rw',
    ),
    _AppItem(
      name: 'مراقب الذهب',
      playStoreUrl:
          'https://play.google.com/store/apps/details?id=com.almurakib.goldmonitor',
      appStoreUrl:
          'https://apps.apple.com/sg/app/%D9%85%D8%B1%D8%A7%D9%82%D8%A8-%D8%A7%D9%84%D8%B0%D9%87%D8%A8/id6759033545',
      imageUrl:
          'https://play-lh.googleusercontent.com/gEft1mhy5KD6GwMC9P6Ge-zJLb2fB72BIOmDmxfzB3rSETTix2wT4lEydIhSaZKLztjHiAQIkTbTYNWmCRK8VA=w480-h960-rw',
    ),
    _AppItem(
      name: 'مراقب البيتكوين',
      playStoreUrl:
          'https://play.google.com/store/apps/details?id=com.almurakib.bitcoin',
      appStoreUrl:
          'https://apps.apple.com/sg/app/%D9%85%D8%B1%D8%A7%D9%82%D8%A8-%D8%A7%D9%84%D8%A8%D9%8A%D8%AA%D9%83%D9%88%D9%8A%D9%86/id6759033381',
      imageUrl:
          'https://play-lh.googleusercontent.com/4QG34b9vQ7wVf3cR7q4kI_GvI1A_Q1_X1j_L1K_R1O1Q=w480-h960-rw',
    ),
    _AppItem(
      name: 'مراقب الكريبتو',
      playStoreUrl:
          'https://play.google.com/store/apps/details?id=com.almurakib.cryptomonitor',
      appStoreUrl:
          'https://apps.apple.com/sg/app/%D9%85%D8%B1%D8%A7%D9%82%D8%A8-%D8%A7%D9%84%D9%83%D8%B1%D9%8A%D8%A8%D8%AA%D9%88/id6759033381',
      imageUrl:
          'https://play-lh.googleusercontent.com/U4gMdj8FrCjKBT6n3Dw_7MpYnJCnvGISNPSkOw8leGaGkqiQ9ku5SM7uRJVT946DPP3IZqfOZmjAKlV2__cD-w=w480-h960-rw',
    ),
    _AppItem(
      name: 'مراقب العملات',
      playStoreUrl:
          'https://play.google.com/store/apps/details?id=com.almurakib.currencyexchange.app',
      appStoreUrl:
          'https://apps.apple.com/sg/app/%D9%85%D8%B1%D8%A7%D9%82%D8%A8-%D8%A7%D9%84%D8%B9%D9%85%D9%84%D8%A7%D8%AA/id6759033259',
      imageUrl:
          'https://play-lh.googleusercontent.com/BKkuz_2ZP_NG_KbfvBVpvebAYtPONoMpe5uLgzV_nFh8_9kjgL-4pC0WUk5sAuNlcBfUaJ4HilQGJO3o55iGxA=w480-h960-rw',
    ),
    _AppItem(
      name: 'مراقب الاسهم السعودية',
      playStoreUrl:
          'https://play.google.com/store/apps/details?id=com.almurakib.saudiappstocks',
      appStoreUrl:
          'https://apps.apple.com/sg/app/%D9%85%D8%B1%D8%A7%D9%82%D8%A8-%D8%A7%D9%84%D8%A7%D8%B3%D9%87%D9%85-%D8%A7%D9%84%D8%B3%D8%B9%D9%88%D8%AF%D9%8A%D8%A9/id6759033548',
      imageUrl:
          'https://play-lh.googleusercontent.com/mgW7dsDFDi8_fgwuFyUmgdzxGBnva3vDqDcwAvN7lRCK2-QzA1hhjiwk_wuR6z0n3xYfxCvhfUQf5rySXlPj=w480-h960-rw',
    ),
    _AppItem(
      name: 'صراف',
      playStoreUrl:
          'https://play.google.com/store/apps/details?id=com.almurakib.sarraf&hl=en',
      appStoreUrl:
          'https://apps.apple.com/sg/app/%D8%B5%D8%B1-%D8%A7%D9%81/id6766881553',
      imageUrl:
          'https://play-lh.googleusercontent.com/uKqr-V9BKzafR0liM9I9-PoKLoqq2xOuzuyA-WTQlrsYlpOm2ICwPgdw3FMxrhpZQraVP7pl9e8lY1dK0UXlIg=w480-h960-rw',
      appStoreImageUrl:
          'https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/88/0f/b2/880fb29b-ba50-bfb0-6bcc-cf80521130c3/Placeholder.mill/400x400bb-75.webp',
    ),
    _AppItem(
      name: 'مراقب الوقود',
      playStoreUrl:
          'https://play.google.com/store/apps/details?id=com.almurakib.fuel&hl=en',
      appStoreUrl:
          'https://apps.apple.com/sg/app/%D9%85%D8%B1%D8%A7%D9%82%D8%A8-%D8%A7%D9%84%D9%88%D9%82%D9%88%D8%AF/id6768018888',
      imageUrl:
          'https://play-lh.googleusercontent.com/8He7Qica1oC0F5VvbUW-fchAEyjqn1VlGVjT1LFmM9aMFsYznn1IQggKVoWyyM-gFqQh4SoA1UtkZTJ84ct6=w480-h960-rw',
      appStoreImageUrl:
          'https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/f8/2a/8b/f82a8b50-9bf0-b046-f76b-dcb6fd14d898/Placeholder.mill/400x400bb-75.webp',
    ),
  ];

  static EdgeInsets _pagePadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1200) {
      return const EdgeInsets.symmetric(horizontal: 48, vertical: 20);
    }
    if (width >= 800) {
      return const EdgeInsets.symmetric(horizontal: 28, vertical: 16);
    }
    return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
  }

  bool get _useAppStore =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  String get _storeLabel => _useAppStore ? 'App Store' : 'Google Play';

  TextStyle _paragraphStyle({Color? color}) {
    return AppTextStyles.bodySmall.copyWith(
      color: color ?? AppColors.textSecondary,
      fontWeight: FontWeight.w500,
      height: 1.55,
      letterSpacing: 0,
    );
  }

  List<_AppItem> _resolveApps(List<ManagedAppListing> managedApps) {
    if (managedApps.isEmpty) {
      return _defaultApps;
    }

    final mapped = managedApps
        .map(
          (app) => _AppItem(
            name: app.name,
            playStoreUrl: app.playStoreUrl ?? '',
            appStoreUrl: app.appStoreUrl ?? '',
            imageUrl: app.logoUrl,
          ),
        )
        .where((item) => item.hasUrlFor(_useAppStore))
        .toList();

    return mapped.isEmpty ? _defaultApps : mapped;
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<AppManagerProvider>();
    final useAppStore = _useAppStore;
    final storeLabel = _storeLabel;
    final apps = _resolveApps(manager.ourApps);

    return FadeAnimation(
      child: Center(
        child: SingleChildScrollView(
          padding: _pagePadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 6),
              const AppSectionHeader(
                title: 'تطبيقاتنا',
              ),
              const SizedBox(height: 16),
              SlideAnimation(child: _buildHeaderCard(storeLabel)),
              const SizedBox(height: 16),
              SlideAnimation(
                delay: const Duration(milliseconds: 160),
                child: _buildAppsGrid(
                  context,
                  apps: apps,
                  useAppStore: useAppStore,
                  storeLabel: storeLabel,
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(String storeLabel) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: buildCardDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFFFFFFFF), Color(0xFFFFFAFB)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        border: Border.all(color: _egyptAccent, width: 1.1),
        radius: 22,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: _egyptAccent.withValues(alpha: 0.55),
                width: 0.9,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.store_rounded,
                  size: 16,
                  color: _egyptAccent,
                ),
                const SizedBox(width: 6),
                Text(
                  storeLabel,
                  style: AppTextStyles.bodySmall.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'تطبيقات المراقب',
            style: AppTextStyles.headingSmall.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.15,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'يسرنا أن نقدم لكم مجموعة تطبيقاتنا الرسمية، اضغط على التطبيق للانتقال إلى صفحة التحميل على $storeLabel.',
            style: _paragraphStyle(),
          ),
        ],
      ),
    );
  }

  Widget _buildAppsGrid(
    BuildContext context, {
    required List<_AppItem> apps,
    required bool useAppStore,
    required String storeLabel,
  }) {
    if (apps.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: buildCardDecoration(color: Colors.white),
        child: Text(
          'لا توجد تطبيقات للعرض حالياً.',
          style: _paragraphStyle(),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 900
            ? 3
            : 2;

        final mainAxisExtent = constraints.maxWidth >= 650
            ? 150.0
            : constraints.maxWidth >= 520
                ? 156.0
                : 162.0;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: apps.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: mainAxisExtent,
          ),
          itemBuilder: (context, index) {
            final item = apps[index];
            return _MiniAppTile(
              item: item,
              storeLabel: storeLabel,
              storeIcon: useAppStore
                  ? Icons.apple_rounded
                  : Icons.play_circle_fill_rounded,
              accentColor: _egyptAccent,
              useAppStore: useAppStore,
              onTap: () => _openStore(context, item.urlFor(useAppStore)),
            );
          },
        );
      },
    );
  }

  Future<void> _openStore(BuildContext context, String url) async {
    final parsed = Uri.tryParse(url.trim());
    if (parsed == null || !parsed.hasScheme) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرابط غير صالح.')),
        );
      }
      return;
    }

    final ok = await launchUrl(parsed, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح الرابط الآن.')),
      );
    }
  }
}

class _AppItem {
  const _AppItem({
    required this.name,
    required this.playStoreUrl,
    required this.appStoreUrl,
    required this.imageUrl,
    this.appStoreImageUrl,
  });

  final String name;
  final String playStoreUrl;
  final String appStoreUrl;
  final String imageUrl;
  final String? appStoreImageUrl;

  bool hasUrlFor(bool useAppStore) =>
      (useAppStore ? appStoreUrl : playStoreUrl).trim().isNotEmpty;
  String urlFor(bool useAppStore) => useAppStore ? appStoreUrl : playStoreUrl;
  String imageUrlFor(bool useAppStore) =>
      useAppStore ? (appStoreImageUrl ?? imageUrl) : imageUrl;
}

class _MiniAppTile extends StatelessWidget {
  const _MiniAppTile({
    required this.item,
    required this.storeLabel,
    required this.storeIcon,
    required this.accentColor,
    required this.useAppStore,
    required this.onTap,
  });

  final _AppItem item;
  final String storeLabel;
  final IconData storeIcon;
  final Color accentColor;
  final bool useAppStore;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: buildCardDecoration(
        color: AppColors.cardDark,
        radius: 18,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _AppIcon(
                    url: item.imageUrlFor(useAppStore),
                    accentColor: accentColor,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      height: 1.2,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.24),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(storeIcon, size: 14, color: accentColor),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            storeLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: accentColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              height: 1,
                            ),
                          ),
                        ),
                      ],
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
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.url, required this.accentColor});

  final String url;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: accentColor.withValues(alpha: 0.22)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) {
              return child;
            }
            return Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) =>
              Icon(Icons.apps_outlined, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}