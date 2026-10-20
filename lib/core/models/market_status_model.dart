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
    if (isPremarket) return 'تداولات ما قبل الافتتاح';
    if (isPostmarket) return 'تداولات ما بعد الإغلاق';
    if (isOpen) return 'السوق مفتوح';
    return 'السوق مغلق';
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

    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      return DateTime.tryParse(val.toString());
    }

    return MarketStatusModel(
      isOpen: isOpen,
      statusText: rawStatus,
      sessionName: (regularSession?['name'] ?? profile['market_type'] ?? 'regular').toString(),
      startTime: regularSession?['start_time']?.toString() ?? '10:00',
      endTime: regularSession?['end_time']?.toString() ?? '14:30',
      nextOpenTime: parseDate(profile['next_open_time']),
      nextCloseTime: parseDate(profile['next_close_time']),
      isTradingDay: detailed?['is_trading_day'] != false,
      isHoliday: detailed?['is_holiday'] == true,
      isWeekend: detailed?['is_weekend'] == true,
      isPremarket: detailed?['is_premarket'] == true,
      isPostmarket: detailed?['is_postmarket'] == true,
      timezone: tzInfo?['market_timezone']?.toString() ?? 'Africa/Cairo',
      serverTimeMarket: tzInfo?['current_time_market']?.toString(),
    );
  }

  factory MarketStatusModel.fallback() {
    return const MarketStatusModel(
      isOpen: false,
      statusText: 'closed',
      sessionName: 'regular',
      startTime: '10:00',
      endTime: '14:30',
      timezone: 'Africa/Cairo',
    );
  }
}
