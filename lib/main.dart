import 'dart:ui' show PlatformDispatcher;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'constants/app_colors.dart';
import 'constants/app_theme.dart';
import 'pages/splash_screen_page.dart';
import 'pages/login_page.dart';
import 'pages/article_detail_page.dart';
import 'pages/onboarding_page.dart';
import 'services/auth_service.dart';
import 'services/force_update_service.dart';
import 'services/notification_service.dart';
import 'package:workmanager/workmanager.dart';
import 'widgets/connectivity_wrapper.dart';
import 'providers/theme_provider.dart';

final ValueNotifier<double> globalTextScale = ValueNotifier<double>(1.0);
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize Firebase FIRST
  // Use try-catch because Android's FirebaseInitProvider auto-inits Firebase
  // natively before Flutter starts, so apps.isEmpty on Dart side is unreliable.
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "YOUR_API_KEY_HERE",
        authDomain: "YOUR_AUTH_DOMAIN_HERE",
        projectId: "YOUR_PROJECT_ID_HERE",
        storageBucket: "YOUR_STORAGE_BUCKET_HERE",
        messagingSenderId: "YOUR_MESSAGING_SENDER_ID_HERE",
        appId: "YOUR_APP_ID_HERE",
        measurementId: "YOUR_MEASUREMENT_ID_HERE",
      ),
    );
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
    debugPrint('[Firebase] Already initialized by native layer, skipping.');
  }

  // ✅ Crashlytics - Flutter framework errors (NON-FATAL)
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    FirebaseCrashlytics.instance.recordFlutterError(details);
  };

  // ✅ Crashlytics - Async errors (FATAL)
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Initialize services
  await NotificationService().init();
  Workmanager().initialize(callbackDispatcher);

  final prefs = await SharedPreferences.getInstance();
  globalTextScale.value = prefs.getDouble('text_scale') ?? 1.0;
  final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;

  if (notificationsEnabled) {
    NotificationService().startPeriodicNewsCheck();
  }

  final isFirstTime = prefs.getBool('is_first_time') ?? true;

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: VivechanaOJ(isFirstTime: isFirstTime),
    ),
  );
}

class VivechanaOJ extends StatelessWidget {
  final bool isFirstTime;
  const VivechanaOJ({super.key, required this.isFirstTime});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return ValueListenableBuilder<double>(
      valueListenable: globalTextScale,
      builder: (context, scale, child) {
        return MaterialApp(
          title: 'VIVECHANA OJ',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          navigatorKey: navigatorKey,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
            Locale('hi'),
          ],
          builder: (context, widget) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
              ),
              child: ConnectivityWrapper(child: widget!),
            );
          },
          home: isFirstTime ? const OnboardingPage() : const AuthWrapper(),
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  final ForceUpdateService _forceUpdateService = ForceUpdateService();
  bool _updateDialogShown = false;

  DateTime? _lastUpdateCheck;
  static const Duration _updateCheckCooldown = Duration(minutes: 10);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkForUpdate();
      await _handlePendingNotification();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      if (_lastUpdateCheck == null ||
          now.difference(_lastUpdateCheck!) > _updateCheckCooldown) {
        _checkForUpdate();
      }
    }
  }

  Future<void> _checkForUpdate() async {
    if (!mounted) return;
    _lastUpdateCheck = DateTime.now();

    try {
      final result = await _forceUpdateService.checkForUpdate();

      if (result.updateRequired && !_updateDialogShown && mounted) {
        _updateDialogShown = true;
        _showUpdateDialog(result.playStoreUrl);
      }
    } catch (e, stack) {
      debugPrint('[UpdateError] $e');
      FirebaseCrashlytics.instance.recordError(e, stack);
    }
  }

  void _showUpdateDialog(String url) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: const Icon(Icons.system_update_rounded,
              size: 48, color: AppColors.primaryRed),
          title: const Text('ऐप अपडेट करें',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text(
            'बेहतर अनुभव और नई सुविधाओं के लिए ऐप का नया वर्ज़न उपलब्ध है। कृपया ऐप को अपडेट करें।',
            textAlign: TextAlign.center,
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri,
                      mode: LaunchMode.externalApplication);
                }
              },
              child: const Text('Update Now'),
            ),
          ],
        ),
      ),
    ).then((_) => _updateDialogShown = false);
  }

  Future<void> _handlePendingNotification() async {
    final article =
        await NotificationService.getAndClearPendingArticle();

    if (article != null && mounted) {
      await Future.delayed(const Duration(milliseconds: 500));

      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => ArticleDetailPage(
          article: article,
          heroTag: 'notification_${article.id}',
        ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const SplashScreenPage();
        }

        return const LoginPage();
      },
    );
  }
}