import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../core/services/favorites_service.dart';
import '../data/country_options.dart';
import '../models/app_preferences_model.dart';
import '../models/educational_article_model.dart';
import '../models/managed_app_user.dart';
import '../core/api/api_keys.dart';
import '../models/manual_ad_model.dart';
import '../models/remote_ui_config_model.dart';
import '../services/app_manager_api_service.dart';
import '../services/facebook_sdk_service.dart';
import '../services/push_notification_service.dart';
import '../utils/app_manager_config.dart';
import '../utils/safe_error_message.dart';

class AppManagerProvider with ChangeNotifier {
  AppManagerProvider({AppManagerApiService? api})
      : _api = api ?? AppManagerApiService();

  final AppManagerApiService _api;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>['email'],
    serverClientId: AppManagerConfig.googleServerClientId,
  );

  static const String _tokenKey = 'app_manager_token';
  static const String _deviceIdKey = 'app_manager_device_id';
  static const String _favoriteItemsKey = 'favorite_stocks';
  static const String _profilePromptLaunchCountKey =
      'app_manager_profile_prompt_launch_count';
  static const String _phoneRequirementBaselineLaunchKeyPrefix =
      'app_manager_phone_requirement_baseline_launch_count';
  static const String _popupDismissKeyPrefix = 'app_manager_popup_dismissed';
  static const int _phoneRequirementLaunchThreshold = 5;
  static const Duration _autoRefreshInterval = Duration(seconds: 10);
  static const Duration _minimumRefreshGap = Duration(seconds: 4);

  bool _initialized = false;
  bool _isBusy = false;
  String? _errorMessage;
  Future<void>? _initializationFuture;

  String? _token;
  String? _deviceId;
  ManagedAppUser? _user;
  AppPreferencesModel _preferences = AppPreferencesModel.empty();
  ManualAdModel? _activeAd;
  RemoteUiConfigModel _remoteUiConfig = RemoteUiConfigModel.empty();
  List<EducationalArticleSummary> _articles = <EducationalArticleSummary>[];
  final Map<String, EducationalArticleDetail> _articleCache =
      <String, EducationalArticleDetail>{};
  String? _networkSuggestedCountryCode;

  String? _activeSessionUid;
  int _pagesViewedInSession = 0;
  int _appLaunchCount = 0;
  int _currentUserLaunchCount = 0;
  Timer? _autoRefreshTimer;
  bool _isRefreshingManagedContent = false;
  DateTime? _lastManagedContentRefreshAt;

  bool get initialized => _initialized;
  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated =>
      _token != null && _token!.isNotEmpty && _user != null;
  bool get canUseGoogleSignIn =>
      kIsWeb || defaultTargetPlatform != TargetPlatform.iOS;
  bool get canUseAppleSignIn =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  String? get token => _token;
  ManagedAppUser? get user => _user;
  AppPreferencesModel get preferences => _preferences;
  ManualAdModel? get activeAd => _activeAd;
  RemoteUiConfigModel get remoteUiConfig => _remoteUiConfig;
  List<ManagedAppListing> get ourApps => _remoteUiConfig.ourApps;
  FacebookSdkConfig get facebookSdk => _remoteUiConfig.facebookSdk;
  ManagedMenuCta? get menuCta => _remoteUiConfig.menuCta;
  List<SocialLinkModel> get socialLinks => _remoteUiConfig.socialLinks;
  ManualAdModel? get popupAd => _remoteUiConfig.popupAd;
  ManagedMarketConfig get marketConfig => _remoteUiConfig.market;
  bool get isMarketClosedByManager => !_remoteUiConfig.market.isOpen;
  String get marketClosedMessage => _remoteUiConfig.market.message;
  AppUpdateConfig get appUpdate => _remoteUiConfig.appUpdate;
  List<EducationalArticleSummary> get articles => _articles;
  String get suggestedCountryCode => _resolveAudienceCountryCode();
  int get appLaunchCount => _appLaunchCount;
  int get currentUserLaunchCount => _currentUserLaunchCount;
  int get remainingLaunchesUntilPhoneRequired =>
      max(0, _phoneRequirementLaunchThreshold - _currentUserLaunchCount);

  bool get shouldRequirePhoneNumber =>
      _currentUserLaunchCount >= _phoneRequirementLaunchThreshold;

  bool get shouldRequirePhoneNumberForCurrentUser {
    final user = _user;
    if (user == null || user.hasPhoneNumber) {
      return false;
    }

    final createdAt = user.createdAtDateTime;
    if (createdAt != null) {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      if (createdAt.isBefore(todayStart)) {
        return true;
      }
    }

    return shouldRequirePhoneNumber;
  }

  bool get requiresProfileCompletion {
    if (!isAuthenticated) {
      return false;
    }

    final user = _user;
    if (user == null) {
      return false;
    }

    final missingTradingStatus =
        AppManagerConfig.supportsTradingStatus && !user.hasTradingStatus;
    if (!user.hasCountry || missingTradingStatus) {
      return true;
    }

    return shouldRequirePhoneNumberForCurrentUser;
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    if (_initializationFuture != null) {
      return _initializationFuture;
    }

    _initializationFuture = _initializeInternal();
    return _initializationFuture;
  }

  Future<void> _initializeInternal() async {
    _setBusy(true);
    _errorMessage = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      _appLaunchCount = (prefs.getInt(_profilePromptLaunchCountKey) ?? 0) + 1;
      await prefs.setInt(_profilePromptLaunchCountKey, _appLaunchCount);

      _token = prefs.getString(_tokenKey);
      _deviceId = prefs.getString(_deviceIdKey);
      if (_deviceId == null || _deviceId!.isEmpty) {
        _deviceId = _generateDeviceId();
        await prefs.setString(_deviceIdKey, _deviceId!);
      }

      _preferences = AppPreferencesModel(
        selectedCurrency: null,
        favoriteItems: _normalizeFavoriteItems(
          prefs.getStringList(_favoriteItemsKey) ?? <String>[],
        ),
        watchedSymbols: const <String>[],
        settings: null,
      );

      FavoritesService.bindSyncHandler((favorites) => syncFavoriteStocks(favorites));

      if (_token != null && _token!.isNotEmpty) {
        try {
          _user = await _api.me(_token!);
          await _syncPhoneRequirementProgressForCurrentUser(prefs);
          await _pullPreferencesFromServer();
          await syncPushToken();
        } catch (_) {
          await _clearAuth(prefs);
        }
      } else {
        _currentUserLaunchCount = 0;
      }

      await _refreshSuggestedCountryCode();
      await Future.wait<void>(<Future<void>>[
        refreshAd(),
        refreshRemoteUiConfig(),
        refreshEducationalContent(),
      ]);
      _lastManagedContentRefreshAt = DateTime.now();

      await startSessionIfNeeded();
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _initialized = true;
      _initializationFuture = null;
      _setBusy(false);
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    String? fullName,
    required String countryCode,
    required String countryName,
    String? phoneNumber,
    String? tradingStatus,
  }) async {
    _setBusy(true);
    _errorMessage = null;

    try {
      final normalizedName = (fullName ?? '').trim();
      if (!_isMeaningfulFullName(normalizedName)) {
        _errorMessage = 'الاسم الكامل مطلوب بشكل صحيح.';
        notifyListeners();
        return false;
      }

      if (email.trim().isEmpty) {
        _errorMessage = 'البريد الإلكتروني مطلوب.';
        notifyListeners();
        return false;
      }

      if (password.isEmpty) {
        _errorMessage = 'كلمة المرور مطلوبة.';
        notifyListeners();
        return false;
      }

      final result = await _api.register(
        email: email.trim(),
        password: password,
        fullName: normalizedName,
        countryCode: countryCode.trim(),
        countryName: countryName.trim(),
        phoneNumber:
            phoneNumber?.trim().isEmpty == true ? null : phoneNumber?.trim(),
        tradingStatus: tradingStatus?.trim().isEmpty == true
            ? null
            : tradingStatus?.trim(),
        platform: _platformName(),
        deviceId: _deviceId,
      );

      await _applyAuthResult(result, eventName: 'user_register');
      return true;
    } catch (error) {
      _errorMessage = SafeErrorMessage.forUser(error);
      notifyListeners();
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _setBusy(true);
    _errorMessage = null;

    try {
      final result = await _api.login(
        email: email.trim(),
        password: password,
        platform: _platformName(),
        deviceId: _deviceId,
      );

      await _applyAuthResult(result, eventName: 'user_login');
      return true;
    } catch (error) {
      _errorMessage = SafeErrorMessage.forUser(error);
      notifyListeners();
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<bool> requestPasswordReset(
    String identifier, {
    String? countryCode,
  }) async {
    _setBusy(true);
    _errorMessage = null;
    try {
      final trimmed = identifier.trim();
      final isEmail = trimmed.contains('@');
      await _api.requestPasswordReset(
        email: isEmail ? trimmed : null,
        phone: !isEmail ? trimmed : null,
        countryCode: countryCode ?? _resolveAudienceCountryCode(),
      );
      return true;
    } catch (error) {
      _errorMessage = SafeErrorMessage.forUser(error);
      notifyListeners();
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<String?> verifyPasswordResetCode({
    required String identifier,
    required String code,
    String? countryCode,
  }) async {
    _setBusy(true);
    _errorMessage = null;
    try {
      final trimmed = identifier.trim();
      final isEmail = trimmed.contains('@');
      return await _api.verifyPasswordResetCode(
        email: isEmail ? trimmed : null,
        phone: !isEmail ? trimmed : null,
        countryCode: countryCode ?? _resolveAudienceCountryCode(),
        code: code.trim(),
      );
    } catch (error) {
      _errorMessage = SafeErrorMessage.forUser(error);
      notifyListeners();
      return null;
    } finally {
      _setBusy(false);
    }
  }

  Future<bool> resetPassword({
    required String identifier,
    required String resetToken,
    required String password,
    String? countryCode,
  }) async {
    _setBusy(true);
    _errorMessage = null;
    try {
      final trimmed = identifier.trim();
      final isEmail = trimmed.contains('@');
      await _api.resetPassword(
        email: isEmail ? trimmed : null,
        phone: !isEmail ? trimmed : null,
        countryCode: countryCode ?? _resolveAudienceCountryCode(),
        resetToken: resetToken.trim(),
        password: password,
      );
      return true;
    } catch (error) {
      _errorMessage = SafeErrorMessage.forUser(error);
      notifyListeners();
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<bool> loginWithGoogle() async {
    if (!canUseGoogleSignIn) {
      _errorMessage = 'تسجيل Google غير متاح على iOS.';
      notifyListeners();
      return false;
    }

    _setBusy(true);
    _errorMessage = null;

    try {
      await _googleSignIn.signOut();
      final account = await _googleSignIn.signIn();
      if (account == null) {
        _errorMessage = 'تم إلغاء تسجيل الدخول بجوجل.';
        notifyListeners();
        return false;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken?.trim();
      final accessToken = auth.accessToken?.trim();
      final hasIdToken = idToken != null && idToken.isNotEmpty;
      final hasAccessToken = accessToken != null && accessToken.isNotEmpty;
      if (!hasIdToken && !hasAccessToken) {
        _errorMessage = 'تعذر الحصول على Google token.';
        notifyListeners();
        return false;
      }

      final result = await _api.socialLogin(
        provider: 'google',
        idToken: hasIdToken ? idToken : null,
        accessToken: hasAccessToken ? accessToken : null,
        platform: _platformName(),
        deviceId: _deviceId,
        fullName: account.displayName,
        email: account.email,
      );

      await _applyAuthResult(result, eventName: 'user_login_google');
      return true;
    } catch (error) {
      _errorMessage = _friendlyGoogleSignInError(error);
      notifyListeners();
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<bool> loginWithApple() async {
    if (!canUseAppleSignIn) {
      _errorMessage = 'تسجيل Apple متاح على iPhone وiPad فقط.';
      notifyListeners();
      return false;
    }

    _setBusy(true);
    _errorMessage = null;

    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: <AppleIDAuthorizationScopes>[
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final idToken = credential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        _errorMessage = 'تعذر الحصول على Apple ID Token.';
        notifyListeners();
        return false;
      }

      final given = credential.givenName?.trim() ?? '';
      final family = credential.familyName?.trim() ?? '';
      final fullName =
          '$given $family'.trim().isEmpty ? null : '$given $family'.trim();

      final result = await _api.socialLogin(
        provider: 'apple',
        idToken: idToken,
        platform: _platformName(),
        deviceId: _deviceId,
        fullName: fullName,
        email: credential.email,
      );

      await _applyAuthResult(result, eventName: 'user_login_apple');
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      notifyListeners();
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> logout() async {
    _setBusy(true);
    _errorMessage = null;

    try {
      if (_token != null && _token!.isNotEmpty) {
        await _api.logout(_token!);
      }
    } catch (_) {
      // Local logout still proceeds.
    } finally {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final prefs = await SharedPreferences.getInstance();
      await _clearAuth(prefs);
      await endSession();
      await refreshAd();
      await refreshRemoteUiConfig();
      _setBusy(false);
      notifyListeners();
    }
  }

  Future<bool> updateProfile({
    String? fullName,
    String? countryCode,
    String? countryName,
    String? phoneNumber,
    String? tradingStatus,
    String? currentPassword,
    String? newPassword,
  }) async {
    if (!isAuthenticated) {
      return false;
    }

    _setBusy(true);
    _errorMessage = null;

    try {
      if (fullName != null &&
          fullName.trim().isNotEmpty &&
          !_isMeaningfulFullName(fullName.trim())) {
        _errorMessage = 'الاسم الكامل غير صالح.';
        notifyListeners();
        return false;
      }

      _user = await _api.updateProfile(
        token: _token!,
        fullName: fullName,
        countryCode: countryCode,
        countryName: countryName,
        phoneNumber: phoneNumber,
        tradingStatus: tradingStatus,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      await refreshAd();
      await refreshRemoteUiConfig();
      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      notifyListeners();
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<bool> deleteAccount({String? password}) async {
    if (!isAuthenticated) {
      return false;
    }

    _setBusy(true);
    _errorMessage = null;

    try {
      await _api.deleteAccount(
        token: _token!,
        password: password,
      );

      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final prefs = await SharedPreferences.getInstance();
      await _clearAuth(prefs);
      await endSession();
      await refreshAd();
      await refreshRemoteUiConfig();
      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      notifyListeners();
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> replaceFavoriteItems(
    List<String> items, {
    bool pushRemote = true,
  }) async {
    final normalized = _normalizeFavoriteItems(items);
    if (_listEquals(normalized, _preferences.favoriteItems)) {
      if (pushRemote && isAuthenticated) {
        await _pushPreferencesToServer();
      }
      return;
    }

    _preferences = _preferences.copyWith(favoriteItems: normalized);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoriteItemsKey, normalized);
    notifyListeners();

    if (pushRemote && isAuthenticated) {
      await _pushPreferencesToServer();
    }
  }

  Future<void> refreshAd() async {
    try {
      final ad = await _api.getActiveAd(
        platform: _platformName(),
        countryCode: _resolveAudienceCountryCode(),
        isAuthenticated: isAuthenticated,
        launchCount: _appLaunchCount,
      );
      _activeAd = ad?.placement.trim() == 'rectangle_main' ? ad : null;
      notifyListeners();
    } catch (_) {
      // Keep the existing ad if refresh fails.
    }
  }

  Future<void> refreshRemoteUiConfig() async {
    try {
      final remote = await _api.getRemoteUiConfig(
        platform: _platformName(),
        countryCode: _resolveAudienceCountryCode(),
        isAuthenticated: isAuthenticated,
        launchCount: _appLaunchCount,
      );
      final popupAd = remote.popupAd?.placement.trim() == 'popup_center'
          ? remote.popupAd
          : null;
      final filteredPopupAd = await _filterDismissedPopupAd(popupAd);
      _remoteUiConfig = remote.copyWith(
        popupAd: filteredPopupAd,
        clearPopupAd: filteredPopupAd == null,
      );

      // Configure dynamic keys if provided by manager
      if (_remoteUiConfig.fcsApiKey != null && _remoteUiConfig.fcsApiKey!.isNotEmpty) {
        ApiKeys.setFcsApiKey(_remoteUiConfig.fcsApiKey);
      }
      if (_remoteUiConfig.liveSocketKey != null && _remoteUiConfig.liveSocketKey!.isNotEmpty) {
        ApiKeys.setLiveSocketKey(_remoteUiConfig.liveSocketKey);
      }
      if (_remoteUiConfig.translationUrl != null && _remoteUiConfig.translationUrl!.isNotEmpty) {
        ApiKeys.setTranslationUrl(_remoteUiConfig.translationUrl);
      }

      notifyListeners();
      await FacebookSdkService.instance.configure(_remoteUiConfig.facebookSdk);
    } catch (_) {
      // Keep current UI config if fetch fails.
    }
  }

  Future<void> refreshEducationalContent() async {
    try {
      _articles = await _api.getArticles();
      _articleCache.clear();
      notifyListeners();
    } catch (_) {
      // Keep old content.
    }
  }

  Future<EducationalArticleDetail?> getEducationalArticleDetail(
    String slug,
  ) async {
    if (_articleCache.containsKey(slug)) {
      return _articleCache[slug];
    }

    try {
      final detail = await _api.getArticleDetail(slug);
      _articleCache[slug] = detail;
      return detail;
    } catch (error) {
      _errorMessage = error.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> refreshManagedContent({bool force = false}) async {
    if (!_initialized && _initializationFuture != null) {
      try {
        await _initializationFuture;
      } catch (_) {}
    }

    if (!_initialized || _isRefreshingManagedContent) {
      return;
    }

    final now = DateTime.now();
    if (!force &&
        _lastManagedContentRefreshAt != null &&
        now.difference(_lastManagedContentRefreshAt!) < _minimumRefreshGap) {
      return;
    }

    _isRefreshingManagedContent = true;
    try {
      await Future.wait<void>(<Future<void>>[
        refreshAd(),
        refreshRemoteUiConfig(),
        refreshEducationalContent(),
      ]);
      _lastManagedContentRefreshAt = DateTime.now();
    } finally {
      _isRefreshingManagedContent = false;
    }
  }

  void startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
      refreshManagedContent();
    });
  }

  void stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  Future<void> dismissPopupAd(ManualAdModel ad) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_popupDismissKey(ad.id), true);
    await trackManualAd(ad: ad, eventType: 'dismiss');

    if (_remoteUiConfig.popupAd?.id == ad.id) {
      _remoteUiConfig = _remoteUiConfig.copyWith(clearPopupAd: true);
      notifyListeners();
    }
  }

  Future<void> syncPushToken() async {
    if (!isAuthenticated) {
      return;
    }

    try {
      final pushToken = await PushNotificationService.instance.getToken();
      if (pushToken == null || pushToken.trim().isEmpty) {
        return;
      }
      await registerPushToken(pushToken);
    } catch (_) {
      // Non-blocking path.
    }
  }

  Future<void> registerPushToken(String pushToken) async {
    if (!isAuthenticated || pushToken.trim().isEmpty) {
      return;
    }

    try {
      await _api.registerPushToken(
        token: _token!,
        platform: _platformName(),
        pushToken: pushToken.trim(),
        provider: 'fcm',
        deviceId: _deviceId,
      );
    } catch (_) {
      // Non-blocking path.
    }
  }

  Future<void> startSessionIfNeeded({bool forceRestart = false}) async {
    if (_activeSessionUid != null && !forceRestart) {
      return;
    }

    if (forceRestart && _activeSessionUid != null) {
      await endSession();
    }

    _activeSessionUid = _generateSessionUid();
    _pagesViewedInSession = 1;

    try {
      await _api.startSession(
        token: _token,
        sessionUid: _activeSessionUid!,
        platform: _platformName(),
        deviceId: _deviceId,
        metadata: <String, dynamic>{
          'source': 'mobile',
          'app_slug': AppManagerConfig.appSlug,
        },
      );
    } catch (_) {
      // Session tracking should not block the app.
    }
  }

  Future<void> endSession() async {
    if (_activeSessionUid == null) {
      return;
    }

    final endedSession = _activeSessionUid!;
    _activeSessionUid = null;

    try {
      await _api.endSession(
        token: _token,
        sessionUid: endedSession,
        pagesViewed: _pagesViewedInSession,
      );
    } catch (_) {
      // Ignore lifecycle network failures.
    }
  }

  Future<void> trackPageView(String pageName) async {
    _pagesViewedInSession += 1;
    await trackEvent(
      eventName: 'page_view',
      metadata: <String, dynamic>{'page': pageName},
    );
  }

  Future<void> trackEvent({
    required String eventName,
    int? durationMs,
    double? value,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _api.trackEvent(
        token: _token,
        eventName: eventName,
        sessionUid: _activeSessionUid,
        platform: _platformName(),
        deviceId: _deviceId,
        durationMs: durationMs,
        value: value,
        metadata: metadata,
      );
    } catch (_) {
      // Fire-and-forget analytics.
    }
  }

  Future<void> trackManualAd({
    required ManualAdModel ad,
    required String eventType,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _api.trackManualAd(
        adId: ad.id,
        eventType: eventType,
        platform: _platformName(),
        sessionUid: _activeSessionUid,
        deviceId: _deviceId,
        placement: ad.placement,
        metadata: <String, dynamic>{
          'title': ad.title,
          'target_url': ad.targetUrl,
          if (metadata != null) ...metadata,
        },
      );
    } catch (_) {
      // Ad analytics should never block display/click flows.
    }
  }

  Future<void> trackMenuCta({
    required String eventType,
    String? label,
    String? url,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _api.trackMenuCta(
        eventType: eventType,
        platform: _platformName(),
        sessionUid: _activeSessionUid,
        deviceId: _deviceId,
        label: label ?? _remoteUiConfig.menuCta?.label,
        url: url ?? _remoteUiConfig.menuCta?.url,
        metadata: metadata,
      );
    } catch (_) {
      // Menu CTA analytics fire-and-forget.
    }
  }

  Future<void> syncFavoriteStocks(Iterable<String> symbols) async {
    final normalized = _normalizeFavoriteItems(symbols.toList());
    _preferences = AppPreferencesModel(
      selectedCurrency: _preferences.selectedCurrency,
      favoriteItems: normalized,
      watchedSymbols: _preferences.watchedSymbols,
      settings: _preferences.settings,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoriteItemsKey, normalized);
    notifyListeners();
    if (isAuthenticated) {
      await _pushPreferencesToServer();
    }
  }

  Future<void> _applyAuthResult(
    AuthResult result, {
    required String eventName,
  }) async {
    _token = result.token;
    _user = result.user;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, _token!);
    await _syncPhoneRequirementProgressForCurrentUser(prefs);

    await _pullPreferencesFromServer();
    await _pushPreferencesToServer();
    await startSessionIfNeeded(forceRestart: true);
    await refreshAd();
    await refreshRemoteUiConfig();
    await trackEvent(eventName: eventName);
    await syncPushToken();
    notifyListeners();
  }

  Future<void> _pullPreferencesFromServer() async {
    if (!isAuthenticated) {
      return;
    }

    try {
      final remote = await _api.getPreferences(token: _token!);
      if (remote.favoriteItems.isNotEmpty) {
        final normalized = _normalizeFavoriteItems(remote.favoriteItems);
        _preferences = AppPreferencesModel(
          selectedCurrency:
              remote.selectedCurrency ?? _preferences.selectedCurrency,
          favoriteItems: normalized,
          watchedSymbols: remote.watchedSymbols,
          settings: remote.settings,
        );
        await FavoritesService.replaceFavorites(normalized, syncRemote: false);
      } else {
        final localFavorites = await FavoritesService.getFavorites();
        if (localFavorites.isNotEmpty) {
          final normalized = _normalizeFavoriteItems(localFavorites);
          _preferences = AppPreferencesModel(
            selectedCurrency:
                remote.selectedCurrency ?? _preferences.selectedCurrency,
            favoriteItems: normalized,
            watchedSymbols: remote.watchedSymbols,
            settings: remote.settings,
          );
          await _pushPreferencesToServer();
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_favoriteItemsKey, _preferences.favoriteItems);
      notifyListeners();
    } catch (_) {
      // Keep local preferences.
    }
  }

  Future<void> _pushPreferencesToServer() async {
    if (!isAuthenticated) {
      return;
    }

    try {
      _preferences = await _api.upsertPreferences(
        token: _token!,
        preferences: _preferences,
      );
      notifyListeners();
    } catch (_) {
      // Keep local state if sync fails.
    }
  }

  Future<ManualAdModel?> _filterDismissedPopupAd(ManualAdModel? ad) async {
    if (ad == null) {
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool(_popupDismissKey(ad.id)) ?? false;
    return dismissed ? null : ad;
  }

  Future<void> _refreshSuggestedCountryCode() async {
    try {
      final detectedCountryCode = _normalizedKnownCountryCode(
        await _api.detectCountryCode(),
      );
      if (detectedCountryCode == null) {
        return;
      }

      _networkSuggestedCountryCode = detectedCountryCode;
      notifyListeners();
    } catch (_) {
      // Keep locale fallback if country detection is unavailable.
    }
  }

  String _resolveAudienceCountryCode() {
    final userCountryCode = _normalizedKnownCountryCode(_user?.countryCode);
    if (userCountryCode != null) {
      return userCountryCode;
    }

    final networkCountryCode =
        _normalizedKnownCountryCode(_networkSuggestedCountryCode);
    if (networkCountryCode != null) {
      return networkCountryCode;
    }

    for (final locale in WidgetsBinding.instance.platformDispatcher.locales) {
      final directCountryCode = _normalizedKnownCountryCode(locale.countryCode);
      if (directCountryCode != null) {
        return directCountryCode;
      }

      final taggedCountryCode = _countryCodeFromLocaleTag(
        locale.toLanguageTag(),
      );
      if (taggedCountryCode != null) {
        return taggedCountryCode;
      }
    }

    return _countryCodeFromLocaleTag(
          WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag(),
        ) ??
        '';
  }

  String _popupDismissKey(int adId) {
    return '${_popupDismissKeyPrefix}_${AppManagerConfig.appSlug}_$adId';
  }

  Future<void> _syncPhoneRequirementProgressForCurrentUser(
    SharedPreferences prefs,
  ) async {
    final user = _user;
    if (user == null) {
      _currentUserLaunchCount = 0;
      return;
    }

    final key = _phoneRequirementBaselineLaunchKeyFor(user.id);
    var baselineLaunchCount = prefs.getInt(key);

    if (baselineLaunchCount == null ||
        baselineLaunchCount < 1 ||
        baselineLaunchCount > _appLaunchCount) {
      baselineLaunchCount = _appLaunchCount;
      await prefs.setInt(key, baselineLaunchCount);
    }

    _currentUserLaunchCount = max(1, _appLaunchCount - baselineLaunchCount + 1);
  }

  String _phoneRequirementBaselineLaunchKeyFor(int userId) {
    return '${_phoneRequirementBaselineLaunchKeyPrefix}_'
        '${AppManagerConfig.appSlug}_$userId';
  }

  String? _normalizedKnownCountryCode(String? rawCode) {
    final normalized = (rawCode ?? '').trim().toUpperCase();
    if (normalized.isEmpty) {
      return null;
    }

    return countryOptionByCode(normalized)?.code;
  }

  String? _countryCodeFromLocaleTag(String? rawTag) {
    final tag = (rawTag ?? '').trim().toUpperCase();
    if (tag.isEmpty) {
      return null;
    }

    final parts = tag
        .split(RegExp(r'[-_]'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    for (final part in parts.skip(1)) {
      if (part.length != 2) {
        continue;
      }

      final code = _normalizedKnownCountryCode(part);
      if (code != null) {
        return code;
      }
    }

    return null;
  }

  List<String> _normalizeFavoriteItems(List<String> items) {
    return items
        .map((item) => item.trim().toUpperCase())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (identical(a, b)) {
      return true;
    }
    if (a.length != b.length) {
      return false;
    }

    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }

    return true;
  }

  bool _isMeaningfulFullName(String value) {
    if (value.trim().length < 3) {
      return false;
    }

    final meaningful =
        value.replaceAll(RegExp(r'[\p{P}\p{S}\s]+', unicode: true), '');
    return meaningful.length >= 2;
  }

  String _friendlyGoogleSignInError(Object error) {
    final raw = error.toString();
    final normalized = raw.toLowerCase();

    if (normalized.contains('apiexception: 10') ||
        normalized.contains('sign_in_failed')) {
      return 'فشل تسجيل الدخول عبر Google لأن إعداد OAuth لهذا التطبيق غير مكتمل أو غير مطابق. '
          'تأكد من أن ملف google-services.json الخاص بالإمارات يحتوي OAuth clients، '
          'وأن SHA-1 وSHA-256 الصحيحين مضافتان في Firebase.';
    }

    return raw;
  }

  String _platformName() {
    if (kIsWeb) {
      return 'web';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return 'unknown';
    }
  }

  String _generateDeviceId() {
    final now = DateTime.now().millisecondsSinceEpoch.toRadixString(16);
    final random = Random().nextInt(0x7fffffff).toRadixString(16);
    return 'dv_${now}_$random';
  }

  String _generateSessionUid() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999).toString().padLeft(6, '0');
    return 'session_${now}_$random';
  }

  Future<void> _clearAuth(SharedPreferences prefs) async {
    _token = null;
    _user = null;
    _currentUserLaunchCount = 0;
    _activeAd = null;
    _remoteUiConfig = RemoteUiConfigModel.empty();
    await prefs.remove(_tokenKey);
  }

  void _setBusy(bool value) {
    _isBusy = value;
    notifyListeners();
  }

  @override
  void dispose() {
    stopAutoRefresh();
    super.dispose();
  }
}
