import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_settings.dart';

/// Singleton controller that owns the current [GameSettings] and persists
/// every change to SharedPreferences so settings survive app restarts.
class SettingsController extends ChangeNotifier {
  SettingsController._();

  static final SettingsController instance = SettingsController._();

  static const String _keyDifficulty = 'game_difficulty';
  static const String _keyTapToJump = 'game_tap_to_jump';
  static const String _keyStickmanColor = 'game_stickman_color';
  static const String _keyCoinSize = 'game_coin_size';
  static const String _keyHighContrast = 'game_high_contrast';
  static const String _keyControlScheme = 'game_control_scheme';

  GameSettings _settings = const GameSettings();
  GameSettings get settings => _settings;

  /// Loads persisted settings (or defaults if none stored yet).
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _settings = GameSettings(
      difficulty: GameDifficulty.values.asNameMap()[prefs.getString(_keyDifficulty)] ??
          GameDifficulty.normal,
      tapToJump: prefs.getBool(_keyTapToJump) ?? true,
      stickmanColor: prefs.getInt(_keyStickmanColor) ?? 0xFFFFFFFF,
      coinSize: CoinSize.values.asNameMap()[prefs.getString(_keyCoinSize)] ??
          CoinSize.medium,
      highContrast: prefs.getBool(_keyHighContrast) ?? false,
      controlScheme: switch (prefs.getString(_keyControlScheme)) {
        'gestures' => ControlScheme.gestures,
        'buttons' => ControlScheme.buttons,
        _ => ControlScheme.buttons,
      },
    );
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDifficulty, _settings.difficulty.name);
    await prefs.setBool(_keyTapToJump, _settings.tapToJump);
    await prefs.setInt(_keyStickmanColor, _settings.stickmanColor);
    await prefs.setString(_keyCoinSize, _settings.coinSize.name);
    await prefs.setBool(_keyHighContrast, _settings.highContrast);
    await prefs.setString(_keyControlScheme, _settings.controlScheme?.name ?? 'buttons');
  }

  void setDifficulty(GameDifficulty value) {
    if (_settings.difficulty == value) return;
    _settings = _settings.copyWith(difficulty: value);
    _save();
    notifyListeners();
  }

  void setTapToJump(bool value) {
    if (_settings.tapToJump == value) return;
    _settings = _settings.copyWith(tapToJump: value);
    _save();
    notifyListeners();
  }

  void setStickmanColor(int value) {
    if (_settings.stickmanColor == value) return;
    _settings = _settings.copyWith(stickmanColor: value);
    _save();
    notifyListeners();
  }

  void setCoinSize(CoinSize value) {
    if (_settings.coinSize == value) return;
    _settings = _settings.copyWith(coinSize: value);
    _save();
    notifyListeners();
  }

  void setHighContrast(bool value) {
    if (_settings.highContrast == value) return;
    _settings = _settings.copyWith(highContrast: value);
    _save();
    notifyListeners();
  }

  void setControlScheme(ControlScheme value) {
    if (_settings.controlScheme == value) return;
    _settings = _settings.copyWith(controlScheme: value);
    _save();
    notifyListeners();
  }

  /// Restores every setting to its default and persists immediately.
  Future<void> reset() async {
    _settings = const GameSettings();
    await _save();
    notifyListeners();
  }
}
