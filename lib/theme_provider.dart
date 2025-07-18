import 'package:flutter/material.dart';

import 'data_utili.dart';
 // Ensure this file contains AppPreferences with save/loadThemeMode

class ThemeController extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  ThemeController() {
    _loadTheme(); // Load the theme when the controller is initialized
  }

  Future<void> _loadTheme() async {
    _mode = await AppPreferences.loadThemeMode();
    notifyListeners();
  }

  void setTheme(ThemeMode newMode) {
    if (newMode != _mode) {
      _mode = newMode;
      AppPreferences.saveThemeMode(newMode); // Persist the theme change
      notifyListeners();
    }
  }
}


class ThemeScope extends InheritedWidget {
  final ThemeMode mode;

  const ThemeScope({super.key,
    required this.mode,
    required super.child,
  });

  static ThemeMode of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeScope>()!.mode;

  @override
  bool updateShouldNotify(ThemeScope old) => old.mode != mode;
}
