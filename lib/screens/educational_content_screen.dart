import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils/constants.dart';
import '../models/educational_article_model.dart';
import '../providers/app_manager_provider.dart';
import '../widgets/app_section_header.dart';

const String _kEducationTitle = 'المحتوى التعليمي';
const String _kNoEducationContent = 'لا يوجد محتوى تعليمي متاح حاليًا.';
const String _kLoadContentError = 'تعذر تحميل المحتوى.';
const String _kFeaturedContent = 'محتوى مميز';
const String _kNoBodyText = 'لا يوجد نص متاح لهذا المحتوى.';

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String _formatPublishedDate(String? rawValue) {
  final raw = (rawValue ?? '').trim();
  if (raw.isEmpty) {
    return '';
  }

  final parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    return raw;
  }

  final local = parsed.toLocal();
  return '${local.year}/${_twoDigits(local.month)}/${_twoDigits(local.day)}';
}

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
    final items = manager.articles;

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: RefreshIndicator(
        onRefresh: manager.refreshEducationalContent,
        color: AppColors.primaryBlue,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
          children: <Widget>[
            const SizedBox(height: 6),
            const AppSectionHeader(title: _kEducationTitle),
            const SizedBox(height: 14),
            if (items.isEmpty)
              const _EmptyEducationalState()
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 760;
                  final cardWidth = isWide
                      ? (constraints.maxWidth - 12) / 2
                      : constraints.maxWidth;

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: items
                        .map(
                          (article) => SizedBox(
                            width: cardWidth,
                            child: _LearningModuleCard(article: article),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
            color: AppColors.primaryBlue,
            size: 34,
          ),
          SizedBox(height: 8),
          Text(
            _kNoEducationContent,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Tajawal',
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArticlePill extends StatelessWidget {
  const _ArticlePill({
    required this.text,
    required this.backgroundColor,
    required this.foregroundColor,
    this.icon,
    this.compact = false,
  });

  final String text;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: compact ? 180 : 240),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 11,
        vertical: compact ? 6 : 7,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(
              icon,
              size: compact ? 13 : 14,
              color: foregroundColor,
            ),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: compact ? 11.2 : 11.8,
              fontWeight: FontWeight.w800,
              color: foregroundColor,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _LearningModuleCard extends StatelessWidget {
  const _LearningModuleCard({required this.article});

  final EducationalArticleSummary article;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
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
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: article.isFeatured
                  ? AppColors.accentGold.withValues(alpha: 0.24)
                  : AppColors.border,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              children: <Widget>[
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: article.isFeatured
                        ? AppColors.accentGold.withValues(alpha: 0.14)
                        : AppColors.primaryBlue.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: article.isFeatured
                          ? AppColors.accentGold.withValues(alpha: 0.22)
                          : AppColors.primaryBlue.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Icon(
                    article.isFeatured
                        ? Icons.auto_stories_rounded
                        : Icons.article_outlined,
                    color: article.isFeatured
                        ? AppColors.accentGold
                        : AppColors.primaryBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: article.isFeatured
                      ? AppColors.accentGold
                      : AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EducationalArticleDetailsScreen extends StatefulWidget {
  const EducationalArticleDetailsScreen({
    super.key,
    required this.slug,
  });

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
        titleTextStyle: const TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: AppColors.textPrimary,
        ),
        title: const Text(_kEducationTitle),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryBlue),
            )
          : _article == null
              ? const Center(
                  child: Text(
                    _kLoadContentError,
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
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
                                    icon: Icons.sell_outlined,
                                  ),
                                if (_article!.isFeatured)
                                  _metaChip(
                                    _kFeaturedContent,
                                    icon: Icons.auto_awesome_rounded,
                                    backgroundColor: AppColors.accentGold,
                                    foregroundColor: Colors.white,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color:
                                  AppColors.cardLight.withValues(alpha: 0.38),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.border.withValues(alpha: 0.65),
                              ),
                            ),
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
                            child: SelectionArea(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: _buildBodyParagraphs(
                                  body: _article!.body,
                                  title: _article!.title,
                                  excerpt: _article!.excerpt,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _metaChip(
    String text, {
    IconData? icon,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    return _ArticlePill(
      text: text,
      icon: icon,
      compact: true,
      backgroundColor: backgroundColor ?? AppColors.cardLight,
      foregroundColor: foregroundColor ?? AppColors.textSecondary,
    );
  }

  List<Widget> _buildBodyParagraphs({
    required String body,
    String? title,
    String? excerpt,
  }) {
    final cleaned = _sanitizeBodyText(body);
    if (cleaned.isEmpty) {
      return const <Widget>[
        Text(
          _kNoBodyText,
          style: TextStyle(
            fontFamily: 'Tajawal',
            color: AppColors.textSecondary,
          ),
        ),
      ];
    }

    var sourceParagraphs = cleaned
        .split(RegExp(r'\n\s*\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (sourceParagraphs.length <= 1 && cleaned.contains('\n')) {
      sourceParagraphs = cleaned
          .split(RegExp(r'\n+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    if (sourceParagraphs.isEmpty) {
      sourceParagraphs.add(cleaned);
    }

    final blocked = <String>{
      _normalizeForCompare(title),
      _normalizeForCompare(excerpt),
    }..removeWhere((value) => value.isEmpty);

    final seen = <String>{};
    final paragraphs = <String>[];
    for (var index = 0; index < sourceParagraphs.length; index++) {
      final text = sourceParagraphs[index];
      final normalized = _normalizeForCompare(text);
      if (normalized.isEmpty) continue;
      if (blocked.contains(normalized)) continue;
      if (seen.contains(normalized)) continue;
      if (_isMergedDuplicateParagraph(
        index: index,
        paragraphs: sourceParagraphs,
        blocked: blocked,
      )) {
        continue;
      }
      seen.add(normalized);
      paragraphs.add(text);
    }

    if (paragraphs.isEmpty && cleaned.isNotEmpty) {
      paragraphs.add(cleaned);
    }

    return paragraphs
        .map(
          (text) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              text,
              textAlign: TextAlign.start,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 15.2,
                color: AppColors.textPrimary,
                height: 1.95,
              ),
            ),
          ),
        )
        .toList();
  }

  String _sanitizeBodyText(String body) {
    return body
        .replaceAll(RegExp(r'\r\n?'), '\n')
        .replaceAll(RegExp(r'&nbsp;', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'&amp;', caseSensitive: false), '&')
        .replaceAll(RegExp(r'&lt;', caseSensitive: false), '<')
        .replaceAll(RegExp(r'&gt;', caseSensitive: false), '>')
        .replaceAll(RegExp(r'&quot;', caseSensitive: false), '"')
        .replaceAll(RegExp(r'&#39;', caseSensitive: false), "'")
        .replaceAll(RegExp(r'<br\\s*/?>', caseSensitive: false), '\n')
        .replaceAll(
          RegExp(
            r'<(p|div|section|article|ul|ol|h[1-6])[^>]*>',
            caseSensitive: false,
          ),
          '\n\n',
        )
        .replaceAll(
          RegExp(
            r'</(p|div|section|article|ul|ol|h[1-6])>',
            caseSensitive: false,
          ),
          '\n\n',
        )
        .replaceAll(
          RegExp(r'<li[^>]*>', caseSensitive: false),
          '\n- ',
        )
        .replaceAll(
          RegExp(r'</li>', caseSensitive: false),
          '\n\n',
        )
        .replaceAll(RegExp(r'<[^>]+>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        .trim();
  }

  bool _isMergedDuplicateParagraph({
    required int index,
    required List<String> paragraphs,
    required Set<String> blocked,
  }) {
    final candidate = _normalizeForCompare(paragraphs[index]);
    if (candidate.length < 120) {
      return false;
    }

    var mergedMatches = 0;
    var mergedCharacters = 0;
    for (var i = index + 1; i < paragraphs.length; i++) {
      final other = _normalizeForCompare(paragraphs[i]);
      if (other.length < 24) continue;
      if (candidate.contains(other)) {
        mergedMatches += 1;
        mergedCharacters += other.length;
        if (mergedMatches >= 2) {
          return true;
        }
      }
    }

    if (mergedMatches >= 1 &&
        mergedCharacters >= (candidate.length * 0.35).round()) {
      return true;
    }

    if (index == 0 && mergedMatches >= 1) {
      for (final blockedValue in blocked) {
        if (blockedValue.isEmpty) continue;
        if (candidate.contains(blockedValue) &&
            candidate.length >= blockedValue.length + 80) {
          return true;
        }
      }
    }

    return false;
  }

  String _normalizeForCompare(String? value) {
    if (value == null) {
      return '';
    }
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[\u0610-\u061A\u064B-\u065F]'), '')
        .replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '')
        .trim();
  }
}

class _DetailsHero extends StatelessWidget {
  const _DetailsHero({required this.article});

  final EducationalArticleDetail article;

  @override
  Widget build(BuildContext context) {
    final publishedLabel = _formatPublishedDate(article.publishedAt);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFFFFFFFF), Color(0xFFFFF2F4)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.border,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (article.isFeatured)
                  _ArticlePill(
                    text: _kFeaturedContent,
                    icon: Icons.auto_awesome_rounded,
                    backgroundColor: AppColors.accentGold,
                    foregroundColor: Colors.white,
                  ),
                if ((article.category ?? '').trim().isNotEmpty)
                  _ArticlePill(
                    text: article.category!.trim(),
                    icon: Icons.sell_outlined,
                    backgroundColor: AppColors.cardLight,
                    foregroundColor: AppColors.textSecondary,
                  ),
                if (publishedLabel.isNotEmpty)
                  _ArticlePill(
                    text: publishedLabel,
                    icon: Icons.calendar_today_outlined,
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.textSecondary,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              article.title,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
