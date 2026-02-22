import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/utils/constants.dart';
import '../animations/fade_animation.dart';
import '../animations/slide_animation.dart';

// ─────────────────────────────────────────────
// بيانات التطبيقات
// ─────────────────────────────────────────────
class _AppItem {
  final String name;
  final String storeUrl;
  final String imageUrl;

  const _AppItem({
    required this.name,
    required this.storeUrl,
    required this.imageUrl,
  });
}

const List<_AppItem> _apps = <_AppItem>[
  _AppItem(
    name: 'مراقب الاسهم المصرية',
    storeUrl:
        'https://play.google.com/store/apps/details?id=com.almurakib.egyptappstocks',
    imageUrl:
        'https://play-lh.googleusercontent.com/wVGNy3MT-L2zpkFHF_F9SCgjd8rEeJuK4OMNAeSDn8kRr_t2TMgwfl3ZWdtW1TNQJrclkEFvxIOYM7LjEEaICg=w480-h960-rw',
  ),
  _AppItem(
    name: 'مراقب الفضة',
    storeUrl:
        'https://play.google.com/store/apps/details?id=com.almurakib.silvermonitor',
    imageUrl:
        'https://play-lh.googleusercontent.com/yLohp0qB8efPmZnr4eUlNtrUUboyV7qXcm9aRWoFSM0n7-Zeb9Br4GhuHiGZSI_6flWXOqu9Vn6VT36mLfUp=w480-h960-rw',
  ),
  _AppItem(
    name: 'مراقب البيتكوين',
    storeUrl:
        'https://play.google.com/store/apps/details?id=com.almurakib.bitcoin',
    imageUrl:
        'https://play-lh.googleusercontent.com/xHhXxlevam5VlaSwJ7mR4dNiWilSR53b-AvSPqAmQlOB_0Id8kT6KjqDsCbumj41sSx7e37CCwS8IiAm6Vr41A=w480-h960-rw',
  ),
  _AppItem(
    name: 'مراقب الأسهم الأمريكية',
    storeUrl:
        'https://play.google.com/store/apps/details?id=com.almurakib.usaappstocks',
    imageUrl:
        'https://play-lh.googleusercontent.com/wqDKcI9Pga22rkZNzxssaiU7qVlk-36bd1EKHXV-greisW7XcQuqjdCBcm17QZVP8mgKs_-uwyvBgo6YXzRh2us=w480-h960-rw',
  ),
  _AppItem(
    name: 'مراقب الأسهم القطرية',
    storeUrl:
        'https://play.google.com/store/apps/details?id=com.almurakib.qatarappstocks',
    imageUrl:
        'https://play-lh.googleusercontent.com/rN4Htz4G-T7Y-5nVODMGNmmPE1vNRNsFBPQOlgYXp4-kwZMfrSKx-a0h-vRtMS9b19cx54Cfu_Y3psiVDXZ9XA4=w480-h960-rw',
  ),
  _AppItem(
    name: 'مراقب الاسهم الاماراتية',
    storeUrl:
        'https://play.google.com/store/apps/details?id=com.almurakib.emiratesappstocks',
    imageUrl:
        'https://play-lh.googleusercontent.com/ndvDmG-MD_KFP1ejcUg7hfsQOZh52okON9TeHVYg5WtjE5iUy6vbJfaaosQ5zEIx0RO3t4ac_uBCxzPDWNL7Qg=w480-h960-rw',
  ),
  _AppItem(
    name: 'مراقب الاسهم السعودية',
    storeUrl:
        'https://play.google.com/store/apps/details?id=com.almurakib.saudiappstocks',
    imageUrl:
        'https://play-lh.googleusercontent.com/mgW7dsDFDi8_fgwuFyUmgdzxGBnva3vDqDcwAvN7lRCK2-QzA1hhjiwk_wuR6z0n3xYfxCvhfUQf5rySXlPj=w480-h960-rw',
  ),
  _AppItem(
    name: 'مراقب الذهب',
    storeUrl:
        'https://play.google.com/store/apps/details?id=com.almurakib.goldmonitor',
    imageUrl:
        'https://play-lh.googleusercontent.com/gEft1mhy5KD6GwMC9P6Ge-zJLb2fB72BIOmDmxfzB3rSETTix2wT4lEydIhSaZKLztjHiAQIkTbTYNWmCRK8VA=w480-h960-rw',
  ),
  _AppItem(
    name: 'مراقب العملات',
    storeUrl:
        'https://play.google.com/store/apps/details?id=com.almurakib.currencyexchange.app',
    imageUrl:
        'https://play-lh.googleusercontent.com/BKkuz_2ZP_NG_KbfvBVpvebAYtPONoMpe5uLgzV_nFh8_9kjgL-4pC0WUk5sAuNlcBfUaJ4HilQGJO3o55iGxA=w480-h960-rw',
  ),
  _AppItem(
    name: 'مراقب الكريبتو',
    storeUrl:
        'https://play.google.com/store/apps/details?id=com.almurakib.cryptomonitor',
    imageUrl:
        'https://play-lh.googleusercontent.com/U4gMdj8FrCjKBT6n3Dw_7MpYnJCnvGISNPSkOw8leGaGkqiQ9ku5SM7uRJVT946DPP3IZqfOZmjAKlV2__cD-w=w480-h960-rw',
  ),
];

