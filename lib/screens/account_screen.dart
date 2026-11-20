import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils/constants.dart';
import '../data/country_options.dart';
import '../data/trading_status_options.dart';
import '../models/managed_app_user.dart';
import '../providers/app_manager_provider.dart';
import '../utils/app_manager_config.dart';
import '../utils/phone_number_helper.dart';
import '../widgets/chevron_right_icon.dart';
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
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  String _initialName = '';
  String _initialPhone = '';
  String? _initialCountryCode;
  String? _initialTradingStatus;

  String? _selectedCountryCode = 'EG';
  String? _selectedTradingStatus;

  bool _initialized = false;
  bool _justSaved = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onFieldChanged);
    _phoneController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFieldChanged);
    _phoneController.removeListener(_onFieldChanged);
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (_justSaved) {
      setState(() {
        _justSaved = false;
      });
    } else {
      setState(() {});
    }
  }

  bool get _hasChanges {
    final currentName = _nameController.text.trim();
    final currentPhone = _phoneController.text.trim();
    return currentName != _initialName ||
        currentPhone != _initialPhone ||
        (_selectedCountryCode ?? '') != (_initialCountryCode ?? '') ||
        (_selectedTradingStatus ?? '') != (_initialTradingStatus ?? '');
  }

  void _syncUserOnce(ManagedAppUser user) {
    if (_initialized) return;
    _initialized = true;

    final name = (user.fullName ?? '').trim();
    var phone = (user.phoneNumber ?? '').trim();
    final countryCode = user.countryCode?.trim().toUpperCase() ?? 'EG';
    final tradingStatus = user.tradingStatus?.trim();

    // Remove dial code prefix from display if phone starts with country dial code
    final country = countryOptionByCode(countryCode) ?? countryOptionByCode('EG')!;
    if (phone.startsWith(country.dialCode)) {
      phone = phone.substring(country.dialCode.length).trim();
    } else if (phone.startsWith('+20')) {
      phone = phone.substring(3).trim();
    }

    _initialName = name;
    _initialPhone = phone;
    _initialCountryCode = countryCode;
    _initialTradingStatus = tradingStatus;

    _nameController.text = name;
    _phoneController.text = phone;
    _selectedCountryCode = countryCode;
    _selectedTradingStatus = tradingStatus;
  }

  String _getUserInitials(ManagedAppUser? user) {
    if (user == null) return 'م';
    final name = (user.fullName ?? '').trim();
    if (name.isEmpty) {
      final email = user.email.trim();
      if (email.isNotEmpty) return email[0].toUpperCase();
      return 'م';
    }
    final parts =
        name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts.first[0]} ${parts.last[0]}';
    }
    return parts.first.length >= 2 ? parts.first.substring(0, 2) : parts.first;
  }

  CountryOption get _selectedCountry {
    return countryOptionByCode(_selectedCountryCode) ??
        countryOptionByCode('EG') ??
        const CountryOption(code: 'EG', name: 'مصر', dialCode: '+20');
  }

  String? get _selectedTradingStatusLabel {
    if (_selectedTradingStatus == null) return null;
    return tradingStatusOptionByValue(_selectedTradingStatus)?.label;
  }

  Widget _buildFlag(String countryCode, {double size = 26}) {
    final code = countryCode.toLowerCase();
    return ClipOval(
      child: Image.network(
        'https://flagcdn.com/w80/$code.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: Color(0xFFF1F5F9),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            countryOptionByCode(countryCode)?.flagEmoji ?? '🇪🇬',
            style: TextStyle(fontSize: size * 0.55),
          ),
        ),
      ),
    );
  }

  Future<void> _handleBack() async {
    if (_hasChanges) {
      final shouldPop = await _showDiscardChangesBottomSheet();
      if (shouldPop == true && mounted) {
        Navigator.pop(context);
      }
    } else {
      Navigator.pop(context);
    }
  }

  // ==========================================
  // Image 2: Discard Changes Bottom Sheet
  // ==========================================
  Future<bool?> _showDiscardChangesBottomSheet() {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Grey drag handle
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                const Text(
                  'تجاهل التعديلات؟',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),

                // Description
                const Text(
                  'لديك تعديلات لم يتم حفظها. إذا خرجت الآن ستفقدها.',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 13.5,
                    color: Color(0xFF4B5563),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),

                // Red Button: حفظ التعديلات
                InkWell(
                  onTap: () async {
                    Navigator.pop(ctx, false);
                    final saved = await _saveChanges();
                    if (saved && mounted) {
                      Navigator.pop(context);
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: double.infinity,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFC1121F),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'حفظ التعديلات',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Outlined Button: تجاهل
                InkWell(
                  onTap: () => Navigator.pop(ctx, true),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: double.infinity,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Text(
                      'تجاهل',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // Image 4: Country Picker Bottom Sheet
  // ==========================================
  void _showCountryPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filteredCountries = kCountryOptions.where((country) {
              if (searchQuery.trim().isEmpty) return true;
              return country.searchableText.contains(searchQuery.trim().toLowerCase());
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.45,
              maxChildSize: 0.92,
              expand: false,
              builder: (_, scrollController) {
                return SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      // Grey drag handle
                      Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Title
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'اختر الدولة',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Search Input Box
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            textDirection: TextDirection.rtl,
                            children: [
                              const SizedBox(width: 12),
                              const Icon(
                                Icons.search_rounded,
                                size: 20,
                                color: Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  onChanged: (val) {
                                    setSheetState(() {
                                      searchQuery = val;
                                    });
                                  },
                                  textDirection: TextDirection.rtl,
                                  decoration: const InputDecoration(
                                    hintText: 'ابحث بأسم الدولة أو الكود',
                                    hintStyle: TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontSize: 13,
                                      color: Color(0xFF94A3B8),
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding:
                                        EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  style: const TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 13.5,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Country List
                      Expanded(
                        child: ListView.separated(
                          controller: scrollController,
                          itemCount: filteredCountries.length,
                          separatorBuilder: (_, __) => const Divider(
                            height: 1,
                            thickness: 1,
                            color: Color(0xFFF1F5F9),
                          ),
                          itemBuilder: (context, index) {
                            final country = filteredCountries[index];
                            return InkWell(
                              onTap: () {
                                Navigator.pop(ctx);
                                setState(() {
                                  _selectedCountryCode = country.code;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 15,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  textDirection: TextDirection.rtl,
                                  children: [
                                    // Right: Flag + Country Name
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _buildFlag(country.code, size: 26),
                                        const SizedBox(width: 12),
                                        Text(
                                          country.name,
                                          style: const TextStyle(
                                            fontFamily: 'Tajawal',
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                      ],
                                    ),

                                    // Left: Dial Code in LTR
                                    Text(
                                      country.dialCode,
                                      textDirection: TextDirection.ltr,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ==========================================
  // Image 3: Trading Status Bottom Sheet
  // ==========================================
  void _showTradingStatusPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Grey drag handle
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'ما الذي يصفك بشكل أفضل؟',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // 4 Options separated by dividers (Matching Image 3)
                ...kTradingStatusOptions.map((opt) {
                  final isLast = opt == kTradingStatusOptions.last;
                  final isSelected = _selectedTradingStatus == opt.value;

                  return Column(
                    children: [
                      InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _selectedTradingStatus = opt.value;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              opt.label,
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 14.5,
                                fontWeight: isSelected
                                    ? FontWeight.w900
                                    : FontWeight.w600,
                                color: isSelected
                                    ? const Color(0xFFC1121F)
                                    : const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (!isLast)
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: Color(0xFFF1F5F9),
                        ),
                    ],
                  );
                }),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // Save Changes
  // ==========================================
  Future<bool> _saveChanges() async {
    final manager = context.read<AppManagerProvider>();
    final country = _selectedCountry;

    final rawPhone = _phoneController.text.trim();
    final normalizedPhone = rawPhone.isEmpty
        ? null
        : PhoneNumberHelper.tryNormalize(
            rawInput: rawPhone,
            regionCode: country.code,
          );

    setState(() {
      _saving = true;
    });

    final ok = await manager.updateProfile(
      fullName: _nameController.text.trim(),
      countryCode: country.code,
      countryName: country.name,
      phoneNumber: normalizedPhone?.e164 ??
          (rawPhone.isNotEmpty ? '${country.dialCode}$rawPhone' : null),
      tradingStatus: AppManagerConfig.supportsTradingStatus
          ? _selectedTradingStatus
          : null,
    );

    if (!mounted) return false;

    setState(() {
      _saving = false;
    });

    if (ok) {
      setState(() {
        _initialName = _nameController.text.trim();
        _initialPhone = _phoneController.text.trim();
        _initialCountryCode = country.code;
        _initialTradingStatus = _selectedTradingStatus;
        _justSaved = true;
      });
      return true;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            manager.errorMessage ?? 'تعذر تحديث الحساب حاليًا.',
            style: const TextStyle(fontFamily: 'Tajawal'),
          ),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      return false;
    }
  }

  // ==========================================
  // Delete Account Dialog
  // ==========================================
  Future<void> _confirmDelete(AppManagerProvider manager) async {
    final user = manager.user;
    if (user == null) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'حذف الحساب',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontWeight: FontWeight.w900,
              fontSize: 17,
              color: Color(0xFF111827),
            ),
          ),
          content: const Text(
            'سيطلب منك التأكيد قبل الحذف، ولا يمكن التراجع عنه. هل أنت متأكد؟',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 14,
              color: Color(0xFF4B5563),
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'إلغاء',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC1121F),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'تأكيد الحذف',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) return;

    final ok = await manager.deleteAccount();
    if (!mounted) return;

    if (ok) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            manager.errorMessage ?? 'تعذر حذف الحساب حاليًا.',
            style: const TextStyle(fontFamily: 'Tajawal'),
          ),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<AppManagerProvider>();
    final user = manager.user;

    // Handle Unauthenticated State
    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.scaffold,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'حسابي',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          leading: IconButton(
            icon: const ChevronRightIcon(
              size: 18,
              color: Color(0xFF374151),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.person_outline_rounded,
                  size: 56,
                  color: Color(0xFF94A3B8),
                ),
                const SizedBox(height: 14),
                const Text(
                  'سجل دخولك للوصول إلى بيانات حسابك',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AuthScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC1121F),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'تسجيل الدخول',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    _syncUserOnce(user);

    final initials = _getUserInitials(user);
    final displayName = (user.fullName ?? '').trim().isNotEmpty
        ? user.fullName!
        : 'مستخدم المراقب';
    final email = user.email;
    final country = _selectedCountry;
    final hasChanges = _hasChanges;

    return PopScope(
      canPop: !hasChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleBack();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.scaffold,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'حسابي',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          leading: IconButton(
            icon: const ChevronRightIcon(
              size: 18,
              color: Color(0xFF374151),
            ),
            onPressed: _handleBack,
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              // ==========================================
              // 1. User Header Info (Avatar + Name + Email)
              // ==========================================
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    // Circular Avatar
                    Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE2E8F0),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initials,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Name and Email
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 12.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ==========================================
              // 2. Form Card Container (Matching Image 1, 5)
              // ==========================================
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.015),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- Field 1: الاسم كامل ---
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'الاسم كامل',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        controller: _nameController,
                        textDirection: TextDirection.rtl,
                        decoration: const InputDecoration(
                          hintText: 'ادخل اسمك كامل',
                          hintStyle: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 13.5,
                            color: Color(0xFF94A3B8),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // --- Field 2: رقم الهاتف (اختياري) ---
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      textDirection: TextDirection.rtl,
                      children: [
                        Text(
                          'رقم الهاتف',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          '(اختياري)',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          // Country Selector Button (Flag + Chevron + Dial Code)
                          InkWell(
                            onTap: _showCountryPicker,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildFlag(country.code, size: 26),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 16,
                                  color: Color(0xFF64748B),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  country.dialCode,
                                  textDirection: TextDirection.ltr,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Phone Number Input
                          Expanded(
                            child: TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.right,
                              decoration: const InputDecoration(
                                hintText: '1x xxxx xxxx',
                                hintStyle: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF94A3B8),
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 12),
                              ),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'اختر العلم لتغيير كود الدولة تلقائياً.',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 11.5,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // --- Field 3: ما الذي يصفك بشكل أفضل؟ (اختياري) ---
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      textDirection: TextDirection.rtl,
                      children: [
                        Text(
                          'ما الذي يصفك بشكل أفضل؟',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          '(اختياري)',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _showTradingStatusPicker,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          textDirection: TextDirection.rtl,
                          children: [
                            Text(
                              _selectedTradingStatusLabel ??
                                  'اختر الوصف المناسب',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 13.5,
                                fontWeight: _selectedTradingStatusLabel != null
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: _selectedTradingStatusLabel != null
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 20,
                              color: Color(0xFF64748B),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ==========================================
              // 3. Delete Account Action ("حذف الحساب")
              // ==========================================
              InkWell(
                onTap: () => _confirmDelete(manager),
                child: const Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: Color(0xFFC1121F),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'حذف الحساب',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFC1121F),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      'سيطلب منك التأكيد قبل الحذف، ولا يمكن التراجع عنه.',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ==========================================
              // 4. Save Button & Success Badge (Bottom)
              // ==========================================
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // Green Banner when saved successfully (Image 1)
                    if (!hasChanges && _justSaved) ...[
                      Container(
                        height: 46,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'تم حفظ التعديلات',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                            SizedBox(width: 6),
                            Icon(
                              Icons.check_circle_rounded,
                              size: 18,
                              color: Color(0xFF16A34A),
                            ),
                          ],
                        ),
                      ),
                      // Disabled Button (Image 1)
                      Container(
                        width: double.infinity,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'حفظ التعديلات',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ] else ...[
                      // Active Red Button (Image 5)
                      InkWell(
                        onTap: _saving ? null : _saveChanges,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: double.infinity,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFC1121F),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'حفظ التعديلات',
                                  style: TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
