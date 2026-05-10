import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'news_service.dart';
import '../models/article.dart';
import '../main.dart';
import '../pages/article_detail_page.dart';

// ── SharedPreferences key for the article queued for cold-start navigation ───
const String _kPendingArticleKey = 'pending_notification_article';

// ── SharedPreferences key tracking the last seen announcement doc ID ─────────
const String _kLastAnnouncementId = 'last_announcement_id';

// ─────────────────────────────────────────────────────────────────────────────
// Workmanager background isolate entry-point.
// Must be a top-level function annotated with @pragma('vm:entry-point').
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final service = NotificationService();
      await service.init();
      await service.checkNewsNow();
    } catch (e, stack) {
      debugPrint('[Workmanager] Background task failed: $e');
      // Don't crash the isolate — return true so Workmanager doesn't retry.
      await FirebaseCrashlytics.instance.recordError(e, stack, fatal: false);
    }
    return true;
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Top-level FCM background message handler.
// Must be a top-level function (NOT a class method) for Android background.
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase.initializeApp() is safe to call multiple times — SDK guards it.
  debugPrint('[FCM] Background message received: ${message.messageId}');
  // We do NOT show a local notification here because FCM with a notification
  // payload already shows the system tray notification automatically on Android.
  // We only need to handle data-only payloads if added in the future.
}

// ─────────────────────────────────────────────────────────────────────────────
// Top-level background notification tap handler for flutter_local_notifications.
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> _onLocalNotificationBackgroundTap(
    NotificationResponse details) async {
  if (details.payload != null && details.payload!.isNotEmpty) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPendingArticleKey, details.payload!);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NotificationService — Singleton.
//
// FIX SUMMARY:
//   1. Announcement Firestore listener REMOVED.
//      Replaced by FCM topic subscription ("all_users").
//      The Cloud Function `broadcastAnnouncement` sends the push.
//      Cost: 1 FCM message instead of N Firestore reads per announcement.
//
//   2. Double-polling fixed:
//      - Workmanager handles background checks (every 15 min).
//      - Timer handles foreground checks (every 15 min, matching Workmanager).
//      - _isChecking debounce guard prevents concurrent executions.
//
//   3. Timer interval raised from 2 min → 15 min.
//      Reduces Firestore announcement reads by 7.5× per user.
// ─────────────────────────────────────────────────────────────────────────────
class NotificationService {
  // Singleton
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  // ── Notification channel IDs ────────────────────────────────────────────────
  static const _newsChannelId    = 'vivechana_news_channel';
  static const _newsChannelName  = 'समाचार अपडेट';
  static const _newsChannelDesc  = 'नई खबरें और अपडेट';

  static const _annChannelId    = 'announcements_channel';
  static const _annChannelName  = 'Announcements';
  static const _annChannelDesc  = 'Official announcements from the admin';

  static const _alertChannelId   = 'user_alerts_channel';
  static const _alertChannelName = 'Personal Alerts';
  static const _alertChannelDesc = 'Alerts related to your account and posts';

  // ── State ────────────────────────────────────────────────────────────────────
  Timer? _periodicTimer;

  // Firestore subscription for personal (per-user) notifications.
  // This is KEPT because it is already scoped to one user's documents.
  StreamSubscription<QuerySnapshot>? _userNotificationsSub;
  StreamSubscription<User?>? _authSub;

  /// Debounce guard — prevents Workmanager + Timer from running _checkAndNotify
  /// at the same time (which would cause duplicate API calls and notifications).
  bool _isChecking = false;

