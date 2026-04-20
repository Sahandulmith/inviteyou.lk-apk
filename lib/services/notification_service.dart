import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `Firebase.initializeApp()` first.
  debugPrint("Handling a background message: ${message.messageId}");
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions on Android 13+ and iOS
    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    // --- Firebase Cloud Messaging (Push Notifications) ---
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Get the FCM token and save to DB
    String? token = await messaging.getToken();
    if (token != null) {
      await FirebaseService().saveAdminToken(token);
    }

    // Update token whenever it refreshes
    messaging.onTokenRefresh.listen((newToken) {
      FirebaseService().saveAdminToken(newToken);
    });

    // Listen to messages while app is in FOREGROUND
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        // Show as a local notification since we're in the foreground
        _showForegroundFcm(message.notification!);
      }
    });
  }

  Future<void> _showForegroundFcm(RemoteNotification notification) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'push_channel',
      'Push Notifications',
      importance: Importance.high,
      priority: Priority.high,
      color: Color(0xFF9C7B6E),
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      notification.title,
      notification.body,
      details,
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap - navigate to guests screen
    debugPrint('Notification tapped: ${response.payload}');
  }

  Future<void> showRsvpNotification({
    required String guestName,
    required String status,
    String? message,
  }) async {
    final bool isAttending = status == 'Attending';
    final String emoji = isAttending ? '🎉' : '😔';
    final String statusText = isAttending ? 'will attend!' : 'declined the invitation';

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'rsvp_channel',
      'RSVP Notifications',
      channelDescription: 'Notifications for guest RSVPs',
      importance: Importance.high,
      priority: Priority.high,
      color: const Color(0xFF9C7B6E),
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(
        message != null && message.isNotEmpty
            ? '$emoji $guestName $statusText!\n💬 "$message"'
            : '$emoji $guestName $statusText!',
        contentTitle: 'New RSVP Response',
        summaryText: 'Wedding Dashboard',
      ),
      enableVibration: true,
      playSound: true,
    );

    final NotificationDetails details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'New RSVP: $guestName',
      '$emoji $guestName $statusText',
      details,
      payload: jsonEncode({'guestName': guestName, 'status': status}),
    );
  }

  Future<void> showStatsNotification({
    required int total,
    required int attending,
    required int pending,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'stats_channel',
      'Stats Notifications',
      channelDescription: 'Wedding stats updates',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      color: Color(0xFF9C7B6E),
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      0,
      'Wedding Dashboard Update',
      '👥 $total total • ✅ $attending attending • ⏳ $pending pending',
      details,
    );
  }

  Future<void> showNewUserRequestNotification({
    required String email,
    required String role,
  }) async {
    final String nameOnly = email.split('@')[0];
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'rsvp_channel', // Use the same channel to ensure high priority consistency
      'Wedding Notifications',
      channelDescription: 'Notifications for wedding events and admin requests',
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

    final NotificationDetails details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000 + 1, // Unique ID
      'New Approval Request 💍',
      '$nameOnly wants access as $role',
      details,
    );
  }

  Future<void> showNewGuestNotification({
    required String guestName,
    required String side,
    required String addedByEmail,
    required String addedByRole,
  }) async {
    final String nameOnly = addedByEmail.split('@')[0];
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'guest_channel',
      'Guest Notifications',
      channelDescription: 'Notifications for new guest additions',
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

    final NotificationDetails details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000 + 2,
      'New Guest Added 👤',
      '$guestName added to $side side',
      details,
    );
  }
}
