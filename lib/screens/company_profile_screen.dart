import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/models/company_profile_model.dart';
import '../core/models/stock_model.dart';
import '../core/services/stock_service.dart';
import '../widgets/ad_banner_card.dart';
import '../widgets/stock_logo_widget.dart';

class CompanyProfileScreen extends StatefulWidget {
  final StockModel? initialStock;

  const CompanyProfileScreen({super.key, this.initialStock});

  @override
  State<CompanyProfileScreen> createState() => _CompanyProfileScreenState();
}

class _CompanyProfileScreenState extends State<CompanyProfileScreen> {
  StockModel? _selectedStock;
  List<StockModel> _allStocks = [];
  bool _loadingStocks = true;

  bool _loadingProfile = false;
  CompanyProfileModel? _profile;

  @override
  void initState() {
    super.initState();
    _selectedStock = widget.initialStock;
    _initData();
  }

  Future<void> _initData() async {
    try {
      final list = await StockService.getStocksList(perPage: 500, page: 1);
      if (mounted) {
        setState(() {
          _allStocks = list;
          _loadingStocks = false;
          if (_selectedStock == null && list.isNotEmpty) {
            _selectedStock = list.firstWhere(
              (s) => s.symbol.contains('COMI'),
              orElse: () => list.first,
            );
          }
        });
        if (_selectedStock != null) {
          _fetchProfile();
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingStocks = false);
        if (_selectedStock != null) {
          _fetchProfile();
        }
      }
    }
  }

  Future<void> _fetchProfile() async {
    if (_selectedStock == null) return;
    setState(() => _loadingProfile = true);

    try {
      final profile = await StockService.getCompanyProfile(
        _selectedStock!.symbol,
        nameAr: _selectedStock!.displayName,
      );
      if (mounted) {
        setState(() {
          _profile = profile;
          _loadingProfile = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _profile = CompanyProfileModel.fallback(
            _selectedStock!.symbol,
            nameAr: _selectedStock!.displayName,
          );
          _loadingProfile = false;
        });
      }
    }
  }

