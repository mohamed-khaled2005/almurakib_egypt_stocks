import 'package:flutter/material.dart';

class DisclaimerScreen extends StatelessWidget {
  const DisclaimerScreen({super.key});

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
          'إخلاء المسؤولية',
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
            // Intro Paragraph (Matches Image 1)
            const Text(
              'تطبيق «مراقب الأسهم المصرية» هو منصة معلوماتية وإرشادية مستقلة تقدم بيانات حركة أسعار الأسهم والمؤشرات المالية لأغراض إعلامية وتثقيفية عامة فقط.',
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
            _buildSectionHeader('1. طبيعة البيانات المعروضة'),
            _buildCard([
              _buildTextItem('يتم جمع البيانات من مصادر ومزودي بيانات خارجيين عبر واجهات برمجية متخصصة.'),
              _buildTextItem('على الرغم من سعينا الدائم لتحديث الأسعار بأقصى سرعة ودقة ممكنة، إلا أن البيانات المعروضة قد تخضع لتأخير زمني ناتج عن تقلبات الأسواق أو ظروف الاتصال الشبكي أو سياسات مزودي البيانات.'),
            ]),

            // Section 2
            _buildSectionHeader('2. التطبيق ليس استشارة مالية أو منصة تداول'),
            _buildCard([
              _buildTextItem('لا يعتبر المحتوى المعروض في هذا التطبيق بأي حال من الأحوال توصية استثمارية أو مشورة مالية أو قانونية أو دعوة للشراء أو البيع أو الاكتتاب في أي ورقة مالية أو سهم.'),
              _buildTextItem('التطبيق ليس وسيطاً مالياً أو منصة لتنفيذ صفقات التداول أو إدارة المحافظ الاستثمارية.'),
            ]),

            // Section 3
            _buildSectionHeader('3. المسؤولية الكاملة للمستثمر'),
            _buildCard([
              _buildTextItem('تداول الأسهم والأسواق المالية ينطوي على مخاطر مالية عالية وتقلبات سعرية مستمرة قد تؤدي إلى خسارة جزء من رأس المال أو كله.'),
              _buildTextItem('يتحمل المستخدم بمفرده المسؤولية الكاملة عن أي قرارات استثمارية أو مالية يتخذها بناءً على المعلومات الواردة في التطبيق.'),
              _buildTextItem('لا تتحمل شركة "المراقب Almurakib LLC" أو ملاك التطبيق أو العاملون فيه أي مسؤولية عن أي خسائر مالية مباشرة أو غير مباشرة أو أرباح فائتة تنجم عن استخدام التطبيق أو الاعتماد على بياناته.'),
            ]),

            // Outro Paragraph (Matches Image 1)
            const Padding(
              padding: EdgeInsets.only(top: 20, bottom: 24),
              child: Text(
                'يُنصح دائماً باستشارة مستشار مالي مرخص ومراجعة المنصات الرسمية للسوق المالي قبل اتخاذ أي قرار استثماري.',
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                  height: 1.5,
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
