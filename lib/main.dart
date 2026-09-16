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

void _dismissKeyboard() {
  FocusManager.instance.primaryFocus?.unfocus();
  SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
}

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

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static final FirebaseAnalyticsObserver _observer =
      FirebaseAnalyticsObserver(analytics: _analytics);

  late final ThemeData _lightTheme;

  @override
  void initState() {
    super.initState();
    _lightTheme = _buildTheme(Brightness.light);
  }

  static ThemeData _buildTheme(Brightness brightness) {
    final background = AppColors.backgroundFor(brightness);
    final card = AppColors.cardFor(brightness);
    final cardSoft = AppColors.cardSoftFor(brightness);
    final border = AppColors.borderFor(brightness);
    final textPrimary = AppColors.textPrimaryFor(brightness);
    final textSecondary = AppColors.textSecondaryFor(brightness);
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Tajawal',
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryBlue,
        brightness: brightness,
      ).copyWith(
        primary: AppColors.primaryBlue,
        secondary: isDark ? AppColors.lightBlue : AppColors.darkBlue,
        surface: card,
        surfaceContainerHighest: cardSoft,
        onSurface: textPrimary,
        onSurfaceVariant: textSecondary,
        outline: border,
      ),
      scaffoldBackgroundColor: background,
      cardColor: card,
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border),
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        modalBackgroundColor: card,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(
        color: border,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppManagerProvider>(
          create: (_) => AppManagerProvider()..initialize(),
        ),
      ],
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
          theme: _lightTheme,
          builder: (context, child) {
            final appChild = child ?? const SizedBox.shrink();
            return Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => _dismissKeyboard(),
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