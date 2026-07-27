import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide settings, persisted and reactive via ChangeNotifier so
/// MaterialApp can rebuild its theme/text scale live without adding a
/// state-management package. Instantiate once and pass down; call
/// [load] before runApp so the first frame already has saved prefs.
class AppSettings extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  double _fontScale = 1.0;
  bool _loaded = false;

  ThemeMode get themeMode => _themeMode;
  double get fontScale => _fontScale;
  bool get loaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final storedTheme = prefs.getString('settings_theme_mode');
    _themeMode = switch (storedTheme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    _fontScale = prefs.getDouble('settings_font_scale') ?? 1.0;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('settings_theme_mode', switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
  }

  Future<void> setFontScale(double scale) async {
    _fontScale = scale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('settings_font_scale', scale);
  }
}

/// Single app-wide instance. Simple top-level singleton — avoids pulling
/// in Provider/Riverpod purely to broadcast theme changes.
final AppSettings appSettings = AppSettings();
