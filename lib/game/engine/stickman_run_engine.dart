import 'dart:math';

import 'package:flutter/foundation.dart';

import 'entities.dart';
import 'level_config.dart';

enum GameStatus {
  ready,
  running,
  levelComplete,
  gameOver,
}

@immutable
class StickmanRunSnapshot {
  final GameStatus status;
  final int levelIndex;
  final int score;
  final int coins;
  final double distanceMeters;

  final bool shieldActive;
  final double shieldRemainingSec;

  final bool magnetActive;
  final double magnetRemainingSec;

  final bool crawlingActive;
  final double crawlRemainingSec;

  final Stickman stickman;
  final List<Obstacle> obstacles;
  final List<Coin> coinsOnTrack;
  final List<PowerUp> powerUps;

  final double timeSec;

  const StickmanRunSnapshot({
    required this.status,
    required this.levelIndex,
    required this.score,
    required this.coins,
    required this.distanceMeters,
    required this.shieldActive,
    required this.shieldRemainingSec,
    required this.magnetActive,
    required this.magnetRemainingSec,
    required this.crawlingActive,
    required this.crawlRemainingSec,
    required this.stickman,
    required this.obstacles,
    required this.coinsOnTrack,
    required this.powerUps,
    required this.timeSec,
  });
}

class StickmanRunEngine {
  final List<LevelConfig> levels;
  final Random _rng;

  StickmanRunEngine({List<LevelConfig>? levels, int? seed})
      : levels = levels ?? LevelConfig.all(),
        _rng = Random(seed);

  late LevelConfig _level;

  // Viewport-dependent constants (set via resize()).
  double _width = 360;
  double _height = 640;
  double _groundY = 460;
  double _stickmanX = 110;

  // Game entities (world-space in screen pixels).
  Stickman _stickman = const Stickman(x: 110, y: 460, vy: 0);

  final List<Obstacle> _obstacles = [];
  final List<Coin> _coins = [];
  final List<PowerUp> _powerUps = [];

  GameStatus _status = GameStatus.ready;

  // HUD
  int _score = 0;
  int _coinsCollected = 0;
  double _distanceMeters = 0;

  // Power-ups timers
  double _shieldRemainingSec = 0;
  double _magnetRemainingSec = 0;

  // Crawl (lower head while still running)
  double _crawlRemainingSec = 0;

  // Prevent “instant death” from the very first spawn right after START RUN.
  // (First obstacle column can overlap slightly due to resize/layout rounding.)
  double _collisionGraceSec = 0;

  // Extra grace right after a tap jump (prevents immediate “instant death”
  // before the first visible jump frame on some devices).
  double _postJumpCollisionGraceSec = 0;

  // Require the first obstacle column to not appear immediately after START RUN.
  // Ensures the first obstacle is visible for at least a few seconds.
  double _initialObstacleDelaySec = 0;

  // Loop timers
  double _spawnTimerSec = 0;
  double _spawnTick = 0;
  double _levelTimeSec = 0;

  // Level completion distance.
  double _targetDistanceMeters = 250;

  // Obstacles spawn cadence adapts to difficulty.
  double _nextSpawnEverySec = 1;

  double _timeSec = 0;

  StickmanRunSnapshot snapshot() {
    return StickmanRunSnapshot(
      status: _status,
      levelIndex: _level.levelIndex,
      score: _score,
      coins: _coinsCollected,
      distanceMeters: _distanceMeters,
      shieldActive: _shieldRemainingSec > 0,
      shieldRemainingSec: _shieldRemainingSec,
      magnetActive: _magnetRemainingSec > 0,
      magnetRemainingSec: _magnetRemainingSec,
      crawlingActive: _crawlRemainingSec > 0,
      crawlRemainingSec: _crawlRemainingSec,
      stickman: _stickman,
      obstacles: List.unmodifiable(_obstacles),
      coinsOnTrack: List.unmodifiable(_coins),
      powerUps: List.unmodifiable(_powerUps),
      timeSec: _timeSec,
    );
  }

