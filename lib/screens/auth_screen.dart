import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../core/utils/legal_texts.dart';
import '../providers/app_manager_provider.dart';
import '../widgets/chevron_right_icon.dart';
import '../widgets/legal_policy_sheet.dart';
import 'app_shell_screen.dart';
import 'forgot_password_screen.dart';
import 'profile_completion_screen.dart';

class AuthScreen extends StatefulWidget {
  final bool redirectToHomeOnSuccess;
  final bool initialIsRegister;

  const AuthScreen({
    super.key,
    this.redirectToHomeOnSuccess = false,
    this.initialIsRegister = false,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  late bool _isRegisterMode;
  bool _obscurePassword = true;
  String? _errorMessage;
  bool _submitting = false;

  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  static const String _googleSvg = '''
<svg viewBox="0 0 24 24" width="24" height="24">
  <path fill="#4285F4" d="M23.745 12.27c0-.7-.06-1.4-.19-2.07H12v4.51h6.6c-.29 1.52-1.14 2.82-2.4 3.68v3.05h3.88c2.27-2.09 3.66-5.17 3.66-9.17z"/>
  <path fill="#34A853" d="M12 24c3.24 0 5.95-1.08 7.93-2.91l-3.88-3.05c-1.08.72-2.45 1.16-4.05 1.16-3.12 0-5.77-2.1-6.72-4.93H1.25v3.15C3.26 21.36 7.33 24 12 24z"/>
  <path fill="#FBBC05" d="M5.28 14.27c-.25-.72-.38-1.49-.38-2.27s.14-1.55.38-2.27V6.58H1.25C.45 8.18 0 9.98 0 12s.45 3.82 1.25 5.42l4.03-3.15z"/>
  <path fill="#EA4335" d="M12 4.75c1.77 0 3.35.61 4.6 1.8l3.42-3.42C17.95 1.19 15.24 0 12 0 7.33 0 3.26 2.64 1.25 6.58l4.03 3.15c.95-2.83 3.6-4.98 6.72-4.98z"/>
</svg>
''';

  @override
  void initState() {
    super.initState();
    _isRegisterMode = widget.initialIsRegister;
    _termsRecognizer = TapGestureRecognizer()..onTap = _openTermsOfUse;
    _privacyRecognizer = TapGestureRecognizer()..onTap = _openPrivacyPolicy;
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _openPrivacyPolicy() {
    LegalPolicySheet.show(
      context,
      title: 'سياسة الخصوصية',
      content: LegalTexts.privacyPolicy,
    );
  }

  void _openTermsOfUse() {
    LegalPolicySheet.show(
      context,
      title: 'شروط الاستخدام',
      content: LegalTexts.termsOfUse,
    );
  }

  void _toggleMode() {
    setState(() {
      _isRegisterMode = !_isRegisterMode;
      _errorMessage = null;
    });
  }

  Future<void> _handlePostAuthSuccess() async {
    final completed = await ProfileCompletionScreen.ensureCompleted(context);
    if (!mounted || !completed) return;

    if (widget.redirectToHomeOnSuccess) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AppShellScreen()),
        (_) => false,
      );
    } else {
      Navigator.pop(context, true);
    }
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final fullName = _fullNameController.text.trim();

    if (email.isEmpty || password.isEmpty || (_isRegisterMode && fullName.isEmpty)) {
      setState(() {
        _errorMessage = _isRegisterMode
            ? 'يرجى ملء جميع الحقول المطلوبة.'
            : 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
      });
      return;
    }

    if (_isRegisterMode && password.length < 8) {
      setState(() {
        _errorMessage = 'كلمة المرور يجب أن تكون 8 أحرف على الأقل.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final manager = context.read<AppManagerProvider>();

    try {
      final ok = _isRegisterMode
          ? await manager.register(
              email: email,
              password: password,
              fullName: fullName,
              countryCode: 'EG',
              countryName: 'مصر',
            )
          : await manager.login(
              email: email,
              password: password,
            );

      if (!mounted) return;

      if (ok) {
        await _handlePostAuthSuccess();
      } else {
        setState(() {
          _errorMessage = manager.errorMessage ?? 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final manager = context.read<AppManagerProvider>();
    try {
      final ok = await manager.loginWithGoogle();
      if (!mounted) return;

      if (ok) {
        await _handlePostAuthSuccess();
      } else {
        setState(() {
          _errorMessage = manager.errorMessage ?? 'تعذر تسجيل الدخول عبر Google.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'حدث خطأ أثناء تسجيل الدخول عبر Google.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final manager = context.read<AppManagerProvider>();
    try {
      final ok = await manager.loginWithApple();
      if (!mounted) return;

      if (ok) {
        await _handlePostAuthSuccess();
      } else {
        setState(() {
          _errorMessage = manager.errorMessage ?? 'تعذر تسجيل الدخول عبر Apple.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'حدث خطأ أثناء تسجيل الدخول عبر Apple.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // 1. Top bar with Back Chevron
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8, top: 4),
                  child: IconButton(
                    onPressed: () {
                      if (_isRegisterMode && !widget.initialIsRegister) {
                        setState(() {
                          _isRegisterMode = false;
                          _errorMessage = null;
                        });
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    icon: const ChevronRightIcon(
                      size: 20,
                      color: Color(0xFF374151),
                    ),
                  ),
                ),
              ),

              // 2. Scrollable Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 8),

                        // Logo (Assets)
                        Image.asset(
                          'assets/images/Icon.png',
                          width: 115,
                          height: 115,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Container(
                            width: 100,
                            height: 100,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFC1121F),
                            ),
                            child: const Icon(Icons.assessment_rounded, size: 50, color: Colors.white),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Title
                        Text(
                          _isRegisterMode ? 'إنشاء حساب جديد' : 'تسجيل الدخول',
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827),
                          ),
                        ),

                        const SizedBox(height: 6),

                        // Subtitle
                        Text(
                          _isRegisterMode
                              ? 'أهلاً بك في المراقب، أنشئ حسابك للبدء.'
                              : 'مرحباً بعودتك إلى المراقب.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF4B5563),
                          ),
                        ),

                        // Error Banner (Matching Images 2 & 1)
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              textDirection: TextDirection.rtl,
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: Color(0xFFDC2626),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF991B1B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Name Field (Register Mode Only - Image 4)
                        if (_isRegisterMode) ...[
                          _buildFieldLabel('الاسم كامل'),
                          const SizedBox(height: 8),
                          _buildTextInput(
                            controller: _fullNameController,
                            hintText: 'ادخل اسمك كامل',
                            keyboardType: TextInputType.name,
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Email Field
                        _buildFieldLabel('البريد الإلكتروني'),
                        const SizedBox(height: 8),
                        _buildTextInput(
                          controller: _emailController,
                          hintText: 'name@gmail.com',
                          keyboardType: TextInputType.emailAddress,
                        ),

                        const SizedBox(height: 16),

                        // Password Field
                        _buildFieldLabel('كلمة المرور'),
                        const SizedBox(height: 8),
                        _buildPasswordInput(
                          controller: _passwordController,
                          hintText: _isRegisterMode ? 'ادخل كلمة مرور' : 'ادخل كلمة المرور',
                        ),

                        // Password length hint (Register Mode - Image 4)
                        if (_isRegisterMode) ...[
                          const SizedBox(height: 6),
                          const Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'استخدم 8 أحرف على الأقل.',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],

                        // Forgot Password Link (Login Mode - Image 2 & 5)
                        if (!_isRegisterMode) ...[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ForgotPasswordScreen(
                                      initialEmail: _emailController.text.trim(),
                                    ),
                                  ),
                                );
                              },
                              child: const Text(
                                'نسيت كلمة المرور؟',
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFDC2626),
                                  decoration: TextDecoration.underline,
                                  decorationColor: Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 28),

                        // Red Action Button
                        InkWell(
                          onTap: _submitting ? null : _submit,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: double.infinity,
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: _submitting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                                  )
                                : Text(
                                    _isRegisterMode ? 'إنشاء حساب' : 'تسجيل الدخول',
                                    style: const TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Social Login Divider: "أو المتابعة عبر"
                        const Row(
                          children: [
                            Expanded(child: Divider(color: Color(0xFFE5E7EB), thickness: 1)),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 14),
                              child: Text(
                                'أو المتابعة عبر',
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: Color(0xFFE5E7EB), thickness: 1)),
                          ],
                        ),

                        const SizedBox(height: 18),

                        // Social Buttons: Google & Apple
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildSocialCircleButton(
                              onTap: _submitting ? null : _handleGoogleSignIn,
                              child: SvgPicture.string(_googleSvg, width: 24, height: 24),
                            ),
                            const SizedBox(width: 16),
                            _buildSocialCircleButton(
                              onTap: _submitting ? null : _handleAppleSignIn,
                              child: const Icon(Icons.apple, color: Colors.black, size: 28),
                            ),
                          ],
                        ),

                        // Terms & Privacy Notice (Register Mode Only - Image 4)
                        if (_isRegisterMode) ...[
                          const SizedBox(height: 20),
                          RichText(
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl,
                            text: TextSpan(
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF4B5563),
                                height: 1.45,
                              ),
                              children: [
                                const TextSpan(text: 'بالمتابعة فإنك توافق على '),
                                TextSpan(
                                  text: 'شروط الاستخدام',
                                  style: const TextStyle(
                                    color: Color(0xFFDC2626),
                                    fontWeight: FontWeight.w700,
                                  ),
                                  recognizer: _termsRecognizer,
                                ),
                                const TextSpan(text: ' و '),
                                TextSpan(
                                  text: 'سياسة الخصوصية',
                                  style: const TextStyle(
                                    color: Color(0xFFDC2626),
                                    fontWeight: FontWeight.w700,
                                  ),
                                  recognizer: _privacyRecognizer,
                                ),
                                const TextSpan(text: '.'),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // Footer Toggle Link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          textDirection: TextDirection.rtl,
                          children: [
                            Text(
                              _isRegisterMode ? 'لديك حساب؟ ' : 'ليس لديك حساب؟ ',
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF4B5563),
                              ),
                            ),
                            InkWell(
                              onTap: _toggleMode,
                              child: Text(
                                _isRegisterMode ? 'تسجيل الدخول' : 'إنشاء حساب جديد',
                                style: const TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1E293B),
        ),
      ),
    );
  }

  Widget _buildTextInput({
    required TextEditingController controller,
    required String hintText,
    required TextInputType keyboardType,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.center,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.right,
        cursorColor: const Color(0xFFDC2626),
        style: const TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E293B),
        ),
        decoration: InputDecoration(
          isDense: true,
          hintText: hintText,
          hintTextDirection: TextDirection.rtl,
          hintStyle: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: Color(0xFF94A3B8),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildPasswordInput({
    required TextEditingController controller,
    required String hintText,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.center,
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: _obscurePassword,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              cursorColor: const Color(0xFFDC2626),
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: hintText,
                hintTextDirection: TextDirection.rtl,
                hintStyle: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF94A3B8),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          InkWell(
            onTap: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: const Color(0xFF94A3B8),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialCircleButton({
    required VoidCallback? onTap,
    required Widget child,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}
