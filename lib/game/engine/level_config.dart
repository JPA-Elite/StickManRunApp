import 'package:flutter/foundation.dart';

import 'entities.dart';

@immutable
class LevelVisuals {
  final String name;
  final String themeTag;

  /// Background “feel” (we’ll render with solid colors + simple shapes)
  final Color topColor;
  final Color bottomColor;

  /// Ground line styling.
  final Color groundColor;

  const LevelVisuals({
    required this.name,
    required this.themeTag,
    required this.topColor,
    required this.bottomColor,
    required this.groundColor,
  });
}

/// Simple color type alias to avoid importing dart:ui from multiple files.
typedef Color = int;

@immutable
class LevelTuning {
  /// How fast the world scrolls (px/sec in screen space).
  final double speed;

  /// Stickman vertical motion.
  final double gravity;
  final double jumpVelocity;

  /// How often to spawn obstacle “columns” (seconds).
  final double obstacleSpawnEvery;

  /// Difficulty ramp.
  final double speedMultiplierPerCoin;

  /// Coin/power-up tuning.
  final double coinChance;
  final double powerUpChance;

  const LevelTuning({
    required this.speed,
    required this.gravity,
    required this.jumpVelocity,
    required this.obstacleSpawnEvery,
    required this.speedMultiplierPerCoin,
    required this.coinChance,
    required this.powerUpChance,
  });

  LevelTuning copyWith({
    double? speed,
    double? gravity,
    double? jumpVelocity,
    double? obstacleSpawnEvery,
    double? speedMultiplierPerCoin,
    double? coinChance,
    double? powerUpChance,
  }) {
    return LevelTuning(
      speed: speed ?? this.speed,
      gravity: gravity ?? this.gravity,
      jumpVelocity: jumpVelocity ?? this.jumpVelocity,
      obstacleSpawnEvery: obstacleSpawnEvery ?? this.obstacleSpawnEvery,
      speedMultiplierPerCoin:
          speedMultiplierPerCoin ?? this.speedMultiplierPerCoin,
      coinChance: coinChance ?? this.coinChance,
      powerUpChance: powerUpChance ?? this.powerUpChance,
    );
  }
}

@immutable
class ObstacleSpawnRule {
  /// Which obstacle types this rule can generate.
  final List<ObstacleType> obstacleTypes;

  /// Bias (higher -> more likely).
  final double weight;

  /// Whether this rule should spawn coins near this column.
  final bool spawnCoins;

  /// Which power-ups are allowed for this rule.
  final List<PowerUpType> powerUps;

  const ObstacleSpawnRule({
    required this.obstacleTypes,
    required this.weight,
    required this.spawnCoins,
    this.powerUps = const [],
  });
}

@immutable
class LevelConfig {
  final int levelIndex;

  final LevelVisuals visuals;
  final LevelTuning tuning;

  /// Obstacles selection “bands” across the level.
  final List<ObstacleSpawnRule> obstacleRules;

  /// Order of obstacle rules used as the game progresses.
  /// The engine picks a rule by weighted random, then slowly shifts over time.
  final List<int> ruleOrder;

  const LevelConfig({
    required this.levelIndex,
    required this.visuals,
    required this.tuning,
    required this.obstacleRules,
    required this.ruleOrder,
  });

  LevelConfig copyWith({LevelTuning? tuning}) {
    return LevelConfig(
      levelIndex: levelIndex,
      visuals: visuals,
      tuning: tuning ?? this.tuning,
      obstacleRules: obstacleRules,
      ruleOrder: ruleOrder,
    );
  }

  static Color _c(int value) => value;

