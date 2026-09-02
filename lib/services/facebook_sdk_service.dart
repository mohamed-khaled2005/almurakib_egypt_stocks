import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/remote_ui_config_model.dart';

class FacebookSdkService {
  FacebookSdkService._();

  static final FacebookSdkService instance = FacebookSdkService._();
  static const MethodChannel _channel = MethodChannel(
    'com.almurakib.egyptappstocks/facebook_sdk',
  );

  String? _configuredAppId;

  Future<bool> configure(FacebookSdkConfig config) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    if (!config.isUsable) {
      return false;
    }

    final appId = config.appId!.trim();
    if (_configuredAppId == appId) {
      return true;
    }

    try {
      final configured = await _channel.invokeMethod<bool>(
        'configure',
        <String, dynamic>{
          'app_id': appId,
          'client_token': config.clientToken!.trim(),
          'auto_log_app_events': config.autoLogAppEvents,
        },
      );
      if (configured == true) {
        _configuredAppId = appId;
        return true;
      }
    } on MissingPluginException {
      // The native SDK is intentionally Android-only for this integration.
    } on PlatformException catch (error) {
      if (kDebugMode) {
        debugPrint('Facebook SDK configuration failed: ${error.code}');
      }
    }
    return false;
  }
}