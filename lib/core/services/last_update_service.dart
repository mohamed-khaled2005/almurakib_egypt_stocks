// lib/core/services/last_update_service.dart
import 'package:flutter/foundation.dart';
import '../utils/server_time_parser.dart';

class LastUpdateService {
  static final ValueNotifier<DateTime?> lastUpdateUtc =
      ValueNotifier<DateTime?>(null);

  static void updateFromApi(Map<String, dynamic> data) {
    final dt = ServerTimeParser.extractFromApiResponse(
      data,
      // نفس منطق BTC: لو string بدون timezone اعتبره UTC
      assumeUtcIfNoZone: true,
    );

    if (dt == null) return;

    final curr = lastUpdateUtc.value;
    if (curr == null || dt.isAfter(curr)) {
      lastUpdateUtc.value = dt;
    }
  }

  static void clear() => lastUpdateUtc.value = null;
}
