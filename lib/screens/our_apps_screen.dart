import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../animations/fade_animation.dart';
import '../animations/slide_animation.dart';
import '../core/utils/constants.dart';
import '../widgets/app_section_header.dart';

const Color _egyptAccent = AppColors.primaryBlue;

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

  static const List<_AppItem> _apps = <_AppItem>[
    _AppItem(
      name:
          '\u0645\u0631\u0627\u0642\u0628 \u0627\u0644\u0623\u0633\u0647\u0645 \u0627\u0644\u0625\u0645\u0627\u0631\u0627\u062a\u064a\u0629',
      playStoreUrl:
          'https://play.google.com/store/apps/details?id=com.almurakib.emiratesappstocks',
      appStoreUrl:
          'https://apps.apple.com/sg/app/%D9%85%D8%B1%D8%A7%D9%82%D8%A8-%D8%A7%D9%84%D8%A7%D8%B3%D9%87%D9%85-%D8%A7%D9%84%D8%A7%D9%85%D8%A7%D8%B1%D8%A7%D8%AA%D9%8A%D8%A9/id6759033698',
      imageUrl:
          'https://play-lh.googleusercontent.com/ndvDmG-MD_KFP1ejcUg7hfsQOZh52okON9TeHVYg5WtjE5iUy6vbJfaaosQ5zEIx0RO3t4ac_uBCxzPDWNL7Qg=w480-h960-rw',
    ),
    _AppItem(
      name: '\u0645\u0631\u0627\u0642\u0628 \u0627\u0644\u0641\u0636\u0629',
      playStoreUrl:
          'https://play.google.com/store/apps/details?id=com.almurakib.silvermonitor',
      appStoreUrl:
          'https://apps.apple.com/sg/app/%D9%85%D8%B1%D8%A7%D9%82%D8%A8-%D8%A7%D9%84%D9%81%D8%B6%D8%A9/id6759033737',
      imageUrl:
          'https://play-lh.googleusercontent.com/yLohp0qB8efPmZnr4eUlNtrUUboyV7qXcm9aRWoFSM0n7-Zeb9Br4GhuHiGZSI_6flWXOqu9Vn6VT36mLfUp=w480-h960-rw',
    ),
    _AppItem(
      name:
          '\u0645\u0631\u0627\u0642\u0628 \u0627\u0644\u0623\u0633\u0647\u0645 \u0627\u0644\u0623\u0645\u0631\u064a\u0643\u064a\u0629',
      playStoreUrl:
          'https://play.google.com/store/apps/details?id=com.almurakib.usaappstocks',
      appStoreUrl:
          'https://apps.apple.com/sg/app/%D9%85%D8%B1%D8%A7%D9%82%D8%A8-%D8%A7%D9%84%D8%A7%D8%B3%D9%87%D9%85-%D8%A7%D9%84%D8%A7%D9%85%D8%B1%D9%8A%D9%83%D9%8A%D8%A9/id6759033724',
      imageUrl:
          'https://play-lh.googleusercontent.com/wqDKcI9Pga22rkZNzxssaiU7qVlk-36bd1EKHXV-greisW7XcQuqjdCBcm17QZVP8mgKs_-uwyvBgo6YXzRh2us=w480-h960-rw',
    ),
    _AppItem(
      name:
          '\u0645\u0631\u0627\u0642\u0628 \u0627\u0644\u0623\u0633\u0647\u0645 \u0627\u0644\u0642\u0637\u0631\u064a\u0629',
      playStoreUrl:
          'https://play.google.com/store/apps/details?id=com.almurakib.qatarappstocks',
      appStoreUrl:
          'https://apps.apple.com/sg/app/%D9%85%D8%B1%D8%A7%D9%82%D8%A8-%D8%A7%D9%84%D8%A7%D8%B3%D9%87%D9%85-%D8%A7%D9%84%D9%82%D8%B7%D8%B1%D9%8A/id6759033574',
      imageUrl:
          'https://play-lh.googleusercontent.com/rN4Htz4G-T7Y-5nVODMGNmmPE1vNRNsFBPQOlgYXp4-kwZMfrSKx-a0h-vRtMS9b19cx54Cfu_Y3psiVDXZ9XA4=w480-h960-rw',
    ),
    _AppItem(
      name: '\u0645\u0631\u0627\u0642\u0628 \u0627\u0644\u0630\u0647\u0628',
      playStoreUrl:
          'https://play.google.com/store/apps/details?id=com.almurakib.goldmonitor',
      appStoreUrl:
          'https://apps.apple.com/sg/app/%D9%85%D8%B1%D8%A7%D9%82%D8%A8-%D8%A7%D9%84%D8%B0%D9%87%D8%A8/id6759033545',
      imageUrl:
          'https://play-lh.googleusercontent.com/gEft1mhy5KD6GwMC9P6Ge-zJLb2fB72BIOmDmxfzB3rSETTix2wT4lEydIhSaZKLztjHiAQIkTbTYNWmCRK8VA=w480-h960-rw',
    ),
    _AppItem(
      name:
          '\u0645\u0631\u0627\u0642\u0628 \u0627\u0644\u0643\u0631\u064a\u0628\u062a\u0648',
      playStoreUrl:
          'https://play.google.com/store/apps/details?id=com.almurakib.cryptomonitor',
      appStoreUrl:
          'https://apps.apple.com/sg/app/%D9%85%D8%B1%D8%A7%D9%82%D8%A8-%D8%A7%D9%84%D9%83%D8%B1%D9%8A%D8%A8%D8%AA%D9%88/id6759033381',
      imageUrl:
          'https://play-lh.googleusercontent.com/U4gMdj8FrCjKBT6n3Dw_7MpYnJCnvGISNPSkOw8leGaGkqiQ9ku5SM7uRJVT946DPP3IZqfOZmjAKlV2__cD-w=w480-h960-rw',
    ),
    _AppItem(
      name:
          '\u0645\u0631\u0627\u0642\u0628 \u0627\u0644\u0639\u0645\u0644\u0627\u062a',
      playStoreUrl:
          'https://play.google.com/store/apps/details?id=com.almurakib.currencyexchange.app',
      appStoreUrl:
          'https://apps.apple.com/sg/app/%D9%85%D8%B1%D8%A7%D9%82%D8%A8-%D8%A7%D9%84%D8%B9%D9%85%D9%84%D8%A7%D8%AA/id6759033259',
      imageUrl:
          'https://play-lh.googleusercontent.com/BKkuz_2ZP_NG_KbfvBVpvebAYtPONoMpe5uLgzV_nFh8_9kjgL-4pC0WUk5sAuNlcBfUaJ4HilQGJO3o55iGxA=w480-h960-rw',
    ),
    _AppItem(
      name:
          '\u0645\u0631\u0627\u0642\u0628 \u0627\u0644\u0623\u0633\u0647\u0645 \u0627\u0644\u0633\u0639\u0648\u062f\u064a\u0629',
      playStoreUrl:
          'https://play.google.com/store/apps/details?id=com.almurakib.saudiappstocks',
      appStoreUrl:
          'https://apps.apple.com/sg/app/%D9%85%D8%B1%D8%A7%D9%82%D8%A8-%D8%A7%D9%84%D8%A7%D8%B3%D9%87%D9%85-%D8%A7%D9%84%D8%B3%D8%B9%D9%88%D8%AF%D9%8A%D8%A9/id6759033548',
      imageUrl:
          'https://play-lh.googleusercontent.com/mgW7dsDFDi8_fgwuFyUmgdzxGBnva3vDqDcwAvN7lRCK2-QzA1hhjiwk_wuR6z0n3xYfxCvhfUQf5rySXlPj=w480-h960-rw',
    ),
    _AppItem(
      name:
          '\u0645\u0631\u0627\u0642\u0628 \u0627\u0644\u0623\u0633\u0647\u0645 \u0627\u0644\u0645\u0635\u0631\u064a\u0629',
      playStoreUrl:
          'https://play.google.com/store/apps/details?id=com.almurakib.egyptappstocks',
      appStoreUrl:
          'https://apps.apple.com/sg/app/%D9%85%D8%B1%D8%A7%D9%82%D8%A8-%D8%A7%D9%84%D8%A7%D8%B3%D9%87%D9%85-%D8%A7%D9%84%D9%85%D8%B5%D8%B1%D9%8A%D8%A9/id6759033465',
      imageUrl:
          'https://play-lh.googleusercontent.com/wVGNy3MT-L2zpkFHF_F9SCgjd8rEeJuK4OMNAeSDn8kRr_t2TMgwfl3ZWdtW1TNQJrclkEFvxIOYM7LjEEaICg=w480-h960-rw',
    ),
    _AppItem(
      name:
          '\u0645\u0631\u0627\u0642\u0628 \u0627\u0644\u0628\u064a\u062a\u0643\u0648\u064a\u0646',
      playStoreUrl:
          'https://play.google.com/store/apps/details?id=com.almurakib.bitcoin',
      appStoreUrl:
          'https://apps.apple.com/sg/app/%D9%85%D8%B1%D8%A7%D9%82%D8%A8-%D8%A7%D9%84%D8%A8%D9%8A%D8%AA%D9%83%D9%88%D9%8A%D9%86/id6759033453',
      imageUrl:
          'https://play-lh.googleusercontent.com/xHhXxlevam5VlaSwJ7mR4dNiWilSR53b-AvSPqAmQlOB_0Id8kT6KjqDsCbumj41sSx7e37CCwS8IiAm6Vr41A=w480-h960-rw',
    ),
  ];

  bool get _useAppStore =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  String get _storeLabel => _useAppStore ? 'App Store' : 'Google Play';

  EdgeInsets _pagePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final horizontal = width >= 1100
        ? 28.0
        : width >= 700
            ? 22.0
            : 16.0;
    return EdgeInsets.fromLTRB(horizontal, 16, horizontal, 28);
  }

  TextStyle _paragraphStyle({Color? color}) {
    return AppTextStyles.bodySmall.copyWith(
      color: color ?? AppColors.textPrimary,
      fontWeight: FontWeight.w500,
      height: 1.55,
      letterSpacing: 0.05,
    );
  }

  Future<void> _openStore(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '\u062a\u0639\u0630\u0631 \u0641\u062a\u062d \u0627\u0644\u0631\u0627\u0628\u0637 \u0627\u0644\u0622\u0646',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final useAppStore = _useAppStore;
    final storeLabel = _storeLabel;

    return FadeAnimation(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: _pagePadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 6),
              const AppSectionHeader(
                title: '\u062a\u0637\u0628\u064a\u0642\u0627\u062a\u0646\u0627',
              ),
              const SizedBox(height: 16),
              SlideAnimation(child: _buildHeaderCard(storeLabel)),
              const SizedBox(height: 16),
              SlideAnimation(
                delay: const Duration(milliseconds: 160),
                child: _buildAppsGrid(
                  context,
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
                const Icon(
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
            '\u062a\u0637\u0628\u064a\u0642\u0627\u062a \u0627\u0644\u0645\u0631\u0627\u0642\u0628',
            style: AppTextStyles.headingSmall.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.15,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '\u064a\u0633\u0631\u0646\u0627 \u0623\u0646 \u0646\u0642\u062f\u0645 \u0644\u0643\u0645 \u0645\u062c\u0645\u0648\u0639\u0629 \u062a\u0637\u0628\u064a\u0642\u0627\u062a\u0646\u0627 \u0627\u0644\u0631\u0633\u0645\u064a\u0629\u060c \u0627\u0636\u063a\u0637 \u0639\u0644\u0649 \u0627\u0644\u062a\u0637\u0628\u064a\u0642 \u0644\u0644\u0627\u0646\u062a\u0642\u0627\u0644 \u0625\u0644\u0649 \u0635\u0641\u062d\u0629 \u0627\u0644\u062a\u062d\u0645\u064a\u0644 \u0639\u0644\u0649 $storeLabel.',
            style: _paragraphStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildAppsGrid(
    BuildContext context, {
    required bool useAppStore,
    required String storeLabel,
  }) {
    if (_apps.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: buildCardDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          '\u0644\u0627 \u062a\u0648\u062c\u062f \u062a\u0637\u0628\u064a\u0642\u0627\u062a \u0644\u0644\u0639\u0631\u0636 \u062d\u0627\u0644\u064a\u064b\u0627.',
          style: _paragraphStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const crossAxisCount = 2;
        final aspect = constraints.maxWidth >= 650
            ? 1.08
            : constraints.maxWidth >= 520
                ? 0.96
                : 0.84;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _apps.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: aspect,
          ),
          itemBuilder: (context, index) {
            final item = _apps[index];
            return _MiniAppTile(
              item: item,
              storeLabel: storeLabel,
              storeIcon: useAppStore
                  ? Icons.apple_rounded
                  : Icons.play_circle_fill_rounded,
              accentColor: _egyptAccent,
              onTap: () => _openStore(context, item.urlFor(useAppStore)),
            );
          },
        );
      },
    );
  }
}

