import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/chevron_right_icon.dart';

class AlmurakibAppItem {
  final String title;
  final String url;
  final String imageAsset;

  const AlmurakibAppItem({
    required this.title,
    required this.url,
    required this.imageAsset,
  });
}

class OurAppsScreen extends StatelessWidget {
  const OurAppsScreen({super.key});

  Future<void> _launchApp(String url) async {
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      try {
        final uri = Uri.parse(url);
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {}
    }
  }

  static const List<AlmurakibAppItem> _stocksApps = [
    AlmurakibAppItem(
      title: 'مراقب الأسهم الإماراتية',
      url: 'https://apps.apple.com/app/id6759033698',
      imageAsset: 'assets/images/apps/emirates.png',
    ),
    AlmurakibAppItem(
      title: 'مراقب الأسهم الأمريكية',
      url: 'https://apps.apple.com/app/id6759033724',
      imageAsset: 'assets/images/apps/usa.png',
    ),
    AlmurakibAppItem(
      title: 'مراقب الأسهم القطرية',
      url: 'https://apps.apple.com/app/id6759033698',
      imageAsset: 'assets/images/apps/qatar.png',
    ),
    AlmurakibAppItem(
      title: 'مراقب الأسهم السعودية',
      url: 'https://apps.apple.com/app/id6759033682',
      imageAsset: 'assets/images/apps/saudi.png',
    ),
  ];

  static const List<AlmurakibAppItem> _commoditiesApps = [
    AlmurakibAppItem(
      title: 'مراقب الذهب',
      url: 'https://apps.apple.com/app/id6759033669',
      imageAsset: 'assets/images/apps/gold.png',
    ),
    AlmurakibAppItem(
      title: 'مراقب الفضة',
      url: 'https://apps.apple.com/app/id6759033737',
      imageAsset: 'assets/images/apps/silver.png',
    ),
    AlmurakibAppItem(
      title: 'مراقب الوقود',
      url: 'https://apps.apple.com/developer/almurakib',
      imageAsset: 'assets/images/apps/wakoud.png',
    ),
  ];

  static const List<AlmurakibAppItem> _currenciesApps = [
    AlmurakibAppItem(
      title: 'مراقب أسعار صرف العملات',
      url: 'https://apps.apple.com/developer/almurakib',
      imageAsset: 'assets/images/apps/currency.png',
    ),
    AlmurakibAppItem(
      title: 'مراقب العملات الرقمية',
      url: 'https://apps.apple.com/developer/almurakib',
      imageAsset: 'assets/images/apps/crypto.png',
    ),
    AlmurakibAppItem(
      title: 'مراقب البيتكوين',
      url: 'https://apps.apple.com/developer/almurakib',
      imageAsset: 'assets/images/apps/bitcoin.png',
    ),
    AlmurakibAppItem(
      title: 'Sarraf',
      url: 'https://apps.apple.com/developer/almurakib',
      imageAsset: 'assets/images/apps/sarraf.png',
    ),
  ];

  static const List<AlmurakibAppItem> _calculatorsApps = [
    AlmurakibAppItem(
      title: 'حاسبة الزكاة',
      url: 'https://apps.apple.com/developer/almurakib',
      imageAsset: 'assets/images/apps/zakat.png',
    ),
    AlmurakibAppItem(
      title: 'حاسبة التمويل',
      url: 'https://apps.apple.com/developer/almurakib',
      imageAsset: 'assets/images/apps/finance.png',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final storeName = Platform.isAndroid ? 'Google Play' : 'App Store';

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
            'تطبيقاتنا',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 17.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            physics: const BouncingScrollPhysics(),
            children: [
              // 1. Intro Text
              Text(
                'تطبيقات المراقب الرسمية. اضغط على أي تطبيق لفتح\nصفحته على $storeName.',
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF4B5563),
                  height: 1.45,
                ),
              ),

              const SizedBox(height: 18),

              // 2. Section: أسهم عربية وعالمية
              _buildSection(
                title: 'أسهم عربية وعالمية',
                items: _stocksApps,
              ),

              const SizedBox(height: 20),

              // 3. Section: معادن وطاقة
              _buildSection(
                title: 'معادن وطاقة',
                items: _commoditiesApps,
              ),

              const SizedBox(height: 20),

              // 4. Section: عملات
              _buildSection(
                title: 'عملات',
                items: _currenciesApps,
              ),

              const SizedBox(height: 20),

              // 5. Section: حاسبات
              _buildSection(
                title: 'حاسبات',
                items: _calculatorsApps,
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<AlmurakibAppItem> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isLast = index == items.length - 1;

              return Column(
                children: [
                  InkWell(
                    onTap: () => _launchApp(item.url),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          // App Logo Icon
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.asset(
                              item.imageAsset,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.apps_rounded,
                                color: Color(0xFFC1121F),
                                size: 24,
                              ),
                            ),
                          ),

                          const SizedBox(width: 14),

                          // App Title
                          Expanded(
                            child: Text(
                              item.title,
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),

                          // Left External Link Icon (pointing top-left in RTL)
                          Transform.flip(
                            flipX: true,
                            child: const Icon(
                              Icons.open_in_new_rounded,
                              color: Color(0xFF94A3B8),
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!isLast)
                    const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}
