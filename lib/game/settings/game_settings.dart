import 'package:flutter/foundation.dart';

/// Global difficulty presets that scale every level's tuning.
enum GameDifficulty {
  easy,
  normal,
  hard;

  String get label {
    switch (this) {
      case GameDifficulty.easy:
        return 'EASY';
      case GameDifficulty.normal:
        return 'NORMAL';
      case GameDifficulty.hard:
        return 'HARD';
    }
  }

  /// Speed multiplier (higher = faster world scroll).
  double get speedMultiplier {
    switch (this) {
      case GameDifficulty.easy:
        return 0.85;
      case GameDifficulty.normal:
        return 1.0;
      case GameDifficulty.hard:
        return 1.15;
    }
  }

  /// Obstacle spawn interval multiplier (higher = wider gaps / easier).
  double get spawnIntervalMultiplier {
    switch (this) {
      case GameDifficulty.easy:
        return 1.25;
      case GameDifficulty.normal:
        return 1.0;
      case GameDifficulty.hard:
        return 0.8;
    }
  }

  /// Power-up spawn chance multiplier (higher = more power-ups).
  double get powerUpMultiplier {
    switch (this) {
      case GameDifficulty.easy:
        return 1.3;
      case GameDifficulty.normal:
        return 1.0;
      case GameDifficulty.hard:
        return 0.75;
    }
  }

  /// Coin spawn chance multiplier.
  double get coinMultiplier {
    switch (this) {
      case GameDifficulty.easy:
        return 1.1;
      case GameDifficulty.normal:
        return 1.0;
      case GameDifficulty.hard:
        return 0.9;
    }
  }
}

/// Relative coin radius scale (visual + collision).
enum CoinSize {
  small,
  medium,
  large;

  String get label {
    switch (this) {
      case CoinSize.small:
        return 'SMALL';
      case CoinSize.medium:
        return 'MEDIUM';
      case CoinSize.large:
        return 'LARGE';
    }
  }

  double get radiusMultiplier {
    switch (this) {
      case CoinSize.small:
        return 0.8;
      case CoinSize.medium:
        return 1.0;
      case CoinSize.large:
        return 1.25;
    }
  }
}

/// How jump and crawl are triggered during a run.
enum ControlScheme {
  buttons,
  gestures;

  String get label {
    switch (this) {
      case ControlScheme.buttons:
        return 'BUTTONS';
      case ControlScheme.gestures:
        return 'GESTURES';
    }
  }
}

/// Immutable snapshot of all user-facing game settings.
@immutable
class GameSettings {
  final GameDifficulty difficulty;
  final int stickmanColor;
  final CoinSize coinSize;
  final bool highContrast;

  /// Nullable only as a defensive guard: after a hot reload a live
  /// [GameSettings] from before this field existed can have it
  /// uninitialized. Consumers treat null as [ControlScheme.buttons].
  final ControlScheme? controlScheme;

  /// When true, the device vibrates on smash and on hitting an obstacle.
  final bool vibrationsEnabled;

  /// Normalized (0..1, 0..1) position of the SMASH (attack) button center
  /// within the play area (origin = top-left). Only used in BUTTONS mode.
  final double attackButtonDx;
  final double attackButtonDy;

  /// Normalized (0..1, 0..1) position of the JUMP button center.
  /// Only used in BUTTONS mode.
  final double jumpButtonDx;
  final double jumpButtonDy;

  /// Normalized (0..1, 0..1) position of the CRAWL button center.
  /// Only used in BUTTONS mode.
  final double crawlButtonDx;
  final double crawlButtonDy;

  /// Per-button size multipliers (0.5..1.5) applied to each on-screen button
  /// (SMASH, JUMP, CRAWL). Only used in BUTTONS mode.
  final double attackButtonScale;
  final double jumpButtonScale;
  final double crawlButtonScale;

  const GameSettings({
    this.difficulty = GameDifficulty.normal,
    this.stickmanColor = 0xFFFFFFFF,
    this.coinSize = CoinSize.medium,
    this.highContrast = false,
    this.controlScheme = ControlScheme.buttons,
    this.vibrationsEnabled = false,
    this.attackButtonDx = 0.07,
    this.attackButtonDy = 0.865,
    this.jumpButtonDx = 0.855,
    this.jumpButtonDy = 0.89,
    this.crawlButtonDx = 0.935,
    this.crawlButtonDy = 0.89,
    this.attackButtonScale = 1.0,
    this.jumpButtonScale = 1.0,
    this.crawlButtonScale = 1.0,
  });

  GameSettings copyWith({
    GameDifficulty? difficulty,
    int? stickmanColor,
    CoinSize? coinSize,
    bool? highContrast,
    ControlScheme? controlScheme,
    bool? vibrationsEnabled,
    double? attackButtonDx,
    double? attackButtonDy,
    double? jumpButtonDx,
    double? jumpButtonDy,
    double? crawlButtonDx,
    double? crawlButtonDy,
    double? attackButtonScale,
    double? jumpButtonScale,
    double? crawlButtonScale,
  }) {
    return GameSettings(
      difficulty: difficulty ?? this.difficulty,
      stickmanColor: stickmanColor ?? this.stickmanColor,
      coinSize: coinSize ?? this.coinSize,
      highContrast: highContrast ?? this.highContrast,
      controlScheme: controlScheme ?? this.controlScheme,
      vibrationsEnabled: vibrationsEnabled ?? this.vibrationsEnabled,
      attackButtonDx: attackButtonDx ?? this.attackButtonDx,
      attackButtonDy: attackButtonDy ?? this.attackButtonDy,
      jumpButtonDx: jumpButtonDx ?? this.jumpButtonDx,
      jumpButtonDy: jumpButtonDy ?? this.jumpButtonDy,
      crawlButtonDx: crawlButtonDx ?? this.crawlButtonDx,
      crawlButtonDy: crawlButtonDy ?? this.crawlButtonDy,
      attackButtonScale: attackButtonScale ?? this.attackButtonScale,
      jumpButtonScale: jumpButtonScale ?? this.jumpButtonScale,
      crawlButtonScale: crawlButtonScale ?? this.crawlButtonScale,
    );
  }
}
