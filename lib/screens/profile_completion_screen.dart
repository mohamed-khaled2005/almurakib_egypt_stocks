import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/country_options.dart';
import '../data/trading_status_options.dart';
import '../providers/app_manager_provider.dart';
import '../utils/app_manager_config.dart';
import '../utils/phone_number_helper.dart';
import '../widgets/country_picker_form_field.dart';

class ProfileCompletionScreen extends StatefulWidget {
  const ProfileCompletionScreen({
    super.key,
    this.mandatory = true,
    this.isDialog = true,
  });

  final bool mandatory;
  final bool isDialog;

  static Future<bool> ensureCompleted(
    BuildContext context, {
    bool mandatory = true,
  }) async {
    final manager = context.read<AppManagerProvider>();
    if (!manager.requiresProfileCompletion) {
      return true;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: !mandatory,
      barrierColor: Colors.black.withValues(alpha: 0.54),
      builder: (_) => ProfileCompletionScreen(
        mandatory: mandatory,
        isDialog: true,
      ),
    );

    if (!context.mounted) {
      return result == true;
    }

    return result == true ||
        !context.read<AppManagerProvider>().requiresProfileCompletion;
  }

  @override
  State<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();

  bool _didManuallySelectCountry = false;
  String? _selectedCountryCode;
  String? _selectedTradingStatus;

