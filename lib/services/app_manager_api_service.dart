import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../models/app_preferences_model.dart';
import '../models/educational_article_model.dart';
import '../models/managed_app_user.dart';
import '../models/manual_ad_model.dart';
import '../models/remote_ui_config_model.dart';
import '../utils/app_manager_config.dart';

class AppManagerApiException implements Exception {
  const AppManagerApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AuthResult {
  const AuthResult({
    required this.token,
    required this.user,
  });

  final String token;
  final ManagedAppUser user;
}

class AppManagerApiService {
  AppManagerApiService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  Uri get _apiBaseUri {
    final base = AppManagerConfig.apiBaseUrl.endsWith('/')
        ? AppManagerConfig.apiBaseUrl.substring(
            0,
            AppManagerConfig.apiBaseUrl.length - 1,
          )
        : AppManagerConfig.apiBaseUrl;
    return Uri.parse(base);
  }

  Uri get _apiOriginUri => _apiBaseUri.replace(
        path: '/',
        query: null,
        fragment: null,
      );

  bool _isLoopbackHost(String host) {
    final normalized = host.trim().toLowerCase();
    return normalized == 'localhost' ||
        normalized == '127.0.0.1' ||
        normalized == '0.0.0.0' ||
        normalized == '::1';
  }

  String _normalizeAssetUrl(String rawUrl) {
    final url = rawUrl.trim();
    if (url.isEmpty) {
      return '';
    }

    final parsed = Uri.tryParse(url);
    if (parsed == null) {
      return url;
    }

    if (!parsed.hasScheme || parsed.host.isEmpty) {
      return _apiOriginUri.resolveUri(parsed).toString();
    }

    final apiHost = _apiOriginUri.host;
    if (_isLoopbackHost(parsed.host) && !_isLoopbackHost(apiHost)) {
      return _apiOriginUri
          .replace(
            path: parsed.path.isEmpty ? '/' : parsed.path,
            query: parsed.hasQuery ? parsed.query : null,
          )
          .toString();
    }

    return parsed.toString();
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = AppManagerConfig.apiBaseUrl.endsWith('/')
        ? AppManagerConfig.apiBaseUrl.substring(
            0,
            AppManagerConfig.apiBaseUrl.length - 1,
          )
        : AppManagerConfig.apiBaseUrl;
    final fullPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$fullPath').replace(queryParameters: query);
  }

  Map<String, String> _headers({String? token}) {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<Map<String, dynamic>> _request({
    required String method,
    required String path,
    Map<String, String>? query,
    Map<String, dynamic>? body,
    String? token,
    int retryCount = 2,
  }) async {
    final uri = _uri(path, query);

    for (var attempt = 1; attempt <= retryCount + 1; attempt++) {
      try {
        late http.Response response;
        final encodedBody = body == null ? null : jsonEncode(body);

        switch (method.toUpperCase()) {
          case 'GET':
            response = await _client
                .get(uri, headers: _headers(token: token))
                .timeout(AppManagerConfig.requestTimeout);
            break;
          case 'POST':
            response = await _client
                .post(
                  uri,
                  headers: _headers(token: token),
                  body: encodedBody,
                )
                .timeout(AppManagerConfig.requestTimeout);
            break;
          case 'PUT':
            response = await _client
                .put(
                  uri,
                  headers: _headers(token: token),
                  body: encodedBody,
                )
                .timeout(AppManagerConfig.requestTimeout);
            break;
          case 'PATCH':
            response = await _client
                .patch(
                  uri,
                  headers: _headers(token: token),
                  body: encodedBody,
                )
                .timeout(AppManagerConfig.requestTimeout);
            break;
          case 'DELETE':
            response = await _client
                .delete(
                  uri,
                  headers: _headers(token: token),
                  body: encodedBody,
                )
                .timeout(AppManagerConfig.requestTimeout);
            break;
          default:
            throw const AppManagerApiException('Unsupported HTTP method.');
        }

        final data = _decode(response);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return data;
        }

        final message = _extractMessage(data) ??
            'Request failed with status ${response.statusCode}.';
        throw AppManagerApiException(message, statusCode: response.statusCode);
      } on AppManagerApiException {
        rethrow;
      } catch (error) {
        if (attempt > retryCount) {
          throw AppManagerApiException(
            'Unable to connect to apps manager API at $uri. $error',
          );
        }

        await Future<void>.delayed(
          Duration(milliseconds: 350 * pow(2, attempt - 1).toInt()),
        );
      }
    }

    throw const AppManagerApiException('Unexpected request failure.');
  }

