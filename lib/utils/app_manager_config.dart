import 'package:flutter/foundation.dart';

class AppManagerConfig {
  static const String appSlug = 'almurakib_egypt_stocks';
  static const String _defaultApiBase = 'https://amanager.almurakib.com/';
  static const String _androidEmulatorLoopback = '10.0.2.2';
  static const bool supportsTradingStatus = bool.fromEnvironment(
    'APP_MANAGER_SUPPORTS_TRADING_STATUS',
    defaultValue: true,
  );
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
    return _normalizeApiBase(
      _resolvePlatformLocalApiBase(base),
    );
  }

  static String _resolvePlatformLocalApiBase(String value) {
    final trimmed = value.trim();
    final parsed = Uri.tryParse(trimmed);
    if (kIsWeb ||
        parsed == null ||
        defaultTargetPlatform != TargetPlatform.android) {
      return trimmed;
    }

    final host = parsed.host.trim().toLowerCase();
    if (host != '127.0.0.1' && host != 'localhost' && host != '0.0.0.0') {
      return trimmed;
    }

    return parsed.replace(host: _androidEmulatorLoopback).toString();
  }

  static String _normalizeApiBase(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '$_defaultApiBase/api/v1';
    }

    final withoutTrailingSlash = trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
    final parsed = Uri.tryParse(withoutTrailingSlash);
    if (parsed == null) {
      return withoutTrailingSlash;
    }

    if (parsed.path.isEmpty || parsed.path == '/') {
      return '$withoutTrailingSlash/api/v1';
    }

    return withoutTrailingSlash;
  }

  static const Duration requestTimeout = Duration(seconds: 20);
}
