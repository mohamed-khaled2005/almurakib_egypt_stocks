import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils/constants.dart';
import '../providers/app_manager_provider.dart';
import 'app_shell_screen.dart';
import 'profile_completion_screen.dart';

const Color _authAccent = AppColors.primaryBlue;
const Color _authHighlight = AppColors.accentGold;
const Color _authTop = Color(0xFFFFFCFC);
const Color _authBottom = Color(0xFFFFF2F4);
const Color _authSurface = Colors.white;
const Color _authInput = Color(0xFFFFF6F7);

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    this.redirectToHomeOnSuccess = false,
  });

  final bool redirectToHomeOnSuccess;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _fullName = TextEditingController();

  bool _isRegisterMode = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _fullName.dispose();
    super.dispose();
  }

  Future<void> _submitEmailAuth() async {
    if (!_formKey.currentState!.validate()) return;

    final manager = context.read<AppManagerProvider>();
    final ok = _isRegisterMode
        ? await manager.register(
            email: _email.text,
            password: _password.text,
            fullName: _fullName.text,
          )
        : await manager.login(
            email: _email.text,
            password: _password.text,
          );

    if (!mounted) return;
    if (ok) {
      await _handleSuccess();
      return;
    }

    _showError(manager.errorMessage ?? 'حدث خطأ أثناء العملية.');
  }

  Future<void> _loginWithGoogle() async {
    final manager = context.read<AppManagerProvider>();
    final ok = await manager.loginWithGoogle();

    if (!mounted) return;
    if (ok) {
      await _handleSuccess();
      return;
    }

    _showError(manager.errorMessage ?? 'تعذر تسجيل الدخول عبر Google.');
  }

  Future<void> _loginWithApple() async {
    final manager = context.read<AppManagerProvider>();
    final ok = await manager.loginWithApple();

    if (!mounted) return;
    if (ok) {
      await _handleSuccess();
      return;
    }

    _showError(manager.errorMessage ?? 'تعذر تسجيل الدخول عبر Apple.');
  }

  Future<void> _handleSuccess() async {
    if (!mounted) return;

    final completed = await ProfileCompletionScreen.ensureCompleted(context);
    if (!mounted || !completed) return;

    if (widget.redirectToHomeOnSuccess) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute<void>(builder: (_) => const AppShellScreen()),
        (_) => false,
      );
    } else {
      Navigator.pop(context, true);
    }
  }

  void _continueWithoutLogin() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute<void>(builder: (_) => const AppShellScreen()),
      (_) => false,
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Tajawal'),
        ),
        backgroundColor: AppColors.textPrimary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<AppManagerProvider>();
    final canUseApple = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

    return PopScope(
      canPop: !widget.redirectToHomeOnSuccess,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppColors.scaffold,
          body: Stack(
            children: <Widget>[
              const _AuthBackground(),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _buildTopAction(manager),
                          const SizedBox(height: 6),
                          _buildHero(),
                          const SizedBox(height: 16),
                          _buildAuthCard(
                            manager: manager,
                            canUseApple: canUseApple,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'بالمتابعة أنت توافق على شروط الاستخدام وسياسة الخصوصية الخاصة بالتطبيق.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.45,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildTopAction(AppManagerProvider manager) {
    if (widget.redirectToHomeOnSuccess) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: manager.isBusy ? null : _continueWithoutLogin,
          style: TextButton.styleFrom(
            foregroundColor: _authAccent,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            backgroundColor: Colors.white.withValues(alpha: 0.86),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.border),
            ),
          ),
          icon: const Icon(Icons.home_rounded, size: 18),
          label: const Text(
            'تخطي الدخول',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: manager.isBusy ? null : () => Navigator.maybePop(context),
          child: Ink(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    final title = _isRegisterMode ? 'إنشاء حساب جديد' : 'تسجيل الدخول';
    final description = _isRegisterMode
        ? 'أنشئ حسابك لحفظ المفضلة ومزامنة إعداداتك بين أجهزتك داخل تطبيق الأسهم المصرية.'
        : 'سجّل دخولك للوصول إلى مفضلتك وحسابك ومزامنة بياناتك بين الأجهزة.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFFFFFFFF), Color(0xFFFFF2F4)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 68,
            height: 68,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Image.asset(
              'assets/images/Icon.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.headingSmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.55,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthCard({
    required AppManagerProvider manager,
    required bool canUseApple,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: _authSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
            _buildModeSwitcher(),
            const SizedBox(height: 16),
            _buildSocialButtons(
              busy: manager.isBusy,
              canUseApple: canUseApple,
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: Divider(
                    color: AppColors.border.withValues(alpha: 0.95),
                    thickness: 1,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'أو بالبريد الإلكتروني',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: AppColors.border.withValues(alpha: 0.95),
                    thickness: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_isRegisterMode) ...<Widget>[
              TextFormField(
                controller: _fullName,
                textInputAction: TextInputAction.next,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontFamily: 'Tajawal',
                ),
                decoration: _fieldDecoration(
                  label: 'الاسم الكامل',
                  icon: Icons.person_outline_rounded,
                ),
                validator: (value) {
                  final input = (value ?? '').trim();
                  if (input.isEmpty) return null;
                  if (input.length < 3) {
                    return 'اكتب اسمًا واضحًا لا يقل عن 3 أحرف.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
            ],
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontFamily: 'Tajawal',
              ),
              decoration: _fieldDecoration(
                label: 'البريد الإلكتروني',
                icon: Icons.alternate_email_rounded,
              ),
              validator: (value) {
                final input = (value ?? '').trim();
                if (input.isEmpty) {
                  return 'أدخل البريد الإلكتروني.';
                }
                if (!input.contains('@') || !input.contains('.')) {
                  return 'صيغة البريد الإلكتروني غير صحيحة.';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _password,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submitEmailAuth(),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontFamily: 'Tajawal',
              ),
              decoration: _fieldDecoration(
                label: 'كلمة المرور',
                icon: Icons.lock_outline_rounded,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
              validator: (value) {
                final input = value ?? '';
                if (input.isEmpty) {
                  return 'أدخل كلمة المرور.';
                }
                if (input.length < 8) {
                  return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: manager.isBusy ? null : _submitEmailAuth,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _authAccent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _authAccent.withValues(alpha: 0.55),
                  disabledForegroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: manager.isBusy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isRegisterMode
                            ? 'إنشاء الحساب والمتابعة'
                            : 'تسجيل الدخول',
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontWeight: FontWeight.w900,
                          fontSize: 15.5,
                        ),
                      ),
              ),
            ),
            if (widget.redirectToHomeOnSuccess) ...<Widget>[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: manager.isBusy ? null : _continueWithoutLogin,
                style: TextButton.styleFrom(
                  foregroundColor: _authAccent,
                ),
                icon: const Icon(Icons.skip_next_rounded, size: 18),
                label: const Text(
                  'المتابعة بدون تسجيل',
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
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.border),
    );

    return InputDecoration(
      labelText: label,
      labelStyle: AppTextStyles.bodySmall.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w700,
      ),
      filled: true,
      fillColor: _authInput,
      prefixIcon: Icon(
        icon,
        size: 20,
        color: _authAccent,
      ),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(
          color: _authAccent,
          width: 1.3,
        ),
      ),
      errorBorder: border.copyWith(
        borderSide: const BorderSide(
          color: AppColors.error,
          width: 1.2,
        ),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: const BorderSide(
          color: AppColors.error,
          width: 1.4,
        ),
      ),
      errorStyle: AppTextStyles.bodySmall.copyWith(
        color: AppColors.error,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildModeSwitcher() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _buildModeItem(
              title: 'تسجيل الدخول',
              selected: !_isRegisterMode,
              onTap: () => setState(() => _isRegisterMode = false),
            ),
          ),
          Expanded(
            child: _buildModeItem(
              title: 'إنشاء حساب',
              selected: _isRegisterMode,
              onTap: () => setState(() => _isRegisterMode = true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeItem({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: selected ? AppColors.blueGradient : null,
          color: selected ? null : Colors.transparent,
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: _authAccent.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall.copyWith(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButtons({
    required bool busy,
    required bool canUseApple,
  }) {
    return Column(
      children: <Widget>[
        _socialButton(
          label: 'المتابعة عبر Google',
          icon: Icons.g_mobiledata_rounded,
          brandColor: const Color(0xFFDB4437),
          onTap: busy ? null : _loginWithGoogle,
        ),
        if (canUseApple) ...<Widget>[
          const SizedBox(height: 8),
          _socialButton(
            label: 'المتابعة عبر Apple',
            icon: Icons.apple,
            brandColor: const Color(0xFF111827),
            onTap: busy ? null : _loginWithApple,
          ),
        ],
      ],
    );
  }

  Widget _socialButton({
    required String label,
    required IconData icon,
    required Color brandColor,
    required VoidCallback? onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          backgroundColor: Colors.white,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: brandColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 19, color: brandColor),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthBackground extends StatelessWidget {
  const _AuthBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[_authTop, _authBottom],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -110,
            right: -70,
            child: _GlowCircle(
              size: 260,
              color: _authAccent.withValues(alpha: 0.08),
            ),
          ),
          Positioned(
            top: 220,
            left: -40,
            child: _GlowCircle(
              size: 180,
              color: _authHighlight.withValues(alpha: 0.08),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -70,
            child: _GlowCircle(
              size: 240,
              color: _authAccent.withValues(alpha: 0.06),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color,
            blurRadius: 90,
            spreadRadius: 14,
          ),
        ],
      ),
    );
  }
}