  Map<String, dynamic> _decode(http.Response response) {
    final raw = _decodeBodyText(response);
    if (raw.trim().isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return <String, dynamic>{'data': decoded};
  }

  String _decodeBodyText(http.Response response) {
    final bytes = response.bodyBytes;
    if (bytes.isEmpty) {
      return '';
    }

    try {
      return utf8.decode(bytes);
    } catch (_) {
      return response.body;
    }
  }

  String? _extractMessage(Map<String, dynamic> data) {
    final message = data['message'] ?? data['msg'];
    if (message != null) {
      return message.toString();
    }

    final errors = data['errors'];
    if (errors is Map) {
      for (final entry in errors.entries) {
        final value = entry.value;
        if (value is List && value.isNotEmpty) {
          return value.first.toString();
        }
      }
    }

    return null;
  }

  Future<AuthResult> register({
    required String email,
    required String password,
    String? fullName,
    String? countryCode,
    String? countryName,
    String? phoneNumber,
    String? tradingStatus,
    required String platform,
    String? deviceId,
  }) async {
    final data = await _request(
      method: 'POST',
      path: '/auth/register',
      body: <String, dynamic>{
        'email': email,
        'password': password,
        'full_name': fullName,
        'country_code': countryCode,
        'country_name': countryName,
        'phone_number': phoneNumber,
        if (AppManagerConfig.supportsTradingStatus)
          'trading_status': tradingStatus,
        'target_app_slug': AppManagerConfig.appSlug,
        'platform': platform,
        'device_id': deviceId,
      },
    );

    return AuthResult(
      token: (data['token'] ?? '').toString(),
      user: ManagedAppUser.fromJson(
        Map<String, dynamic>.from(data['user'] ?? <String, dynamic>{}),
      ),
    );
  }

  Future<AuthResult> login({
    required String email,
    required String password,
    required String platform,
    String? deviceId,
    String? sourceAppSlug,
  }) async {
    final data = await _request(
      method: 'POST',
      path: '/auth/login',
      body: <String, dynamic>{
        'email': email,
        'password': password,
        'target_app_slug': AppManagerConfig.appSlug,
        'source_app_slug': sourceAppSlug,
        'platform': platform,
        'device_id': deviceId,
      },
    );

    return AuthResult(
      token: (data['token'] ?? '').toString(),
      user: ManagedAppUser.fromJson(
        Map<String, dynamic>.from(data['user'] ?? <String, dynamic>{}),
      ),
    );
  }

  Future<void> requestPasswordReset({
    String? email,
    String? phone,
    String? countryCode,
  }) async {
    final body = <String, dynamic>{
      'target_app_slug': AppManagerConfig.appSlug,
    };
    if (email != null && email.trim().isNotEmpty) {
      body['email'] = email.trim();
    }
    if (phone != null && phone.trim().isNotEmpty) {
      body['phone'] = phone.trim();
    }
    if (countryCode != null && countryCode.trim().isNotEmpty) {
      body['country_code'] = countryCode.trim();
    }
    await _request(
      method: 'POST',
      path: '/auth/password/forgot',
      retryCount: 0,
      body: body,
    );
  }

  Future<String> verifyPasswordResetCode({
    String? email,
    String? phone,
    String? countryCode,
    required String code,
  }) async {
    final body = <String, dynamic>{
      'code': code.trim(),
      'target_app_slug': AppManagerConfig.appSlug,
    };
    if (email != null && email.trim().isNotEmpty) {
      body['email'] = email.trim();
    }
    if (phone != null && phone.trim().isNotEmpty) {
      body['phone'] = phone.trim();
    }
    if (countryCode != null && countryCode.trim().isNotEmpty) {
      body['country_code'] = countryCode.trim();
    }
    final data = await _request(
      method: 'POST',
      path: '/auth/password/verify',
      retryCount: 0,
      body: body,
    );

    final resetToken = (data['reset_token'] ?? '').toString().trim();
    if (resetToken.isEmpty) {
      throw const AppManagerApiException(
        'تعذر إنشاء جلسة استرجاع كلمة المرور. حاول مرة أخرى.',
      );
    }
    return resetToken;
  }

  Future<void> resetPassword({
    String? email,
    String? phone,
    String? countryCode,
    required String resetToken,
    required String password,
  }) async {
    final body = <String, dynamic>{
      'reset_token': resetToken.trim(),
      'password': password,
      'password_confirmation': password,
      'target_app_slug': AppManagerConfig.appSlug,
    };
    if (email != null && email.trim().isNotEmpty) {
      body['email'] = email.trim();
    }
    if (phone != null && phone.trim().isNotEmpty) {
      body['phone'] = phone.trim();
    }
    if (countryCode != null && countryCode.trim().isNotEmpty) {
      body['country_code'] = countryCode.trim();
    }
    await _request(
      method: 'POST',
      path: '/auth/password/reset',
      retryCount: 0,
      body: body,
    );
  }

  Future<AuthResult> socialLogin({
    required String provider,
    String? idToken,
    String? accessToken,
    required String platform,
    String? deviceId,
    String? fullName,
    String? email,
    String? sourceAppSlug,
  }) async {
    final normalizedIdToken = idToken?.trim();
    final normalizedAccessToken = accessToken?.trim();
    final normalizedProvider = provider.trim().toLowerCase();

    final hasIdToken =
        normalizedIdToken != null && normalizedIdToken.isNotEmpty;
    final hasAccessToken =
        normalizedAccessToken != null && normalizedAccessToken.isNotEmpty;

    if (!hasIdToken && !hasAccessToken) {
      throw const AppManagerApiException('Social sign-in token is missing.');
    }

    if (normalizedProvider != 'google' && !hasIdToken) {
      throw const AppManagerApiException(
          'ID token is required for this login.');
    }

    final data = await _request(
      method: 'POST',
      path: '/auth/social',
      body: <String, dynamic>{
        'provider': normalizedProvider,
        if (hasIdToken) 'id_token': normalizedIdToken,
        if (hasAccessToken) 'access_token': normalizedAccessToken,
        'email': email,
        'full_name': fullName,
        'target_app_slug': AppManagerConfig.appSlug,
        'source_app_slug': sourceAppSlug,
        'platform': platform,
        'device_id': deviceId,
      },
    );

    return AuthResult(
      token: (data['token'] ?? '').toString(),
      user: ManagedAppUser.fromJson(
        Map<String, dynamic>.from(data['user'] ?? <String, dynamic>{}),
      ),
    );
  }

  Future<ManagedAppUser> me(String token) async {
    final data = await _request(
      method: 'GET',
      path: '/auth/me',
      token: token,
    );

    return ManagedAppUser.fromJson(
      Map<String, dynamic>.from(data['user'] ?? <String, dynamic>{}),
    );
  }

  Future<void> logout(String token) async {
    await _request(
      method: 'POST',
      path: '/auth/logout',
      token: token,
      body: <String, dynamic>{
        'target_app_slug': AppManagerConfig.appSlug,
      },
    );
  }

  Future<ManagedAppUser> updateProfile({
    required String token,
    String? fullName,
    String? countryCode,
    String? countryName,
    String? phoneNumber,
    String? tradingStatus,
    String? currentPassword,
    String? newPassword,
  }) async {
    final data = await _request(
      method: 'PATCH',
      path: '/auth/profile',
      token: token,
      body: <String, dynamic>{
        'full_name': fullName,
        'country_code': countryCode,
        'country_name': countryName,
        'phone_number': phoneNumber,
        if (AppManagerConfig.supportsTradingStatus)
          'trading_status': tradingStatus,
        'current_password': currentPassword,
        'new_password': newPassword,
      },
    );

    return ManagedAppUser.fromJson(
      Map<String, dynamic>.from(data['user'] ?? <String, dynamic>{}),
    );
  }

  Future<void> deleteAccount({
    required String token,
    String? password,
  }) async {
    await _request(
      method: 'DELETE',
      path: '/auth/account',
      token: token,
      body: <String, dynamic>{
        if (password != null && password.trim().isNotEmpty)
          'password': password.trim(),
      },
    );
  }

  Future<AppPreferencesModel> getPreferences({
    required String token,
  }) async {
    final data = await _request(
      method: 'GET',
      path: '/preferences',
      token: token,
      query: <String, String>{'app_slug': AppManagerConfig.appSlug},
    );

    return AppPreferencesModel.fromJson(
      Map<String, dynamic>.from(data['preferences'] ?? <String, dynamic>{}),
    );
  }

  Future<AppPreferencesModel> upsertPreferences({
    required String token,
    required AppPreferencesModel preferences,
  }) async {
    final data = await _request(
      method: 'PUT',
      path: '/preferences',
      token: token,
      body: <String, dynamic>{
        'app_slug': AppManagerConfig.appSlug,
        ...preferences.toJson(),
      },
    );

    return AppPreferencesModel.fromJson(
      Map<String, dynamic>.from(data['preferences'] ?? <String, dynamic>{}),
    );
  }

  Future<void> startSession({
    String? token,
    required String sessionUid,
    required String platform,
    String? deviceId,
    Map<String, dynamic>? metadata,
  }) async {
    await _request(
      method: 'POST',
      path: '/analytics/session/start',
      token: token,
      body: <String, dynamic>{
        'app_slug': AppManagerConfig.appSlug,
        'session_uid': sessionUid,
        'platform': platform,
        'device_id': deviceId,
        'metadata': metadata,
      },
    );
  }

  Future<void> endSession({
    String? token,
    required String sessionUid,
    int? pagesViewed,
    Map<String, dynamic>? metadata,
  }) async {
    await _request(
      method: 'POST',
      path: '/analytics/session/end',
      token: token,
      body: <String, dynamic>{
        'session_uid': sessionUid,
        'pages_viewed': pagesViewed,
        'metadata': metadata,
      },
    );
  }

  Future<void> trackEvent({
    String? token,
    required String eventName,
    String? sessionUid,
    required String platform,
    String? deviceId,
    int? durationMs,
    double? value,
    Map<String, dynamic>? metadata,
  }) async {
    await _request(
      method: 'POST',
      path: '/analytics/event',
      token: token,
      body: <String, dynamic>{
        'app_slug': AppManagerConfig.appSlug,
        'event_name': eventName,
        'session_uid': sessionUid,
        'platform': platform,
        'device_id': deviceId,
        'duration_ms': durationMs,
        'value': value,
        'metadata': metadata,
      },
    );
  }

  Future<void> trackManualAd({
    required int adId,
    required String eventType,
    required String platform,
    String? sessionUid,
    String? deviceId,
    String? placement,
    Map<String, dynamic>? metadata,
  }) async {
    await _request(
      method: 'POST',
      path: '/manual-ads/$adId/track',
      body: <String, dynamic>{
        'event_type': eventType,
        'app_slug': AppManagerConfig.appSlug,
        'platform': platform,
        'session_uid': sessionUid,
        'device_id': deviceId,
        'placement': placement,
        'metadata': metadata,
      },
    );
  }

  Future<void> trackMenuCta({
    required String eventType,
    required String platform,
    String? sessionUid,
    String? deviceId,
    String? label,
    String? url,
    Map<String, dynamic>? metadata,
  }) async {
    await _request(
      method: 'POST',
      path: '/menu-cta/track',
      body: <String, dynamic>{
        'event_type': eventType,
        'app_slug': AppManagerConfig.appSlug,
        'platform': platform,
        'session_uid': sessionUid,
        'device_id': deviceId,
        'label': label,
        'url': url,
        'metadata': metadata,
      },
    );
  }

  Future<ManualAdModel?> getActiveAd({
    required String platform,
    String placement = 'rectangle_main',
    String? countryCode,
    required bool isAuthenticated,
    required int launchCount,
  }) async {
    final query = <String, String>{
      'app_slug': AppManagerConfig.appSlug,
      'platform': platform,
      'placement': placement,
      'is_authenticated': isAuthenticated ? '1' : '0',
      'launch_count': '$launchCount',
    };
    final normalizedCountryCode = countryCode?.trim().toUpperCase() ?? '';
    if (normalizedCountryCode.isNotEmpty) {
      query['country_code'] = normalizedCountryCode;
    }

    final data = await _request(
      method: 'GET',
      path: '/manual-ads/active',
      query: query,
    );

    final ad = data['ad'];
    if (ad is Map<String, dynamic>) {
      final normalized = Map<String, dynamic>.from(ad);
      normalized['image_url'] =
          _normalizeAssetUrl((normalized['image_url'] ?? '').toString());
      return ManualAdModel.fromJson(normalized);
    }

    return null;
  }

  Future<RemoteUiConfigModel> getRemoteUiConfig({
    required String platform,
    String? countryCode,
    required bool isAuthenticated,
    required int launchCount,
  }) async {
    final query = <String, String>{
      'app_slug': AppManagerConfig.appSlug,
      'platform': platform,
      'is_authenticated': isAuthenticated ? '1' : '0',
      'launch_count': '$launchCount',
    };
    final normalizedCountryCode = countryCode?.trim().toUpperCase() ?? '';
    if (normalizedCountryCode.isNotEmpty) {
      query['country_code'] = normalizedCountryCode;
    }

    final data = await _request(
      method: 'GET',
      path: '/ui/config',
      query: query,
    );

    final popupAd = data['popup_ad'];
    if (popupAd is Map<String, dynamic>) {
      popupAd['image_url'] =
          _normalizeAssetUrl((popupAd['image_url'] ?? '').toString());
    }

    final ourApps = data['our_apps'];
    if (ourApps is List) {
      for (final rawApp in ourApps.whereType<Map>()) {
        final logoUrl = (rawApp['logo_url'] ?? '').toString();
        if (logoUrl.trim().isNotEmpty) {
          rawApp['logo_url'] = _normalizeAssetUrl(logoUrl);
        }
      }
    }

    return RemoteUiConfigModel.fromJson(data);
  }

  Future<String?> detectCountryCode() async {
    final data = await _request(
      method: 'GET',
      path: '/geo/country',
    );

    final countryCode = data['country_code']?.toString();
    return countryCode?.trim().isEmpty == true ? null : countryCode?.trim();
  }

  Future<List<EducationalArticleSummary>> getArticles({
    int page = 1,
    int perPage = 20,
  }) async {
    final data = await _request(
      method: 'GET',
      path: '/education/articles',
      query: <String, String>{
        'app_slug': AppManagerConfig.appSlug,
        'page': '$page',
        'per_page': '$perPage',
      },
    );

    final raw = data['data'];
    if (raw is! List) {
      return <EducationalArticleSummary>[];
    }

    return raw.whereType<Map>().map((entry) {
      final normalized =
          Map<String, dynamic>.from(entry.cast<String, dynamic>());
      final cover = (normalized['cover_image_url'] ?? '').toString();
      if (cover.trim().isNotEmpty) {
        normalized['cover_image_url'] = _normalizeAssetUrl(cover);
      }
      return EducationalArticleSummary.fromJson(normalized);
    }).toList();
  }

  Future<EducationalArticleDetail> getArticleDetail(String slug) async {
    final data = await _request(
      method: 'GET',
      path: '/education/articles/$slug',
      query: <String, String>{
        'app_slug': AppManagerConfig.appSlug,
      },
    );

    final raw =
        Map<String, dynamic>.from(data['article'] ?? <String, dynamic>{});
    final cover = (raw['cover_image_url'] ?? '').toString();
    if (cover.trim().isNotEmpty) {
      raw['cover_image_url'] = _normalizeAssetUrl(cover);
    }
    return EducationalArticleDetail.fromJson(raw);
  }

  Future<void> registerPushToken({
    required String token,
    required String platform,
    required String pushToken,
    String provider = 'fcm',
    String? deviceId,
  }) async {
    await _request(
      method: 'POST',
      path: '/push/device-token',
      token: token,
      body: <String, dynamic>{
        'app_slug': AppManagerConfig.appSlug,
        'platform': platform,
        'provider': provider,
        'token': pushToken,
        'device_id': deviceId,
      },
    );
  }
}
