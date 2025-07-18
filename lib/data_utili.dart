import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  static const _keyDisallowedPackages = 'disallowed_packages';
  static const _keyAppTheme = 'app_theme_mode';
  static Future<void> saveDisallowedPackages(Set<String> packages) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyDisallowedPackages, packages.toList());
  }

  static Future<Set<String>> loadDisallowedPackages() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyDisallowedPackages)?.toSet() ?? {};
  }

  // === Theme Mode ===
  static Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAppTheme, mode.name); // saves 'system', 'light', or 'dark'
  }

  static Future<ThemeMode> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyAppTheme);

    switch (saved) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
}
