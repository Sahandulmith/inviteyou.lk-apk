import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
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

  // Check for saved session
  final prefs = await SharedPreferences.getInstance();
  final String? userJson = prefs.getString('currentUser');
  Map<String, dynamic>? initialUser;
  if (userJson != null) {
    try {
      initialUser = jsonDecode(userJson);
    } catch (e) {
      debugPrint('Error decoding saved user: $e');
    }
  }

  runApp(WeddingApp(initialUser: initialUser));
}

class WeddingApp extends StatelessWidget {
  final Map<String, dynamic>? initialUser;
  const WeddingApp({super.key, this.initialUser});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kalana & Chanchala Wedding',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: initialUser != null 
          ? DashboardScreen(currentUser: initialUser!) 
          : const LoginScreen(),
    );
  }
}
