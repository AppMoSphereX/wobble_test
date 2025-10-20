import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/services.dart';
import '../../data/services/theme_service.dart';

/// Provider for managing theme mode state
final themeModeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier(ref.read(themeServiceProvider));
});

/// Theme notifier that manages theme mode and persists to storage
class ThemeNotifier extends StateNotifier<ThemeMode> {
  final ThemeService _themeService;

  ThemeNotifier(this._themeService) : super(ThemeMode.system) {
    _loadTheme();
  }

  /// Load saved theme from storage on initialization
  Future<void> _loadTheme() async {
    final savedTheme = await _themeService.loadThemeMode();
    state = savedTheme;
  }

  /// Set theme to light mode
  Future<void> setLightMode() async {
    state = ThemeMode.light;
    await _themeService.saveThemeMode(ThemeMode.light);
  }

  /// Set theme to dark mode
  Future<void> setDarkMode() async {
    state = ThemeMode.dark;
    await _themeService.saveThemeMode(ThemeMode.dark);
  }

  /// Set theme to system default (follows device settings)
  Future<void> setSystemMode() async {
    state = ThemeMode.system;
    await _themeService.saveThemeMode(ThemeMode.system);
  }

  /// Toggle between light and dark (skip system)
  Future<void> toggleTheme() async {
    if (state == ThemeMode.light) {
      await setDarkMode();
    } else {
      await setLightMode();
    }
  }

  /// Get human-readable theme mode name
  String get themeModeName {
    switch (state) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  /// Get icon for current theme mode
  IconData get themeModeIcon {
    switch (state) {
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
      case ThemeMode.system:
        return Icons.brightness_auto;
    }
  }
}

