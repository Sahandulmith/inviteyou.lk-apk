import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  static const String _themeKey = "theme_mode_str";
  ThemeMode _themeMode = ThemeMode.system;

  ThemeProvider() {
    _loadTheme();
  }

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _saveTheme(mode);
    notifyListeners();
  }

  // Maintain toggleTheme for convenience but it will now toggle specifically between light and dark
  void toggleTheme(bool isDark) {
    setThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);
  }

  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeStr = prefs.getString(_themeKey);
    
    if (themeStr == null) {
      // Legacy support for the old bool key
      final isDarkLegacy = prefs.getBool("theme_mode");
      if (isDarkLegacy != null) {
        _themeMode = isDarkLegacy ? ThemeMode.dark : ThemeMode.light;
      } else {
        _themeMode = ThemeMode.system;
      }
    } else {
      switch (themeStr) {
        case "light":
          _themeMode = ThemeMode.light;
          break;
        case "dark":
          _themeMode = ThemeMode.dark;
          break;
        default:
          _themeMode = ThemeMode.system;
      }
    }
    notifyListeners();
  }

  void _saveTheme(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    String themeStr;
    switch (mode) {
      case ThemeMode.light:
        themeStr = "light";
        break;
      case ThemeMode.dark:
        themeStr = "dark";
        break;
      default:
        themeStr = "system";
    }
    await prefs.setString(_themeKey, themeStr);
  }
}

