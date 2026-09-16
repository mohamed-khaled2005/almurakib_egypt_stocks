import 'package:flutter/material.dart';

class AppColors {
  // ==========================================================
  // ✅ الهوية المصرية:
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

  // ✅ درجات الوضع الفاتح (Light Mode) - مطابقة 100% للتصميم الحالي
  static const Color _lightBackground = Color(0xFFFFF7F8); // Warm light background
  static const Color _lightCard = Color(0xFFFFFFFF); // Card أبيض
  static const Color _lightCardSoft = Color(0xFFFFE9EC); // Surface فاتح أحمر
  static const Color _lightBorder = Color(0xFFF2C9CF);
  static const Color _lightTextPrimary = Color(0xFF1A0B0D);
  static const Color _lightTextSecondary = Color(0xFF6B4B50);

  static Color background = _lightBackground;
  static Color get scaffold => background;
  static Color cardDark = _lightCard;
  static Color cardLight = _lightCardSoft;
  static Color border = _lightBorder;
  static Color shadow = const Color(0x14000000);
  static Color textPrimary = _lightTextPrimary;
  static Color textSecondary = _lightTextSecondary;

  static bool get isDark => false;

  // Helpers for theme construction
  static Color backgroundFor(Brightness brightness) => _lightBackground;
  static Color cardFor(Brightness brightness) => _lightCard;
  static Color cardSoftFor(Brightness brightness) => _lightCardSoft;
  static Color borderFor(Brightness brightness) => _lightBorder;
  static Color textPrimaryFor(Brightness brightness) => _lightTextPrimary;
  static Color textSecondaryFor(Brightness brightness) => _lightTextSecondary;

  static Color get subtleBorder => textSecondary.withValues(alpha: 0.08);

  static Color get fieldFill => const Color(0xFFFFFFFF);

  static Color get onAccent => Colors.white;

  static void applyThemeMode(
    ThemeMode themeMode, {
    Brightness platformBrightness = Brightness.light,
  }) {
    // Pure light mode only
  }

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

  static const Gradient accentGradient = LinearGradient(
    colors: [accentGold, darkAccentGold],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient goldGradient = LinearGradient(
    colors: [accentGold, darkAccentGold],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ==========================================================
  // ✅ Aliases لتوافق الأكواد القديمة
  // ==========================================================
  static const Color primaryGold = accentGold;
  static const Color darkGold = darkAccentGold;
  static const Color lightGold = lightAccentGold;
  static Color get accent => primaryBlue;

  // ==========================================================
  // ✅ إضافات مفيدة للسوق: ألوان الربح/الخسارة
  // ==========================================================
  static const Color gain = Color(0xFF16A34A); // أخضر ربح
  static const Color loss = Color(0xFFDC2626); // أحمر خسارة
  static const Color neutral = Color(0xFF6B7280); // رمادي محايد
}

class AppTextStyles {
  static TextStyle get headingLarge => TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
        fontFamily: 'Tajawal',
      );

  static TextStyle get headingMedium => TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        fontFamily: 'Tajawal',
      );

  static TextStyle get headingSmall => TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        fontFamily: 'Tajawal',
      );

  static TextStyle get bodyLarge => TextStyle(
        fontSize: 16,
        color: AppColors.textPrimary,
        fontFamily: 'Tajawal',
      );

  static TextStyle get bodyMedium => TextStyle(
        fontSize: 14,
        color: AppColors.textSecondary,
        fontFamily: 'Tajawal',
      );

  static TextStyle get bodySmall => TextStyle(
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