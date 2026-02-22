import 'package:flutter/material.dart';

class AppColors {
  // ==========================================================
  // ✅ الهوية المصرية الجديدة:
  // Primary: #CE1126 (أحمر)
  // Accent : #C09300 (ذهبي)
  // - نحافظ على أسماء المتغيرات القديمة (primaryBlue) للتوافق
  // ==========================================================

  // ✅ Primary Brand (Red)
  static const Color primaryBlue = Color(0xFFCE1126); // Brand Red #CE1126
  static const Color darkBlue = Color(0xFF9F0D1D); // Darker Red shade
  static const Color lightBlue = Color(0xFFE14B59); // Lighter Red tint

  // ✅ Accent (Gold)
  static const Color accentGold = Color(0xFFC09300); // Gold #C09300
  static const Color darkAccentGold = Color(0xFF9A7400); // Dark Gold shade
  static const Color lightAccentGold = Color(0xFFD7B24A); // Light Gold tint

  // ✅ خلفيات لايت (تماشي مع الأحمر/الذهبي)
  static const Color background = Color(0xFFFFF7F8); // Warm light background
  static const Color scaffold = background;

  // ✅ كروت
  static const Color cardDark = Color(0xFFFFFFFF); // Card أبيض
  static const Color cardLight = Color(0xFFFFE9EC); // Surface فاتح أحمر

  // ✅ حدود/فواصل/ظل
  static const Color border = Color(0xFFF2C9CF);
  static const Color shadow = Color(0x14000000);

  // ✅ نصوص
  static const Color textPrimary = Color(0xFF1A0B0D);
  static const Color textSecondary = Color(0xFF6B4B50);

  // ✅ حالات
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFDC2626);

  // ✅ تدرج (الاسم Blue قديم لكن هوية حمراء)
  static const Gradient blueGradient = LinearGradient(
    colors: [primaryBlue, darkBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ✅ تدرج ذهبي (اختياري للاستخدام في Buttons/Badges)
  static const Gradient goldGradient = LinearGradient(
    colors: [accentGold, darkAccentGold],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ==========================================================
  // ✅ Aliases لتوافق الأكواد القديمة اللي كانت بتستخدم gold
  // ==========================================================
  static const Color primaryGold = accentGold;
  static const Color darkGold = darkAccentGold;
  static const Color lightGold = lightAccentGold;

  // ==========================================================
  // ✅ إضافات مفيدة للسوق: ألوان الربح/الخسارة
  // ==========================================================
  static const Color gain = Color(0xFF16A34A); // أخضر ربح
  static const Color loss = Color(0xFFDC2626); // أحمر خسارة
  static const Color neutral = Color(0xFF6B7280); // رمادي محايد
}

class AppTextStyles {
  static const TextStyle headingLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    fontFamily: 'Tajawal',
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    fontFamily: 'Tajawal',
  );

  static const TextStyle headingSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    fontFamily: 'Tajawal',
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    color: AppColors.textPrimary,
    fontFamily: 'Tajawal',
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    color: AppColors.textSecondary,
    fontFamily: 'Tajawal',
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
    fontFamily: 'Tajawal',
  );
}

class AppDimensions {
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;

  static const double borderRadius = 16.0;
  static const double borderRadiusLarge = 24.0;
}

class AppAnimations {
  static const Duration pageTransition = Duration(milliseconds: 350);
  static const Duration buttonAnimation = Duration(milliseconds: 200);
  static const Duration shimmerDuration = Duration(milliseconds: 1000);
}
