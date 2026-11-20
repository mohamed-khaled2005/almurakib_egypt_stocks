class Formatters {
  /// ✅ تنسيق الأرقام لأقرب فاصلتين
  static String formatNumber(double value) {
    return value.toStringAsFixed(2);
  }

  /// ✅ تنسيق السعر مع العملة (مصري)
  static String formatPrice(double price) {
    return '${formatNumber(price)} ج.م';
  }

  /// ✅ تنسيق النسبة المئوية
  static String formatPercent(double percent) {
    if (percent == 0) return '0.00%';
    final absVal = percent.abs().toStringAsFixed(2);
    final sign = percent > 0 ? '+' : '-';
    return '$sign$absVal%';
  }

  /// ✅ تنسيق النسبة المئوية لكبسولات التغيير (+2.65% أو -24.44%)
  /// تضع الإشارة (+ أو -) قبل الرقم بدقة مطابقة للصورة 100%
  static String formatPillPercent(double percent) {
    if (percent == 0) return '0.00%';
    final absVal = percent.abs().toStringAsFixed(2);
    final sign = percent > 0 ? '+' : '-';
    return '$sign$absVal%';
  }

  /// ✅ تنسيق التغيير (رقم فقط مع الإشارة)
  static String formatChange(double change) {
    final sign = change >= 0 ? '+' : '';
    return '$sign${formatNumber(change)}';
  }

  /// ✅ إصلاح التنوين العربي
  static String fixArabicTanween(String text) {
    return text
        .replaceAll('ـًا', 'اً')
        .replaceAll('ـٌو', 'ٌو')
        .replaceAll('ـٍي', 'ٍي');
  }

  /// ✅ تنسيق رقم كبير (مثل حجم التداول)
  static String formatLargeNumber(double value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(2)} مليار';
    } else if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(2)} مليون';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(2)} ألف';
    }
    return formatNumber(value);
  }
}