  void _onStockSelected(StockModel stock) {
    setState(() {
      _selectedStock = stock;
    });
    _fetchProfile();
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openStockSelector() {
    showModalBottomSheet<StockModel>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = _allStocks.where((s) {
              if (query.isEmpty) return true;
              final q = query.toLowerCase();
              return s.symbol.toLowerCase().contains(q) ||
                  s.displayName.toLowerCase().contains(q);
            }).toList();

            return SafeArea(
              child: Container(
                height: MediaQuery.of(context).size.height * 0.75,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'اختر الشركة لعرض البروفايل',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                        onChanged: (val) => setModalState(() => query = val),
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 13.5,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'ابحث عن اسم الشركة أو رمزها...',
                          hintStyle: TextStyle(
                            fontFamily: 'Tajawal',
                            color: Color(0xFF94A3B8),
                            fontSize: 13,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: Color(0xFF94A3B8),
                            size: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text(
                                'لا توجد نتائج مطابقة',
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(
                                height: 1,
                                color: Color(0xFFF1F5F9),
                              ),
                              itemBuilder: (_, idx) {
                                final s = filtered[idx];
                                final isSelected =
                                    _selectedStock?.symbol == s.symbol;
                                return ListTile(
                                  onTap: () {
                                    Navigator.pop(ctx, s);
                                  },
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  leading: StockLogoWidget(
                                    stock: s,
                                    size: 38,
                                    borderRadius: 10,
                                  ),
                                  title: Text(
                                    s.displayName,
                                    textDirection: TextDirection.rtl,
                                    style: TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontWeight: isSelected
                                          ? FontWeight.w900
                                          : FontWeight.w700,
                                      color: isSelected
                                          ? const Color(0xFFC1121F)
                                          : const Color(0xFF1E293B),
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  subtitle: Text(
                                    s.displaySymbol,
                                    textDirection: TextDirection.rtl,
                                    style: const TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontSize: 11.5,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  trailing: Text(
                                    '${s.price.toStringAsFixed(2)} ج.م',
                                    style: const TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((selected) {
      if (selected != null) {
        _onStockSelected(selected);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEFEFE),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          color: const Color(0xFFFEFEFE),
          child: SafeArea(
            bottom: false,
            child: Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
                ),
              ),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  // Right: Back Button
                  InkWell(
                    onTap: () => Navigator.maybePop(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Center: Title
                  const Expanded(
                    child: Text(
                      'بروفايل الشركة',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),

                  // Left: Refresh button
                  InkWell(
                    onTap: _fetchProfile,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: _loadingProfile
                          ? const Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFFC1121F),
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.refresh_rounded,
                              size: 18,
                              color: Color(0xFF1E293B),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              children: [
                // 1. Selector Bar
                _buildSelectorBar(),

                const SizedBox(height: 14),

                if (_loadingProfile)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFC1121F),
                      ),
                    ),
                  )
                else if (_profile != null) ...[
                  // 2. Company Identity Card
                  _buildCompanyHeroCard(_profile!),

                  const SizedBox(height: 14),

                  // 3. Market Live Snapshot Card
                  _buildMarketSnapshotCard(_profile!),

                  const SizedBox(height: 14),

                  // 4. Detailed Corporate Information Card
                  _buildCorporateDetailsCard(_profile!),

                  // 5. Description / About (if present)
                  if (_profile!.description != null &&
                      _profile!.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _buildDescriptionCard(_profile!.description!),
                  ],

                  const SizedBox(height: 16),

                  // 6. Educational Note
                  _buildDisclaimerCard(),

                  const SizedBox(height: 20),
                ] else
                  _buildEmptyState(),
              ],
            ),
          ),

          // Fixed Ad Banner Card at bottom
          const SafeArea(
            top: false,
            child: AdBannerCard(),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // WIDGETS
  // ==========================================

  Widget _buildSelectorBar() {
    return InkWell(
      onTap: _loadingStocks ? null : _openStockSelector,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.015),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            const Icon(
              Icons.search_rounded,
              size: 20,
              color: Color(0xFF64748B),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _selectedStock != null
                    ? '${_selectedStock!.displayName} (${_selectedStock!.displaySymbol})'
                    : 'اضغط لاختيار شركة أخرى...',
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'تغيير',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyHeroCard(CompanyProfileModel profile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            textDirection: TextDirection.rtl,
            children: [
              StockLogoWidget(
                stock: _selectedStock,
                symbol: profile.symbol,
                size: 54,
                borderRadius: 12,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  textDirection: TextDirection.rtl,
                  children: [
                    Text(
                      _selectedStock?.displayName ?? profile.name,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      profile.name,
                      textDirection: TextDirection.ltr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Text(
                            profile.ticker,
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFC1121F),
                            ),
                          ),
                        ),
                        if (profile.sector.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              profile.sector,
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMarketSnapshotCard(CompanyProfileModel profile) {
    final price = profile.currentPrice ?? _selectedStock?.price ?? 0.0;
    final change = profile.change ?? _selectedStock?.change ?? 0.0;
    final changePercent =
        profile.changePercent ?? _selectedStock?.changePercent ?? 0.0;
    final isGain = change >= 0;
    final changeColor =
        isGain ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        textDirection: TextDirection.rtl,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                textDirection: TextDirection.rtl,
                children: [
                  const Text(
                    'سعر السهم الحالي',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 11.5,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      Text(
                        price.toStringAsFixed(2),
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        profile.currency,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: changeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: changeColor.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  textDirection: TextDirection.rtl,
                  children: [
                    Icon(
                      isGain
                          ? Icons.arrow_drop_up_rounded
                          : Icons.arrow_drop_down_rounded,
                      color: changeColor,
                      size: 20,
                    ),
                    Text(
                      '${changePercent.abs().toStringAsFixed(2)}% (${change.abs().toStringAsFixed(2)})',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: changeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          Row(
            textDirection: TextDirection.rtl,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricCell(
                label: 'الافتتاح',
                value: profile.open != null
                    ? '${profile.open!.toStringAsFixed(2)} ج.م'
                    : (_selectedStock?.open != null
                        ? '${_selectedStock!.open!.toStringAsFixed(2)} ج.م'
                        : '-'),
              ),
              _buildMetricCell(
                label: 'أعلى سعر',
                value: profile.high != null
                    ? '${profile.high!.toStringAsFixed(2)} ج.م'
                    : (_selectedStock?.high != null
                        ? '${_selectedStock!.high!.toStringAsFixed(2)} ج.م'
                        : '-'),
              ),
              _buildMetricCell(
                label: 'أدنى سعر',
                value: profile.low != null
                    ? '${profile.low!.toStringAsFixed(2)} ج.م'
                    : (_selectedStock?.low != null
                        ? '${_selectedStock!.low!.toStringAsFixed(2)} ج.م'
                        : '-'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCell({required String label, required String value}) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 11,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildCorporateDetailsCard(CompanyProfileModel profile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                'بيانات الشركة والورقة المالية',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          _buildInfoRow(
            label: 'رمز السهم (Ticker)',
            value: profile.symbol,
            isLtr: true,
          ),
          _buildInfoRow(
            label: 'البورصة المدرج بها',
            value: profile.exchange == 'EGX'
                ? 'البورصة المصرية (EGX)'
                : profile.exchange,
          ),
          _buildInfoRow(
            label: 'عملة التداول',
            value: profile.currency == 'EGP'
                ? 'الجنيه المصري (EGP)'
                : profile.currency,
          ),
          if (profile.sector.isNotEmpty)
            _buildInfoRow(
              label: 'القطاع الرئيسي',
              value: profile.sector,
            ),
          _buildInfoRow(
            label: 'نوع الورقة المالية',
            value: profile.subType == 'common' ? 'أسهم عادية' : profile.subType,
          ),
          if (profile.isin.isNotEmpty)
            _buildInfoRow(
              label: 'رقم التعريف الدولي (ISIN)',
              value: profile.isin,
              isLtr: true,
            ),
          if (profile.ceo != null && profile.ceo!.trim().isNotEmpty)
            _buildInfoRow(
              label: 'الرئيس التنفيذي / العضو المنتدب',
              value: profile.ceo!,
            ),
          if (profile.employees != null &&
              profile.employees!.trim().isNotEmpty)
            _buildInfoRow(
              label: 'عدد الموظفين',
              value: profile.employees!,
            ),
          if (profile.website != null && profile.website!.trim().isNotEmpty)
            InkWell(
              onTap: () => _launchUrl(profile.website!),
              child: _buildInfoRow(
                label: 'الموقع الرسمي',
                value: profile.website!,
                isLtr: true,
                isLink: true,
                isLast: true,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    bool isLtr = false,
    bool isLink = false,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            textDirection: TextDirection.rtl,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 12.5,
                  color: Color(0xFF64748B),
                ),
              ),
              Flexible(
                child: Text(
                  value,
                  textDirection: isLtr ? TextDirection.ltr : TextDirection.rtl,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isLink
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF1E293B),
                    decoration:
                        isLink ? TextDecoration.underline : TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, color: Color(0xFFF1F5F9)),
      ],
    );
  }

  Widget _buildDescriptionCard(String desc) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        textDirection: TextDirection.rtl,
        children: [
          const Text(
            'نبذة عن نشاط الشركة',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 12,
              height: 1.6,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimerCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Row(
        textDirection: TextDirection.rtl,
        children: [
          Icon(
            Icons.shield_outlined,
            size: 16,
            color: Color(0xFF64748B),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'البيانات الرسمية لملف الشركة مستخرجة من مصادر البورصة وتخضع للتحديثات الدورية.',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 11,
                color: Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Text(
          'لا تتوفر معلومات ملف الشركة حالياً',
          style: TextStyle(
            fontFamily: 'Tajawal',
            color: Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }
}
