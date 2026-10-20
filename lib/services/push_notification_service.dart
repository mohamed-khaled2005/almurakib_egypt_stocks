import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushNotificationService {
  PushNotificationService._();

  static const AndroidNotificationChannel _defaultAndroidChannel =
      AndroidNotificationChannel(
    'default_channel',
    'General Notifications',
    description: 'General app notifications',
    importance: Importance.high,
    playSound: true,
  );

  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _listenersBound = false;
  bool _localNotificationsReady = false;
  String? _cachedToken;
  Future<void>? _initializationFuture;

  static void registerBackgroundHandler() {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  Future<void> initialize() {
    if (_initialized || kIsWeb) {
      _initialized = true;
      return Future<void>.value();
    }

    final inFlight = _initializationFuture;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _initializeInternal();
    _initializationFuture = future;
    return future;
  }

  Future<void> _initializeInternal() async {
    try {
      if (defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS) {
        _initialized = true;
        return;
      }

      await _initializeLocalNotifications();

      final permission = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
      );

      if (kDebugMode) {
        debugPrint(
          'FCM permission status: ${permission.authorizationStatus.name}',
        );
      }

      await _requestAndroidNotificationPermission();
      await _messaging.setAutoInitEnabled(true);
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      await _waitForApnsTokenIfNeeded();
      _cachedToken ??= await _fetchTokenWithTimeout();
      _printToken();
      await _bindListeners();
      _initialized = true;
    } finally {
      if (_initialized) {
        _initializationFuture = Future<void>.value();
      } else {
        _initializationFuture = null;
      }
    }
  }

  Future<String?> getToken() async {
    if (!_initialized) {
      await initialize();
    }

    _cachedToken ??= await _fetchTokenWithTimeout();
    _printToken();
    return _cachedToken;
  }

  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  Future<void> _initializeLocalNotifications() async {
    if (_localNotificationsReady || kIsWeb) return;

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _localNotifications.initialize(settings);

    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_defaultAndroidChannel);

    _localNotificationsReady = true;
  }

  Future<void> _requestAndroidNotificationPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android ||
        !_localNotificationsReady) {
      return;
    }

    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
  }

  Future<void> _waitForApnsTokenIfNeeded() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;

    for (var attempt = 0; attempt < 12; attempt++) {
      final apnsToken = await _messaging.getAPNSToken();
      if (apnsToken != null && apnsToken.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('APNs Token: $apnsToken');
        }
        return;
      }

      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<void> _bindListeners() async {
    if (_listenersBound) return;
    _listenersBound = true;

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (kDebugMode) {
        debugPrint(
          'FCM onMessageOpenedApp id=${message.messageId ?? "-"} data=${message.data}',
        );
      }
    });

    final initialMessage = await _messaging.getInitialMessage().timeout(
          const Duration(seconds: 3),
          onTimeout: () => null,
        );
    if (initialMessage != null && kDebugMode) {
      debugPrint(
        'FCM initialMessage id=${initialMessage.messageId ?? "-"} data=${initialMessage.data}',
      );
    }
  }

  Future<String?> _fetchTokenWithTimeout() {
    return _messaging.getToken().timeout(
          const Duration(seconds: 4),
          onTimeout: () => null,
        );
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (!_localNotificationsReady ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    final title = (message.notification?.title ?? message.data['title'] ?? '')
        .toString()
        .trim();
    final body = (message.notification?.body ?? message.data['body'] ?? '')
        .toString()
        .trim();

    if (title.isEmpty && body.isEmpty) return;

    await _localNotifications.show(
      message.messageId?.hashCode ??
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _defaultAndroidChannel.id,
          _defaultAndroidChannel.name,
          channelDescription: _defaultAndroidChannel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
        ),
      ),
    );
  }

  Future<void> showLocalAlert({
    required String title,
    required String body,
    int? id,
  }) async {
    if (!_localNotificationsReady) return;
    try {
      final notificationId = id ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
      await _localNotifications.show(
        notificationId,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _defaultAndroidChannel.id,
            _defaultAndroidChannel.name,
            channelDescription: _defaultAndroidChannel.description,
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            playSound: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to show local notification: $e');
      }
    }
  }

  void _printToken() {
    if (!kDebugMode) return;

    final token = _cachedToken?.trim();
    if (token == null || token.isEmpty) {
      debugPrint('FCM Token is empty.');
      return;
    }

    debugPrint('FCM Token: $token');
  }
}
