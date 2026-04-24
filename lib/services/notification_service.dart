import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    
    // Show notification even if app is terminated
    if (message.notification != null || message.data.isNotEmpty) {
      final notification = message.notification;
      final data = message.data;
      
      final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();
      
      const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initSettings = InitializationSettings(android: androidSettings);
      await localNotifications.initialize(initSettings);

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'push_channel',
        'Push Notifications',
        importance: Importance.max,
        priority: Priority.high,
        color: Color(0xFF9C7B6E),
        styleInformation: BigTextStyleInformation(''),
      );
      const NotificationDetails details = NotificationDetails(android: androidDetails);

      await localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        notification?.title ?? data['title'] ?? 'Wedding Update',
        notification?.body ?? data['body'] ?? 'New message received',
        details,
        payload: jsonEncode(data),
      );
    }
  } catch (e) {
    debugPrint("Error in background handler: $e");
  }
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

    // Request permissions on Android 13+
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
        _showForegroundFcm(message.notification!, message.data);
      } else if (message.data.isNotEmpty) {
        // Handle data-only messages in foreground
        _showDataFcm(message.data);
      }
    });
    
    // Handle message if app was opened from a terminated state
    RemoteMessage? initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageTap(initialMessage.data);
    }

    // Handle message if app is in background but not terminated
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleMessageTap(message.data);
    });
  }

  Future<void> _showForegroundFcm(RemoteNotification notification, Map<String, dynamic> data) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'push_channel',
      'Push Notifications',
      importance: Importance.max,
      priority: Priority.high,
      color: Color(0xFF9C7B6E),
      styleInformation: BigTextStyleInformation(''),
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      notification.title,
      notification.body,
      details,
      payload: jsonEncode(data),
    );
  }

  Future<void> _showDataFcm(Map<String, dynamic> data) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'push_channel',
      'Push Notifications',
      importance: Importance.max,
      priority: Priority.high,
      color: Color(0xFF9C7B6E),
      styleInformation: BigTextStyleInformation(''),
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      data['title'] ?? 'Wedding Update',
      data['body'] ?? 'New message received',
      details,
      payload: jsonEncode(data),
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!);
        _handleMessageTap(data);
      } catch (e) {
        debugPrint('Error parsing notification payload: $e');
      }
    }
  }

  void _handleMessageTap(Map<String, dynamic> data) {
    debugPrint('Notification tapped with data: $data');
    // Navigation logic can be added here if needed
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
      payload: jsonEncode({'guestName': guestName, 'status': status, 'type': 'rsvp'}),
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
      'rsvp_channel',
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
      payload: jsonEncode({'guestName': guestName, 'side': side, 'type': 'new_guest'}),
    );
  }
}

