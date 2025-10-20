import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class ThemeService {
  static const String _themeKey = 'theme_mode';

  /// Save theme mode to local storage
  Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.name);
  }

  /// Load theme mode from local storage
  /// Returns ThemeMode.system as default if not set
  Future<ThemeMode> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString(_themeKey);

    if (themeName == null) {
      return ThemeMode.system;
    }

    switch (themeName) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  /// Clear theme preference (reset to system default)
  Future<void> clearThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_themeKey);
  }
}
