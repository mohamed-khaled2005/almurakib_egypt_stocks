import 'package:flutter/material.dart';

class TermsOfUseScreen extends StatelessWidget {
  const TermsOfUseScreen({super.key});

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
          'شروط الاستخدام',
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
            // Intro Paragraph (Matches Image 2)
            const Text(
              'يرجى قراءة هذه الشروط والأحكام بعناية قبل استخدام تطبيق «مراقب الأسهم المصرية». استخدامك للتطبيق أو تسجيل حساب فيه يُعد موافقة صريحة وغير مشروطة على كافة البنود والشروط والسياسات المرتبطة به.',
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
            _buildSectionHeader('1. الأهلية وإنشاء الحساب'),
            _buildCard([
              _buildTextItem('يجب أن يكون عمرك 18 عاماً فأكثر لاستخدام التطبيق وإنشاء حساب.'),
              _buildTextItem('أنت مسؤول مسؤولية كاملة عن الحفاظ على سرية بيانات تسجيل دخولك وكلمة المرور الخاصة بك، وعن كافة الأنشطة التي تتم من خلال حسابك.'),
              _buildTextItem('يجب تقديم معلومات صحيحة ودقيقة عند التسجيل أو إضافة رقم الهاتف والبريد الإلكتروني.'),
            ]),

            // Section 2
            _buildSectionHeader('2. الاستخدام المصرح به وقواعد السلوك'),
            _buildCard([
              _buildTextItem('يُرخص لك استخدام التطبيق للأغراض الشخصية غير التجارية.'),
              _buildTextItem('يُحظر تماماً محاولة تفكيك التطبيق أو استخدام أي وسائل مؤتمتة (Scraping/Bots) لاستخراج البيانات أو تحميل خوادم التطبيق بما يجاوز الاستخدام الطبيعي.'),
              _buildTextItem('يُحظر إساءة استخدام الخدمات التفاعلية أو محاولة التحايل على أنظمة تتبع الإعلانات أو إساءة استغلال كوبونات وخصومات الترويج.'),
            ]),

            // Section 3
            _buildSectionHeader('3. الملكية وحقوق النشر'),
            _buildCard([
              _buildTextItem('كافة التصاميم، الشعارات، الواجهات، النصوص البرمجية، والمحتويات الإرشادية مملوكة حصرياً لشركة Almurakib LLC ومحمية بموجب قوانين الملكية الفكرية الدولية.'),
              _buildTextItem('لا يجوز نسخ أو اقتباس أو توزيع أي جزء من محتوى التطبيق دون موافقة كتابية مسبقة.'),
            ]),

            // Section 4
            _buildSectionHeader('4. الإعلانات والروابط الترويجية'),
            _buildCard([
              _buildTextItem('قد يحتوي التطبيق على إعلانات وروابط خارجية لمواقع ومنصات تابعة لجهات أخرى.'),
              _buildTextItem('يخضع تتبع الإعلانات لسياساتنا في قياس الظهور والنقر، ولكن المنصة لا تتحمل أي مسؤولية عن محتوى المنتجات أو الخدمات المعلن عنها من قبل أطراف ثالثة.'),
            ]),

            // Section 5
            _buildSectionHeader('5. تعديل الخدمات وإنهاء الاستخدام'),
            _buildCard([
              _buildTextItem('تحتفظ المنصة بحق تعديل أو إيقاف أو تحديث أي ميزة أو خدمة في التطبيق في أي وقت دون إشعار مسبق.'),
              _buildTextItem('يحق للمنصة تعليق أو حظر أي حساب يخالف شروط الاستخدام أو يُظهر نشاطاً مشبوهاً.'),
            ]),

            // Section 6
            _buildSectionHeader('6. القانون المطبق وحل النزاعات'),
            _buildCard([
              _buildTextItem('تخضع هذه الشروط وتفسر وفقاً لقوانين دولة بيليز حيث تقع الشركة المالكة Almurakib LLC، وتختص محاكمها بالفصل في أي نزاع ينشأ عنها.'),
            ]),

            // Outro Paragraph (Matches Image 2)
            const Padding(
              padding: EdgeInsets.only(top: 20, bottom: 24),
              child: Text(
                'باستمرارك في استخدام التطبيق، فإنك تؤكد التزامك الكامل بكافة الشروط والأحكام المذكورة أعلاه.',
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