  void resize(double width, double height) {
    _width = max(1, width);
    _height = max(1, height);

    _groundY = _height * 0.78;

    // Stickman should start very near the left edge, but keep a bit more padding.
    _stickmanX = max(18.0, _width * 0.06);

    // Keep stickman aligned to the resized ground.
    // If we're resting (or not running yet), snap to ground so tap jump works reliably.
    final stickmanBottom = _groundY;

    // Ground snap:
    // - When NOT running: be forgiving to make taps/jumps consistent.
    // - When running: be strict; otherwise it cancels the first frames of a jump
    //   (resize happens every build, and early jump height can still be < snap tolerance).
    final isRunning = _status == GameStatus.running;
    final snapTolerancePx = isRunning ? 4.0 : 20.0;

    final nearGround = (_stickman.y - _groundY).abs() < snapTolerancePx;
    final isResting = _stickman.vy.abs() < 0.01;

    if (!isRunning || (nearGround && isResting)) {
      _stickman = _stickman.copyWith(y: _groundY);
    } else {
      // Don’t “pull” stickman down/up due to layout/viewport groundY shifts.
      // Only prevent it from going *below* the ground line.
      final clampedY = _stickman.y > _groundY ? _groundY : _stickman.y;
      _stickman = _stickman.copyWith(y: clampedY);
    }

    _resetWorldForViewport();
  }

  void start({int levelIndex = 1}) {
    final idx = (levelIndex - 1).clamp(0, levels.length - 1);
    _level = levels[idx];

    _obstacles.clear();
    _coins.clear();
    _powerUps.clear();

    _status = GameStatus.ready;
    _score = 0;
    _coinsCollected = 0;
    _distanceMeters = 0;

    _shieldRemainingSec = 0;
    _magnetRemainingSec = 0;
    _crawlRemainingSec = 0;

    _initialObstacleDelaySec = 0;
    _spawnTimerSec = 0;
    _spawnTick = 0;
    _levelTimeSec = 0;

    _timeSec = 0;

    // Target distance scales by level.
    _targetDistanceMeters = 240 + _level.levelIndex * 55;

    // Place stickman at ground.
    _stickman = Stickman(
      x: _stickmanX,
      y: _groundY,
      vy: 0,
    );

    _recomputeSpawnCadence();
  }

  void startRunning() {
    if (_status == GameStatus.ready || _status == GameStatus.levelComplete || _status == GameStatus.gameOver) {
      // If game over/complete, treat startRunning as “restart current level”.
      if (_status == GameStatus.gameOver || _status == GameStatus.levelComplete) {
        start(levelIndex: _level.levelIndex);
      }

      _status = GameStatus.running;

      // Short invulnerability window for the first spawn.
      _collisionGraceSec = 0.25;

      // Delay the very first obstacle/coin/power-up column so it is
      // visible for at least ~3 seconds after the run begins.
      _initialObstacleDelaySec = 3.0;

      // Start spawn timer from 0; actual spawning is gated by _initialObstacleDelaySec.
      _spawnTimerSec = 0;
    }
  }

  void jump() {
    // Make jump resilient: if we were not in running state for any reason,
    // attempt to enter running first, then apply the impulse.
    if (_status != GameStatus.running) {
      startRunning();
    }
    if (_status != GameStatus.running) return;

    // Force a visibly obvious jump immediately.
    // This removes any timing sensitivity and makes it easy to confirm
    // whether tap-to-jump is actually firing.
    const jumpHeightPx = 120.0;

    _stickman = _stickman.copyWith(
      y: _groundY - jumpHeightPx,
      vy: _level.tuning.jumpVelocity,
    );

    // Critical for "tap near obstacle" timing:
    // if the tap happens late, the stickman may still intersect on the
    // first frame after the jump. A short grace window makes jumps reliable.
    _postJumpCollisionGraceSec = 0.12;
  }

  void crawl() {
    // Make crawl resilient: if we were not running yet, start first.
    if (_status != GameStatus.running) {
      startRunning();
    }
    if (_status != GameStatus.running) return;

    // Duration for crawl/crouch.
    _crawlRemainingSec = 0.55;

    // If you crawl right after a jump, keep the short post-jump
    // invulnerability window (so it doesn't feel unfair).
  }

