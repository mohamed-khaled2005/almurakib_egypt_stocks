import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/favorites_service.dart';
import '../providers/app_manager_provider.dart';
import '../services/push_notification_service.dart';

class AppManagerLifecycleObserver extends StatefulWidget {
  const AppManagerLifecycleObserver({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<AppManagerLifecycleObserver> createState() =>
      _AppManagerLifecycleObserverState();
}

class _AppManagerLifecycleObserverState
    extends State<AppManagerLifecycleObserver> with WidgetsBindingObserver {
  StreamSubscription<String>? _tokenRefreshSub;
  AppManagerProvider? _manager;
  bool _updatingLocalFavorites = false;
  bool _lastAuthState = false;
  String _lastRemoteFavoritesSignature = '';
  String _lastLocalFavoritesSignature = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _tokenRefreshSub?.cancel();
    FavoritesService.favoritesNotifier.removeListener(_handleLocalFavorites);
    _manager?.removeListener(_handleManagerChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final manager = _manager;
    if (manager == null) return;

    if (state == AppLifecycleState.resumed) {
      manager.startSessionIfNeeded(forceRestart: true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      manager.endSession();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;

  Future<void> _bootstrap() async {
    if (!mounted) return;

    await FavoritesService.init();
    if (!mounted) return;

    final manager = context.read<AppManagerProvider>();
    _manager = manager;
    _lastAuthState = manager.isAuthenticated;
    manager.addListener(_handleManagerChanged);
    FavoritesService.favoritesNotifier.addListener(_handleLocalFavorites);

    unawaited(_bootstrapPushToken(manager));
    await _syncManagerFavoritesToLocal(force: true);
  }

  Future<void> _bootstrapPushToken(AppManagerProvider manager) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final onboardingCompleted =
          prefs.getBool('onboarding_completed') ?? false;
      if (!onboardingCompleted) {
        return;
      }

      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;

      await _bindPushToken(manager);
    } catch (_) {
      // Notification bootstrap should not block the app.
    }
  }

  Future<void> _bindPushToken(AppManagerProvider manager) async {
    try {
      await PushNotificationService.instance.initialize().timeout(
            const Duration(seconds: 6),
          );
      if (!mounted) return;

      final token = await PushNotificationService.instance.getToken().timeout(
            const Duration(seconds: 4),
            onTimeout: () => null,
          );
      if (token != null && token.isNotEmpty) {
        await manager.registerPushToken(token);
      }

      _tokenRefreshSub?.cancel();
      _tokenRefreshSub =
          PushNotificationService.instance.onTokenRefresh.listen((newToken) {
        if (kDebugMode && newToken.trim().isNotEmpty) {
          debugPrint('FCM Token refreshed: $newToken');
        }
        manager.registerPushToken(newToken);
      });
    } catch (_) {
      // Notification bootstrap should not block the app.
    }
  }

  void _handleManagerChanged() {
    final manager = _manager;
    if (manager == null) return;

    final remoteSignature = _signature(manager.preferences.favoriteItems);
    if (remoteSignature != _lastRemoteFavoritesSignature) {
      _lastRemoteFavoritesSignature = remoteSignature;
      unawaited(_syncManagerFavoritesToLocal());
    }

    if (manager.isAuthenticated && !_lastAuthState) {
      unawaited(manager.syncPushToken());
    }

    _lastAuthState = manager.isAuthenticated;
  }

  void _handleLocalFavorites() {
    final manager = _manager;
    if (manager == null || _updatingLocalFavorites) return;

    final items = FavoritesService.favoritesNotifier.value.toList()..sort();
    final localSignature = _signature(items);
    if (localSignature == _lastLocalFavoritesSignature) return;

    _lastLocalFavoritesSignature = localSignature;
    unawaited(
      manager.replaceFavoriteItems(
        items,
        pushRemote: manager.isAuthenticated,
      ),
    );
  }

  Future<void> _syncManagerFavoritesToLocal({bool force = false}) async {
    final manager = _manager;
    if (manager == null) return;

    final remote = List<String>.from(manager.preferences.favoriteItems)..sort();
    final remoteSignature = _signature(remote);
    final local = FavoritesService.favoritesNotifier.value.toList()..sort();
    final localSignature = _signature(local);

    if (!force && remoteSignature == localSignature) return;

    _updatingLocalFavorites = true;
    try {
      await FavoritesService.overwriteFavorites(remote);
      _lastRemoteFavoritesSignature = remoteSignature;
      _lastLocalFavoritesSignature = remoteSignature;
    } finally {
      _updatingLocalFavorites = false;
    }
  }

  String _signature(Iterable<String> values) {
    final sorted = values.map((item) => item.trim().toUpperCase()).toList()
      ..sort();
    return sorted.join('|');
  }
}
