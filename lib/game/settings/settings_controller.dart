import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/audio_controller.dart';
import 'game_settings.dart';

/// Singleton controller that owns the current [GameSettings] and persists
/// every change to SharedPreferences so settings survive app restarts.
class SettingsController extends ChangeNotifier {
  SettingsController._();

  static final SettingsController instance = SettingsController._();

  static const String _keyDifficulty = 'game_difficulty';
  static const String _keyStickmanColor = 'game_stickman_color';
  static const String _keyCoinSize = 'game_coin_size';
  static const String _keyHighContrast = 'game_high_contrast';
  static const String _keyControlScheme = 'game_control_scheme';
  static const String _keyVibrations = 'game_vibrations_enabled';
  static const String _keyAttackDx = 'btn_attack_dx';
  static const String _keyAttackDy = 'btn_attack_dy';
  static const String _keyJumpDx = 'btn_jump_dx';
  static const String _keyJumpDy = 'btn_jump_dy';
  static const String _keyCrawlDx = 'btn_crawl_dx';
  static const String _keyCrawlDy = 'btn_crawl_dy';
  static const String _keyAttackScale = 'btn_attack_scale';
  static const String _keyJumpScale = 'btn_jump_scale';
  static const String _keyCrawlScale = 'btn_crawl_scale';
  static const String _keyMusicEnabled = 'audio_music_enabled';
  static const String _keySfxEnabled = 'audio_sfx_enabled';
  static const String _keyMusicVolume = 'audio_music_volume';
  static const String _keySfxVolume = 'audio_sfx_volume';

  GameSettings _settings = const GameSettings();
  GameSettings get settings => _settings;

  /// Serializes all persistence so rapid toggles can never interleave and
  /// leave stale audio/prefs behind.
  Future<void> _saveQueue = Future.value();
  Timer? _volumeSaveTimer;