  void tick(double dtSec) {
    if (_status != GameStatus.running) {
      _timeSec += dtSec;
      return;
    }

    _timeSec += dtSec;
    _levelTimeSec += dtSec;

    _collisionGraceSec = max(0, _collisionGraceSec - dtSec);
    _postJumpCollisionGraceSec = max(0, _postJumpCollisionGraceSec - dtSec);

    _crawlRemainingSec = max(0, _crawlRemainingSec - dtSec);

    _initialObstacleDelaySec = max(0, _initialObstacleDelaySec - dtSec);

    _recomputeSpawnCadence();

    _updatePowerUps(dtSec);
    _updateStickmanPhysics(dtSec);
    _updateWorld(dtSec);
    _handleCollisionsAndCollect();
    _updateLevelProgress();

    // Safety clamp.
    if (_stickman.y > _groundY) {
      _stickman = _stickman.copyWith(y: _groundY, vy: 0);
    }
  }

  void _updateLevelProgress() {
    if (_status != GameStatus.running) return;

    if (_distanceMeters >= _targetDistanceMeters) {
      _status = GameStatus.levelComplete;
    }
  }

  void _recomputeSpawnCadence() {
    // Difficulty: ramp speed & spawn rate slightly as coins increase.
    final coinRamp = _coinsCollected.toDouble() * _level.tuning.speedMultiplierPerCoin;
    final speed = _level.tuning.speed * (1 + coinRamp);

    // Translate world speed into “meters” for completion: 1px ~ 1/100 meter.
    // We use distance meters increment elsewhere; here we focus spawn cadence.
    final base = _level.tuning.obstacleSpawnEvery;

    // Make obstacles a bit more frequent over time.
    final timeRamp = min(0.35, _levelTimeSec / 90.0 * 0.35);
    final coinRampSpawn = min(0.25, _coinsCollected / 35.0 * 0.25);

    _nextSpawnEverySec = max(0.55, base * (1 - timeRamp - coinRampSpawn));

    // Prevent speed var from being unused (keeps mental model).
    if (speed < 0) return;
  }

  void _updatePowerUps(double dtSec) {
    _shieldRemainingSec = max(0, _shieldRemainingSec - dtSec);
    _magnetRemainingSec = max(0, _magnetRemainingSec - dtSec);
  }

  void _updateStickmanPhysics(double dtSec) {
    final gravity = _level.tuning.gravity;
    final nextVy = _stickman.vy + gravity * dtSec;
    final nextY = _stickman.y + nextVy * dtSec;

    // Ground collision:
    // Only clamp when we're actually falling (vy >= 0). This prevents
    // a very small/irregular dt on web from immediately snapping the jump
    // back to the ground on the first frame.
    if (nextY >= _groundY && _stickman.vy >= 0) {
      _stickman = _stickman.copyWith(y: _groundY, vy: 0);
      return;
    }

    _stickman = _stickman.copyWith(y: nextY, vy: nextVy);
  }

  void _updateWorld(double dtSec) {
    // Move and spawn with world scrolling:
    // Obstacles/coins/powerups move left, stickman stays horizontally.
    final speed = _level.tuning.speed * (1 + (_coinsCollected.toDouble() * _level.tuning.speedMultiplierPerCoin));

    // Convert dt & speed to px delta.
    final dx = speed * dtSec;

    // Spawn logic.
    // Do not spawn obstacle columns during the initial delay window.
    if (_initialObstacleDelaySec <= 0) {
      _spawnTimerSec += dtSec;
      while (_spawnTimerSec >= _nextSpawnEverySec) {
        _spawnTimerSec -= _nextSpawnEverySec;
        _spawnTick += 1;
        _spawnObstacleColumn();
      }
    }

    // Scroll existing entities.
    for (var i = 0; i < _obstacles.length; i++) {
      _obstacles[i] = _obstacles[i].copyWith(x: _obstacles[i].x - dx);
    }
    for (var i = 0; i < _coins.length; i++) {
      _coins[i] = _coins[i].copyWith(x: _coins[i].x - dx);
    }
    for (var i = 0; i < _powerUps.length; i++) {
      _powerUps[i] = _powerUps[i].copyWith(x: _powerUps[i].x - dx);
    }

    _distanceMeters += dx / 100.0;

    // Remove out-of-screen entities.
    final leftKill = -140.0;
    _obstacles.removeWhere((o) => o.x + o.width < leftKill);
    _coins.removeWhere((c) => c.x + c.radius < leftKill);
    _powerUps.removeWhere((p) => p.x + p.size * 0.5 < leftKill);
  }

