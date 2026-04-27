import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ota_update/ota_update.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'dashboard_screen.dart';
import 'login_screen.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  String _status = "Initializing...";
  double _progress = 0;
  bool _isUpdating = false;
  late AnimationController _heartController;
  late Animation<double> _heartAnimation;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    
    _heartAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _heartController, curve: Curves.easeInOut),
    );

    _initializeApp();
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      int currentBuildNumber = int.parse(packageInfo.buildNumber);
      String currentVersion = packageInfo.version;

      setState(() => _status = "Checking for updates...");

      var doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('versioning')
          .get();

      if (doc.exists) {
        final data = doc.data();
        int latestBuildNumber = int.parse(data?['latest_build_number']?.toString() ?? "0");
        String latestVersion = data?['latest_version']?.toString() ?? "1.0.0";
        String downloadUrl = data?['download_url']?.toString() ?? "";

        bool hasUpdate = latestBuildNumber > currentBuildNumber || 
                        _isVersionNewer(latestVersion, currentVersion);

        if (hasUpdate && downloadUrl.isNotEmpty) {
          _showUpdateDialog(latestVersion, downloadUrl);
          return;
        }
      }
    } catch (e) {
      debugPrint("Update check failed: $e");
    }

    final elapsed = stopwatch.elapsedMilliseconds;
    if (elapsed < 3500) {
      await Future.delayed(Duration(milliseconds: 3500 - elapsed));
    }
    
    _proceedToApp();
  }

  bool _isVersionNewer(String latest, String current) {
    try {
      List<int> latestParts = latest.split('.').map((e) => int.parse(e.replaceAll(RegExp(r'[^0-9]'), ''))).toList();
      List<int> currentParts = current.split('.').map((e) => int.parse(e.replaceAll(RegExp(r'[^0-9]'), ''))).toList();
      
      for (int i = 0; i < latestParts.length && i < currentParts.length; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      return latestParts.length > currentParts.length;
    } catch (e) {
      return latest != current;
    }
  }

  void _showUpdateDialog(String version, String url) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text("Update Available", style: GoogleFonts.inter(color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : const Color(0xFF003366), fontWeight: FontWeight.bold)),
        content: Text("A new version ($version) is available. Would you like to update now?", style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => _proceedToApp(),
            child: Text("Later", style: GoogleFonts.inter(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : const Color(0xFF003366),
              foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _startUpdate(url);
            },
            child: Text("Update Now", style: GoogleFonts.inter()),
          ),
        ],
      ),
    );
  }

  Future<void> _startUpdate(String url) async {
    setState(() {
      _isUpdating = true;
      _status = "Preparing update...";
    });

    try {
      if (await Permission.requestInstallPackages.request().isDenied) {
        _showError("You must allow 'Install Unknown Apps' in Settings to update.");
        return;
      }

      _status = "Connecting to server...";

      OtaUpdate().execute(url).listen(
        (OtaEvent event) {
          setState(() {
            switch (event.status) {
              case OtaStatus.DOWNLOADING:
                _status = "Downloading: ${event.value}%";
                _progress = double.parse(event.value!) / 100;
                break;
              case OtaStatus.INSTALLING:
                _status = "Installing...";
                _progress = 1.0;
                break;
              default:
                _status = "Processing...";
                break;
            }
          });
        },
        onError: (e) {
          _showError("Update Step Error: $e");
        },
      );
    } catch (e) {
      _showError("Critical Error: $e");
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _isUpdating = false;
      _status = message;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter()),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: "CONTINUE",
          textColor: Colors.white,
          onPressed: () => _proceedToApp(),
        ),
        duration: const Duration(seconds: 10),
      ),
    );
  }

  Future<void> _proceedToApp() async {
    setState(() => _status = "Launching...");
    
    final prefs = await SharedPreferences.getInstance();
    final String? userJson = prefs.getString('currentUser');
    Map<String, dynamic>? currentUser;
    
    if (userJson != null) {
      try {
        currentUser = jsonDecode(userJson);
      } catch (e) {
        debugPrint('Error decoding saved user: $e');
      }
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => currentUser != null 
            ? DashboardScreen(currentUser: currentUser!) 
            : const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 1000),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF003366),
              Color(0xFF001F3F),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _heartAnimation,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withOpacity(0.2),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                    border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.4), width: 1.5),
                  ),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.favorite,
                      color: Color(0xFFFFD700),
                      size: 100,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 50),
              Text(
                "InviteYou.lk",
                style: GoogleFonts.greatVibes(
                  color: const Color(0xFFFFD700),
                  fontSize: 42,
                  letterSpacing: 2,
                ),
              ),
              Text(
                "MANAGEMENT APP",
                style: GoogleFonts.inter(
                  color: Colors.white60,
                  fontSize: 12,
                  letterSpacing: 5,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 70),
              if (_isUpdating)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 60),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: _progress,
                          minHeight: 4,
                          backgroundColor: Colors.white10,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              Text(
                _status.toUpperCase(),
                style: GoogleFonts.inter(
                  color: Colors.white, 
                  fontSize: 11, 
                  letterSpacing: 3,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 40),
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Text(
                      "VERSION ${snapshot.data!.version}",
                      style: GoogleFonts.inter(color: Colors.white24, fontSize: 10, letterSpacing: 2),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