  /// 5 levels based on the requested vibe:
  /// 1) Forest, 2) Desert, 3) Night City, 4) Dark Cave, 5) Volcano.
  static List<LevelConfig> all() {
    // NOTE: We store colors as ints (ARGB) because this file is pure engine-side.
    // The painter will decode them.
    return [
      LevelConfig(
        levelIndex: 1,
        visuals: LevelVisuals(
          name: 'FOREST',
          themeTag: 'LEVEL 1',
          topColor: _c(0xFF1F5B2B),
          bottomColor: _c(0xFF0F2D16),
          groundColor: _c(0xFF2E7D4F),
        ),
        tuning: LevelTuning(
          speed: 280,
          gravity: 2600,
          jumpVelocity: -760,
          obstacleSpawnEvery: 1.05,
          speedMultiplierPerCoin: 0.015,
          coinChance: 0.75,
          powerUpChance: 0.08,
        ),
        obstacleRules: [
          ObstacleSpawnRule(
            obstacleTypes: const [
              ObstacleType.spike,
              ObstacleType.cactus,
              ObstacleType.stalagmite,
            ],
            weight: 1.0,
            spawnCoins: true,
            powerUps: const [
              PowerUpType.shield,
              PowerUpType.heal25,
              PowerUpType.heal50,
            ],
          ),
          ObstacleSpawnRule(
            obstacleTypes: const [ObstacleType.bat, ObstacleType.drone],
            weight: 0.35,
            spawnCoins: true,
            powerUps: const [PowerUpType.magnet, PowerUpType.heal25],
          ),
          ObstacleSpawnRule(
            obstacleTypes: const [ObstacleType.rollingRock],
            weight: 0.25,
            spawnCoins: false,
          ),
        ],
        ruleOrder: const [0, 1, 0, 2, 0],
      ),
      LevelConfig(
        levelIndex: 2,
        visuals: LevelVisuals(
          name: 'DESERT',
          themeTag: 'LEVEL 2',
          topColor: _c(0xFF8F5A24),
          bottomColor: _c(0xFF2B1A07),
          groundColor: _c(0xFFB07A3E),
        ),
        tuning: LevelTuning(
          speed: 330,
          gravity: 2700,
          jumpVelocity: -780,
          obstacleSpawnEvery: 0.98,
          speedMultiplierPerCoin: 0.018,
          coinChance: 0.7,
          powerUpChance: 0.1,
        ),
        obstacleRules: [
          ObstacleSpawnRule(
            obstacleTypes: const [
              ObstacleType.cactus,
              ObstacleType.spike,
              ObstacleType.pendulumMine,
            ],
            weight: 1.1,
            spawnCoins: true,
            powerUps: const [
              PowerUpType.shield,
              PowerUpType.magnet,
              PowerUpType.heal50,
            ],
          ),
          ObstacleSpawnRule(
            obstacleTypes: const [ObstacleType.rollingRock],
            weight: 0.55,
            spawnCoins: false,
          ),
          ObstacleSpawnRule(
            obstacleTypes: const [ObstacleType.laser],
            weight: 0.25,
            spawnCoins: true,
            powerUps: const [PowerUpType.heal25],
          ),
        ],
        ruleOrder: const [0, 2, 0, 1, 0],
      ),
      LevelConfig(
        levelIndex: 3,
        visuals: LevelVisuals(
          name: 'NIGHT CITY',
          themeTag: 'LEVEL 3',
          topColor: _c(0xFF0C2D6B),
          bottomColor: _c(0xFF050D2B),
          groundColor: _c(0xFF27489A),
        ),
        tuning: LevelTuning(
          speed: 370,
          gravity: 2800,
          jumpVelocity: -800,
          obstacleSpawnEvery: 0.92,
          speedMultiplierPerCoin: 0.02,
          coinChance: 0.78,
          powerUpChance: 0.11,
        ),
        obstacleRules: [
          ObstacleSpawnRule(
            obstacleTypes: const [
              ObstacleType.drone,
              ObstacleType.laser,
              ObstacleType.bat,
            ],
            weight: 1.2,
            spawnCoins: true,
            powerUps: const [
              PowerUpType.magnet,
              PowerUpType.heal25,
              PowerUpType.heal50,
            ],
          ),
          ObstacleSpawnRule(
            obstacleTypes: const [ObstacleType.spike, ObstacleType.cactus],
            weight: 0.7,
            spawnCoins: true,
            powerUps: const [PowerUpType.shield, PowerUpType.heal25],
          ),
          ObstacleSpawnRule(
            obstacleTypes: const [ObstacleType.fireJet],
            weight: 0.3,
            spawnCoins: false,
          ),
        ],
        ruleOrder: const [1, 0, 2, 0, 1],
      ),
      LevelConfig(
        levelIndex: 4,
        visuals: LevelVisuals(
          name: 'DARK CAVE',
          themeTag: 'LEVEL 4',
          topColor: _c(0xFF4D1C6E),
          bottomColor: _c(0xFF1B0830),
          groundColor: _c(0xFF148CD2),
        ),
        tuning: LevelTuning(
          speed: 410,
          gravity: 2920,
          jumpVelocity: -820,
          obstacleSpawnEvery: 0.86,
          speedMultiplierPerCoin: 0.021,
          coinChance: 0.72,
          powerUpChance: 0.12,
        ),
        obstacleRules: [
          ObstacleSpawnRule(
            obstacleTypes: const [
              ObstacleType.stalagmite,
              ObstacleType.pendulumMine,
              ObstacleType.spike,
            ],
            weight: 1.15,
            spawnCoins: true,
            powerUps: const [
              PowerUpType.shield,
              PowerUpType.heal25,
              PowerUpType.heal50,
            ],
          ),
          ObstacleSpawnRule(
            obstacleTypes: const [ObstacleType.bat, ObstacleType.drone],
            weight: 0.55,
            spawnCoins: true,
            powerUps: const [PowerUpType.magnet, PowerUpType.heal25],
          ),
          ObstacleSpawnRule(
            obstacleTypes: const [ObstacleType.fireball],
            weight: 0.25,
            spawnCoins: false,
          ),
        ],
        ruleOrder: const [0, 1, 0, 2, 1],
      ),
      LevelConfig(
        levelIndex: 5,
        visuals: LevelVisuals(
          name: 'VOLCANO',
          themeTag: 'LEVEL 5',
          topColor: _c(0xFF8A1F1B),
          bottomColor: _c(0xFF2B0808),
          groundColor: _c(0xFF992611),
        ),
        tuning: LevelTuning(
          speed: 460,
          gravity: 3050,
          jumpVelocity: -840,
          obstacleSpawnEvery: 0.8,
          speedMultiplierPerCoin: 0.024,
          coinChance: 0.74,
          powerUpChance: 0.13,
        ),
        obstacleRules: [
          ObstacleSpawnRule(
            obstacleTypes: const [
              ObstacleType.fireJet,
              ObstacleType.fireball,
              ObstacleType.spike,
              ObstacleType.rollingRock,
            ],
            weight: 1.35,
            spawnCoins: true,
            powerUps: const [
              PowerUpType.shield,
              PowerUpType.magnet,
              PowerUpType.heal25,
              PowerUpType.heal50,
            ],
          ),
          ObstacleSpawnRule(
            obstacleTypes: const [ObstacleType.laser, ObstacleType.drone],
            weight: 0.5,
            spawnCoins: true,
            powerUps: const [PowerUpType.heal25],
          ),
          ObstacleSpawnRule(
            obstacleTypes: const [ObstacleType.pendulumMine],
            weight: 0.25,
            spawnCoins: false,
          ),
        ],
        ruleOrder: const [0, 1, 0, 2, 0],
      ),
      LevelConfig(
        levelIndex: 6,
        visuals: LevelVisuals(
          name: 'RANDOM',
          themeTag: 'LEVEL 6',
          // Placeholder theme; the painter cycles through the other five
          // level palettes while this endless level runs.
          topColor: _c(0xFF202020),
          bottomColor: _c(0xFF0A0A0A),
          groundColor: _c(0xFF141414),
        ),
        tuning: LevelTuning(
          speed: 500,
          gravity: 3150,
          jumpVelocity: -860,
          obstacleSpawnEvery: 0.72,
          speedMultiplierPerCoin: 0.026,
          coinChance: 0.8,
          powerUpChance: 0.15,
        ),
        obstacleRules: [
          ObstacleSpawnRule(
            obstacleTypes: const [
              ObstacleType.spike,
              ObstacleType.cactus,
              ObstacleType.stalagmite,
              ObstacleType.rollingRock,
              ObstacleType.pendulumMine,
              ObstacleType.laser,
              ObstacleType.drone,
              ObstacleType.bat,
              ObstacleType.fireJet,
              ObstacleType.fireball,
            ],
            weight: 1.5,
            spawnCoins: true,
            powerUps: const [
              PowerUpType.shield,
              PowerUpType.magnet,
              PowerUpType.heal25,
              PowerUpType.heal50,
            ],
          ),
          ObstacleSpawnRule(
            obstacleTypes: const [
              ObstacleType.spike,
              ObstacleType.cactus,
              ObstacleType.stalagmite,
              ObstacleType.rollingRock,
            ],
            weight: 0.8,
            spawnCoins: true,
            powerUps: const [
              PowerUpType.shield,
              PowerUpType.heal25,
              PowerUpType.heal50,
            ],
          ),
          ObstacleSpawnRule(
            obstacleTypes: const [
              ObstacleType.laser,
              ObstacleType.drone,
              ObstacleType.bat,
              ObstacleType.fireJet,
              ObstacleType.fireball,
            ],
            weight: 0.9,
            spawnCoins: true,
            powerUps: const [
              PowerUpType.magnet,
              PowerUpType.heal25,
              PowerUpType.heal50,
            ],
          ),
        ],
        ruleOrder: const [0, 2, 0, 1, 2],
      ),
    ];
  }
}