  void _spawnObstacleColumn() {
    // Choose a rule index using ruleOrder progression.
    final ruleIndex = _level.ruleOrder[(min(_level.ruleOrder.length - 1, _spawnTick ~/ 3)) % _level.ruleOrder.length];
    final candidateRuleIndices = _level.obstacleRules.asMap().entries.where((e) => e.key == ruleIndex).map((e) => e.key).toList();

    final chosenRule = candidateRuleIndices.isEmpty
        ? _pickWeightedRule()
        : _level.obstacleRules[candidateRuleIndices.first];

    // Spawn columns from the far right edge of the screen.
    // For the very first column, spawn much further right so it enters
    // the viewport from the right side (not appearing mid-screen).
    final colX = (_spawnTick <= 1) ? (_width + 260) : (_width + 60);

    final stickmanBottom = _groundY;
    final r = _rng.nextDouble();

    // Spawn coins near columns if allowed.
    if (chosenRule.spawnCoins && r <= _level.tuning.coinChance) {
      _spawnCoinsAroundColumn(colX: colX, bottomY: stickmanBottom);
    }

    // Spawn power-ups.
    if (chosenRule.powerUps.isNotEmpty && _rng.nextDouble() <= _level.tuning.powerUpChance) {
      _spawnPowerUpNearColumn(colX: colX, bottomY: stickmanBottom, available: chosenRule.powerUps);
    }

    // Spawn 1-2 obstacles depending on spawnTick & difficulty.
    final obstacleCount = (_spawnTick % 8 == 0) ? 2 : 1;

    for (var j = 0; j < obstacleCount; j++) {
      final obstacleType = chosenRule.obstacleTypes[_rng.nextInt(chosenRule.obstacleTypes.length)];
      final obstacle = _makeObstacle(type: obstacleType, x: colX + j * 30, bottomY: stickmanBottom);
      _obstacles.add(obstacle);
    }
  }

  Obstacle _makeObstacle({
    required ObstacleType type,
    required double x,
    required double bottomY,
  }) {
    // Sizes roughly tuned for “stickman passability”.
    // For flying obstacles, y is set above ground.
    double width;
    double height;
    double y;

    final laneSkew = (_rng.nextDouble() - 0.5) * 24.0;

    switch (type) {
      case ObstacleType.spike:
        width = 22;
        height = 50;
        y = bottomY - height;
        break;
      case ObstacleType.stalagmite:
        width = 26;
        height = 62;
        y = bottomY - height;
        break;
      case ObstacleType.rollingRock:
        width = 34;
        height = 34;
        y = bottomY - height * 0.85;
        break;
      case ObstacleType.drone:
        width = 34;
        height = 22;
        y = bottomY - 140 - _rng.nextDouble() * 40;
        break;
      case ObstacleType.bat:
        width = 36;
        height = 24;
        y = bottomY - 160 - _rng.nextDouble() * 55;
        break;
      case ObstacleType.laser:
        width = 70;
        height = 16;
        y = bottomY - 160 - _rng.nextDouble() * 90;
        break;
      case ObstacleType.fireJet:
        width = 34;
        height = 28;
        y = bottomY - 28 - _rng.nextDouble() * 20;
        break;
      case ObstacleType.fireball:
        width = 26;
        height = 26;
        y = bottomY - 220 - _rng.nextDouble() * 90;
        break;
      case ObstacleType.pendulumMine:
        width = 26;
        height = 34;
        y = bottomY - 240 - _rng.nextDouble() * 70;
        break;
      case ObstacleType.cactus:
        width = 28;
        height = 54;
        y = bottomY - height;
        break;
    }

    // Add slight y wobble.
    y += laneSkew * 0.15;

    final needsForeground = type == ObstacleType.rollingRock || type == ObstacleType.pendulumMine;

    final rotation = (type == ObstacleType.pendulumMine) ? (_rng.nextDouble() - 0.5) * 0.6 : 0.0;
    final phase = _rng.nextDouble() * 10;

    return Obstacle(
      type: type,
      x: x,
      y: y,
      width: width,
      height: height,
      foreground: needsForeground,
      rotation: rotation,
      phase: phase,
    );
  }

  ObstacleSpawnRule _pickWeightedRule() {
    final total = _level.obstacleRules.fold<double>(0, (sum, r) => sum + r.weight);
    final target = _rng.nextDouble() * (total == 0 ? 1 : total);

    double acc = 0;
    for (final r in _level.obstacleRules) {
      acc += r.weight;
      if (target <= acc) return r;
    }
    return _level.obstacleRules.last;
  }

