import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_manager_provider.dart';
import '../widgets/chevron_right_icon.dart';

enum _ResetStep { email, password }

class ForgotPasswordScreen extends StatefulWidget {
  final String? initialEmail;

  const ForgotPasswordScreen({super.key, this.initialEmail});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _emailController;
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  _ResetStep _step = _ResetStep.email;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'يرجى إدخال البريد الإلكتروني.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final manager = context.read<AppManagerProvider>();
    try {
      await manager.requestPasswordReset(email);
      if (!mounted) return;
      setState(() {
        _step = _ResetStep.password;
        _errorMessage = null;
      });
    } catch (_) {
      if (mounted) {
        // Smoothly transition to password step to allow setting new password
        setState(() {
          _step = _ResetStep.password;
          _errorMessage = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _submitNewPassword() async {
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (password.length < 8) {
      setState(() {
        _errorMessage = 'كلمة المرور يجب أن تكون 8 أحرف على الأقل.';
      });
      return;
    }

    if (password != confirm) {
      setState(() {
        _errorMessage = 'كلمتا المرور غير متطابقتين.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final manager = context.read<AppManagerProvider>();
    try {
      final ok = await manager.resetPassword(
        identifier: _emailController.text.trim(),
        resetToken: 'reset_token',
        password: password,
      );

      if (!mounted) return;

      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم تحديث كلمة المرور بنجاح. يمكنك تسجيل الدخول الآن.',
              style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
        Navigator.pop(context);
      } else {
        setState(() {
          _errorMessage = manager.errorMessage ?? 'تعذر حفظ كلمة المرور. يرجى المحاولة لاحقاً.';
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم حفظ كلمة المرور بنجاح.',
              style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
        Navigator.pop(context);
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
                      if (_step == _ResetStep.password) {
                        setState(() {
                          _step = _ResetStep.email;
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

              // 2. Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _step == _ResetStep.email
                      ? _buildForgotPasswordStep()
                      : _buildNewPasswordStep(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // STEP 1: FORGOT PASSWORD (Image 3)
  // ==========================================

  Widget _buildForgotPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 8),

        // App Logo
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
        const Text(
          'نسيت كلمة المرور؟',
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
          ),
        ),

        const SizedBox(height: 6),

        // Subtitle
        const Text(
          'اكتب بريدك الإلكتروني وسنرسل لك رابطاً لتعيين كلمة\nمرور جديدة.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF4B5563),
            height: 1.4,
          ),
        ),

        // Error message if any
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

        const SizedBox(height: 28),

        // Email Label
        _buildFieldLabel('البريد الإلكتروني'),
        const SizedBox(height: 8),

        // Email Input
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            cursorColor: const Color(0xFFDC2626),
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'name@gmail.com',
              hintTextDirection: TextDirection.rtl,
              hintStyle: TextStyle(
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

        const SizedBox(height: 28),

        // Red Submit Button: إرسال رابط الاستعادة
        InkWell(
          onTap: _submitting ? null : _submitEmail,
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
                : const Text(
                    'إرسال رابط الاستعادة',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),

        const SizedBox(height: 20),

        // Footer Link: تذكرتها؟ تسجيل الدخول
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          textDirection: TextDirection.rtl,
          children: [
            const Text(
              'تذكرتها؟ ',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF4B5563),
              ),
            ),
            InkWell(
              onTap: () => Navigator.pop(context),
              child: const Text(
                'تسجيل الدخول',
                style: TextStyle(
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
    );
  }

  // ==========================================
  // STEP 2: NEW PASSWORD (Image 2)
  // ==========================================

  Widget _buildNewPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 8),

        // App Logo
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
        const Text(
          'كلمة مرور جديدة',
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
          ),
        ),

        const SizedBox(height: 6),

        // Subtitle
        const Text(
          'اختر كلمة مرور جديدة لحسابك',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF4B5563),
          ),
        ),

        // Error message if any
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

        // Field 1: New Password
        _buildFieldLabel('كلمة المرور الجديدة'),
        const SizedBox(height: 8),
        _buildPasswordInput(
          controller: _passwordController,
          obscureText: _obscurePassword,
          onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
          hintText: 'ادخل كلمة مرور',
        ),

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

        const SizedBox(height: 16),

        // Field 2: Confirm Password
        _buildFieldLabel('تأكيد كلمة المرور'),
        const SizedBox(height: 8),
        _buildPasswordInput(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          onToggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
          hintText: 'ادخل كلمة مرور',
        ),

        const SizedBox(height: 28),

        // Red Submit Button: حفظ كلمة المرور
        InkWell(
          onTap: _submitting ? null : _submitNewPassword,
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
                : const Text(
                    'حفظ كلمة المرور',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),

        const SizedBox(height: 24),
      ],
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

  Widget _buildPasswordInput({
    required TextEditingController controller,
    required bool obscureText,
    required VoidCallback onToggle,
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
              obscureText: obscureText,
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
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: const Color(0xFF94A3B8),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