class _AppItem {
  const _AppItem({
    required this.name,
    required this.playStoreUrl,
    required this.appStoreUrl,
    required this.imageUrl,
  });

  final String name;
  final String playStoreUrl;
  final String appStoreUrl;
  final String imageUrl;

  String urlFor(bool useAppStore) {
    return useAppStore ? appStoreUrl : playStoreUrl;
  }
}

class _MiniAppTile extends StatelessWidget {
  const _MiniAppTile({
    required this.item,
    required this.storeLabel,
    required this.storeIcon,
    required this.accentColor,
    required this.onTap,
  });

  final _AppItem item;
  final String storeLabel;
  final IconData storeIcon;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: buildCardDecoration(
        color: Colors.white,
        radius: 18,
        border: Border.all(color: AppColors.border),
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
                  _AppIcon(url: item.imageUrl, accentColor: accentColor),
                  const SizedBox(height: 8),
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      height: 1.2,
                      letterSpacing: 0.1,
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
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          storeIcon,
                          size: 14,
                          color: accentColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          storeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 11.5,
                            color: accentColor,
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
  const _AppIcon({
    required this.url,
    required this.accentColor,
  });

  final String url;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            spreadRadius: 0.2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
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
          errorBuilder: (_, __, ___) => const Icon(
            Icons.apps_outlined,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
