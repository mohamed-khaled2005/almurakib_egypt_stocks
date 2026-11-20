import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/ad_banner_card.dart';
import '../widgets/chevron_right_icon.dart';

class ContactScreen extends StatelessWidget {
  final bool showFixedBanner;
  const ContactScreen({super.key, this.showFixedBanner = true});

  static const String _websiteUrl = 'https://almurakib.com';
  static const String _email = 'info@almurakib.com';
  static const String _phone = '+3197010284689';
  static const String _whatsAppUrl = 'https://wa.me/3197010284689';
  static const String _telegramUrl = 'https://t.me/Almurakib';

  Future<void> _launch(String urlString) async {
    try {
      final uri = Uri.parse(urlString);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      try {
        final uri = Uri.parse(urlString);
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {}
    }
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
            'اتصل بنا',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 17.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
            // 1. Intro Text
            const Text(
              'يسعدنا سماع رأيك ومساعدتك. اختر الطريقة الأنسب\nللتواصل معنا.',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF4B5563),
                height: 1.45,
              ),
            ),

            const SizedBox(height: 18),

            // 2. Section Header: قنوات التواصل
            const Text(
              'قنوات التواصل',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
              ),
            ),

            const SizedBox(height: 8),

            // Channels Card Container
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // 1. Website
                  _buildChannelRow(
                    iconWidget: const Icon(Icons.language_rounded, color: Color(0xFF374151), size: 22),
                    title: 'الموقع الإلكتروني',
                    subtitle: 'almurakib.com',
                    onTap: () => _launch(_websiteUrl),
                  ),
                  const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

                  // 2. Email
                  _buildChannelRow(
                    iconWidget: const Icon(Icons.mail_outline_rounded, color: Color(0xFF374151), size: 22),
                    title: 'البريد الإلكتروني',
                    subtitle: _email,
                    onTap: () => _launch('mailto:$_email'),
                  ),
                  const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

                  // 3. Phone
                  _buildChannelRow(
                    iconWidget: const Icon(Icons.phone_outlined, color: Color(0xFF374151), size: 22),
                    title: 'رقم الهاتف',
                    subtitle: _phone,
                    isPhone: true,
                    onTap: () => _launch('tel:$_phone'),
                  ),
                  const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

                  // 4. WhatsApp
                  _buildChannelRow(
                    iconWidget: const FaIcon(FontAwesomeIcons.whatsapp, color: Color(0xFF374151), size: 22),
                    title: 'واتساب',
                    subtitle: 'تواصل معنا مباشرة',
                    onTap: () => _launch(_whatsAppUrl),
                  ),
                  const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

                  // 5. Telegram
                  _buildChannelRow(
                    iconWidget: const FaIcon(FontAwesomeIcons.telegram, color: Color(0xFF374151), size: 22),
                    title: 'تيليجرام',
                    subtitle: 'انضم لقناتنا',
                    onTap: () => _launch(_telegramUrl),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 3. Section: عن الشركة
            const Text(
              'عن الشركة',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'شركة رسمية مرخصة في دولة بيليز تحت اسم\nAlmurakib LLC\nتطبيق "مراقب الأسهم المصرية" هو أحد منتجات منصة\nالمراقب لتسهيل متابعة السوق المصري بشكل\nمبسط وواضح.',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF4B5563),
                height: 1.5,
              ),
            ),

            const SizedBox(height: 20),

            // 4. Copyright Footer
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

            const SizedBox(height: 16),
          ],
        ),
      ),

      // Fixed Bottom Ad Banner
      if (showFixedBanner)
        const SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: AdBannerCard(),
          ),
        ),
    ],
  ),
),
);
  }

  Widget _buildChannelRow({
    required Widget iconWidget,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isPhone = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            // Right: Channel Icon
            SizedBox(
              width: 26,
              height: 26,
              child: Center(child: iconWidget),
            ),

            const SizedBox(width: 14),

            // Middle: Title & Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    textDirection: isPhone ? TextDirection.ltr : TextDirection.rtl,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),

            // Left: External Link Icon (mirrored top-left)
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
    );
  }
}
