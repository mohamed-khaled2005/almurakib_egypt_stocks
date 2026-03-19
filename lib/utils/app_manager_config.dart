import 'package:flutter/foundation.dart';

class AppManagerConfig {
  static const String appSlug = 'almurakib_egypt_stocks';
  static const String _defaultApiBase = 'https://amanager.almurakib.com';
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '875588732525-av9d72v1vtca3ee6ngs06uc0ht71b383.apps.googleusercontent.com',
  );

  static String get apiBaseUrl {
    const configured = String.fromEnvironment(
      'APP_MANAGER_API_BASE',
      defaultValue: '',
    );

    final base = configured.trim().isNotEmpty ? configured : _defaultApiBase;
    final adapted = _adaptLoopbackBaseForPlatform(base);
    final normalized = adapted.endsWith('/')
        ? adapted.substring(0, adapted.length - 1)
        : adapted;

    if (normalized.endsWith('/api/v1')) {
      return normalized;
    }

    return '$normalized/api/v1';
  }

  static String _adaptLoopbackBaseForPlatform(String value) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return value;
    }

    final parsed = Uri.tryParse(value);
    if (parsed == null) {
      return value;
    }

    final host = parsed.host.trim().toLowerCase();
    if (host != '127.0.0.1' && host != 'localhost') {
      return value;
    }

    return parsed.replace(host: '10.0.2.2').toString();
  }

  static const Duration requestTimeout = Duration(seconds: 20);
}
