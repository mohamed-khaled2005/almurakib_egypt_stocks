import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils/constants.dart';
import '../data/country_options.dart';
import '../data/trading_status_options.dart';
import '../models/managed_app_user.dart';
import '../providers/app_manager_provider.dart';
import '../utils/app_manager_config.dart';
import '../utils/phone_number_helper.dart';
import '../widgets/app_section_header.dart';
import '../widgets/country_picker_form_field.dart';
import 'auth_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({
    super.key,
    this.onAuthSuccess,
  });

  final VoidCallback? onAuthSuccess;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();

  String _syncedName = '';
  String _syncedPhone = '';
  String? _syncedCountryCode;
  String? _syncedTradingStatus;
  String? _selectedCountryCode;
  String? _selectedTradingStatus;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _openAuth() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(builder: (_) => const AuthScreen()),
    );

    if (!mounted || result != true) {
      return;
    }

    widget.onAuthSuccess?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تسجيل الدخول بنجاح.')),
    );
  }

  CountryOption? _selectedCountry() =>
      countryOptionByCode(_selectedCountryCode);

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

  Future<void> _saveProfile(AppManagerProvider manager) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = manager.user;
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
      fullName: _nameController.text.trim(),
      countryCode: country.code,
      countryName: country.name,
      phoneNumber: normalizedPhone?.e164,
      tradingStatus: AppManagerConfig.supportsTradingStatus
          ? _selectedTradingStatus
          : null,
      currentPassword: user?.hasPassword == true &&
              _currentPasswordController.text.trim().isNotEmpty
          ? _currentPasswordController.text.trim()
          : null,
      newPassword: user?.hasPassword == true &&
              _newPasswordController.text.trim().isNotEmpty
          ? _newPasswordController.text.trim()
          : null,
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'تم تحديث الحساب بنجاح.'
              : (manager.errorMessage ?? 'تعذر تحديث الحساب حاليًا.'),
        ),
      ),
    );

    if (!ok) {
      return;
    }

    _setControllerText(_phoneController, normalizedPhone?.e164 ?? '');
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _syncedName = _nameController.text.trim();
    _syncedPhone = normalizedPhone?.e164 ?? '';
    _syncedCountryCode = country.code;
    _syncedTradingStatus = _selectedTradingStatus;
  }

  Future<void> _logoutAndNavigate(AppManagerProvider manager) async {
    await manager.logout();
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تسجيل الخروج بنجاح.')),
    );
  }

  Future<void> _confirmDelete(AppManagerProvider manager) async {
    final user = manager.user;
    if (user == null) {
      return;
    }

    final passwordController = TextEditingController();
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text(
                'تأكيد حذف الحساب',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.w900,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    user.hasPassword
                        ? 'سيؤدي حذف الحساب إلى إزالة بياناتك نهائيًا. أدخل كلمة المرور الحالية للمتابعة.'
                        : 'سيؤدي حذف الحساب إلى إزالة بياناتك نهائيًا من التطبيق.',
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      height: 1.45,
                    ),
                  ),
                  if (user.hasPassword) ...<Widget>[
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور الحالية',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('حذف الحساب'),
                ),
              ],
            );
          },
        ) ??
        false;

    final password = passwordController.text.trim();
    passwordController.dispose();

    if (!mounted || !shouldDelete) {
      return;
    }

    if (user.hasPassword && password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل كلمة المرور الحالية أولًا.')),
      );
      return;
    }

    final ok = await manager.deleteAccount(
      password: user.hasPassword ? password : null,
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'تم حذف الحساب بنجاح.'
              : (manager.errorMessage ?? 'تعذر حذف الحساب حاليًا.'),
        ),
      ),
    );
  }

  void _setControllerText(TextEditingController controller, String value) {
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _syncFormFromUser(ManagedAppUser user) {
    final manager = context.read<AppManagerProvider>();
    final name = user.displayName.trim();
    final phone = (user.phoneNumber ?? '').trim();
    final countryCode = countryOptionByCode(user.countryCode)?.code ??
        countryOptionByCode(manager.suggestedCountryCode)?.code;
    final tradingStatus = tradingStatusOptionByValue(user.tradingStatus)?.value;

    if (_nameController.text.trim() == _syncedName) {
      _setControllerText(_nameController, name);
    }
    if (_phoneController.text.trim() == _syncedPhone) {
      _setControllerText(_phoneController, phone);
    }
    if ((_selectedCountryCode ?? '') == (_syncedCountryCode ?? '')) {
      _selectedCountryCode = countryCode;
    }
    if ((_selectedTradingStatus ?? '') == (_syncedTradingStatus ?? '')) {
      _selectedTradingStatus = tradingStatus;
    }

    _syncedName = name;
    _syncedPhone = phone;
    _syncedCountryCode = countryCode;
    _syncedTradingStatus = tradingStatus;
  }

  InputDecoration _fieldDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: AppColors.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primaryBlue),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: AppTextStyles.bodySmall.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool obscureText = false,
    TextInputType? keyboardType,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildLabel(label),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          enabled: enabled,
          validator: validator,
          decoration: _fieldDecoration(),
        ),
      ],
    );
  }

  Widget _buildLoggedOutState() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryBlue.withValues(alpha: 0.12),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'سجل دخولك للوصول إلى إعدادات الحساب وإدارة بياناتك الشخصية بسهولة.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 46,
            child: ElevatedButton(
              onPressed: _openAuth,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'تسجيل الدخول / إنشاء حساب',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<AppManagerProvider>();
    final user = manager.user;

    final padding = EdgeInsets.fromLTRB(
      16,
      16,
      16,
      MediaQuery.of(context).padding.bottom + 24,
    );

    if (user == null) {
      return SingleChildScrollView(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const AppSectionHeader(title: 'حسابي'),
            const SizedBox(height: 16),
            _buildLoggedOutState(),
          ],
        ),
      );
    }

    _syncFormFromUser(user);

    return SingleChildScrollView(
      padding: padding,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const AppSectionHeader(title: 'حسابي'),
            const SizedBox(height: 16),
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'تعديل البيانات',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(
                    controller: _nameController,
                    label: 'الاسم',
                    enabled: !manager.isBusy,
                    validator: (value) {
                      final input = (value ?? '').trim();
                      if (input.isEmpty) {
                        return 'أدخل الاسم الكامل.';
                      }
                      if (input.length < 3) {
                        return 'اكتب اسمًا واضحًا لا يقل عن 3 أحرف.';
                      }
                      final meaningful = input.replaceAll(
                        RegExp(r'[\p{P}\p{S}\s]+', unicode: true),
                        '',
                      );
                      if (meaningful.length < 2) {
                        return 'أدخل اسمًا صحيحًا.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildLabel('الدولة'),
                  const SizedBox(height: 6),
                  CountryPickerFormField(
                    key: ValueKey('account-country-${_selectedCountryCode ?? "none"}'),
                    initialValue: _selectedCountryCode,
                    enabled: !manager.isBusy,
                    showLabel: false,
                    label: 'الدولة',
                    hintText: 'ابحث واختر الدولة',
                    sheetBackgroundColor: Colors.white,
                    accentColor: AppColors.primaryBlue,
                    decoration: _fieldDecoration(),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'اختر الدولة.';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      setState(() {
                        _selectedCountryCode = value;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(
                    controller: _phoneController,
                    label: manager.shouldRequirePhoneNumberForCurrentUser
                        ? 'رقم الهاتف'
                        : 'رقم الهاتف (اختياري)',
                    keyboardType: TextInputType.phone,
                    enabled: !manager.isBusy,
                    validator: _validatePhone,
                  ),
                  if (AppManagerConfig.supportsTradingStatus) ...<Widget>[
                    const SizedBox(height: 10),
                    _buildLabel(kTradingStatusQuestionLabel),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedTradingStatus,
                      dropdownColor: Colors.white,
                      decoration: _fieldDecoration(),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'Tajawal',
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
                ],
              ),
            ),
            if (user.hasPassword) ...<Widget>[
              const SizedBox(height: 12),
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'تغيير كلمة المرور',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildTextField(
                      controller: _currentPasswordController,
                      label: 'كلمة المرور الحالية',
                      obscureText: true,
                      enabled: !manager.isBusy,
                      validator: (value) {
                        final current = (value ?? '').trim();
                        final next = _newPasswordController.text.trim();
                        if (next.isNotEmpty && current.isEmpty) {
                          return 'أدخل كلمة المرور الحالية.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildTextField(
                      controller: _newPasswordController,
                      label: 'كلمة المرور الجديدة',
                      obscureText: true,
                      enabled: !manager.isBusy,
                      validator: (value) {
                        final next = (value ?? '').trim();
                        final current = _currentPasswordController.text.trim();
                        if (current.isNotEmpty && next.isEmpty) {
                          return 'أدخل كلمة المرور الجديدة.';
                        }
                        if (next.isNotEmpty && next.length < 8) {
                          return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل.';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: ElevatedButton(
                            onPressed: manager.isBusy
                                ? null
                                : () => _saveProfile(manager),
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
                                    'حفظ التعديلات',
                                    style: TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: OutlinedButton.icon(
                            onPressed: manager.isBusy
                                ? null
                                : () => _logoutAndNavigate(manager),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.logout_rounded, size: 18),
                            label: const Text(
                              'تسجيل الخروج',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'حذف الحساب',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'سيؤدي حذف الحساب إلى إزالة بياناتك المرتبطة بالتطبيق بشكل نهائي.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed:
                        manager.isBusy ? null : () => _confirmDelete(manager),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('حذف الحساب'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
