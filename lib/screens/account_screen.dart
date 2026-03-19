import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/services/favorites_service.dart';
import '../core/utils/constants.dart';
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
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _openAuth() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(builder: (_) => const AuthScreen()),
    );
  }

  Future<void> _saveProfile(AppManagerProvider manager) async {
    final user = manager.user;
    final canChangePassword = user?.hasPassword == true;

    final ok = await manager.updateProfile(
      fullName: _nameController.text.trim(),
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
              ? 'تم تحديث الحساب.'
              : (manager.errorMessage ?? 'فشل تحديث الحساب.'),
        ),
      ),
    );

    if (ok) {
      _currentPasswordController.clear();
      _newPasswordController.clear();
    }
  }

  Future<void> _logout(AppManagerProvider manager) async {
    await manager.logout();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تسجيل الخروج.')),
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
                  const Text(
                    'سيتم حذف الحساب نهائيا. لا يمكن التراجع عن هذه العملية.',
                    style: TextStyle(
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
                  child: const Text('تأكيد الحذف'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!mounted) return;

    if (!shouldDelete) {
      passwordController.dispose();
      return;
    }

    final password = passwordController.text.trim();
    passwordController.dispose();

    if (user.hasPassword && password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل كلمة المرور أولا.')),
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
          ok ? 'تم حذف الحساب.' : (manager.errorMessage ?? 'فشل حذف الحساب.'),
        ),
      ),
    );
  }

  Future<void> _removeFavorite(String symbol) async {
    await FavoritesService.removeFavorite(symbol);
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildLabel(label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          decoration: InputDecoration(
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
          ),
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

  Widget _buildFavoriteChip(String symbol) {
    return InputChip(
      avatar: const Icon(
        Icons.star_rounded,
        size: 16,
        color: AppColors.primaryBlue,
      ),
      label: Text(
        symbol,
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
      backgroundColor: AppColors.background,
      side: const BorderSide(color: AppColors.border),
      onDeleted: () => _removeFavorite(symbol),
      deleteIcon: const Icon(Icons.close_rounded, size: 16),
      deleteIconColor: AppColors.textSecondary,
    );
  }

  Widget _buildFavoritesCard({
    required AppManagerProvider manager,
    required List<String> favorites,
    required bool showDeleteAccount,
  }) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'المفضلة المحفوظة (${favorites.length})',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          if (favorites.isEmpty)
            Text(
              'لا توجد أسهم مفضلة محفوظة حاليا.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: favorites.map(_buildFavoriteChip).toList(),
            ),
          if (!manager.isAuthenticated) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              'سجل الدخول لمزامنة المفضلة بين أجهزتك.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (showDeleteAccount) ...<Widget>[
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: manager.isBusy ? null : () => _confirmDelete(manager),
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<AppManagerProvider>();
    final user = manager.user;
    final favorites = List<String>.from(manager.preferences.favoriteItems)
      ..sort();

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
            _buildCard(
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
                          'سجّل الدخول لحفظ المفضلة ومزامنة بياناتك بين الأجهزة.',
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
            ),
            const SizedBox(height: 12),
            _buildFavoritesCard(
              manager: manager,
              favorites: favorites,
              showDeleteAccount: false,
            ),
          ],
        ),
      );
    }

    final fullName = user.fullName ?? '';
    if (_nameController.text != fullName) {
      _nameController.text = fullName;
    }

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
                                : 'مستخدم التطبيق',
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
                      text: 'النوع: ${user.authProvider}',
                    ),
                    _buildInfoChip(
                      icon: Icons.info_outline_rounded,
                      text: 'الحالة: ${user.status}',
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
          _buildFavoritesCard(
            manager: manager,
            favorites: favorites,
            showDeleteAccount: true,
          ),
        ],
      ),
    );
  }
}
