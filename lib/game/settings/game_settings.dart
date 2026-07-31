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

/// Immutable snapshot of all user-facing game settings.
@immutable
class GameSettings {
  final GameDifficulty difficulty;
  final bool tapToJump;
  final int stickmanColor;
  final CoinSize coinSize;
  final bool highContrast;

  const GameSettings({
    this.difficulty = GameDifficulty.normal,
    this.tapToJump = true,
    this.stickmanColor = 0xFFFFFFFF,
    this.coinSize = CoinSize.medium,
    this.highContrast = false,
  });

  GameSettings copyWith({
    GameDifficulty? difficulty,
    bool? tapToJump,
    int? stickmanColor,
    CoinSize? coinSize,
    bool? highContrast,
  }) {
    return GameSettings(
      difficulty: difficulty ?? this.difficulty,
      tapToJump: tapToJump ?? this.tapToJump,
      stickmanColor: stickmanColor ?? this.stickmanColor,
      coinSize: coinSize ?? this.coinSize,
      highContrast: highContrast ?? this.highContrast,
    );
  }
}
