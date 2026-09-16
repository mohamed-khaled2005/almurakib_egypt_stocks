import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils/constants.dart';
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
  });

  final bool mandatory;

  static Future<bool> ensureCompleted(
    BuildContext context, {
    bool mandatory = true,
  }) async {
    final manager = context.read<AppManagerProvider>();
    if (!manager.requiresProfileCompletion) {
      return true;
    }

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ProfileCompletionScreen(mandatory: mandatory),
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
        countryOptionByCode(manager.suggestedCountryCode)?.code;
    _selectedTradingStatus =
        tradingStatusOptionByValue(user?.tradingStatus)?.value;
    _phoneController.text = (user?.phoneNumber ?? '').trim();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  CountryOption? _selectedCountry() =>
      countryOptionByCode(_selectedCountryCode);

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

  String? _validatePhone(String? value) {
    final manager = context.read<AppManagerProvider>();
    final input = (value ?? '').trim();

    if (input.isEmpty) {
      return manager.shouldRequirePhoneNumberForCurrentUser
          ? 'أدخل رقم الهاتف.'
          : null;
    }

    final country = _selectedCountry();
    if (country == null) {
      return 'اختر الدولة أولًا.';
    }

    final normalized = PhoneNumberHelper.tryNormalize(
      rawInput: input,
      regionCode: country.code,
    );

    return normalized == null ? 'أدخل رقم هاتف صحيحًا.' : null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final manager = context.read<AppManagerProvider>();
    final country = _selectedCountry();
    if (country == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر الدولة أولًا.')),
      );
      return;
    }

    final normalizedPhone = _phoneController.text.trim().isEmpty
        ? null
        : PhoneNumberHelper.tryNormalize(
            rawInput: _phoneController.text.trim(),
            regionCode: country.code,
          );

    final ok = await manager.updateProfile(
      countryCode: country.code,
      countryName: country.name,
      phoneNumber: normalizedPhone?.e164,
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

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: AppColors.border),
    );

    return InputDecoration(
      labelText: label,
      labelStyle: AppTextStyles.bodySmall.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w700,
      ),
      filled: true,
      fillColor: AppColors.cardDark,
      prefixIcon: Icon(icon, color: AppColors.primaryBlue, size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(
          color: AppColors.primaryBlue,
          width: 1.2,
        ),
      ),
      errorBorder: border.copyWith(
        borderSide: const BorderSide(color: AppColors.error, width: 1.2),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: const BorderSide(color: AppColors.error, width: 1.3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<AppManagerProvider>();
    _syncSuggestedCountry(manager);
    final requiresPhone = manager.shouldRequirePhoneNumberForCurrentUser;

    return PopScope(
      canPop: !widget.mandatory,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppColors.scaffold,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBlue
                                      .withValues(alpha: 0.10),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.verified_user_outlined,
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      'استكمال بيانات الحساب',
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      requiresPhone
                                          ? 'أكمل الدولة ورقم الهاتف وبيانات التداول للمتابعة.'
                                          : 'أكمل الدولة وبيانات التداول. يمكنك إضافة الهاتف الآن أو لاحقًا.',
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.textSecondary,
                                        height: 1.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          CountryPickerFormField(
                            key: ValueKey(
                              'profile-country-${_selectedCountryCode ?? "none"}',
                            ),
                            initialValue: _selectedCountryCode,
                            enabled: !manager.isBusy,
                            showLabel: false,
                            label: 'الدولة',
                            hintText: 'ابحث واختر الدولة',
                            sheetBackgroundColor: Colors.white,
                            accentColor: AppColors.primaryBlue,
                            decoration: _fieldDecoration(
                              label: 'الدولة',
                              icon: Icons.public_rounded,
                            ),
                            validator: (value) {
                              if ((value ?? '').trim().isEmpty) {
                                return 'اختر الدولة.';
                              }
                              return null;
                            },
                            onChanged: (value) {
                              setState(() {
                                _didManuallySelectCountry = true;
                                _selectedCountryCode = value;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            decoration: _fieldDecoration(
                              label: requiresPhone
                                  ? 'رقم الهاتف'
                                  : 'رقم الهاتف (اختياري)',
                              icon: Icons.phone_android_rounded,
                            ),
                            validator: _validatePhone,
                          ),
                          if (AppManagerConfig.supportsTradingStatus) ...<Widget>[
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedTradingStatus,
                              decoration: _fieldDecoration(
                                label: kTradingStatusQuestionLabel,
                                icon: Icons.query_stats_rounded,
                              ),
                              dropdownColor: Colors.white,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                              items: kTradingStatusOptions
                                  .map(
                                    (option) => DropdownMenuItem<String>(
                                      value: option.value,
                                      child: Text(option.label),
                                    ),
                                  )
                                  .toList(),
                              onChanged: manager.isBusy
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _selectedTradingStatus = value;
                                      });
                                    },
                              validator: (value) {
                                if ((value ?? '').trim().isEmpty) {
                                  return 'اختر إجابة السؤال.';
                                }
                                return null;
                              },
                            ),
                          ],
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: manager.isBusy ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryBlue,
                                foregroundColor: Colors.white,
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
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                            ),
                          ),
                          if (widget.mandatory) ...<Widget>[
                            const SizedBox(height: 10),
                            TextButton.icon(
                              onPressed: manager.isBusy ? null : _logout,
                              icon: const Icon(Icons.logout_rounded, size: 18),
                              label: const Text(
                                'تسجيل الخروج',
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
