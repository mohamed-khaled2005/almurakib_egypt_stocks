import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/chevron_right_icon.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String _websiteUrl = 'https://almurakib.com';

  Future<void> _launchWebsite() async {
    try {
      final uri = Uri.parse(_websiteUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
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
            'عن التطبيق',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 17.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            const SizedBox(height: 12),

            // 1. App Logo
            Center(
              child: Image.asset(
                'assets/images/Icon.png',
                width: 115,
                height: 115,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFC1121F),
                  ),
                  child: const Icon(Icons.assessment_rounded, size: 50, color: Colors.white),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // App Name
            const Center(
              child: Text(
                'مراقب الأسهم المصرية',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Intro Description
            const Center(
              child: Text(
                'هو التطبيق الرسمي لمنصة المراقب، تم تصميمه\nليمنحك رؤية شاملة وسريعة لسوق الأسهم المصرية\nوتحديثات الأسعار لحظة بلحظة.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF4B5563),
                  height: 1.5,
                ),
              ),
            ),

            const SizedBox(height: 28),

            // 2. Section: مميزات التطبيق
            const Text(
              'مميزات التطبيق',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 14.5,
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
                children: [
                  _buildFeatureItem(
                    title: 'بيانات لحظية',
                    subtitle:
                        'نوفر أسعار الأسهم المصرية والمؤشرات بتحديثات مستمرة لحظة بلحظة لمساعدتك على اتخاذ قراراتك الاستثمارية.',
                  ),
                  const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                  _buildFeatureItem(
                    title: 'المفضلة',
                    subtitle:
                        'أضف الشركات التي تهمك إلى قائمة المفضلة وتابع أداءها بسهولة وسرعة من مكان واحد.',
                  ),
                  const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                  _buildFeatureItem(
                    title: 'الموثوقية',
                    subtitle:
                        'نعتمد على مصادر بيانات معتمدة ونلتزم بعرض معلومات شفافة ودقيقة لتعزيز ثقتك أثناء متابعة السوق.',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 3. Section: عن منصة المراقب
            const Text(
              'عن منصة المراقب',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 14.5,
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
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Text(
                      'هي منصة مالية رائدة تهدف لتبسيط البيانات المالية للمستثمر العربي، ومساعدته على اتخاذ قرارات استثمارية مدروسة.',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF4B5563),
                        height: 1.45,
                      ),
                    ),
                  ),
                  const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                  InkWell(
                    onTap: _launchWebsite,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        textDirection: TextDirection.rtl,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'الموقع الإلكتروني',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Almurakib.com',
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Transform.flip(
                                flipX: true,
                                child: const Icon(
                                  Icons.open_in_new_rounded,
                                  color: Color(0xFFDC2626),
                                  size: 16,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // 4. Copyright
            const Center(
              child: Text(
                'جميع الحقوق محفوظة لمنصة المراقب 2026',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
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
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
