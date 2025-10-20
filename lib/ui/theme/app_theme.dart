import 'package:flutter/material.dart';

class AppTheme {
  // Light Theme Colors
  static const _lightPrimary = Color(0xFF6750A4);
  static const _lightPrimaryContainer = Color(0xFFEADDFF);
  static const _lightSecondary = Color(0xFF625B71);
  static const _lightSecondaryContainer = Color(0xFFE8DEF8);
  static const _lightBackground = Color(0xFFF7F7FC);
  static const _lightSurface = Color(0xFFFFFFFF);
  static const _lightError = Color(0xFFB3261E);
  static const _lightOnPrimary = Color(0xFFFFFFFF);
  static const _lightOnSecondary = Color(0xFFFFFFFF);
  static const _lightOnSurface = Color(0xFF1C1B1F);
  static const _lightOnError = Color(0xFFFFFFFF);

  // Dark Theme Colors
  static const _darkPrimary = Color(0xFFD0BCFF);
  static const _darkPrimaryContainer = Color(0xFF4F378B);
  static const _darkSecondary = Color(0xFFCCC2DC);
  static const _darkSecondaryContainer = Color(0xFF4A4458);
  static const _darkBackground = Color(0xFF1C1B1F);
  static const _darkSurface = Color(0xFF1C1B1F);
  static const _darkSurfaceVariant = Color(0xFF2B2930);
  static const _darkError = Color(0xFFF2B8B5);
  static const _darkOnPrimary = Color(0xFF381E72);
  static const _darkOnSecondary = Color(0xFF332D41);
  static const _darkOnSurface = Color(0xFFE6E1E5);
  static const _darkOnError = Color(0xFF601410);

  // Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: _lightPrimary,
        primaryContainer: _lightPrimaryContainer,
        secondary: _lightSecondary,
        secondaryContainer: _lightSecondaryContainer,
        surface: _lightSurface,
        error: _lightError,
        onPrimary: _lightOnPrimary,
        onSecondary: _lightOnSecondary,
        onSurface: _lightOnSurface,
        onError: _lightOnError,
      ),
      scaffoldBackgroundColor: _lightBackground,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: _lightSurface,
        foregroundColor: _lightOnSurface,
        iconTheme: IconThemeData(color: _lightPrimary),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: InputBorder.none,
        filled: false,
        hintStyle: TextStyle(color: Colors.grey[400]),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: _lightPrimary,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
      ),
      dividerColor: Colors.grey[300],
      // Ensure minimum touch targets
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }

  // Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: _darkPrimary,
        primaryContainer: _darkPrimaryContainer,
        secondary: _darkSecondary,
        secondaryContainer: _darkSecondaryContainer,
        surface: _darkSurface,
        error: _darkError,
        onPrimary: _darkOnPrimary,
        onSecondary: _darkOnSecondary,
        onSurface: _darkOnSurface,
        onError: _darkOnError,
      ),
      scaffoldBackgroundColor: _darkBackground,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: _darkSurface,
        foregroundColor: _darkOnSurface,
        iconTheme: IconThemeData(color: _darkPrimary),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: _darkSurfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: InputBorder.none,
        filled: false,
        hintStyle: TextStyle(color: Colors.grey[600]),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: _darkPrimary,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
        backgroundColor: _darkSurface,
      ),
      dividerColor: Colors.grey[800],
      drawerTheme: const DrawerThemeData(backgroundColor: _darkSurface),
      dialogTheme: const DialogThemeData(backgroundColor: _darkSurfaceVariant),
      // Ensure minimum touch targets
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}

/// Extension methods on ThemeData to provide custom colors
/// Usage: Theme.of(context).ticketOpenBackground
extension AppThemeExtension on ThemeData {
  // Chat-specific colors
  Color get userBubbleColor {
    return brightness == Brightness.light
        ? const Color(0xFF6750A4)
        : const Color(0xFF4F378B);
  }

  Color get assistantBubbleColor {
    return brightness == Brightness.light
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF2B2930);
  }

  Color get userBubbleTextColor {
    return brightness == Brightness.light
        ? const Color(0xFFFFFFFF)
        : const Color(0xFFE6E1E5);
  }

  Color get assistantBubbleTextColor {
    return colorScheme.onSurface;
  }

  Color get inputBackgroundColor {
    return brightness == Brightness.light
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF2B2930);
  }

  Color get chatBackgroundColor {
    return brightness == Brightness.light
        ? const Color(0xFFF7F7FC)
        : const Color(0xFF1C1B1F);
  }

  Color get selectedTileColor {
    return brightness == Brightness.light
        ? const Color(0xFFEADDFF).withValues(alpha: 0.5)
        : const Color(0xFF4F378B).withValues(alpha: 0.3);
  }

  Color get drawerHeaderColor {
    return brightness == Brightness.light
        ? const Color(0xFFEADDFF).withValues(alpha: 0.3)
        : const Color(0xFF4F378B).withValues(alpha: 0.2);
  }

  // Ticket Status Colors
  Color get ticketOpenBackground {
    return brightness == Brightness.light
        ? const Color(0xFFE3F2FD) // Light blue
        : const Color(
            0xFF1565C0,
          ).withValues(alpha: 0.3); // Dark blue with opacity
  }

  Color get ticketOpenText {
    return brightness == Brightness.light
        ? const Color(0xFF1565C0) // Blue 800
        : const Color(0xFF90CAF9); // Light blue 300
  }

  Color get ticketResolvedBackground {
    return brightness == Brightness.light
        ? const Color(0xFFE8F5E9) // Light green
        : const Color(
            0xFF2E7D32,
          ).withValues(alpha: 0.3); // Dark green with opacity
  }

  Color get ticketResolvedText {
    return brightness == Brightness.light
        ? const Color(0xFF2E7D32) // Green 800
        : const Color(0xFF81C784); // Light green 300
  }

  Color get ticketClosedBackground {
    return brightness == Brightness.light
        ? const Color(0xFFF5F5F5) // Grey 100
        : colorScheme.surfaceContainerHighest;
  }

  Color get ticketClosedText {
    return colorScheme.onSurface.withValues(alpha: 0.7);
  }
}
