import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/utils/constants.dart';
import 'providers/app_manager_provider.dart';
import 'screens/splash_screen.dart';
import 'services/push_notification_service.dart';
import 'utils/app_manager_config.dart';
import 'utils/app_lifecycle_refresh.dart';
import 'widgets/app_manager_lifecycle_observer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLifecycleSignals.ensureInitialized();

  await Firebase.initializeApp();
  await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
  await FirebaseAnalytics.instance.setDefaultEventParameters(
    <String, Object?>{
      'managed_app_slug': AppManagerConfig.appSlug,
      'firebase_project_id': Firebase.app().options.projectId,
    },
  );
  await FirebaseAnalytics.instance.setUserProperty(
    name: 'managed_app_slug',
    value: AppManagerConfig.appSlug,
  );
  PushNotificationService.registerBackgroundHandler();

  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static final FirebaseAnalyticsObserver _observer =
      FirebaseAnalyticsObserver(analytics: _analytics);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppManagerProvider>(
      create: (_) => AppManagerProvider()..initialize(),
      child: AppManagerLifecycleObserver(
        child: MaterialApp(
          title: 'مراقب الأسهم المصرية',
          debugShowCheckedModeBanner: false,
          navigatorObservers: <NavigatorObserver>[_observer],
          locale: const Locale('ar', 'EG'),
          supportedLocales: const <Locale>[
            Locale('ar', 'EG'),
            Locale('en', 'US'),
          ],
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: 'Tajawal',
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primaryBlue,
              primary: AppColors.primaryBlue,
              secondary: AppColors.accentGold,
            ),
            scaffoldBackgroundColor: AppColors.scaffold,
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              elevation: 0,
              backgroundColor: Colors.white,
              foregroundColor: AppColors.textPrimary,
            ),
          ),
          builder: (context, child) {
            final appChild = child ?? const SizedBox.shrink();
            return Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: appChild,
              ),
            );
          },
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