// ─────────────────────────────────────────────
// الشاشة الرئيسية
// ─────────────────────────────────────────────
class OurAppsScreen extends StatelessWidget {
  const OurAppsScreen({super.key});

  Future<void> _openStore(BuildContext context, String url) async {
    final Uri uri = Uri.parse(url);
    final bool ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'تعذر فتح الرابط الآن',
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
    return Scaffold(
      // ✅ إزالة أي خلفية ملونة/حمراء
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeAnimation(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // ── العنوان ──
              _buildSectionTitle('تطبيقاتنا'),
              const SizedBox(height: 20),

              // ── البطاقة العلوية ──
              SlideAnimation(
                child: _buildHeaderCard(),
              ),
              const SizedBox(height: 24),

              // ── شبكة التطبيقات ──
              SlideAnimation(
                delay: const Duration(milliseconds: 150),
                child: _buildAppsGrid(context),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // عنوان القسم (نفس ستايل الهوم)
  // ─────────────────────────────────────────
  Widget _buildSectionTitle(String title) {
    return SlideAnimation(
      delay: const Duration(milliseconds: 100),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: AppTextStyles.headingSmall.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 20,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // البطاقة الترويجية العلوية (✅ بدون خلفية ملونة)
  // ─────────────────────────────────────────
  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Badge ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.store_rounded,
                    size: 16, color: AppColors.primaryBlue),
                SizedBox(width: 6),
                Text(
                  'Google Play',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── العنوان ──
          const Text(
            'تطبيقات المراقب',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),

          // ── الوصف ──
          Text(
            'يسرنا أن نقدم لكم مجموعة تطبيقاتنا الرسمية، اضغط على التطبيق للانتقال لصفحة التحميل على متجر جوجل.',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black.withOpacity(0.65),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // شبكة التطبيقات
  // ─────────────────────────────────────────
  Widget _buildAppsGrid(BuildContext context) {
    if (_apps.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Text(
          'لا توجد تطبيقات للعرض حالياً.',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (ctx, constraints) {
        const int crossAxisCount = 2;
        final double aspect = constraints.maxWidth >= 520 ? 1.25 : 1.05;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _apps.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: aspect,
          ),
          itemBuilder: (_, index) {
            final item = _apps[index];
            return SlideAnimation(
              delay: Duration(milliseconds: 200 + (index * 40)),
              child: _AppTile(
                item: item,
                onTap: () => _openStore(context, item.storeUrl),
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// عنصر التطبيق الواحد
// ─────────────────────────────────────────────
class _AppTile extends StatelessWidget {
  const _AppTile({required this.item, required this.onTap});

  final _AppItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: AppColors.primaryBlue.withOpacity(0.08),
            highlightColor: AppColors.primaryBlue.withOpacity(0.04),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── أيقونة التطبيق ──
                  _AppIcon(url: item.imageUrl),
                  const SizedBox(height: 12),

                  // ── اسم التطبيق ──
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                      height: 1.3,
                    ),
                  ),

                  // ✅ تم حذف زر "تحميل" بالكامل
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// أيقونة التطبيق المستديرة
// ─────────────────────────────────────────────
class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                ),
              ),
            );
          },
          errorBuilder: (_, __, ___) => const Icon(
            Icons.apps_rounded,
            color: AppColors.textSecondary,
            size: 28,
          ),
        ),
      ),
    );
  }
}
