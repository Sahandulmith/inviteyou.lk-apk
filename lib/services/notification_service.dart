import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import 'firebase_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Background handler — called by FCM when app is TERMINATED or in BACKGROUND.
// Must be a top-level function annotated with @pragma('vm:entry-point').
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if not already done in this isolate
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    if (!e.toString().contains('duplicate-app')) {
      debugPrint('Firebase background init error: $e');
    }
  }

  // Show the notification via flutter_local_notifications
  final FlutterLocalNotificationsPlugin localNotifications =
      FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initSettings =
      InitializationSettings(android: androidSettings);
  await localNotifications.initialize(initSettings);

  final notification = message.notification;
  final data = message.data;

  final String title =
      notification?.title ?? data['title'] ?? 'Wedding Update';
  final String body =
      notification?.body ?? data['body'] ?? 'New update received';

  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'rsvp_channel',
    'Wedding Notifications',
    channelDescription: 'Real-time wedding event notifications',
    importance: Importance.max,
    priority: Priority.high,
    color: Color(0xFF9C7B6E),
    enableVibration: true,
    playSound: true,
    styleInformation: BigTextStyleInformation(''),
  );
  const NotificationDetails details = NotificationDetails(android: androidDetails);

  await localNotifications.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    body,
    details,
    payload: jsonEncode(data),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// NotificationService — singleton, handles FCM setup + local notifications
// ─────────────────────────────────────────────────────────────────────────────
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // ── 1. Local notifications setup ──────────────────────────────────────
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels up-front so they exist before any message arrives
    await _createNotificationChannels();

    // Request POST_NOTIFICATIONS permission (Android 13+)
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    // ── 2. FCM setup ──────────────────────────────────────────────────────

    // Register background message handler (MUST be called before any other FCM call)
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Request FCM permission
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Save/update the FCM token to Firestore so Cloud Functions can reach this device
    try {
      final String? token = await messaging.getToken();
      if (token != null) {
        debugPrint('FCM Token: $token');
        await FirebaseService().saveAdminToken(token);
      }
    } catch (e) {
      debugPrint('Failed to get or save FCM token during initialization: $e');
    }

    // Refresh token handler
    messaging.onTokenRefresh.listen((newToken) {
      debugPrint('FCM Token refreshed: $newToken');
      FirebaseService().saveAdminToken(newToken);
    });

    // ── 3. Foreground message handler ─────────────────────────────────────
    // When the app is OPEN, FCM does NOT show a heads-up automatically on Android.
    // We handle it here with flutter_local_notifications.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('FCM foreground message: ${message.messageId}');
      _showFcmNotification(message);
    });

    // ── 4. App opened from a TERMINATED state via notification tap ─────────
    final RemoteMessage? initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageTap(initialMessage.data);
    }

    // ── 5. App brought to foreground from BACKGROUND via notification tap ──
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleMessageTap(message.data);
    });
  }

  // Create all channels so Android knows about them before first notification
  Future<void> _createNotificationChannels() async {
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'rsvp_channel',
        'Wedding Notifications',
        description: 'RSVP and wedding event notifications',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );

    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'guest_channel',
        'Guest Notifications',
        description: 'New guest addition notifications',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );
  }

  // Show notification for foreground FCM message
  Future<void> _showFcmNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    final String title =
        notification?.title ?? data['title'] ?? 'Wedding Update';
    final String body =
        notification?.body ?? data['body'] ?? 'New update received';

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'rsvp_channel',
      'Wedding Notifications',
      importance: Importance.max,
      priority: Priority.high,
      color: Color(0xFF9C7B6E),
      enableVibration: true,
      playSound: true,
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(''),
    );
    const NotificationDetails details =
        NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: jsonEncode(data),
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        _handleMessageTap(data);
      } catch (e) {
        debugPrint('Notification payload parse error: $e');
      }
    }
  }

  void _handleMessageTap(Map<String, dynamic> data) {
    debugPrint('Notification tapped — data: $data');
    // Navigation logic can be added here if needed
  }

  // ── Manual local notification helpers (for in-app use if ever needed) ────

  Future<void> showRsvpNotification({
    required String guestName,
    required String status,
    String? message,
  }) async {
    final bool isAttending = status == 'Attending';
    final String emoji = isAttending ? '🎉' : '😔';
    final String statusText =
        isAttending ? 'will attend!' : 'declined the invitation';

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'rsvp_channel',
      'Wedding Notifications',
      channelDescription: 'RSVP and wedding event notifications',
      importance: Importance.max,
      priority: Priority.high,
      color: const Color(0xFF9C7B6E),
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      enableVibration: true,
      playSound: true,
      styleInformation: BigTextStyleInformation(
        message != null && message.isNotEmpty
            ? '$emoji $guestName $statusText!\n💬 "$message"'
            : '$emoji $guestName $statusText!',
        contentTitle: 'New RSVP Response',
        summaryText: 'Wedding Dashboard',
      ),
    );

    final NotificationDetails details =
        NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'New RSVP: $guestName',
      '$emoji $guestName $statusText',
      details,
      payload: jsonEncode(
          {'guestName': guestName, 'status': status, 'type': 'rsvp'}),
    );
  }

  Future<void> showNewUserRequestNotification({
    required String email,
    required String role,
  }) async {
    final String nameOnly = email.split('@')[0];
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'rsvp_channel',
      'Wedding Notifications',
      importance: Importance.max,
      priority: Priority.max,
      color: const Color(0xFF9C7B6E),
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      enableVibration: true,
      playSound: true,
      styleInformation: BigTextStyleInformation(
        '$nameOnly ($role) has requested dashboard access.',
        contentTitle: 'New Approval Request 💍',
        summaryText: 'Wedding Dashboard',
      ),
    );

    final NotificationDetails details =
        NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000 + 1,
      'New Approval Request 💍',
      '$nameOnly wants access as $role',
      details,
      payload: jsonEncode({'email': email, 'role': role, 'type': 'user_request'}),
    );
  }

  Future<void> showNewGuestNotification({
    required String guestName,
    required String side,
    required String addedByEmail,
    required String addedByRole,
  }) async {
    final String nameOnly = addedByEmail.split('@')[0];
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'guest_channel',
      'Guest Notifications',
      channelDescription: 'New guest addition notifications',
      importance: Importance.high,
      priority: Priority.high,
      color: const Color(0xFF9C7B6E),
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      enableVibration: true,
      playSound: true,
      styleInformation: BigTextStyleInformation(
        'A new guest "$guestName" has been added to the $side side by $nameOnly ($addedByRole).',
        contentTitle: 'New Guest Added 👤',
        summaryText: 'Wedding Dashboard',
      ),
    );

    final NotificationDetails details =
        NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000 + 2,
      'New Guest Added 👤',
      '$guestName added to $side side',
      details,
      payload: jsonEncode(
          {'guestName': guestName, 'side': side, 'type': 'new_guest'}),
    );
  }

  Future<void> showStatsNotification({
    required int total,
    required int attending,
    required int pending,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'rsvp_channel',
      'Wedding Notifications',
      channelDescription: 'RSVP and wedding event notifications',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      color: Color(0xFF9C7B6E),
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      0,
      'Wedding Dashboard Stats',
      '👥 $total total • ✅ $attending attending • ⏳ $pending pending',
      details,
    );
  }
}
