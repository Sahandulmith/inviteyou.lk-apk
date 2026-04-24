import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ota_update/ota_update.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dashboard_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _status = "Initializing...";
  double _progress = 0;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // 1. Get current version
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      int currentBuildNumber = int.parse(packageInfo.buildNumber);
      String currentVersion = packageInfo.version;

      setState(() => _status = "Checking for updates...");

      // 2. Fetch latest version from Firestore
      // Assume collection 'app_config' and document 'versioning'
      var doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('versioning')
          .get();

      if (doc.exists) {
        final data = doc.data();
        int latestBuildNumber = int.parse(data?['latest_build_number']?.toString() ?? "0");
        String latestVersion = data?['latest_version']?.toString() ?? "1.0.0";
        String downloadUrl = data?['download_url']?.toString() ?? "";

        // Check if build number is higher OR if version string is different
        // (Best practice is to always increment build number, but this is safer)
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
      return latest != current; // Fallback to simple inequality
    }
  }

  void _showUpdateDialog(String version, String url) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Update Available", style: TextStyle(color: Color(0xFF003366), fontWeight: FontWeight.bold)),
        content: Text("A new version ($version) is available. Would you like to update now?"),
        actions: [
          TextButton(
            onPressed: () => _proceedToApp(),
            child: const Text("Later", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF003366)),
            onPressed: () {
              Navigator.pop(context);
              _startUpdate(url);
            },
            child: const Text("Update Now"),
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
      // 1. Explicitly check for Install Permission (Android 13 requirement)
      if (await Permission.requestInstallPackages.request().isDenied) {
        _showError("You must allow 'Install Unknown Apps' in Settings to update.");
        return;
      }

      _status = "Connecting to server...";

      // 2. Execute update without a custom filename (safer)
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
                // Give the user 2 seconds to read the message before the installer takes over
                Future.delayed(const Duration(seconds: 2), () {
                  // The installer will now close the app
                });
                break;
              case OtaStatus.ALREADY_RUNNING_ERROR:
                _status = "Update already running";
                break;
              case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
                _showError("Permission Denied: Go to Settings > Apps > Special Access > Install Unknown Apps and enable it for this app.");
                break;
              case OtaStatus.DOWNLOAD_ERROR:
                _showError("Download Failed: Check your internet or GitHub link.");
                break;
              case OtaStatus.INTERNAL_ERROR:
                _showError("Internal Error: Try again later.");
                break;
              default:
                _status = "Processing: ${event.status}";
                break;
            }
          });
        },
        onError: (e) {
          debugPrint('OTA Update Error: $e');
          _showError("Update Step Error: $e");
        },
      );
    } catch (e) {
      debugPrint('Failed to start update: $e');
      _showError("Critical Error: $e");
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _isUpdating = false;
      _status = message; // Show the error plainly as the status
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
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
      MaterialPageRoute(
        builder: (context) => currentUser != null 
            ? DashboardScreen(currentUser: currentUser!) 
            : const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF003366), // Sapphire Blue
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo or Icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFD700), width: 2), // Gold
              ),
              child: const Icon(
                Icons.favorite,
                color: Color(0xFFFFD700), // Gold
                size: 80,
              ),
            ),
            const SizedBox(height: 30),
            // const Text(
            //   "Kalana & Chanchala",
            //   style: TextStyle(
            //     color: Color(0xFFFFD700),
            //     fontSize: 24,
            //     fontWeight: FontWeight.bold,
            //     letterSpacing: 2,
            //   ),
            // ),
            const Text(
              "Wedding Invitation",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 50),
            if (_isUpdating)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            Text(
              _status,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 20),
            // Current version display
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Text(
                    "Version ${snapshot.data!.version}+${snapshot.data!.buildNumber}",
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  );
                }
                return const SizedBox();
              },
            ),
          ],
        ),
      ),
    );
  }
}
