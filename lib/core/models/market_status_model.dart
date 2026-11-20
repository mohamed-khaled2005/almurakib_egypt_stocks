class MarketStatusModel {
  final bool isOpen;
  final String statusText;
  final String sessionName;
  final String? startTime;
  final String? endTime;
  final DateTime? nextOpenTime;
  final DateTime? nextCloseTime;
  final bool isTradingDay;
  final bool isHoliday;
  final bool isWeekend;
  final bool isPremarket;
  final bool isPostmarket;
  final String timezone;
  final String? serverTimeMarket;

  const MarketStatusModel({
    required this.isOpen,
    required this.statusText,
    required this.sessionName,
    this.startTime,
    this.endTime,
    this.nextOpenTime,
    this.nextCloseTime,
    this.isTradingDay = true,
    this.isHoliday = false,
    this.isWeekend = false,
    this.isPremarket = false,
    this.isPostmarket = false,
    this.timezone = 'Africa/Cairo',
    this.serverTimeMarket,
  });

  String get localizedStatus {
    if (isHoliday) return 'عطلة رسمية';
    if (isWeekend) return 'عطلة نهاية الأسبوع';
    if (isPremarket) return 'ما قبل الافتتاح';
    if (isPostmarket) return 'جلسة الإغلاق';
    if (isOpen) return 'السوق مفتوح';
    return 'السوق مغلق';
  }

  /// حساب توقيت القاهرة بدقة مع مراعاة التوقيت الصيفي المصري (UTC+2 شتاءً / UTC+3 صيفاً)
  static int getCairoUtcOffsetHours([DateTime? utcNow]) {
    final now = utcNow ?? DateTime.now().toUtc();
    final year = now.year;

    // يبدأ التوقيت الصيفي في مصر آخر جمعة من أبريل
    var aprilEnd = DateTime.utc(year, 4, 30);
    while (aprilEnd.weekday != DateTime.friday) {
      aprilEnd = aprilEnd.subtract(const Duration(days: 1));
    }

    // ينتهي التوقيت الصيفي آخر خميس من أكتوبر عند نهاية اليوم
    var octEnd = DateTime.utc(year, 10, 31);
    while (octEnd.weekday != DateTime.thursday) {
      octEnd = octEnd.subtract(const Duration(days: 1));
    }
    final octEndLimit = DateTime.utc(octEnd.year, octEnd.month, octEnd.day, 23, 59, 59);

    final isDst = now.isAfter(aprilEnd) && now.isBefore(octEndLimit);
    return isDst ? 3 : 2;
  }

  static DateTime getCairoNow() {
    final utc = DateTime.now().toUtc();
    final offset = getCairoUtcOffsetHours(utc);
    return utc.add(Duration(hours: offset));
  }

  /// تحويل موعد بتوقيت القاهرة إلى DateTime متوافق مع توقيت جهاز المستخدم المحلي
  static DateTime _cairoToLocal(int year, int month, int day, int hour, int minute) {
    final sampleUtc = DateTime.utc(year, month, day, hour, minute);
    final offset = getCairoUtcOffsetHours(sampleUtc);
    final actualUtc = sampleUtc.subtract(Duration(hours: offset));
    return actualUtc.toLocal();
  }

  /// حساب حالة البورصة المصرية ومواعيد الجلسات بدقة حية لحظية
  static MarketStatusModel calculateCurrentStatus() {
    final cairoNow = getCairoNow();
    final weekday = cairoNow.weekday;
    final year = cairoNow.year;
    final month = cairoNow.month;
    final day = cairoNow.day;
    final minutes = cairoNow.hour * 60 + cairoNow.minute;

    // الجمعة والسبت: عطلة نهاية الأسبوع في مصر
    final isWeekend = weekday == DateTime.friday || weekday == DateTime.saturday;
    if (isWeekend) {
      final daysUntilSunday = weekday == DateTime.friday ? 2 : 1;
      final sundayTarget = cairoNow.add(Duration(days: daysUntilSunday));
      final nextOpen = _cairoToLocal(sundayTarget.year, sundayTarget.month, sundayTarget.day, 10, 0);

      return MarketStatusModel(
        isOpen: false,
        statusText: 'weekend',
        sessionName: 'عطلة نهاية الأسبوع',
        startTime: '10:00',
        endTime: '14:30',
        isTradingDay: false,
        isWeekend: true,
        nextOpenTime: nextOpen,
      );
    }

    // أيام التداول: الأحد إلى الخميس
    // جلسة ما قبل الافتتاح: 09:30 - 10:00
    if (minutes < (9 * 60 + 30)) {
      final nextOpen = _cairoToLocal(year, month, day, 10, 0);
      return MarketStatusModel(
        isOpen: false,
        statusText: 'closed',
        sessionName: 'جلسة التداول الرسمية',
        startTime: '10:00',
        endTime: '14:30',
        isTradingDay: true,
        nextOpenTime: nextOpen,
      );
    }

    if (minutes >= (9 * 60 + 30) && minutes < (10 * 60)) {
      final nextOpen = _cairoToLocal(year, month, day, 10, 0);
      return MarketStatusModel(
        isOpen: false,
        statusText: 'premarket',
        sessionName: 'ما قبل الافتتاح',
        startTime: '10:00',
        endTime: '14:30',
        isTradingDay: true,
        isPremarket: true,
        nextOpenTime: nextOpen,
      );
    }

    // جلسة التداول المستمرة: 10:00 - 14:30 (السوق مفتوح)
    if (minutes >= (10 * 60) && minutes < (14 * 60 + 30)) {
      final nextClose = _cairoToLocal(year, month, day, 14, 30);
      return MarketStatusModel(
        isOpen: true,
        statusText: 'open',
        sessionName: 'جلسة التداول المستمرة',
        startTime: '10:00',
        endTime: '14:30',
        isTradingDay: true,
        nextCloseTime: nextClose,
      );
    }

    // جلسة المزاد والإغلاق: 14:30 - 14:35
    if (minutes >= (14 * 60 + 30) && minutes < (14 * 60 + 35)) {
      final nextDay = cairoNow.add(Duration(days: weekday == DateTime.thursday ? 3 : 1));
      final nextOpen = _cairoToLocal(nextDay.year, nextDay.month, nextDay.day, 10, 0);
      return MarketStatusModel(
        isOpen: false,
        statusText: 'postmarket',
        sessionName: 'جلسة الإغلاق',
        startTime: '10:00',
        endTime: '14:30',
        isTradingDay: true,
        isPostmarket: true,
        nextOpenTime: nextOpen,
      );
    }

    // ما بعد 14:35: السوق مغلق حتى الجلسة التالية
    final nextTradingDay = cairoNow.add(Duration(days: weekday == DateTime.thursday ? 3 : 1));
    final nextOpen = _cairoToLocal(nextTradingDay.year, nextTradingDay.month, nextTradingDay.day, 10, 0);
    return MarketStatusModel(
      isOpen: false,
      statusText: 'closed',
      sessionName: 'السوق مغلق',
      startTime: '10:00',
      endTime: '14:30',
      isTradingDay: true,
      nextOpenTime: nextOpen,
    );
  }

  factory MarketStatusModel.fromJson(Map<String, dynamic> json) {
    // Navigate inside { "EGX:COMI": { "profile": { ... } } }
    Map profile;
    if (json.values.isNotEmpty && json.values.first is Map) {
      final inner = json.values.first as Map;
      if (inner['profile'] is Map) {
        profile = inner['profile'] as Map;
      } else {
        profile = inner;
      }
    } else if (json['profile'] is Map) {
      profile = json['profile'] as Map;
    } else {
      profile = json;
    }

    final rawStatus = (profile['market_status'] ?? '').toString().toLowerCase();
    final isOpen = rawStatus == 'open';

    final detailed = profile['market_status_detailed'] as Map?;
    final tzInfo = profile['timezone_info'] as Map?;
    final sessions = profile['today_sessions'] as Map?;
    final regularSession = sessions?['regular'] as Map?;

    final now = DateTime.now();
    final fallbackCalc = MarketStatusModel.calculateCurrentStatus();

    DateTime? parseFutureDate(dynamic val) {
      if (val == null) return null;
      final parsed = DateTime.tryParse(val.toString());
      if (parsed == null || parsed.isBefore(now)) return null;
      return parsed;
    }

    final parsedOpen = parseFutureDate(profile['next_open_time']);
    final parsedClose = parseFutureDate(profile['next_close_time']);

    return MarketStatusModel(
      isOpen: isOpen,
      statusText: rawStatus.isNotEmpty ? rawStatus : fallbackCalc.statusText,
      sessionName: (regularSession?['name'] ?? profile['market_type'] ?? fallbackCalc.sessionName).toString(),
      startTime: regularSession?['start_time']?.toString() ?? '10:00',
      endTime: regularSession?['end_time']?.toString() ?? '14:30',
      nextOpenTime: parsedOpen ?? fallbackCalc.nextOpenTime,
      nextCloseTime: parsedClose ?? fallbackCalc.nextCloseTime,
      isTradingDay: detailed?['is_trading_day'] != false,
      isHoliday: detailed?['is_holiday'] == true,
      isWeekend: detailed?['is_weekend'] == true || fallbackCalc.isWeekend,
      isPremarket: detailed?['is_premarket'] == true || fallbackCalc.isPremarket,
      isPostmarket: detailed?['is_postmarket'] == true || fallbackCalc.isPostmarket,
      timezone: tzInfo?['market_timezone']?.toString() ?? 'Africa/Cairo',
      serverTimeMarket: tzInfo?['current_time_market']?.toString(),
    );
  }

  factory MarketStatusModel.fallback() {
    return MarketStatusModel.calculateCurrentStatus();
  }
}
