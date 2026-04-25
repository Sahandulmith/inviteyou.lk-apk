import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../firebase_options.dart';
import 'notification_service.dart';

class AppBackgroundService {
  static const String notificationChannelId = 'background_service_channel';
  static const int notificationId = 888;

  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    // Create the notification channel for the foreground service
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      notificationChannelId,
      'Wedding Sync Service',
      description: 'Maintains real-time wedding updates',
      importance: Importance.high, // Increased importance
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: false, // This removes the persistent notification
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'Wedding Dashboard',
        initialNotificationContent: 'Monitoring updates in background',
        foregroundServiceNotificationId: notificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
    
    // Explicitly start the service
    await service.startService();
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    if (service is AndroidServiceInstance) {
      // service.setAsForegroundService(); // Disabled to hide persistent notification
    }

    // Initialize Firebase in the background process
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      
      // Initialize notifications for the background isolate
      await NotificationService().initialize();
      
      // Notify user that sync is starting (Optional: only if you want a temporary notification)
      /* 
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "Wedding Dashboard Sync",
          content: "Service started. Monitoring for updates...",
        );
      }
      */
      
      debugPrint('Background Service: Initialized successfully in separate process');
    } catch (e) {
      debugPrint('Background Init Error: $e');
    }

    final prefs = await SharedPreferences.getInstance();

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        // service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // --- Listen to Firestore with robust error handling ---
    void setupListeners() {
      // 1. Listen for RSVPs
      FirebaseFirestore.instance
          .collection('wedding_guests')
          .snapshots()
          .listen((snapshot) async {
        debugPrint('Background Service: Received guest update from Firestore');
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.modified || change.type == DocumentChangeType.added) {
            final data = change.doc.data();
            if (data == null) continue;

            final String docId = change.doc.id;
            final String status = data['status'] ?? '';
            final String rsvpDate = data['rsvpDate'] ?? '';
            final String guestName = data['name'] ?? 'Guest';

            final String lastNotifiedKey = 'notified_rsvp_$docId';
            final String lastStatusKey = 'last_status_$docId';
            
            await prefs.reload();
            final String? lastStatus = prefs.getString(lastStatusKey);
            final String? lastNotifiedDate = prefs.getString(lastNotifiedKey);

            if (rsvpDate.isNotEmpty && status != 'Invited') {
              if (status != lastStatus || rsvpDate != lastNotifiedDate) {
                debugPrint('Background Service: TRIGGERING RSVP notification for $guestName');
                await NotificationService().showRsvpNotification(
                  guestName: guestName,
                  status: status,
                  message: data['rsvpMessage'],
                );
                
                await prefs.setString(lastStatusKey, status);
                await prefs.setString(lastNotifiedKey, rsvpDate);
              }
            }
          }
        }
      }, onError: (e) {
        debugPrint('Background Service Firestore Error: $e');
        // Retry after delay
        Future.delayed(const Duration(seconds: 10), () => setupListeners());
      });

      // 2. Listen for new Approval Requests
      FirebaseFirestore.instance
          .collection('dashboard_users')
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .listen((snapshot) async {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data();
            if (data == null) continue;

            final String email = data['email'] ?? '';
            final String role = data['role'] ?? 'User';
            final String docId = change.doc.id;

            final String lastNotifiedKey = 'notified_user_$docId';
            await prefs.reload();
            if (!prefs.containsKey(lastNotifiedKey)) {
              debugPrint('Background Service: TRIGGERING User Request notification for $email');
              await NotificationService().showNewUserRequestNotification(
                email: email,
                role: role,
              );
              await prefs.setBool(lastNotifiedKey, true);
            }
          }
        }
      }, onError: (e) {
        debugPrint('Background Service User Listener Error: $e');
      });
    }

    // Start listeners
    setupListeners();

    // Periodic Keep-Alive (Silent)
    Timer.periodic(const Duration(minutes: 15), (timer) async {
      debugPrint('Background Service: Keep-alive check at ${DateTime.now()}');
    });
  }
}