  /// Loads persisted settings (or defaults if none stored yet).
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _settings = GameSettings(
      difficulty: GameDifficulty.values.asNameMap()[prefs.getString(_keyDifficulty)] ??
          GameDifficulty.normal,
      stickmanColor: prefs.getInt(_keyStickmanColor) ?? 0xFFFFFFFF,
      coinSize: CoinSize.values.asNameMap()[prefs.getString(_keyCoinSize)] ??
          CoinSize.medium,
      highContrast: prefs.getBool(_keyHighContrast) ?? false,
      controlScheme: switch (prefs.getString(_keyControlScheme)) {
        'gestures' => ControlScheme.gestures,
        'buttons' => ControlScheme.buttons,
        _ => ControlScheme.buttons,
      },
      vibrationsEnabled: prefs.getBool(_keyVibrations) ?? false,
      attackButtonDx: _normalized(prefs.getDouble(_keyAttackDx), 0.07),
      attackButtonDy: _normalized(prefs.getDouble(_keyAttackDy), 0.865),
      jumpButtonDx: _normalized(prefs.getDouble(_keyJumpDx), 0.855),
      jumpButtonDy: _normalized(prefs.getDouble(_keyJumpDy), 0.89),
      crawlButtonDx: _normalized(prefs.getDouble(_keyCrawlDx), 0.935),
      crawlButtonDy: _normalized(prefs.getDouble(_keyCrawlDy), 0.89),
      attackButtonScale: _scale(prefs.getDouble(_keyAttackScale), 1.0),
      jumpButtonScale: _scale(prefs.getDouble(_keyJumpScale), 1.0),
      crawlButtonScale: _scale(prefs.getDouble(_keyCrawlScale), 1.0),
      musicEnabled: prefs.getBool(_keyMusicEnabled) ?? true,
      sfxEnabled: prefs.getBool(_keySfxEnabled) ?? true,
      musicVolume: (prefs.getDouble(_keyMusicVolume) ?? 0.7).clamp(0.0, 1.0),
      sfxVolume: (prefs.getDouble(_keySfxVolume) ?? 1.0).clamp(0.0, 1.0),
    );
    AudioController.effectiveInstance.applySettings(
      musicEnabled: _settings.musicEnabled,
      sfxEnabled: _settings.sfxEnabled,
      musicVolume: _settings.musicVolume,
      sfxVolume: _settings.sfxVolume,
    );
    notifyListeners();
  }

  /// Clamps a persisted normalized coordinate into the safe 0..1 range.
  static double _normalized(double? value, double fallback) {
    if (value == null) return fallback;
    return value.clamp(0.0, 1.0);
  }

  /// Clamps a persisted button size multiplier into 0.5..2.05.
  static double _scale(double? value, double fallback) {
    if (value == null) return fallback;
    return value.clamp(0.5, 2.05);
  }

  void _applyAudioNow() {
    // Immediate feedback: audio reacts synchronously, persistence follows.
    AudioController.effectiveInstance.applySettings(
      musicEnabled: _settings.musicEnabled,
      sfxEnabled: _settings.sfxEnabled,
      musicVolume: _settings.musicVolume,
      sfxVolume: _settings.sfxVolume,
    );
  }

  Future<void> _save() {
    // Chain writes so rapid toggles always finish in order.
    _saveQueue = _saveQueue.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyDifficulty, _settings.difficulty.name);
      await prefs.setInt(_keyStickmanColor, _settings.stickmanColor);
      await prefs.setString(_keyCoinSize, _settings.coinSize.name);
      await prefs.setBool(_keyHighContrast, _settings.highContrast);
      await prefs.setString(
          _keyControlScheme, _settings.controlScheme?.name ?? 'buttons');
      await prefs.setBool(_keyVibrations, _settings.vibrationsEnabled);
      await prefs.setDouble(_keyAttackDx, _settings.attackButtonDx);
      await prefs.setDouble(_keyAttackDy, _settings.attackButtonDy);
      await prefs.setDouble(_keyJumpDx, _settings.jumpButtonDx);
      await prefs.setDouble(_keyJumpDy, _settings.jumpButtonDy);
      await prefs.setDouble(_keyCrawlDx, _settings.crawlButtonDx);
      await prefs.setDouble(_keyCrawlDy, _settings.crawlButtonDy);
      await prefs.setDouble(_keyAttackScale, _settings.attackButtonScale);
      await prefs.setDouble(_keyJumpScale, _settings.jumpButtonScale);
      await prefs.setDouble(_keyCrawlScale, _settings.crawlButtonScale);
      await prefs.setBool(_keyMusicEnabled, _settings.musicEnabled);
      await prefs.setBool(_keySfxEnabled, _settings.sfxEnabled);
      await prefs.setDouble(_keyMusicVolume, _settings.musicVolume);
      await prefs.setDouble(_keySfxVolume, _settings.sfxVolume);
    });
    return _saveQueue;
  }

  Timer? _volumeAudioTimer;
  bool _volumeAudioPending = false;

  void _applyAudioThrottledVolume() {
    // C4: sliders fire dozens/sec; 49 setVolume + chain task per tick would
    // flood the platform channel. Immediate first tick, then trailing 80ms.
    if (_volumeAudioTimer?.isActive ?? false) {
      _volumeAudioPending = true;
      return;
    }
    _applyAudioNow();
    _volumeAudioTimer = Timer(const Duration(milliseconds: 80), () {
      if (_volumeAudioPending) {
        _volumeAudioPending = false;
        _applyAudioNow();
      }
    });
  }

  void _saveDebouncedVolume() {
    _applyAudioThrottledVolume();
    _volumeSaveTimer?.cancel();
    _volumeSaveTimer = Timer(const Duration(milliseconds: 300), () {
      unawaited(_save());
    });
  }

  void setMusicEnabled(bool value) {
    if (_settings.musicEnabled == value) return;
    _settings = _settings.copyWith(musicEnabled: value);
    _applyAudioNow();
    unawaited(_save());
    notifyListeners();
  }

  void setSfxEnabled(bool value) {
    if (_settings.sfxEnabled == value) return;
    _settings = _settings.copyWith(sfxEnabled: value);
    _applyAudioNow();
    unawaited(_save());
    notifyListeners();
  }

  /// Master sound toggle used by the home header: music + SFX together.
  void setSoundEnabled(bool value) {
    if (_settings.musicEnabled == value && _settings.sfxEnabled == value) {
      return;
    }
    _settings =
        _settings.copyWith(musicEnabled: value, sfxEnabled: value);
    _applyAudioNow();
    unawaited(_save());
    notifyListeners();
  }

  void setMusicVolume(double value) {
    final clamped = value.clamp(0.0, 1.0);
    if (_settings.musicVolume == clamped) return;
    _settings = _settings.copyWith(musicVolume: clamped);
    _saveDebouncedVolume();
    notifyListeners();
  }

  void setSfxVolume(double value) {
    final clamped = value.clamp(0.0, 1.0);
    if (_settings.sfxVolume == clamped) return;
    _settings = _settings.copyWith(sfxVolume: clamped);
    _saveDebouncedVolume();
    notifyListeners();
  }

  void setDifficulty(GameDifficulty value) {
    if (_settings.difficulty == value) return;
    _settings = _settings.copyWith(difficulty: value);
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

  void setVibrationsEnabled(bool value) {
    if (_settings.vibrationsEnabled == value) return;
    _settings = _settings.copyWith(vibrationsEnabled: value);
    _save();
    notifyListeners();
  }

  void setAttackButtonPos(double dx, double dy) {
    _settings = _settings.copyWith(
      attackButtonDx: dx.clamp(0.0, 1.0),
      attackButtonDy: dy.clamp(0.0, 1.0),
    );
    _save();
    notifyListeners();
  }

  void setJumpButtonPos(double dx, double dy) {
    _settings = _settings.copyWith(
      jumpButtonDx: dx.clamp(0.0, 1.0),
      jumpButtonDy: dy.clamp(0.0, 1.0),
    );
    _save();
    notifyListeners();
  }

  void setCrawlButtonPos(double dx, double dy) {
    _settings = _settings.copyWith(
      crawlButtonDx: dx.clamp(0.0, 1.0),
      crawlButtonDy: dy.clamp(0.0, 1.0),
    );
    _save();
    notifyListeners();
  }

  void setAttackButtonScale(double value) {
    _settings = _settings.copyWith(
      attackButtonScale: value.clamp(0.5, 2.05),
    );
    _save();
    notifyListeners();
  }

  void setJumpButtonScale(double value) {
    _settings = _settings.copyWith(
      jumpButtonScale: value.clamp(0.5, 2.05),
    );
    _save();
    notifyListeners();
  }

  void setCrawlButtonScale(double value) {
    _settings = _settings.copyWith(
      crawlButtonScale: value.clamp(0.5, 2.05),
    );
    _save();
    notifyListeners();
  }

  /// Restores the default button placement (matches the original layout).
  void resetButtonPositions() {
    _settings = _settings.copyWith(
      attackButtonDx: 0.07,
      attackButtonDy: 0.865,
      jumpButtonDx: 0.855,
      jumpButtonDy: 0.89,
      crawlButtonDx: 0.935,
      crawlButtonDy: 0.89,
      attackButtonScale: 1.0,
      jumpButtonScale: 1.0,
      crawlButtonScale: 1.0,
    );
    _save();
    notifyListeners();
  }

  /// Applies a complete button layout (positions + scales) from a draft and
  /// persists once. Used by the button placement editor's SAVE CHANGES.
  Future<void> applyButtonLayout(GameSettings draft) async {
    _settings = _settings.copyWith(
      attackButtonDx: draft.attackButtonDx,
      attackButtonDy: draft.attackButtonDy,
      jumpButtonDx: draft.jumpButtonDx,
      jumpButtonDy: draft.jumpButtonDy,
      crawlButtonDx: draft.crawlButtonDx,
      crawlButtonDy: draft.crawlButtonDy,
      attackButtonScale: draft.attackButtonScale,
      jumpButtonScale: draft.jumpButtonScale,
      crawlButtonScale: draft.crawlButtonScale,
    );
    await _save();
    notifyListeners();
  }

  /// Restores every setting to its default and persists immediately.
  Future<void> reset() async {
    _settings = const GameSettings();
    _applyAudioNow();
    await _save();
    notifyListeners();
  }
}
