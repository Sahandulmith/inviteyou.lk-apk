import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/firebase_service.dart';
import 'login_screen.dart';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';

import 'package:firebase_messaging/firebase_messaging.dart';

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  const ProfileScreen({super.key, required this.currentUser});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseService _firebase = FirebaseService();
  final TextEditingController _urlCtrl = TextEditingController();
  StreamSubscription<String>? _urlSub;

  @override
  void initState() {
    super.initState();
    _urlSub = _firebase.baseUrlStream().listen((url) {
      if (mounted) _urlCtrl.text = url;
    });
  }

  @override
  void dispose() {
    _urlSub?.cancel();
    _urlCtrl.dispose();
    super.dispose();
  }
  
  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('currentUser');

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _confirmDeleteUser(Map<String, dynamic> user) {
    if (user['id'] == widget.currentUser['uid']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You cannot delete your own account!")),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove User'),
        content: Text('Are you sure you want to remove access for ${user['email']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await _firebase.deleteUser(user['id']);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.declined),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isPrimary = widget.currentUser['isPrimary'] == true;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          _buildUserInfoCard(),
          const SizedBox(height: 24),
          _buildSectionHeader('Notification Settings'),
          const SizedBox(height: 12),
          _buildFcmStatusCard(),
          const SizedBox(height: 24),
          _buildSectionHeader('Display Settings'),
          const SizedBox(height: 12),
          _buildThemeToggle(),
          const SizedBox(height: 24),
          if (isPrimary) ...[
            _buildSectionHeader('Global Invitation Link'),
            const SizedBox(height: 12),
            _buildUrlEditor(),
            const SizedBox(height: 24),
            _buildSectionHeader('User Management'),
            const SizedBox(height: 12),
            _buildUsersList(),
            const SizedBox(height: 24),
          ],
          _buildSectionHeader('Account Actions'),
          const SizedBox(height: 12),
          _buildLogoutButton(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildUserInfoCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [AppTheme.textDark, Colors.blueGrey.shade800],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: AppTheme.gold.withOpacity(0.2),
              child: const Icon(Icons.person, size: 40, color: AppTheme.gold),
            ),
            const SizedBox(height: 16),
            Text(
              widget.currentUser['email'].toString().split('@')[0].toUpperCase(),
              style: GoogleFonts.playfairDisplay(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.currentUser['role'] ?? 'Admin',
              style: GoogleFonts.inter(color: AppTheme.gold, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white24),
            const SizedBox(height: 16),
            _infoRow(Icons.email_outlined, widget.currentUser['email'] ?? ''),
            _infoRow(
              Icons.verified_user_outlined, 
              widget.currentUser['isPrimary'] == true ? 'Primary Account' : 'Secondary Account'
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUrlEditor() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _urlCtrl,
              decoration: const InputDecoration(
                labelText: 'Invitation Base URL',
                hintText: 'https://your-domain.com',
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.language),
                label: const Text('Update Domain'),
                onPressed: () async {
                  await _firebase.updateBaseUrl(_urlCtrl.text.trim());
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invitation link domain updated! 🌐')),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFcmStatusCard() {
    return FutureBuilder<NotificationSettings>(
      future: FirebaseMessaging.instance.getNotificationSettings(),
      builder: (context, snapshot) {
        final status = snapshot.data?.authorizationStatus;
        final bool granted = status == AuthorizationStatus.authorized ||
            status == AuthorizationStatus.provisional;

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (granted ? AppTheme.attending : AppTheme.declined)
                        .withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    granted
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_off_rounded,
                    color: granted ? AppTheme.attending : AppTheme.declined,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Push Notifications (FCM)',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        granted
                            ? 'Active — alerts arrive even when app is closed'
                            : 'Disabled — enable in device Settings',
                        style: TextStyle(
                          fontSize: 12,
                          color: granted
                              ? AppTheme.attending
                              : AppTheme.declined,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  granted ? Icons.check_circle_rounded : Icons.warning_rounded,
                  color: granted ? AppTheme.attending : AppTheme.declined,
                  size: 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThemeToggle() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isEffectiveDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  themeProvider.themeMode == ThemeMode.system
                      ? Icons.brightness_auto_rounded
                      : (themeProvider.themeMode == ThemeMode.dark
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded),
                  color: isEffectiveDark ? AppTheme.gold : AppTheme.rosePrimary,
                ),
                const SizedBox(width: 12),
                const Text('App Appearance', style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isEffectiveDark ? AppTheme.gold : AppTheme.rosePrimary).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    themeProvider.themeMode == ThemeMode.system
                        ? 'System'
                        : (themeProvider.themeMode == ThemeMode.dark ? 'Dark' : 'Light'),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isEffectiveDark ? AppTheme.gold : AppTheme.rosePrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.system,
                    label: Text('System'),
                    icon: Icon(Icons.settings_suggest_rounded, size: 18),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.light,
                    label: Text('Light'),
                    icon: Icon(Icons.light_mode_rounded, size: 18),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.dark,
                    label: Text('Dark'),
                    icon: Icon(Icons.dark_mode_rounded, size: 18),
                  ),
                ],
                selected: {themeProvider.themeMode},
                onSelectionChanged: (Set<ThemeMode> newSelection) {
                  themeProvider.setThemeMode(newSelection.first);
                },
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: isEffectiveDark ? AppTheme.gold : AppTheme.rosePrimary,
                  selectedForegroundColor: isEffectiveDark ? Colors.black : Colors.white,
                  side: BorderSide(color: AppTheme.rosePrimary.withOpacity(0.1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.playfairDisplay(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).textTheme.titleLarge?.color,
      ),
    );
  }

  Widget _buildUsersList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _firebase.allUsersStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final users = snapshot.data!;
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: users.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final user = users[index];
              final bool isME = user['id'] == widget.currentUser['uid'];
              final bool otherPrimary = user['isPrimary'] == true && !isME;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: user['role'] == 'Groom'
                      ? AppTheme.groomBlue.withOpacity(0.12)
                      : AppTheme.bridePink.withOpacity(0.12),
                  child: Icon(
                    user['role'] == 'Groom' ? Icons.man : Icons.woman,
                    size: 20,
                    color: user['role'] == 'Groom'
                        ? AppTheme.groomBlue
                        : AppTheme.bridePink,
                  ),
                ),
                title: Text(user['email'].toString().split('@')[0]),
                subtitle: Text('${user['role']} • ${user['status']}'),
                trailing: isME 
                  ? const Badge(label: Text('ME'), backgroundColor: Colors.blue)
                  : (otherPrimary 
                      ? const Icon(Icons.star, color: AppTheme.gold, size: 18)
                      : IconButton(
                          icon: const Icon(Icons.person_remove_outlined, color: AppTheme.declined),
                          onPressed: () => _confirmDeleteUser(user),
                        )
                    ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildLogoutButton() {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.declined.withOpacity(0.1),
        foregroundColor: AppTheme.declined,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: const Icon(Icons.logout_rounded),
      label: const Text('Logout Session', style: TextStyle(fontWeight: FontWeight.bold)),
      onPressed: _logout,
    );
  }
}