  @override
  void initState() {
    super.initState();
    final manager = context.read<AppManagerProvider>();
    final user = manager.user;
    _selectedCountryCode = countryOptionByCode(user?.countryCode)?.code ??
        countryOptionByCode(manager.suggestedCountryCode)?.code ??
        'EG';
    _selectedTradingStatus =
        tradingStatusOptionByValue(user?.tradingStatus)?.value;

    final rawPhone = (user?.phoneNumber ?? '').trim();
    final country = _selectedCountry();
    if (country != null && rawPhone.startsWith(country.dialCode)) {
      _phoneController.text =
          rawPhone.substring(country.dialCode.length).trim();
    } else {
      _phoneController.text = rawPhone;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  CountryOption? _selectedCountry() =>
      countryOptionByCode(_selectedCountryCode) ?? countryOptionByCode('EG');

  void _syncSuggestedCountry(AppManagerProvider manager) {
    if (_didManuallySelectCountry) {
      return;
    }

    final suggestedCountryCode =
        countryOptionByCode(manager.user?.countryCode)?.code ??
            countryOptionByCode(manager.suggestedCountryCode)?.code;

    if (suggestedCountryCode != null) {
      _selectedCountryCode = suggestedCountryCode;
    }
  }

  Future<void> _openCountryPicker() async {
    final result = await showModalBottomSheet<CountryOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => CountrySearchSheet(
        selectedCode: _selectedCountryCode,
        accentColor: const Color(0xFFC1121F),
        backgroundColor: Colors.white,
      ),
    );

    if (result != null) {
      setState(() {
        _didManuallySelectCountry = true;
        _selectedCountryCode = result.code;
      });
    }
  }

  Widget _buildFlagWidget(CountryOption country) {
    if (country.code == 'EG') {
      return Container(
        width: 22,
        height: 22,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
        ),
        child: Column(
          children: [
            Expanded(child: Container(color: const Color(0xFFCE1126))),
            Expanded(
              child: Container(
                color: Colors.white,
                child: Center(
                  child: Container(
                    width: 5,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: Color(0xFFC09300),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: Container(color: Colors.black)),
          ],
        ),
      );
    }
    return Text(
      country.flagEmoji,
      style: const TextStyle(fontSize: 18),
    );
  }

  Future<void> _submit() async {
    final manager = context.read<AppManagerProvider>();
    final country = _selectedCountry();
    if (country == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر الدولة أولًا.')),
      );
      return;
    }

    final rawPhone = _phoneController.text.trim();
    String? normalizedE164;
    if (rawPhone.isNotEmpty) {
      final normalized = PhoneNumberHelper.tryNormalize(
        rawInput: rawPhone.startsWith('+') ? rawPhone : '${country.dialCode}$rawPhone',
        regionCode: country.code,
      );
      if (normalized == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('أدخل رقم هاتف صحيحًا.')),
        );
        return;
      }
      normalizedE164 = normalized.e164;
    }

    final ok = await manager.updateProfile(
      countryCode: country.code,
      countryName: country.name,
      phoneNumber: normalizedE164,
      tradingStatus: AppManagerConfig.supportsTradingStatus
          ? _selectedTradingStatus
          : null,
    );

    if (!mounted) {
      return;
    }

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            manager.errorMessage ?? 'تعذر حفظ بيانات الحساب.',
          ),
        ),
      );
      return;
    }

    Navigator.of(context).pop(true);
  }

  Future<void> _logout() async {
    await context.read<AppManagerProvider>().logout();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(false);
  }

  Widget _buildCardContent(BuildContext context, AppManagerProvider manager) {
    final country = _selectedCountry() ?? const CountryOption(code: 'EG', name: 'مصر', dialCode: '+20');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Row: Title + Shield Icon Badge (Matches Image 4)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              textDirection: TextDirection.rtl,
              children: [
                const Text(
                  'استكمال بيانات الحساب',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFDE8E8),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.shield_outlined,
                      color: Color(0xFFC1121F),
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Subtitle
            const Text(
              'أكمل الدولة وبيانات التداول. يمكنك إضافة الهاتف الآن أو لاحقاً.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            // Field 1: رقم الهاتف (اختياري)
            Row(
              textDirection: TextDirection.rtl,
              children: const [
                Text(
                  'رقم الهاتف',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                SizedBox(width: 4),
                Text(
                  '(اختياري)',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Phone Input Box with Integrated Country Flag & Dial Code (Matches Image 4)
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                textDirection: TextDirection.ltr,
                children: [
                  // Flag Button + Chevron (Leftmost in LTR)
                  InkWell(
                    onTap: manager.isBusy ? null : _openCountryPicker,
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildFlagWidget(country),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: Color(0xFF64748B),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Dial Code (+20)
                  Text(
                    country.dialCode,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Phone Number Input with Placeholder
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.left,
                      enabled: !manager.isBusy,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        hintText: country.code == 'EG' ? '1x xxxx xxxx' : 'xx xxx xxxx',
                        hintStyle: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),

            // Helper text under phone
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'اختر العلم لتغيير كود الدولة تلقائياً.',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Field 2: ما الذي يصفك بشكل أفضل؟ (اختياري)
            if (AppManagerConfig.supportsTradingStatus) ...[
              Row(
                textDirection: TextDirection.rtl,
                children: const [
                  Text(
                    'ما الذي يصفك بشكل أفضل؟',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  SizedBox(width: 4),
                  Text(
                    '(اختياري)',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Dropdown Box (Matches Image 4)
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedTradingStatus,
                    isExpanded: true,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: Color(0xFF64748B),
                    ),
                    hint: const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'اختر الوصف المناسب',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                    items: kTradingStatusOptions
                        .map(
                          (opt) => DropdownMenuItem(
                            value: opt.value,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                opt.label,
                                textDirection: TextDirection.rtl,
                                style: const TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: manager.isBusy
                        ? null
                        : (val) {
                            setState(() {
                              _selectedTradingStatus = val;
                            });
                          },
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Submit Button: حفظ والمتابعة (Matches Image 4)
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: manager.isBusy ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC1121F),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: manager.isBusy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'حفظ والمتابعة',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),

            // Logout Button (Matches Image 4)
            Center(
              child: InkWell(
                onTap: manager.isBusy ? null : _logout,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'تسجيل الخروج',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(
                        Icons.logout_rounded,
                        size: 18,
                        color: Color(0xFF475569),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<AppManagerProvider>();
    _syncSuggestedCountry(manager);

    if (widget.isDialog) {
      return PopScope(
        canPop: !widget.mandatory,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _buildCardContent(context, manager),
          ),
        ),
      );
    }

    return PopScope(
      canPop: !widget.mandatory,
      child: Scaffold(
        backgroundColor: const Color(0xFFFEFEFE),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFEFEFE),
          elevation: 0,
          leading: widget.mandatory
              ? null
              : IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF111827)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: _buildCardContent(context, manager),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