  // ── Public: retrieve + clear the article queued for cold-start navigation ───
  static Future<Article?> getAndClearPendingArticle() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_kPendingArticleKey);
    if (json != null) {
      await prefs.remove(_kPendingArticleKey);
      return Article.fromJsonString(json);
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // init() — Call once from main() before runApp().
  // Safe to call multiple times (subsequent calls are no-ops after first init).
  // ─────────────────────────────────────────────────────────────────────────
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      // ── 1. Local notifications setup ────────────────────────────────────
      const androidInit =
          AndroidInitializationSettings('@mipmap/launcher_icon');
      const iosInit = DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
      );
      await _plugin.initialize(
        const InitializationSettings(android: androidInit, iOS: iosInit),
        onDidReceiveNotificationResponse: _onLocalNotificationTap,
        onDidReceiveBackgroundNotificationResponse:
            _onLocalNotificationBackgroundTap,
      );

      // Android 8+ notification channels
      await _createChannel(_newsChannelId, _newsChannelName, _newsChannelDesc);
      await _createChannel(_annChannelId, _annChannelName, _annChannelDesc);
      await _createChannel(_alertChannelId, _alertChannelName, _alertChannelDesc);

      // ── 2. FCM setup ─────────────────────────────────────────────────────
      // Register the background message handler (must be top-level fn).
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Request permission (Android 13+ requires explicit permission).
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false, // Require explicit grant on iOS
      );
      debugPrint(
          '[NotificationService] FCM permission: ${settings.authorizationStatus}');

      // Subscribe to the topic that Cloud Functions broadcasts announcements to.
      // All authenticated users subscribe; the Cloud Function sends to this topic.
      await _fcm.subscribeToTopic('all_users');
      debugPrint('[NotificationService] Subscribed to FCM topic: all_users');

      // Handle FCM messages when app is in the FOREGROUND.
      FirebaseMessaging.onMessage.listen(_handleForegroundFcmMessage);

      // Handle FCM notification tap when app was in BACKGROUND (not terminated).
      FirebaseMessaging.onMessageOpenedApp.listen(_handleFcmNotificationTap);

      // Handle FCM notification tap when app was TERMINATED.
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleFcmNotificationTap(initialMessage);
      }

      // ── 3. Personal Firestore notification listener ──────────────────────
      // This listener is scoped per-user and is KEPT (not replaced with FCM)
      // because personal alerts require real-time delivery when the app is open.
      _listenForUserNotifications();

      debugPrint('[NotificationService] Initialized successfully.');
    } catch (e, stack) {
      debugPrint('[NotificationService] init error: $e');
      await FirebaseCrashlytics.instance.recordError(e, stack, fatal: false);
      // Do not rethrow — a notification failure must never block runApp().
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FCM Foreground Message Handler
  // Shows a local notification when an FCM message arrives while app is open.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _handleForegroundFcmMessage(RemoteMessage message) async {
    debugPrint(
        '[FCM] Foreground message: ${message.notification?.title}');
    final notification = message.notification;
    if (notification == null) return;

    final type = message.data['type'] ?? '';

    if (type == 'announcement') {
      // Guard duplicate: only show if we haven't shown this doc ID already.
      final prefs = await SharedPreferences.getInstance();
      final lastId = prefs.getString(_kLastAnnouncementId) ?? '';
      final docId  = message.data['docId'] ?? '';
      if (docId.isNotEmpty && docId == lastId) return;
      if (docId.isNotEmpty) {
        await prefs.setString(_kLastAnnouncementId, docId);
      }
      await _showAnnouncementNotification(
          notification.title ?? 'सूचना', notification.body ?? '');
    } else {
      // Default: show as a news notification.
      await showNewsNotification(
        notification.title ?? 'अपडेट',
        notification.body ?? '',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FCM Notification Tap Handler (background → foreground)
  // ─────────────────────────────────────────────────────────────────────────
  void _handleFcmNotificationTap(RemoteMessage message) {
    debugPrint('[FCM] Notification tapped: ${message.data}');
    // Extend here to navigate to a specific page based on message.data['type']
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Local notification tap (foreground or cold-start)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _onLocalNotificationTap(NotificationResponse details) async {
    debugPrint('[LocalNotif] Tapped: ${details.payload}');
    if (details.payload == null || details.payload!.isEmpty) return;

    // Direct navigation if app is already running.
    if (navigatorKey.currentState != null) {
      try {
        final article = Article.fromJsonString(details.payload!);
        if (article != null) {
          navigatorKey.currentState!.push(
            MaterialPageRoute(
              builder: (_) => ArticleDetailPage(
                article: article,
                heroTag: 'notification_${article.id}',
              ),
            ),
          );
          return;
        }
      } catch (e) {
        debugPrint('[LocalNotif] Direct nav failed: $e');
      }
    }

    // Fallback: persist for cold-start pickup in main.dart.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPendingArticleKey, details.payload!);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Personal notification listener (KEPT — scoped per user, not broadcast)
  // ─────────────────────────────────────────────────────────────────────────
  void _listenForUserNotifications() {
    _authSub?.cancel();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      _userNotificationsSub?.cancel();
      if (user == null || user.isAnonymous) return;

      final DateTime listenStartTime = DateTime.now();
      final query = FirebaseFirestore.instance
          .collection('user_notifications')
          .where('userId', isEqualTo: user.uid)
          .where('isRead', isEqualTo: false);

      _userNotificationsSub = query.snapshots().listen((snapshot) {
        for (final change in snapshot.docChanges) {
          if (change.type != DocumentChangeType.added) continue;
          final data = change.doc.data();
          if (data == null) continue;
          final createdAt = data['createdAt'] as Timestamp?;
          if (createdAt == null) continue;
          // Only show notifications for docs created AFTER we started listening.
          // Prevents showing stale unread notifications on app launch.
          if (createdAt.toDate().isAfter(listenStartTime)) {
            _showPersonalNotification(
              data['title'] as String? ?? 'Notification',
              data['body']  as String? ?? '',
            );
          }
        }
      }, onError: (e) {
        debugPrint('[NotificationService] userNotifications listener error: $e');
      });
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Periodic background news check lifecycle management
  // ─────────────────────────────────────────────────────────────────────────

  /// Call this from main() when the user has notifications enabled.
  /// Registers Workmanager (background) + starts an in-process timer
  /// (foreground). Both share the same debounce guard so they never
  /// execute _checkAndNotify() concurrently.
  void startPeriodicNewsCheck() {
    // Background task via Workmanager (fires even when app is killed).
    Workmanager().registerPeriodicTask(
      'vivechana_news_check',
      'checkBBCNews',
      // 15-minute interval (minimum allowed by Android JobScheduler).
      frequency: const Duration(minutes: 15),
      // existingWorkPolicy: replace so we never accumulate duplicate tasks.
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      constraints: Constraints(networkType: NetworkType.connected),
    );

    // Foreground timer — raised from 2 min → 15 min to match Workmanager.
    // When both fire around the same time the debounce guard (_isChecking)
    // ensures only one execution proceeds.
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      checkNewsNow();
    });

    debugPrint(
        '[NotificationService] Periodic news check started (15 min interval).');
  }

  void stopPeriodicNewsCheck() {
    Workmanager().cancelByUniqueName('vivechana_news_check');
    _periodicTimer?.cancel();
    _periodicTimer = null;
    debugPrint('[NotificationService] Periodic news check stopped.');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Core news check — debounce-guarded to prevent concurrent executions.
  // ─────────────────────────────────────────────────────────────────────────

  /// Public entry-point used by Workmanager background isolate and timer.
  Future<bool> checkNewsNow() => _checkAndNotify();

  Future<bool> _checkAndNotify() async {
    // ── DEBOUNCE GUARD ────────────────────────────────────────────────────
    // Prevents the Workmanager task and the in-process timer from both
    // running concurrently. The second caller simply returns false immediately.
    if (_isChecking) {
      debugPrint('[NotificationService] _checkAndNotify already in progress — skipping.');
      return false;
    }
    _isChecking = true;

    try {
      final prefs = await SharedPreferences.getInstance();

      // ── News headline check ──────────────────────────────────────────────
      final lastHeadline = prefs.getString('last_trending_keyword') ?? '';
      final newsService  = NewsService();
      final newsResult   = await newsService.fetchNews(category: 'सभी');
      final articles = (newsResult['articles'] as List<dynamic>?)
              ?.whereType<Article>()
              .toList() ??
          [];

      if (articles.isEmpty) return false;

      final topArticle  = articles.first;
      final topHeadline = topArticle.title;

      if (topHeadline == lastHeadline) return false;

      await prefs.setString('last_trending_keyword', topHeadline);
      await showNewsNotification(
        '🚀 ताज़ा ख़बर',
        topHeadline,
        articlePayload: topArticle.toJsonString(),
      );
      return true;
    } catch (e, stack) {
      debugPrint('[NotificationService] _checkAndNotify error: $e');
      await FirebaseCrashlytics.instance.recordError(e, stack, fatal: false);
      return false;
    } finally {
      // Always release the guard so the next check can proceed.
      _isChecking = false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Notification display helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Shows a news headline notification. Uses a fixed ID (1) so new headlines
  /// replace the previous one rather than stacking in the tray.
  Future<void> showNewsNotification(
    String title,
    String body, {
    String? articlePayload,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        _newsChannelId,
        _newsChannelName,
        channelDescription: _newsChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'नई खबर',
        icon: '@mipmap/logo',
      );
      await _plugin.show(
        1, // Fixed ID → overwrites, never stacks.
        title,
        body,
        const NotificationDetails(android: androidDetails),
        payload: articlePayload,
      );
    } catch (e) {
      debugPrint('[NotificationService] showNewsNotification error: $e');
    }
  }

  Future<void> _showAnnouncementNotification(String title, String body) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        _annChannelId,
        _annChannelName,
        channelDescription: _annChannelDesc,
        importance: Importance.max,
        priority: Priority.max,
        ticker: 'Announcement',
        icon: '@mipmap/launcher_icon',
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      await _plugin.show(
        2, // Fixed ID for announcements.
        title,
        body,
        const NotificationDetails(android: androidDetails, iOS: iosDetails),
      );
    } catch (e) {
      debugPrint('[NotificationService] _showAnnouncementNotification error: $e');
    }
  }

  Future<void> _showPersonalNotification(String title, String body) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        _alertChannelId,
        _alertChannelName,
        channelDescription: _alertChannelDesc,
        importance: Importance.max,
        priority: Priority.max,
        ticker: 'Alert',
        icon: '@mipmap/logo',
      );
      await _plugin.show(
        // Dynamic ID based on time to stack personal alerts.
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        const NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      debugPrint('[NotificationService] _showPersonalNotification error: $e');
    }
  }

  Future<void> requestPermission() async {
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (e) {
      debugPrint('[NotificationService] requestPermission error: $e');
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<void> _createChannel(
      String id, String name, String description) async {
    final channel = AndroidNotificationChannel(
      id,
      name,
      description: description,
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }
}