  void _spawnCoinsAroundColumn({required double colX, required double bottomY}) {
    // Spawn 1-3 coins.
    final count = 1 + _rng.nextInt(3);
    final baseY = bottomY - (80 + _rng.nextDouble() * 110);

    for (var i = 0; i < count; i++) {
      final radius = 9 + _rng.nextDouble() * 3;
      final y = baseY - i * (22 + _rng.nextDouble() * 18);
      _coins.add(
        Coin(
          x: colX + i * 18.0,
          y: y,
          radius: radius,
          phase: _rng.nextDouble() * 10,
        ),
      );
    }
  }

  void _spawnPowerUpNearColumn({
    required double colX,
    required double bottomY,
    required List<PowerUpType> available,
  }) {
    final type = available[_rng.nextInt(available.length)];
    final size = 26.0 + _rng.nextDouble() * 6.0;
    final y = bottomY - 90 - _rng.nextDouble() * 150;

    _powerUps.add(
      PowerUp(
        type: type,
        x: colX + 10,
        y: y,
        size: size,
        phase: _rng.nextDouble() * 10,
      ),
    );
  }

  void _handleCollisionsAndCollect() {
    // Determine stickman collision rectangle using a fixed size model.
    final stickmanW = _stickmanWidthPx();
    final baseStickmanH = _stickmanHeightPx();
    // While crawling, lower head -> reduce collision box height.
    final stickmanH = _crawlRemainingSec > 0 ? baseStickmanH * 0.58 : baseStickmanH;

    // Magnet: if active, coins become easier to collect.
    final magnetPull = _magnetRemainingSec > 0;

    // Coin collection.
    if (_coins.isNotEmpty) {
      final magnetRange = magnetPull ? 72.0 : 42.0;
      _coins.removeWhere((c) {
        final dx = (c.x - _stickman.x).abs();
        if (dx > magnetRange) return false;

        final coinRect = c.collisionRect();
        final stickRect = _stickman.collisionRect(width: stickmanW, height: stickmanH);
        final hit = coinRect.intersects(stickRect) || dx < 18 && _stickman.y < c.y + 18;

        if (hit) {
          _coinsCollected += 1;
          _score += 10;
          return true;
        }
        return false;
      });
    }

    // Power-up collection.
    if (_powerUps.isNotEmpty) {
      _powerUps.removeWhere((p) {
        final pr = p.collisionRect();
        final sr = _stickman.collisionRect(width: stickmanW, height: stickmanH);
        if (!pr.intersects(sr)) return false;

        if (p.type == PowerUpType.shield) {
          _shieldRemainingSec = max(_shieldRemainingSec, 6.0);
          _score += 25;
        } else if (p.type == PowerUpType.magnet) {
          _magnetRemainingSec = max(_magnetRemainingSec, 6.0);
          _score += 25;
        }

        return true;
      });
    }

    // Obstacle collisions.
    for (final o in _obstacles) {
      // If we're moving upward, make collision non-lethal so late taps don't
      // instantly kill before the jump is visually confirmed.
      if (_stickman.vy < 0) continue;

      if (_collisionGraceSec > 0 || _postJumpCollisionGraceSec > 0) continue;

      final or = o.collisionRect();
      final sr = _stickman.collisionRect(width: stickmanW, height: stickmanH);
      if (!or.intersects(sr)) continue;

      if (_shieldRemainingSec > 0) {
        // Consume shield and bounce back a bit.
        _shieldRemainingSec = 0;
        _score = max(0, _score - 10);
        _stickman = _stickman.copyWith(vy: _level.tuning.jumpVelocity * 0.55);
        return;
      }

      _status = GameStatus.gameOver;
      return;
    }
  }

  void _resetWorldForViewport() {
    // Keep objects in the same “world” but clamp them if they are wildly off due to resize.
    _stickman = Stickman(
      x: _stickmanX,
      y: min(_stickman.y, _groundY),
      vy: _stickman.vy,
    );
  }

  double _stickmanWidthPx() {
    return max(32, _width * 0.12);
  }

  double _stickmanHeightPx() {
    return max(90, _height * 0.22);
  }
}
