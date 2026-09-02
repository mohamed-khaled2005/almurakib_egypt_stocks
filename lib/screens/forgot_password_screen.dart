import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/utils/constants.dart';
import '../providers/app_manager_provider.dart';
import '../utils/safe_error_message.dart';

Color get _egyptAccent => AppColors.primaryBlue;

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
  final TextEditingController _code = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _passwordConfirmation = TextEditingController();

  _ResetStep _step = _ResetStep.email;
  String? _resetToken;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail?.trim() ?? '');
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _passwordConfirmation.dispose();
    super.dispose();
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
    final ok = await manager.requestPasswordReset(_email.text);
    if (!mounted) return;

    if (!ok) {
      _showMessage(manager.errorMessage ?? 'تعذر إرسال رمز التحقق.');
      return;
    }

    _startResendCountdown();
    setState(() {
      _step = _ResetStep.code;
    });
    _showMessage('تم إرسال رمز التحقق إلى بريدك الإلكتروني بنجاح.');
  }

  Future<void> _verifyCode() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final manager = context.read<AppManagerProvider>();
    final token = await manager.verifyPasswordResetCode(
      email: _email.text,
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
      email: _email.text,
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
      labelStyle: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 13.5,
      ),
      prefixIcon: Icon(icon, size: 20, color: _egyptAccent),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.cardLight,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _egyptAccent, width: 1.8),
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'استرجاع كلمة المرور',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
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
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 20,
                      offset: Offset(0, 10),
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
    );
  }

  Widget _buildProgressHeader() {
    final steps = [
      {'title': 'البريد', 'step': _ResetStep.email},
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
            color: isPast ? _egyptAccent : AppColors.border,
          );
        }
        final stepIndex = index ~/ 2;
        final isActive = _step.index >= stepIndex;
        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? _egyptAccent : AppColors.cardLight,
            border: Border.all(
              color: isActive ? _egyptAccent : AppColors.border,
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

  Widget _buildEmailStep(AppManagerProvider manager) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.mark_email_unread_outlined, size: 54, color: _egyptAccent),
        const SizedBox(height: 12),
        const Text(
          'نسيت كلمة المرور؟',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'أدخل بريدك الإلكتروني المسجل وسنرسل لك رمز تحقق لإعادة تعيين كلمة المرور.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _requestCode(),
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: _fieldDecoration(
            label: 'البريد الإلكتروني',
            icon: Icons.alternate_email_rounded,
          ),
          validator: (value) {
            final input = (value ?? '').trim();
            if (input.isEmpty) return 'أدخل البريد الإلكتروني.';
            if (!input.contains('@') || !input.contains('.')) {
              return 'صيغة البريد الإلكتروني غير صحيحة.';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: manager.isBusy ? null : _requestCode,
          style: ElevatedButton.styleFrom(
            backgroundColor: _egyptAccent,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.pin_outlined, size: 54, color: _egyptAccent),
        const SizedBox(height: 12),
        const Text(
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
          'تم إرسال رمز مكون من 6 أرقام إلى ${_email.text}. أدخله للمتابعة.',
          textAlign: TextAlign.center,
          style: const TextStyle(
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
          style: const TextStyle(
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
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              )
            else
              TextButton(
                onPressed: manager.isBusy ? null : () => _requestCode(validateForm: false),
                child: Text(
                  'إعادة إرسال الرمز',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _egyptAccent,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: manager.isBusy ? null : _verifyCode,
          style: ElevatedButton.styleFrom(
            backgroundColor: _egyptAccent,
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
        Icon(Icons.lock_reset_rounded, size: 54, color: _egyptAccent),
        const SizedBox(height: 12),
        const Text(
          'تعيين كلمة المرور الجديدة',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
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
          style: const TextStyle(color: AppColors.textPrimary),
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
          style: const TextStyle(color: AppColors.textPrimary),
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
            backgroundColor: _egyptAccent,
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
        const Text(
          'تم تغيير كلمة المرور بنجاح!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
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
            backgroundColor: _egyptAccent,
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