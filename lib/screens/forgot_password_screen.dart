import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/utils/constants.dart';
import '../data/country_options.dart';
import '../providers/app_manager_provider.dart';
import '../utils/phone_number_helper.dart';
import '../utils/safe_error_message.dart';
import '../widgets/country_picker_form_field.dart';

Color get _appAccent => AppColors.primaryBlue;

enum _ResetStep { email, code, password, success }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email;
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _code = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _passwordConfirmation = TextEditingController();

  bool _usePhone = false;
  String _selectedCountryCode = 'EG';
  bool _countryInitialized = false;

  _ResetStep _step = _ResetStep.email;
  String? _resetToken;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialEmail?.trim() ?? '';
    _email = TextEditingController(text: initial);
    if (initial.isNotEmpty && !initial.contains('@')) {
      final digits = initial.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 7) {
        _usePhone = true;
        _phone.text = initial;
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_countryInitialized) {
      _countryInitialized = true;
      final manager = context.read<AppManagerProvider>();
      final suggested = manager.user?.countryCode ?? manager.suggestedCountryCode;
      final country = countryOptionByCode(suggested);
      if (country != null) {
        _selectedCountryCode = country.code;
      } else {
        _selectedCountryCode = 'EG';
      }
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _email.dispose();
    _phone.dispose();
    _code.dispose();
    _password.dispose();
    _passwordConfirmation.dispose();
    super.dispose();
  }

  String get _currentIdentifier {
    if (_usePhone) {
      final normalized = PhoneNumberHelper.tryNormalize(
        rawInput: _phone.text.trim(),
        regionCode: _selectedCountryCode,
      );
      return normalized?.e164 ?? _phone.text.trim();
    }
    return _email.text.trim();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  Future<void> _requestCode({bool validateForm = true}) async {
    if (validateForm && !(_formKey.currentState?.validate() ?? false)) return;

    final manager = context.read<AppManagerProvider>();
    final ok = await manager.requestPasswordReset(
      _currentIdentifier,
      countryCode: _usePhone ? _selectedCountryCode : null,
    );
    if (!mounted) return;

    if (!ok) {
      _showMessage(manager.errorMessage ?? 'تعذر إرسال رمز التحقق.');
      return;
    }

    _startResendCountdown();
    setState(() {
      _step = _ResetStep.code;
    });
    _showMessage(
      _usePhone
          ? 'تم إرسال رمز التحقق إلى البريد الإلكتروني المرتبط برقم الهاتف.'
          : 'تم إرسال رمز التحقق إلى بريدك الإلكتروني بنجاح.',
    );
  }

  Future<void> _verifyCode() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final manager = context.read<AppManagerProvider>();
    final token = await manager.verifyPasswordResetCode(
      identifier: _currentIdentifier,
      countryCode: _usePhone ? _selectedCountryCode : null,
      code: _code.text,
    );
    if (!mounted) return;

    if (token == null || token.isEmpty) {
      _showMessage(manager.errorMessage ?? 'رمز التحقق غير صحيح أو انتهت صلاحيته.');
      return;
    }

    setState(() {
      _resetToken = token;
      _step = _ResetStep.password;
    });
  }

  Future<void> _resetPassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_resetToken == null) {
      _showMessage('انتهت صلاحية الجلسة، يرجى طلب الرمز مجدداً.');
      setState(() => _step = _ResetStep.email);
      return;
    }

    final manager = context.read<AppManagerProvider>();
    final ok = await manager.resetPassword(
      identifier: _currentIdentifier,
      countryCode: _usePhone ? _selectedCountryCode : null,
      resetToken: _resetToken!,
      password: _password.text,
    );
    if (!mounted) return;

    if (!ok) {
      _showMessage(manager.errorMessage ?? 'تعذر تعيين كلمة المرور الجديدة.');
      return;
    }

    setState(() => _step = _ResetStep.success);
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          SafeErrorMessage.forUser(text),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: AppColors.textSecondary,
        fontSize: 13.5,
      ),
      prefixIcon: Icon(icon, size: 20, color: _appAccent),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.cardLight,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _appAccent, width: 1.8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<AppManagerProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () {
            if (_step == _ResetStep.code || _step == _ResetStep.password) {
              setState(() => _step = _ResetStep.email);
            } else {
              Navigator.of(context).maybePop();
            }
          },
        ),
        title: Text(
          'استرجاع كلمة المرور',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: PopScope(
        canPop: _step == _ResetStep.email || _step == _ResetStep.success,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && mounted) {
            setState(() => _step = _ResetStep.email);
          }
        },
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              children: [
                _buildProgressHeader(),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.cardDark,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: _buildStepContent(manager),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressHeader() {
    final steps = [
      {'title': _usePhone ? 'الهاتف' : 'البريد', 'step': _ResetStep.email},
      {'title': 'التحقق', 'step': _ResetStep.code},
      {'title': 'كلمة المرور', 'step': _ResetStep.password},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(steps.length * 2 - 1, (index) {
        if (index.isOdd) {
          final isPast = _step.index > (index ~/ 2);
          return Container(
            width: 32,
            height: 3,
            color: isPast ? _appAccent : AppColors.border,
          );
        }
        final stepIndex = index ~/ 2;
        final isActive = _step.index >= stepIndex;
        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? _appAccent : AppColors.cardLight,
            border: Border.all(
              color: isActive ? _appAccent : AppColors.border,
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              '${stepIndex + 1}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isActive ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildStepContent(AppManagerProvider manager) {
    switch (_step) {
      case _ResetStep.email:
        return _buildEmailStep(manager);
      case _ResetStep.code:
        return _buildCodeStep(manager);
      case _ResetStep.password:
        return _buildPasswordStep(manager);
      case _ResetStep.success:
        return _buildSuccessStep();
    }
  }

  Widget _buildMethodSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildMethodTab(
              title: 'البريد الإلكتروني',
              icon: Icons.email_outlined,
              isSelected: !_usePhone,
              onTap: () {
                if (_usePhone) {
                  setState(() {
                    _usePhone = false;
                    _formKey.currentState?.reset();
                  });
                }
              },
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildMethodTab(
              title: 'رقم الهاتف',
              icon: Icons.phone_android_rounded,
              isSelected: _usePhone,
              onTap: () {
                if (!_usePhone) {
                  setState(() {
                    _usePhone = true;
                    _formKey.currentState?.reset();
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodTab({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? _appAccent : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailStep(AppManagerProvider manager) {
    final selectedCountry = countryOptionByCode(_selectedCountryCode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildMethodSelector(),
        const SizedBox(height: 20),
        Icon(
          _usePhone ? Icons.phonelink_lock_rounded : Icons.mark_email_unread_outlined,
          size: 52,
          color: _appAccent,
        ),
        const SizedBox(height: 12),
        Text(
          'نسيت كلمة المرور؟',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _usePhone
              ? 'اختر دولتك وأدخل رقم هاتفك المسجل وسنرسل لك رمز تحقق لإعادة تعيين كلمة المرور.'
              : 'أدخل بريدك الإلكتروني المسجل وسنرسل لك رمز تحقق لإعادة تعيين كلمة المرور.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        if (!_usePhone) ...[
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _requestCode(),
            style: TextStyle(color: AppColors.textPrimary),
            decoration: _fieldDecoration(
              label: 'البريد الإلكتروني',
              icon: Icons.alternate_email_rounded,
            ),
            validator: (value) {
              final input = (value ?? '').trim();
              if (input.isEmpty) return 'يرجى إدخال البريد الإلكتروني.';
              if (!input.contains('@') || !input.contains('.')) {
                return 'صيغة البريد الإلكتروني غير صحيحة.';
              }
              return null;
            },
          ),
        ] else ...[
          CountryPickerFormField(
            key: ValueKey('country-picker-$_selectedCountryCode'),
            initialValue: _selectedCountryCode,
            label: 'الدولة وكود الاتصال',
            hintText: 'ابحث واختر الدولة',
            sheetBackgroundColor: Colors.white,
            accentColor: _appAccent,
            decoration: _fieldDecoration(
              label: 'الدولة وكود الاتصال',
              icon: Icons.public_rounded,
            ),
            selectedBuilder: (country) {
              return Row(
                children: [
                  Text(
                    country.flagEmoji,
                    style: const TextStyle(fontSize: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      country.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _appAccent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      country.dialCode,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        color: _appAccent,
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              );
            },
            validator: (value) {
              if ((value ?? '').trim().isEmpty) {
                return 'يرجى اختيار الدولة.';
              }
              return null;
            },
            onChanged: (value) {
              if (value != null && value.isNotEmpty) {
                setState(() {
                  _selectedCountryCode = value;
                });
              }
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            onFieldSubmitted: (_) => _requestCode(),
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
            decoration: _fieldDecoration(
              label: 'رقم الهاتف',
              icon: Icons.phone_android_rounded,
            ).copyWith(
              hintText: 'أدخل رقم الهاتف بدون رمز الدولة',
              prefixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 12),
                  Icon(Icons.phone_android_rounded, size: 20, color: _appAccent),
                  const SizedBox(width: 8),
                  Text(
                    selectedCountry?.dialCode ?? '',
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      color: _appAccent,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 1,
                    height: 20,
                    color: AppColors.border,
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            validator: (value) {
              final input = (value ?? '').trim();
              if (input.isEmpty) return 'يرجى إدخال رقم الهاتف.';
              final normalized = PhoneNumberHelper.tryNormalize(
                rawInput: input,
                regionCode: _selectedCountryCode,
              );
              if (normalized == null) {
                return 'رقم الهاتف غير صحيح للدولة المحددة.';
              }
              return null;
            },
          ),
        ],
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: manager.isBusy ? null : _requestCode,
          style: ElevatedButton.styleFrom(
            backgroundColor: _appAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: manager.isBusy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text(
                  'إرسال رمز التحقق',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
        ),
      ],
    );
  }

  Widget _buildCodeStep(AppManagerProvider manager) {
    final destinationText = _usePhone
        ? 'البريد الإلكتروني المرتبط برقم الهاتف (${_phone.text.trim()})'
        : _email.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.pin_outlined, size: 54, color: _appAccent),
        const SizedBox(height: 12),
        Text(
          'أدخل رمز التحقق',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'تم إرسال رمز مكون من 6 أرقام إلى $destinationText. أدخله للمتابعة.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _code,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _verifyCode(),
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            letterSpacing: 8,
            fontWeight: FontWeight.w800,
          ),
          decoration: _fieldDecoration(
            label: 'رمز التحقق (6 أرقام)',
            icon: Icons.security_rounded,
          ).copyWith(counterText: ''),
          validator: (value) {
            final input = (value ?? '').trim();
            if (input.length != 6) return 'أدخل رمز التحقق المكون من 6 أرقام.';
            return null;
          },
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_resendSeconds > 0)
              Text(
                'إعادة الإرسال بعد $_resendSeconds ثانية',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              )
            else
              TextButton(
                onPressed: manager.isBusy ? null : () => _requestCode(validateForm: false),
                child: Text(
                  'إعادة إرسال الرمز',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _appAccent,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: manager.isBusy ? null : _verifyCode,
          style: ElevatedButton.styleFrom(
            backgroundColor: _appAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: manager.isBusy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text(
                  'تحقق من الرمز',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
        ),
      ],
    );
  }

  Widget _buildPasswordStep(AppManagerProvider manager) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.lock_reset_rounded, size: 54, color: _appAccent),
        const SizedBox(height: 12),
        Text(
          'تعيين كلمة المرور الجديدة',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'أدخل كلمة المرور الجديدة وتأكيدها (8 أحرف على الأقل).',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _password,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.next,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: _fieldDecoration(
            label: 'كلمة المرور الجديدة',
            icon: Icons.lock_outline_rounded,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: AppColors.textSecondary,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          validator: (value) {
            final input = value ?? '';
            if (input.isEmpty) return 'أدخل كلمة المرور.';
            if (input.length < 8) return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل.';
            return null;
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _passwordConfirmation,
          obscureText: _obscureConfirmation,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _resetPassword(),
          style: TextStyle(color: AppColors.textPrimary),
          decoration: _fieldDecoration(
            label: 'تأكيد كلمة المرور الجديدة',
            icon: Icons.lock_outline_rounded,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmation ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: AppColors.textSecondary,
              ),
              onPressed: () => setState(() => _obscureConfirmation = !_obscureConfirmation),
            ),
          ),
          validator: (value) {
            if ((value ?? '') != _password.text) {
              return 'كلمتا المرور غير متطابقتين.';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: manager.isBusy ? null : _resetPassword,
          style: ElevatedButton.styleFrom(
            backgroundColor: _appAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: manager.isBusy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text(
                  'حفظ كلمة المرور الجديدة',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
        ),
      ],
    );
  }

  Widget _buildSuccessStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle_rounded, size: 64, color: AppColors.success),
        const SizedBox(height: 14),
        Text(
          'تم تغيير كلمة المرور بنجاح!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'يمكنك الآن تسجيل الدخول إلى حسابك باستخدام كلمة المرور الجديدة.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _appAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text(
            'العودة لتسجيل الدخول',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
        ),
      ],
    );
  }
}