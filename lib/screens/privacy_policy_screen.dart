import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEFEFE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFEFEFE),
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          'سياسة الخصوصية',
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18,
              color: Color(0xFF111827),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: const Color(0xFFF1F5F9),
            height: 1,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            // Intro Paragraph (Matches Image 3)
            const Text(
              'نحن في تطبيق «مراقب الأسهم المصرية» (إحدى خدمات منصة المراقب Almurakib LLC) نلتزم التزاماً كاملاً بحماية خصوصيتك وأمان بياناتك الرقمية والشخصية وفقاً لأعلى المعايير القانونية والتقنية.',
              textAlign: TextAlign.justify,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
                height: 1.6,
              ),
            ),

            // Section 1
            _buildSectionHeader('1. البيانات التي نقوم بجمعها'),
            _buildCard([
              _buildTitledItem(
                'بيانات الحساب والتسجيل',
                'عند إنشاء حساب، نقوم بجمع الاسم، عنوان البريد الإلكتروني، ورقم الهاتف للتحقق وتأمين تسجيل الدخول واستعادة الحساب.',
              ),
              _buildTitledItem(
                'تفضيلات المستخدم',
                'نقوم بحفظ ومزامنة الأسهم المفضلة وقوائم المتابعة الخاصة بك سحابياً لتمكينك من الوصول إليها عبر أجهزتك.',
              ),
              _buildTitledItem(
                'بيانات الجهاز والتشغيل',
                'نوع الجهاز، نظام التشغيل وإصداره، لغة النظام، والمعرفات الرقمية المجهولة (Device IDs) لضمان استقرار الخدمة وتوافقها.',
              ),
              _buildTitledItem(
                'رموز الإشعارات (Push Notification Tokens)',
                'نجمع رموز خدمة الإشعارات لإرسال تنبيهات الأسواق والتحديثات والأخبار المهمة، ويمكنك تعطيل الإشعارات من إعدادات جهازك في أي وقت.',
              ),
              _buildTitledItem(
                'تحليلات الاستخدام والإعلانات',
                'نستخدم أدوات تحليلية وتتبعية متقدمة (مثل Facebook SDK و Firebase) لتسجيل مرات ظهور الإعلانات (Impressions) والنقرات (Clicks) والأحداث التفاعلية لتحسين تجربة الاستخدام وملاءمة المحتوى الإعلاني.',
              ),
            ]),

            // Section 2
            _buildSectionHeader('2. كيفية استخدام البيانات'),
            _buildCard([
              _buildTextItem('إدارة حسابك وتوثيق ملكيته واسترجاع كلمة المرور عبر البريد أو الهاتف.'),
              _buildTextItem('مزامنة تفضيلاتك وقوائم المتابعة عبر الخوادم السحابية.'),
              _buildTextItem('قياس أداء الحملات الإعلانية ومتابعة تفاعل المستخدمين مع الإعلانات المعروضة داخل التطبيق.'),
              _buildTextItem('إرسال الإشعارات التنبيهية حول حركة الأسواق والتقارير المالية.'),
              _buildTextItem('حماية التطبيق من الهجمات التقنية ومنع الاحتيال أو إساءة الاستخدام.'),
            ]),

            // Section 3
            _buildSectionHeader('3. مشاركة البيانات وحمايتها'),
            _buildCard([
              _buildTextItem('لا نقوم إطلاقاً ببيع بياناتك الشخصية لأي طرف ثالث.'),
              _buildTextItem('لا تتم مشاركة البيانات إلا مع مزودي البنية التحتية والخدمات السحابية والتحليلية المعتمدين لغايات التشغيل فقط.'),
              _buildTextItem('نعتمد بروتوكولات تشفير متقدمة (SSL/TLS) لحماية حركة البيانات، وتشفير كلمات المرور والرموز الحساسة.'),
            ]),

            // Section 4
            _buildSectionHeader('4. حقوق المستخدم'),
            _buildCard([
              _buildTextItem('يحق لك الوصول إلى بياناتك المسجلة أو تعديلها من شاشة الحساب في أي وقت.'),
              _buildTextItem('يحق لك طلب حذف حسابك نهائياً وكافة البيانات المرتبطة به بالتواصل معنا مباشرة.'),
              _buildTextItem('يحق لك إلغاء الاشتراك في الإشعارات أو تخصيص التفضيلات في أي وقت.'),
            ]),

            // Outro Paragraph (Matches Image 3)
            const Padding(
              padding: EdgeInsets.only(top: 20, bottom: 24),
              child: Text(
                'باستخدامك للتطبيق، فإنك توافق على بنود سياسة الخصوصية هذه.',
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          title,
          textDirection: TextDirection.rtl,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 14.5,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: List.generate(items.length, (index) {
          return Column(
            children: [
              items[index],
              if (index < items.length - 1)
                const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildTitledItem(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        textDirection: TextDirection.rtl,
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
              color: Color(0xFF475569),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          text,
          textDirection: TextDirection.rtl,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: Color(0xFF475569),
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
