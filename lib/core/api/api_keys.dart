class ApiKeys {
  // ====== AlMurakib API (ONLY) ======
  static const String almurakibBaseUrl =
      'https://api.almurakib.com/egypt-stocks-app/api.php';

  static const String almurakibToken =
      '11x2x2x4x3XXXWWs2a9w8xvVvWxVcJZNuzn9Oft';

  static const String translationUrl =
      'https://api.almurakib.com/egypt-stocks-app/stocks-ar-names.json';

  // ✅ Egypt
  static const String defaultCountry = 'egypt';
  static const String egyptExchange = 'EGX';

  // ✅ Main Index ticker (زي اللي راجع في response)
  static const String egyptMainIndexTicker = 'EGX:EGX30';

  // ------------------------------------------------------------------
  // ✅ Backward compatibility (عشان أي كود قديم ما يتكسر)
  // ------------------------------------------------------------------
  static const String saudiCountry = defaultCountry;

  // في كود السعودية كان بيستخدم TASI symbols/id
  // هنا هنخلّيهم يرجعوا مؤشر مصر
  static const String tasiSymbol = egyptMainIndexTicker; // مهم: استخدم الـ ticker الكامل
  static const String tasiIndexId = ''; // لم يعد مستخدم
}
