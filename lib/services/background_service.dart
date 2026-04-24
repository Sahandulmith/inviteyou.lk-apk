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
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'Wedding Dashboard Active',
        initialNotificationContent: 'Monitoring for new RSVPs...',
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
      service.setAsForegroundService();
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
      debugPrint('Background Service: Initialized successfully');
    } catch (e) {
      debugPrint('Background Init Error: $e');
    }

    final prefs = await SharedPreferences.getInstance();

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // --- Listen to Firestore for Real-time Notifications ---
    
    // 1. Listen for RSVPs (Both added and modified)
    FirebaseFirestore.instance
        .collection('wedding_guests')
        .snapshots()
        .listen((snapshot) async {
      debugPrint('Background Service: Received guest update');
      for (var change in snapshot.docChanges) {
        // We handle added (initial load or new guest) and modified (status change)
        if (change.type == DocumentChangeType.modified || change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data == null) continue;

          final String docId = change.doc.id;
          final String status = data['status'] ?? '';
          final String rsvpDate = data['rsvpDate'] ?? '';
          final String guestName = data['name'] ?? 'Guest';

          // Check if this is an RSVP update we haven't notified about
          final String lastNotifiedKey = 'notified_rsvp_$docId';
          final String lastStatusKey = 'last_status_$docId';
          
          await prefs.reload(); // Ensure we have latest data
          final String? lastStatus = prefs.getString(lastStatusKey);
          final String? lastNotifiedDate = prefs.getString(lastNotifiedKey);

          // Notify if:
          // 1. There is an RSVP date
          // 2. Status is not 'Invited'
          // 3. Status has changed OR it's a new rsvpDate we haven't seen
          if (rsvpDate.isNotEmpty && status != 'Invited') {
            if (status != lastStatus || rsvpDate != lastNotifiedDate) {
              debugPrint('Background Service: Showing RSVP notification for $guestName');
              await NotificationService().showRsvpNotification(
                guestName: guestName,
                status: status,
                message: data['rsvpMessage'],
              );
              
              // Save state to prevent repeat notifications
              await prefs.setString(lastStatusKey, status);
              await prefs.setString(lastNotifiedKey, rsvpDate);
            }
          }
        }
      }
    }, onError: (e) {
      debugPrint('Background Service Firestore Error: $e');
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
            debugPrint('Background Service: Showing User Request notification for $email');
            await NotificationService().showNewUserRequestNotification(
              email: email,
              role: role,
            );
            await prefs.setBool(lastNotifiedKey, true);
          }
        }
      }
    });

    // Periodic Update (Optional)
    Timer.periodic(const Duration(minutes: 5), (timer) async {
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          service.setForegroundNotificationInfo(
            title: "Wedding Dashboard Sync",
            content: "Last sync: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
          );
        }
      }
    });
  }
}
