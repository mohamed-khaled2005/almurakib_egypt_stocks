import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils/constants.dart';
import '../models/educational_article_model.dart';
import '../providers/app_manager_provider.dart';
import '../widgets/app_section_header.dart';

const String _kEducationTitle = 'المحتوى التعليمي';

class EducationalContentScreen extends StatefulWidget {
  const EducationalContentScreen({super.key});

  @override
  State<EducationalContentScreen> createState() =>
      _EducationalContentScreenState();
}

class _EducationalContentScreenState extends State<EducationalContentScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppManagerProvider>().refreshEducationalContent();
    });
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<AppManagerProvider>();
    final articles = manager.articles;

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: RefreshIndicator(
        onRefresh: manager.refreshEducationalContent,
        color: AppColors.primaryBlue,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: <Widget>[
            const AppSectionHeader(title: _kEducationTitle),
            const SizedBox(height: 12),
            Text(
              'مقالات مبسطة تساعدك على فهم السوق المصري وقراءة حركة الأسهم بشكل أوضح.',
              style: AppTextStyles.bodyMedium.copyWith(
                height: 1.7,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            if (articles.isEmpty)
              const _EmptyEducationalState()
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 760;
                  final itemWidth = isWide
                      ? (constraints.maxWidth - 12) / 2
                      : constraints.maxWidth;

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: articles
                        .map(
                          (article) => SizedBox(
                            width: itemWidth,
                            child: _ArticleCard(article: article),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyEducationalState extends StatelessWidget {
  const _EmptyEducationalState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Column(
        children: <Widget>[
          Icon(
            Icons.menu_book_outlined,
            size: 34,
            color: AppColors.primaryBlue,
          ),
          SizedBox(height: 10),
          Text(
            'لا يوجد محتوى تعليمي متاح حاليًا.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({required this.article});

  final EducationalArticleSummary article;

  @override
  Widget build(BuildContext context) {
    final category = article.category?.trim();
    final badgeText = (category != null && category.isNotEmpty)
        ? category
        : (article.isFeatured ? 'محتوى مميز' : 'محتوى تعليمي');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  EducationalArticleDetailsScreen(slug: article.slug),
            ),
          );
        },
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(21)),
                child: SizedBox(
                  height: 164,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      if (article.coverImageUrl != null &&
                          article.coverImageUrl!.trim().isNotEmpty)
                        Image.network(
                          article.coverImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholderCover(),
                        )
                      else
                        _placeholderCover(),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.58),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: article.isFeatured
                                ? AppColors.accentGold
                                : Colors.white,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            badgeText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: article.isFeatured
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      article.excerpt.trim().isEmpty
                          ? 'افتح المحتوى لقراءة التفاصيل الكاملة.'
                          : article.excerpt,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium.copyWith(
                        height: 1.65,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        const Icon(
                          Icons.play_circle_fill_rounded,
                          size: 18,
                          color: AppColors.primaryBlue,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'ابدأ القراءة',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${article.readingMinutes} د',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholderCover() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[Color(0xFFF9D9DE), Color(0xFFCE1126)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.school_outlined,
          color: Colors.white,
          size: 36,
        ),
      ),
    );
  }
}

class EducationalArticleDetailsScreen extends StatefulWidget {
  const EducationalArticleDetailsScreen({super.key, required this.slug});

  final String slug;

  @override
  State<EducationalArticleDetailsScreen> createState() =>
      _EducationalArticleDetailsScreenState();
}

class _EducationalArticleDetailsScreenState
    extends State<EducationalArticleDetailsScreen> {
  EducationalArticleDetail? _article;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final manager = context.read<AppManagerProvider>();
    final article = await manager.getEducationalArticleDetail(widget.slug);
    if (!mounted) return;
    setState(() {
      _article = article;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        title: const Text(
          _kEducationTitle,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryBlue),
            )
          : _article == null
              ? const Center(
                  child: Text(
                    'تعذر تحميل المحتوى.',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: <Widget>[
                    _DetailsHero(article: _article!),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 14,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          if ((_article!.category ?? '').trim().isNotEmpty ||
                              _article!.isFeatured) ...<Widget>[
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: <Widget>[
                                if ((_article!.category ?? '')
                                    .trim()
                                    .isNotEmpty)
                                  _metaChip(
                                    _article!.category!.trim(),
                                    background: AppColors.cardLight,
                                    foreground: AppColors.primaryBlue,
                                  ),
                                if (_article!.isFeatured)
                                  _metaChip(
                                    'محتوى مميز',
                                    background: AppColors.accentGold,
                                    foreground: Colors.white,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 14),
                          ],
                          ..._buildBodyParagraphs(_article!.body),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  List<Widget> _buildBodyParagraphs(String body) {
    final paragraphs = body
        .split(RegExp(r'\n{2,}'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    if (paragraphs.isEmpty) {
      return <Widget>[
        Text(
          'لا يوجد نص متاح لهذا المحتوى.',
          style: AppTextStyles.bodyMedium.copyWith(height: 1.8),
        ),
      ];
    }

    return paragraphs
        .map(
          (paragraph) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              paragraph,
              textAlign: TextAlign.right,
              style: AppTextStyles.bodyLarge.copyWith(
                height: 1.95,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        )
        .toList();
  }

  Widget _metaChip(
    String text, {
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: foreground,
        ),
      ),
    );
  }
}

class _DetailsHero extends StatelessWidget {
  const _DetailsHero({required this.article});

  final EducationalArticleDetail article;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (article.coverImageUrl != null &&
                article.coverImageUrl!.trim().isNotEmpty)
              Image.network(
                article.coverImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _heroFallback(),
              )
            else
              _heroFallback(),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    Colors.black.withValues(alpha: 0.08),
                    Colors.black.withValues(alpha: 0.72),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  article.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[Color(0xFFF1BFC6), Color(0xFF9F0D1D)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.lightbulb_outline_rounded,
          color: Colors.white,
          size: 42,
        ),
      ),
    );
  }
}
