import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils/constants.dart';
import '../data/country_options.dart';
import '../models/managed_app_user.dart';
import '../providers/app_manager_provider.dart';
import '../widgets/app_section_header.dart';
import 'auth_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();

  String? _selectedCountryCode;
  String _syncedName = '';
  String _syncedPhone = '';
  String? _syncedCountryCode;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _openAuth() async {
    final allowed = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(builder: (_) => const AuthScreen()),
    );

    if (!mounted || allowed != true) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تسجيل الدخول بنجاح.')),
    );
  }

  void _setControllerText(TextEditingController controller, String value) {
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  String? _resolveCountryCode(String? code, String? name) {
    final normalizedCode = (code ?? '').trim().toUpperCase();
    if (normalizedCode.isNotEmpty &&
        kCountryOptions.any((country) => country.code == normalizedCode)) {
      return normalizedCode;
    }

    final normalizedName = (name ?? '').trim();
    if (normalizedName.isEmpty) return null;

    for (final country in kCountryOptions) {
      if (country.name == normalizedName) {
        return country.code;
      }
    }

    return null;
  }

  CountryOption? _selectedCountry() {
    final code = (_selectedCountryCode ?? '').trim().toUpperCase();
    if (code.isEmpty) return null;

    for (final country in kCountryOptions) {
      if (country.code == code) {
        return country;
      }
    }

    return null;
  }

  CountryOption? _countryFromUser(ManagedAppUser user) {
    final code = _resolveCountryCode(user.countryCode, user.countryName);
    if (code == null) return null;

    for (final country in kCountryOptions) {
      if (country.code == code) {
        return country;
      }
    }

    return null;
  }

  String _displayCountryName(ManagedAppUser user) {
    final country = _countryFromUser(user);
    if (country != null) return country.name;

    return (user.countryName ?? '').trim();
  }

  String _providerLabel(String value) {
    switch (value.toLowerCase()) {
      case 'google':
        return 'Google';
      case 'apple':
        return 'Apple';
      case 'password':
        return 'Email';
      default:
        return value;
    }
  }

  String? _validatePhone(String value) {
    final input = value.trim();
    if (input.isEmpty) {
      return 'أدخل رقم الهاتف.';
    }

    final normalized = input.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (!RegExp(r'^\+?[0-9]{7,15}$').hasMatch(normalized)) {
      return 'أدخل رقم هاتف صحيح.';
    }

    return null;
  }

  void _syncProfileFields(ManagedAppUser user) {
    final fullName = (user.fullName ?? '').trim();
    if (_nameController.text.trim().isEmpty ||
        _nameController.text.trim() == _syncedName) {
      _setControllerText(_nameController, fullName);
    }
    _syncedName = fullName;

    final phone = (user.phoneNumber ?? '').trim();
    if (_phoneController.text.trim().isEmpty ||
        _phoneController.text.trim() == _syncedPhone) {
      _setControllerText(_phoneController, phone);
    }
    _syncedPhone = phone;

    final countryCode = _resolveCountryCode(user.countryCode, user.countryName);
    if (_selectedCountryCode == null ||
        _selectedCountryCode == _syncedCountryCode) {
      _selectedCountryCode = countryCode;
    }
    _syncedCountryCode = countryCode;
  }

  Future<void> _saveProfile(AppManagerProvider manager) async {
    final user = manager.user;
    if (user == null) return;

    final country = _selectedCountry();
    if (country == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر الدولة أولًا.')),
      );
      return;
    }

    final phoneError = _validatePhone(_phoneController.text);
    if (phoneError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(phoneError)),
      );
      return;
    }

    final canChangePassword = user.hasPassword;
    final ok = await manager.updateProfile(
      fullName: _nameController.text.trim(),
      countryCode: country.code,
      countryName: country.name,
      phoneNumber: _phoneController.text.trim(),
      currentPassword:
          canChangePassword && _currentPasswordController.text.trim().isNotEmpty
              ? _currentPasswordController.text.trim()
              : null,
      newPassword:
          canChangePassword && _newPasswordController.text.trim().isNotEmpty
              ? _newPasswordController.text.trim()
              : null,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'تم تحديث الحساب بنجاح.'
              : (manager.errorMessage ?? 'تعذر تحديث الحساب حاليًا.'),
        ),
      ),
    );

    if (!ok) return;

    _currentPasswordController.clear();
    _newPasswordController.clear();
    _syncedName = _nameController.text.trim();
    _syncedPhone = _phoneController.text.trim();
    _syncedCountryCode = country.code;
  }

  Future<void> _logout(AppManagerProvider manager) async {
    await manager.logout();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تسجيل الخروج بنجاح.')),
    );
  }

  Future<void> _confirmDelete(AppManagerProvider manager) async {
    final user = manager.user;
    if (user == null) return;

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

    if (!mounted || !shouldDelete) return;

    if (user.hasPassword && password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل كلمة المرور الحالية أولًا.')),
      );
      return;
    }

    final ok = await manager.deleteAccount(
      password: user.hasPassword ? password : null,
    );

    if (!mounted) return;

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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildLabel(label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          decoration: _fieldDecoration(),
        ),
      ],
    );
  }

  Widget _buildCountryField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildLabel('الدولة'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _selectedCountryCode,
          isExpanded: true,
          decoration: _fieldDecoration(),
          items: kCountryOptions
              .map(
                (country) => DropdownMenuItem<String>(
                  value: country.code,
                  child: Text(
                    '${country.flagEmoji} ${country.name} (${country.dialCode})',
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _selectedCountryCode = value),
        ),
      ],
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: AppColors.primaryBlue),
          const SizedBox(width: 6),
          Text(
            text,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
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

    _syncProfileFields(user);
    final countryName = _displayCountryName(user);
    final phoneNumber = (user.phoneNumber ?? '').trim();

    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const AppSectionHeader(title: 'حسابي'),
          const SizedBox(height: 16),
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryBlue.withValues(alpha: 0.12),
                      ),
                      child: const Icon(
                        Icons.account_circle_rounded,
                        color: AppColors.primaryBlue,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            user.email,
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.fullName?.trim().isNotEmpty == true
                                ? user.fullName!
                                : 'لم يتم إضافة الاسم بعد',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _buildInfoChip(
                      icon: Icons.verified_user_outlined,
                      text:
                          'طريقة الدخول: ${_providerLabel(user.authProvider)}',
                    ),
                    _buildInfoChip(
                      icon: Icons.info_outline_rounded,
                      text: 'الحالة: ${user.status}',
                    ),
                    if (countryName.isNotEmpty)
                      _buildInfoChip(
                        icon: Icons.public_rounded,
                        text: countryName,
                      ),
                    if (phoneNumber.isNotEmpty)
                      _buildInfoChip(
                        icon: Icons.phone_android_rounded,
                        text: phoneNumber,
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
                ),
                const SizedBox(height: 10),
                _buildCountryField(),
                const SizedBox(height: 10),
                _buildTextField(
                  controller: _phoneController,
                  label: 'رقم الهاتف',
                  keyboardType: TextInputType.phone,
                ),
                if (user.hasPassword) ...<Widget>[
                  const SizedBox(height: 10),
                  _buildTextField(
                    controller: _currentPasswordController,
                    label: 'كلمة المرور الحالية',
                    obscureText: true,
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(
                    controller: _newPasswordController,
                    label: 'كلمة المرور الجديدة',
                    obscureText: true,
                  ),
                ],
                const SizedBox(height: 12),
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
                          child: const Text(
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
                          onPressed:
                              manager.isBusy ? null : () => _logout(manager),
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
    );
  }
}
