import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/utils/constants.dart';
import '../animations/fade_animation.dart';
import '../animations/slide_animation.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  static const String _websiteUrl = 'https://almurakib.com';
  static const String _email = 'info@almurakib.com';
  static const String _phone = '+3197010284689';
  static const String _whatsAppNumber = '3197010284689';

  // ✅ زر تيليجرام
  static const String _telegramUrl = 'https://t.me/Almurakib';

  // ==========================================================
  // ✅ سياسة الخصوصية الشاملة والمحدثة
  // ==========================================================
  static const String _privacyPolicyText = '''
نحن في تطبيق "مراقب الأسهم المصرية" (إحدى خدمات منصة المراقب Almurakib LLC) نلتزم التزاماً كاملاً بحماية خصوصيتك وأمان بياناتك الرقمية والشخصية وفقاً لأعلى المعايير القانونية والتقنية.

1. البيانات التي نقوم بجمعها:
• بيانات الحساب والتسجيل: عند إنشاء حساب، نقوم بجمع الاسم، عنوان البريد الإلكتروني، ورقم الهاتف للتحقق وتأمين تسجيل الدخول واستعادة الحساب.
• تفضيلات المستخدم: نقوم بحفظ ومزامنة الأسهم المفضلة وقوائم المتابعة الخاصة بك سحابياً لتمكينك من الوصول إليها عبر أجهزتك.
• بيانات الجهاز والتشغيل: نوع الجهاز، نظام التشغيل وإصداره، لغة النظام، والمعرفات الرقمية المجهولة (Device IDs) لضمان استقرار الخدمة وتوافقها.
• رموز الإشعارات (Push Notification Tokens): نجمع رموز خدمة الإشعارات لإرسال تنبيهات الأسواق والتحديثات والأخبار المهمة، ويمكنك تعطيل الإشعارات من إعدادات جهازك في أي وقت.
• تحليلات الاستخدام والإعلانات: نستخدم أدوات تحليلية وتتبعية متقدمة (مثل Firebase و Facebook SDK) لتسجيل مرات ظهور الإعلانات (Impressions) والنقرات (Clicks) والأحداث التفاعلية لتحسين تجربة الاستخدام وملاءمة المحتوى الإعلاني.

2. كيفية استخدام البيانات:
• إدارة حسابك وتوثيق ملكيته واسترجاع كلمة المرور عبر البريد أو الهاتف.
• مزامنة تفضيلاتك وقوائم الأسهم المتابعة عبر الخوادم السحابية.
• قياس أداء الحملات الإعلانية ومتابعة تفاعل المستخدمين مع الإعلانات المعروضة داخل التطبيق.
• إرسال الإشعارات التنبيهية حول حركة الأسواق والتقارير المالية.
• حماية التطبيق من الهجمات التقنية ومنع الاحتيال أو إساءة الاستخدام.

3. مشاركة البيانات وحمايتها:
• لا نقوم إطلاقاً ببيع بياناتك الشخصية لأي طرف ثالث.
• لا تتم مشاركة البيانات إلا مع مزودي البنية التحتية والخدمات السحابية والتحليلية المعتمدين لغايات التشغيل فقط.
• نعتمد بروتوكولات تشفير متقدمة (SSL/TLS) لحماية حركة البيانات، وتشفير كلمات المرور والرموز الحساسة.

4. حقوق المستخدم:
• يحق لك الوصول إلى بياناتك المسجلة أو تعديلها من شاشة الحساب في أي وقت.
• يحق لك طلب حذف حسابك نهائياً وكافة البيانات المرتبطة به بالتواصل معنا مباشرة.
• يحق لك إلغاء الاشتراك في الإشعارات أو تخصيص التفضيلات في أي وقت.

باستخدامك للتطبيق، فإنك توافق على بنود سياسة الخصوصية هذه.
''';

  // ==========================================================
  // ✅ إخلاء المسؤولية القانوني والمالي
  // ==========================================================
  static const String _disclaimerText = '''
تطبيق "مراقب الأسهم المصرية" هو منصة معلوماتية وإرشادية مستقلة تقدم بيانات حركة أسعار الأسهم والمؤشرات المالية لأغراض إعلامية وتثقيفية عامة فقط.

1. طبيعة البيانات المعروضة:
• يتم جمع البيانات من مصادر ومزودي بيانات خارجيين عبر واجهات برمجية متخصصة.
• على الرغم من سعينا الدائم لتحديث الأسعار بأقصى سرعة ودقة ممكنة، إلا أن البيانات المعروضة قد تخضع لتأخير زمني ناتج عن تقلبات الأسواق أو ظروف الاتصال الشبكي أو سياسات مزودي البيانات.

2. التطبيق ليس استشارة مالية أو منصة تداول:
• لا يعتبر المحتوى المعروض في هذا التطبيق بأي حال من الأحوال توصية استثمارية أو مشورة مالية أو قانونية أو دعوة للشراء أو البيع أو الاكتتاب في أي ورقة مالية أو سهم.
• التطبيق ليس وسيطاً مالياً أو منصة لتنفيذ صفقات التداول أو إدارة المحافظ الاستثمارية.

3. المسؤولية الكاملة للمستثمر:
• تداول الأسهم والأسواق المالية ينطوي على مخاطر مالية عالية وتقلبات سعرية مستمرة قد تؤدي إلى خسارة جزء من رأس المال أو كله.
• يتحمل المستخدم بمفرده المسؤولية الكاملة عن أي قرارات استثمارية أو مالية يتخذها بناءً على المعلومات الواردة في التطبيق.
• لا تتحمل شركة "المراقب Almurakib LLC" أو ملاك التطبيق أو العاملون فيه أي مسؤولية عن أي خسائر مالية مباشرة أو غير مباشرة أو أرباح فائتة تنجم عن استخدام التطبيق أو الاعتماد على بياناته.

يُنصح دائماً باستشارة مستشار مالي مرخص ومراجعة المنصات الرسمية للسوق المالي قبل اتخاذ أي قرار استثماري.
''';

  // ==========================================================
  // ✅ الشروط والأحكام الكاملة
  // ==========================================================
  static const String _termsText = '''
يرجى قراءة هذه الشروط والأحكام بعناية قبل استخدام تطبيق "مراقب الأسهم المصرية". استخدامك للتطبيق أو تسجيل حساب فيه يُعد موافقة صريحة وغير مشروطة على كافة البنود والشروط والسياسات المرتبطة به.

1. الأهلية وإنشاء الحساب:
• يجب أن يكون عمرك 18 عاماً فأكثر لاستخدام التطبيق وإنشاء حساب.
• أنت مسؤول مسؤولية كاملة عن الحفاظ على سرية بيانات تسجيل دخولك وكلمة المرور الخاصة بك، وعن كافة الأنشطة التي تتم من خلال حسابك.
• يجب تقديم معلومات صحيحة ودقيقة عند التسجيل أو إضافة رقم الهاتف والبريد الإلكتروني.

2. الاستخدام المصرح به وقواعد السلوك:
• يُرخص لك استخدام التطبيق للأغراض الشخصية غير التجارية.
• يُحظر تماماً محاولة تفكيك التطبيق أو استخدام أي وسائل مؤتمتة (Scraping/Bots) لاستخراج البيانات أو تحميل خوادم التطبيق بما يجاوز الاستخدام الطبيعي.
• يُحظر إساءة استخدام الخدمات التفاعلية أو محاولة التحايل على أنظمة تتبع الإعلانات أو إساءة استغلال كوبونات وخصومات الترويج.

3. الملكية الفكرية وحقوق النشر:
• كافة التصاميم، الشعارات، الواجهات، النصوص البرمجية، والمحتويات الإرشادية مملوكة حصرياً لشركة Almurakib LLC ومحمية بموجب قوانين الملكية الفكرية الدولية.
• لا يجوز نسخ أو اقتباس أو توزيع أي جزء من محتوى التطبيق دون موافقة كتابية مسبقة.

4. الإعلانات والروابط الترويجية:
• قد يحتوي التطبيق على إعلانات وروابط خارجية لمواقع ومنصات تابعة لجهات أخرى.
• يخضع تتبع الإعلانات لسياساتنا في قياس الظهور والنقر، ولكن المنصة لا تتحمل أي مسؤولية عن محتوى المنتجات أو الخدمات المعلن عنها من قبل أطراف ثالثة.

5. تعديل الخدمات وإنهاء الاستخدام:
• تحتفظ المنصة بحق تعديل أو إيقاف أو تحديث أي ميزة أو خدمة في التطبيق في أي وقت دون إشعار مسبق.
• يحق للمنصة تعليق أو حظر أي حساب يخالف شروط الاستخدام أو يُظهر نشاطاً مشبوهاً.

6. القانون المطبق وحل النزاعات:
• تخضع هذه الشروط وتفسر وفقاً لقوانين دولة بيليز حيث تقع الشركة المالكة Almurakib LLC، وتختص محاكمها بالفصل في أي نزاع ينشأ عنها.

باستمرارك في استخدام التطبيق، فإنك تؤكد التزامك الكامل بكافة الشروط والأحكام المذكورة أعلاه.
''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false,
        child: FadeAnimation(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            physics: const BouncingScrollPhysics(),
            children: [
              const _UnifiedHeader(title: "التواصل والدعم"),
              const SizedBox(height: 18),

              SlideAnimation(child: _buildCompanyCard()),
              const SizedBox(height: 32),

              const SlideAnimation(
                delay: Duration(milliseconds: 100),
                child: _UnifiedSectionTitle(title: "قنوات التواصل"),
              ),
              const SizedBox(height: 16),

              SlideAnimation(
                delay: const Duration(milliseconds: 150),
                child: _buildContactInfo(),
              ),
              const SizedBox(height: 24),

              SlideAnimation(
                delay: const Duration(milliseconds: 200),
                child: _buildWhatsAppButton(),
              ),
              const SizedBox(height: 12),

              SlideAnimation(
                delay: const Duration(milliseconds: 225),
                child: _buildTelegramButton(),
              ),
              const SizedBox(height: 32),

              const SlideAnimation(
                delay: Duration(milliseconds: 250),
                child: _UnifiedSectionTitle(title: "معلومات قانونية"),
              ),
              const SizedBox(height: 16),

              SlideAnimation(
                delay: const Duration(milliseconds: 300),
                child: _buildLegalSection(context),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.business_rounded,
                    color: AppColors.primaryBlue, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'شركة وموقع المراقب',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'شركة رسمية مرخصة في دولة بيليز تحت اسم (Almurakib LLC).',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary.withValues(alpha: 0.8),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'تطبيق "مراقب الأسهم المصرية" هو أحد منتجات منصة المراقب لتسهيل متابعة السوق المصري بشكل مبسّط وواضح.',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfo() {
    final items = [
      _ContactItem(
        icon: Icons.language_rounded,
        title: 'الموقع الإلكتروني',
        value: _websiteUrl,
        ltr: true,
        onTap: () => _launchUrl(Uri.parse(_websiteUrl)),
      ),
      _ContactItem(
        icon: Icons.email_outlined,
        title: 'البريد الإلكتروني',
        value: _email,
        ltr: true,
        onTap: () => _launchUrl(Uri.parse('mailto:$_email')),
      ),
      _ContactItem(
        icon: Icons.phone_outlined,
        title: 'رقم الهاتف',
        value: _phone,
        ltr: true,
        onTap: () => _launchUrl(Uri.parse('tel:$_phone')),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final isLast = entry.key == items.length - 1;
          final item = entry.value;
          return _buildTile(
            icon: item.icon,
            title: item.title,
            subtitle: item.value,
            onTap: item.onTap,
            showDivider: !isLast,
            ltr: item.ltr,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWhatsAppButton() {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFF25D366),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF25D366).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            final uri = Uri.parse('https://wa.me/$_whatsAppNumber');
            _launchUrl(uri);
          },
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.chat_bubble_outline_rounded,
                  color: Colors.white, size: 22),
              SizedBox(width: 10),
              Text(
                'تواصل معنا عبر واتساب',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTelegramButton() {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFF229ED9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF229ED9).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            final uri = Uri.parse(_telegramUrl);
            _launchUrl(uri);
          },
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.send_rounded, color: Colors.white, size: 22),
              SizedBox(width: 10),
              Text(
                'انضم لقناتنا على تيليجرام',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegalSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildTile(
            icon: Icons.shield_outlined,
            title: 'سياسة الخصوصية',
            onTap: () => _showPolicySheet(
              context: context,
              title: 'سياسة الخصوصية',
              content: _privacyPolicyText,
            ),
            showDivider: true,
          ),
          _buildTile(
            icon: Icons.description_outlined,
            title: 'شروط الاستخدام',
            onTap: () => _showPolicySheet(
              context: context,
              title: 'شروط الاستخدام',
              content: _termsText,
            ),
            showDivider: true,
          ),
          _buildTile(
            icon: Icons.info_outline_rounded,
            title: 'إخلاء المسؤولية',
            onTap: () => _showPolicySheet(
              context: context,
              title: 'إخلاء المسؤولية',
              content: _disclaimerText,
            ),
            showDivider: false,
          ),
        ],
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    required bool showDivider,
    bool ltr = false,
  }) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 20, color: AppColors.primaryBlue),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            textDirection: ltr ? TextDirection.ltr : TextDirection.rtl,
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: Color(0xFFDDDDDD)),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
              height: 1,
              thickness: 1,
              indent: 60,
              endIndent: 20,
              color: AppColors.border),
      ],
    );
  }

  void _showPolicySheet({
    required BuildContext context,
    required String title,
    required String content,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Row(
                  children: [
                    Icon(Icons.article_rounded, color: AppColors.primaryBlue),
                    const SizedBox(width: 10),
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: Icon(Icons.close_rounded, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.border),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  physics: const BouncingScrollPhysics(),
                  child: Text(
                    content,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 14,
                      height: 1.8,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Future<void> _launchUrl(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $uri');
    }
  }
}

// ✅ هيدر الصفحة (موحد: نفس المقاس/الستايل زي باقي الصفحات)
class _UnifiedHeader extends StatelessWidget {
  final String title;
  const _UnifiedHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
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
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ✅ ويدجت العنوان الموحد للأقسام
class _UnifiedSectionTitle extends StatelessWidget {
  final String title;
  const _UnifiedSectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
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
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ContactItem {
  final IconData icon;
  final String title;
  final String value;
  final bool ltr;
  final VoidCallback onTap;

  _ContactItem({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.ltr = false,
  });
}