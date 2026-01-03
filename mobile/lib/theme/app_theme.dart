import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTheme with ChangeNotifier {
  static final AppTheme instance = AppTheme._();
  AppTheme._() {
    _loadTheme();
  }

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  final String _key = "theme_mode";

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(_key);
    if (val == 'light') _themeMode = ThemeMode.light;
    else if (val == 'dark') _themeMode = ThemeMode.dark;
    else _themeMode = ThemeMode.system;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    String val = 'system';
    if (mode == ThemeMode.light) val = 'light';
    if (mode == ThemeMode.dark) val = 'dark';
    await prefs.setString(_key, val);
  }

  // GRADIENTS
  static const LinearGradient lightGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFE0C3FC), // Soft Purple
      Color(0xFF8EC5FC), // Soft Blue
      // Color(0xFFFBC2EB), // Soft Pink (Alternative)
    ],
    // Let's try to match the user's "Soft Pink and Purple" request more closely
    // User said: "soft mix of pink and purple gradient"
  );
  
  static const LinearGradient lightGradientPinkPurple = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF3E7E9), // Very Light Pink
      Color(0xFFE3EEFF), // Light Purple/Blue mix
      // Let's use more vibrant distinct pink/purple for the "Liquid" feel
      Color(0xFFE0C3FC), // Purple
      Color(0xFFFBC2EB), // Pink
    ],
    stops: [0.0, 0.4, 0.7, 1.0],
  );

  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF2E1437), // Deep Purple
      Color(0xFF4A192C), // Deep Pink/Red
      // Deep Purple and Soft Pink mix
    ],
  );
}
