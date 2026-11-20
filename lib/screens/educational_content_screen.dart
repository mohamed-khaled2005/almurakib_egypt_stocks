import 'package:flutter/material.dart';

import '../widgets/ad_banner_card.dart';
import '../widgets/chevron_right_icon.dart';

class EducationalArticle {
  final String title;
  final String content;

  const EducationalArticle({
    required this.title,
    required this.content,
  });
}

class EducationalContentScreen extends StatefulWidget {
  final bool showFixedBanner;
  const EducationalContentScreen({super.key, this.showFixedBanner = true});

  @override
  State<EducationalContentScreen> createState() => _EducationalContentScreenState();
}

class _EducationalContentScreenState extends State<EducationalContentScreen> {
  int? _expandedIndex; // All collapsed by default matching Image 2, expands on tap matching Image 3

  static const List<EducationalArticle> _articles = [
    EducationalArticle(
      title: 'أخطاء شائعة في تداول الأسهم المصرية',
      content:
          'من الأخطاء الشائعة هو الدخول في سهم بسبب توصية أو إشاعة دون تحليل. هذا يعرض المستخدم لخطر كبير، خاصة في سوق سريع التغير مثل السوق المصري.\n\nخطأ آخر هو عدم إدارة رأس المال بشكل صحيح. بعض المتداولين يضعون مبلغاً كبيراً في سهم واحد، مما يزيد من المخاطر بشكل كبير إذا تحرك السهم عكس التوقعات.\n\nكذلك التسرع في البيع أو الشراء بسبب الخوف أو الطمع يؤدي إلى قرارات غير مدروسة. السوق يحتاج إلى صبر وانضباط، وليس ردود فعل سريعة.\n\nالنجاح في هذا السوق يعتمد على التعلم المستمر وفهم حركة السوق، وليس على الحظ أو التوصيات فقط.',
    ),
    EducationalArticle(
      title: 'كيف تتابع الأسهم المصرية بشكل احترافي؟',
      content:
          'المتابعة الاحترافية تتطلب الاطلاع المستمر على مؤشرات البورصة الرئيسية مثل EGX30 و EGX70، ومراقبة أحجام التداول والسيولة الداخلة والخارجة.\n\nكما ينبغي متابعة الإفصاحات الرسمية الصادرة عن الشركات المقيدة والتقارير المالية الربع سنوية والسنوية لمعرفة الأداء التشغيلي الفعلي.\n\nاستخدام التحليل الفني والأساسي معاً يساعدك على تحديد نقاط الدخول والخروج المناسبة وإدارة المخاطر بحكمة.',
    ),
    EducationalArticle(
      title: 'لماذا يتميز السوق المصري بتقلبات واضحة؟',
      content:
          'يتأثر السوق المصري بعدة عوامل اقتصادية كلية مثل تحركات أسعار الفائدة وقرارات البنك المركزي، ومعدلات التضخم، وسعر صرف الجنيه.\n\nكما تلعب تدفقات السيولة من المؤسسات والصناديق الاستثمارية دوراً رئيسياً في إحداث موجات صعود وهبوط سريعة تفتح فرصاً استثمارية للمتداولين الواعين.',
    ),
    EducationalArticle(
      title: 'كيف تقرأ نتائج الشركات في البورصة المصرية؟',
      content:
          'تبدأ قراءة النتائج بفحص الإيرادات ونموها مقارنة بالفترة المماثلة، ثم النظر إلى صافي الأرباح التشغيلية والتأكد من أنها ناتجة عن نشاط الشركة الأساسي وليس أرباحاً استثنائية.\n\nكذلك ينبغي متابعة هوامش الربحية ونسبة المديونية وعائد السهم ومكرر الربحية (P/E) لتقييم السعر العادل للسهم.',
    ),
    EducationalArticle(
      title: 'ما الفرق بين الأسهم القيادية والأسهم الصغيرة في مصر؟',
      content:
          'الأسهم القيادية (Blue Chips) تمثل الشركات الكبرى ذات السيولة العالية مثل مكونات مؤشر EGX30، وتتميز بالاستقرار النسبي وتوزيعات الأرباح.\n\nبينما أسهم الشركات الصغيرة والمتوسطة (مؤشر EGX70) تتحرك بنطاقات سعرية أوسع وتقدم فرص نمو أعلى لكن بمخاطر وتقلبات أكبر تتطلب حذراً وإدارة صارمة لرأس المال.',
    ),
    EducationalArticle(
      title: 'ما الذي يحرك سوق الأسهم المصرية؟',
      content:
          'تتكامل عوامل متعددة لتحريك السوق، من أبرزها السياسات النقدية والمالية الحكومية، وقرارات لجان تسعير الطاقة، وحجم تداولات المستثمرين الأجانب والعرب والمصريين.\n\nبالإضافة إلى الأخبار الجيوسياسية الإقليمية والصفقات الاستحواذية الكبرى وإعادة تقييم أصول الشركات.',
    ),
  ];

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
            'المحتوى التعليمي',
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
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 4, 4, 16),
                    child: Text(
                      'مقالات قصيرة تساعدك على فهم السوق المصري واتخاذ قرارات أوضح.',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4B5563),
                        height: 1.45,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ),

                  // Accordions Card Container
                  Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: List.generate(_articles.length, (index) {
                  final article = _articles[index];
                  final isExpanded = _expandedIndex == index;
                  final isLast = index == _articles.length - 1;

                  return Column(
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            _expandedIndex = isExpanded ? null : index;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                textDirection: TextDirection.rtl,
                                children: [
                                  // 1. Title on the RIGHT in RTL
                                  Expanded(
                                    child: Text(
                                      article.title,
                                      style: TextStyle(
                                        fontFamily: 'Tajawal',
                                        fontSize: 14,
                                        fontWeight: isExpanded ? FontWeight.w800 : FontWeight.w700,
                                        color: const Color(0xFF1E293B),
                                        height: 1.3,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 14),

                                  // 2. Toggle Circle on the LEFT in RTL
                                  if (isExpanded)
                                    Container(
                                      width: 26,
                                      height: 26,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0xFFC1121F),
                                      ),
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.remove_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    )
                                  else
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.add_rounded,
                                        color: Color(0xFF94A3B8),
                                        size: 18,
                                      ),
                                    ),
                                ],
                              ),

                              // Expanded Content Body
                              if (isExpanded) ...[
                                const SizedBox(height: 12),
                                Text(
                                  article.content,
                                  style: const TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF374151),
                                    height: 1.55,
                                  ),
                                ),
                              ],
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
        ),
      ),

      // Fixed Bottom Ad Banner
      if (widget.showFixedBanner)
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
}
