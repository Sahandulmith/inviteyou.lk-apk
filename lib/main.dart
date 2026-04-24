import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/background_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization warning: $e');
  }
  
  // Initialize notifications
  await NotificationService().initialize();

  // Initialize background service
  await AppBackgroundService.initialize();

  runApp(const WeddingApp());
}

class WeddingApp extends StatelessWidget {
  const WeddingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kalana & Chanchala Wedding',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const SplashScreen(),
    );
  }
}
