import 'dart:math';

import 'package:flutter/foundation.dart';

import '../settings/game_settings.dart';
import '../settings/skill_defs.dart';
import 'entities.dart';
import 'level_config.dart';

enum GameStatus { ready, running, levelComplete, gameOver }

@immutable
class StickmanRunSnapshot {
  final GameStatus status;
  final int levelIndex;
  final int score;
  final int coins;
  final double distanceMeters;

  /// Stickman life, 0..100. Reaching 0 ends the game.
  final double lifePercent;

  /// Seconds remaining of the red hit-flash effect (0 when no flash).
  final double damageFlashSec;

  /// Seconds remaining of post-hit invulnerability (blinks the stickman).
  final double damageGraceSec;

  /// Seconds remaining of the green heal flash overlay.
  final double healFlashSec;

  final bool shieldActive;
  final double shieldRemainingSec;

  final bool magnetActive;
  final double magnetRemainingSec;

  final bool crawlingActive;
  final double crawlRemainingSec;

  final bool smashActive;
  final double smashRemainingSec;
  final double smashCooldownSec;

  final Stickman stickman;
  final List<Obstacle> obstacles;
  final List<Coin> coinsOnTrack;
  final List<PowerUp> powerUps;
  final List<SmashDebris> smashDebris;
  final List<SmashScorePopup> smashScorePopups;

  final double timeSec;

  /// Total number of times the stickman has taken damage this run. The UI uses
  /// changes in this value to trigger haptic feedback on each hit.
  final int hitCount;

  /// Active visual theme index (0..4) for the RANDOM/endless level. Themes
  /// cycle every 500 meters; 0 for normal levels.
  final int randomThemeIndex;

  /// Theme index active just before the current one, used to crossfade the
  /// cinematic transition when the endless theme rotates (0 for normal levels).
  final int randomThemeIndexPrev;

  /// Seconds remaining of the cinematic theme-change transition (0 when no
  /// transition is playing).
  final double themeTransitionSec;

  /// Seconds remaining of the entrance cinematic (start/retry/restart) during
  /// which the HUD and controls are hidden (0 when none). Mid-run scene
  /// changes leave this at 0 so gameplay stays fully responsive.
  final double entranceCinematicSec;

  /// Current combo chain count (consecutive smashes without taking a hit).
  final int combo;

  /// Current score multiplier from an active combo (1.0 when no combo).
  final double comboMult;

  const StickmanRunSnapshot({
    required this.status,
    required this.levelIndex,
    required this.score,
    required this.coins,
    required this.distanceMeters,
    required this.lifePercent,
    required this.damageFlashSec,
    required this.damageGraceSec,
    required this.healFlashSec,
    required this.shieldActive,
    required this.shieldRemainingSec,
    required this.magnetActive,
    required this.magnetRemainingSec,
    required this.crawlingActive,
    required this.crawlRemainingSec,
    required this.smashActive,
    required this.smashRemainingSec,
    required this.smashCooldownSec,
    required this.stickman,
    required this.obstacles,
    required this.coinsOnTrack,
    required this.powerUps,
    required this.smashDebris,
    required this.smashScorePopups,
    required this.timeSec,
    required this.hitCount,
    required this.randomThemeIndex,
    required this.randomThemeIndexPrev,
    required this.themeTransitionSec,
    this.entranceCinematicSec = 0,
    this.combo = 0,
    this.comboMult = 1.0,
  });
}

class StickmanRunEngine {
  final List<LevelConfig> levels;
  final Random _rng;
  GameSettings _settings;

  /// Active skill effects (always-on once owned).
  SkillConfig _skills;

  StickmanRunEngine({
    List<LevelConfig>? levels,
    int? seed,
    GameSettings? settings,
    SkillConfig? skills,
  }) : levels = levels ?? LevelConfig.all(),
       _rng = Random(seed),
       _settings = settings ?? const GameSettings(),
       _skills = skills ?? const SkillConfig();

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
  final List<SmashDebris> _smashDebris = [];
  final List<SmashScorePopup> _smashScorePopups = [];

  GameStatus _status = GameStatus.ready;

  // HUD
  int _score = 0;
  int _coinsCollected = 0;
  double _distanceMeters = 0;

  // Life: 0..100. Big obstacles -10, small -5. game over at 0.
  double _lifePercent = 100.0;

  // Post-hit invulnerability (seconds) so a touching column doesn't drain HP.
  double _damageGraceSec = 0;
  // Seconds remaining of the red hit-flash effect.
  double _damageFlashSec = 0;
  // Seconds remaining of the green heal-flash effect.
  double _healFlashSec = 0;

  // Power-ups timers
  double _shieldRemainingSec = 0;
  double _magnetRemainingSec = 0;

  // Crawl (lower head while still running)
  double _crawlRemainingSec = 0;

  // Double jump: the stickman can jump once more while airborne, then must
  // land again before jumping again. 1 = one extra air-jump remaining.
  int _airJumpsLeft = 1;

  // Smash (punch/destroy front obstacle)
  double _smashActiveSec = 0;
  double _smashCooldownSecRemaining = 0;
  static const double _smashDurationSec = 0.18;

  // --- Skill-driven combo / buff state ---
  int _comboCount = 0;
  double _comboWindowSec = 0;
  double _comboMult = 1.0;
  double _perfectLandingBoostSec = 0;
  double _shieldChargeMeters = 0;
  double _overdriveSec = 0;
  int _coinStreak = 0;
  double _coinStreakBurstSec = 0;
  bool _wasAirborne = false;

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

  // Obstacles spawn cadence adapts to difficulty.
  // Deterministic base cadence, then randomized per spawn so gaps vary.
  double _baseSpawnEverySec = 1;
  double _nextSpawnEverySec = 1;

  // Coin size (visual + collision) from user settings.
  double _coinRadiusMultiplier = 1.0;

  double _timeSec = 0;

  /// Total damage events this run (drives per-hit haptic feedback).
  int _hitCount = 0;

  /// Cycled visual theme index (0..4) for the RANDOM/endless level.
  int _randomThemeIndex = 0;

  /// Previous cycled theme index, used to crossfade cinematic transitions.
  int _randomThemeIndexPrev = 0;

  /// Seconds remaining of the cinematic theme-change transition (0 = none).
  double _themeTransitionSec = 0;

  /// Seconds remaining of the entrance cinematic (0 = none). Set only by
  /// [triggerCinematic] (start/retry/restart), so mid-run scene changes stay
  /// purely visual and never suppress input.
  double _entranceCinematicSec = 0;

  /// Duration of the cinematic theme-change transition.
  static const double themeTransitionDurationSec = 1.4;

  /// Last 500m milestone crossed for the RANDOM/endless level. A change here
  /// (independent of the drawn theme index) triggers exactly one theme draw.
  int _randomThemeBand = 0;

  /// Shuffled "bag" of the five visual themes (0..4) for the RANDOM/endless
  /// level. Consumed one per milestone; refilled with a fresh shuffle so no
  /// theme repeats until all five have been shown. The currently displayed
  /// theme is never inside the bag.
  final List<int> _randomThemeBag = [];

  /// Draws the next endless theme from the shuffled bag, refilling (and
  /// reshuffling) the bag whenever it runs dry. A freshly-refilled bag never
  /// yields the currently displayed theme as its first draw, so the same scene
  /// never shows twice in a row across a cycle boundary.
  int _nextRandomTheme() {
    if (_randomThemeBag.isEmpty) {
      _randomThemeBag.addAll([0, 1, 2, 3, 4]);
      _randomThemeBag.shuffle(_rng);
      while (_randomThemeBag.isNotEmpty &&
          _randomThemeBag.first == _randomThemeIndex) {
        _randomThemeBag.shuffle(_rng);
      }
    }
    return _randomThemeBag.removeAt(0);
  }

  /// Triggers the cinematic bloom + theme-name banner transition on demand
  /// (e.g. when the player starts or restarts a run).
  void triggerCinematic() {
    _themeTransitionSec = themeTransitionDurationSec;
    _entranceCinematicSec = themeTransitionDurationSec;
  }

  StickmanRunSnapshot snapshot() {
    return StickmanRunSnapshot(
      status: _status,
      levelIndex: _level.levelIndex,
      score: _score,
      coins: _coinsCollected,
      distanceMeters: _distanceMeters,
      lifePercent: _lifePercent,
      damageFlashSec: _damageFlashSec,
      damageGraceSec: _damageGraceSec,
      healFlashSec: _healFlashSec,
      shieldActive: _shieldRemainingSec > 0,
      shieldRemainingSec: _shieldRemainingSec,
      magnetActive: _magnetRemainingSec > 0,
      magnetRemainingSec: _magnetRemainingSec,
      crawlingActive: _crawlRemainingSec > 0,
      crawlRemainingSec: _crawlRemainingSec,
      smashActive: _smashActiveSec > 0,
      smashRemainingSec: _smashActiveSec,
      smashCooldownSec: _smashCooldownSecRemaining,
      stickman: _stickman,
      obstacles: List.unmodifiable(_obstacles),
      coinsOnTrack: List.unmodifiable(_coins),
      powerUps: List.unmodifiable(_powerUps),
      smashDebris: List.unmodifiable(_smashDebris),
      smashScorePopups: List.unmodifiable(_smashScorePopups),
      timeSec: _timeSec,
      hitCount: _hitCount,
      randomThemeIndex: _randomThemeIndex,
      randomThemeIndexPrev: _randomThemeIndexPrev,
      themeTransitionSec: _themeTransitionSec,
      entranceCinematicSec: _entranceCinematicSec,
      combo: _comboCount,
      comboMult: _comboMult,
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

    // Apply the global difficulty preset to this level's tuning.
    final difficulty = _settings.difficulty;
    final t = _level.tuning;
    _level = _level.copyWith(
      tuning: t.copyWith(
        speed: t.speed * difficulty.speedMultiplier,
        obstacleSpawnEvery:
            t.obstacleSpawnEvery * difficulty.spawnIntervalMultiplier,
        coinChance: (t.coinChance * difficulty.coinMultiplier).clamp(0.0, 1.0),
        powerUpChance: (t.powerUpChance * difficulty.powerUpMultiplier).clamp(
          0.0,
          1.0,
        ),
      ),
    );

    _coinRadiusMultiplier = _settings.coinSize.radiusMultiplier;

    _obstacles.clear();
    _coins.clear();
    _powerUps.clear();
    _smashDebris.clear();
    _smashScorePopups.clear();

    _status = GameStatus.ready;
    _score = 0;
    _coinsCollected = 0;
    _distanceMeters = 0;
    _lifePercent = _skills.startLife;
    _damageGraceSec = 0;
    _damageFlashSec = 0;
    _healFlashSec = 0;

    _shieldRemainingSec = 0;
    _magnetRemainingSec = 0;
    _crawlRemainingSec = 0;

    _initialObstacleDelaySec = 0;
    _spawnTimerSec = 0;
    _spawnTick = 0;
    _levelTimeSec = 0;

    _timeSec = 0;
    _randomThemeBand = 0;
    _randomThemeIndex = 0;
    _randomThemeIndexPrev = 0;
    // The starting scene (theme 0) is already displayed, so the first bag
    // holds the other four themes. Once it runs dry all five have been shown
    // and the next refill draws a full new shuffle.
    _randomThemeBag
      ..clear()
      ..addAll([1, 2, 3, 4])
      ..shuffle(_rng);
    _themeTransitionSec = 0;
    _entranceCinematicSec = 0;
    _hitCount = 0;

    _comboCount = 0;
    _comboWindowSec = 0;
    _comboMult = 1.0;
    _perfectLandingBoostSec = 0;
    _shieldChargeMeters = 0;
    _overdriveSec = 0;
    _coinStreak = 0;
    _coinStreakBurstSec = 0;

    // Place stickman at ground.
    _stickman = Stickman(x: _stickmanX, y: _groundY, vy: 0);
    _airJumpsLeft = 1;

    _recomputeSpawnCadence();
    _rollNextSpawnInterval();
  }

  /// Applies live setting changes (e.g. changed from the in-pause settings
  /// screen) without resetting the current run. Difficulty multipliers are
  /// re-derived from the pristine level tuning so they aren't double-applied.
  void updateSettings(GameSettings settings) {
    _settings = settings;

    final difficulty = _settings.difficulty;
    final base = levels[_level.levelIndex - 1];
    final t = base.tuning;
    _level = _level.copyWith(
      tuning: t.copyWith(
        speed: t.speed * difficulty.speedMultiplier,
        obstacleSpawnEvery:
            t.obstacleSpawnEvery * difficulty.spawnIntervalMultiplier,
        coinChance: (t.coinChance * difficulty.coinMultiplier).clamp(0.0, 1.0),
        powerUpChance: (t.powerUpChance * difficulty.powerUpMultiplier).clamp(
          0.0,
          1.0,
        ),
      ),
    );

    _coinRadiusMultiplier = _settings.coinSize.radiusMultiplier;

    _recomputeSpawnCadence();
    _rollNextSpawnInterval();
  }

  void startRunning() {
    if (_status == GameStatus.ready ||
        _status == GameStatus.levelComplete ||
        _status == GameStatus.gameOver) {
      // If game over/complete, treat startRunning as “restart current level”.
      if (_status == GameStatus.gameOver ||
          _status == GameStatus.levelComplete) {
        start(levelIndex: _level.levelIndex);
      }

      _status = GameStatus.running;

      // Short invulnerability window for the first spawn.
      _collisionGraceSec = 0.25;

      // Extra safety window when the player has the endless-stamina skill.
      if (_level.levelIndex == 6 && _skills.endlessStamina > 0) {
        _collisionGraceSec =
            max(_collisionGraceSec, _skills.endlessStartGraceSec);
      }

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

    // Only allow a jump while on the ground — no re-jumping or floating while
    // airborne. This stops the stickman from bouncing repeatedly on taps.
    final onGround = (_groundY - _stickman.y).abs() < 4.0;

    // Double jump: on the ground we do the full jump; while airborne we allow
    // one extra mid-air jump that cuts the fall, then no more until landing.
    if (onGround) {
      // Full jump.
      const jumpHeightPx = 120.0;
      _stickman = _stickman.copyWith(
        y: _groundY - jumpHeightPx,
        vy: _level.tuning.jumpVelocity,
      );

      // Grant back the extra air jump for when the player leaves the ground.
      _airJumpsLeft = 1;

      // Critical for "tap near obstacle" timing:
      // if the tap happens late, the stickman may still intersect on the
      // first frame after the jump. A short grace window makes jumps reliable.
      _postJumpCollisionGraceSec = 0.12;
    } else if (_airJumpsLeft > 0) {
      // Mid-air double jump: heave upward off whatever vertical velocity we
      // currently have so it feels like a distinct second impulse.
      _stickman = _stickman.copyWith(vy: _level.tuning.jumpVelocity);
      _airJumpsLeft = 0;
    }
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

  /// Smash — destroys any obstacle within reach in front of the stickman.
  void smash() {
    if (_status != GameStatus.running) return;
    if (_smashCooldownSecRemaining > 0) return;

    _smashActiveSec = _smashDurationSec;
    _smashCooldownSecRemaining = _skills.smashCooldownSec;

    // The attack range matches the farthest extent of the punch animation's
    // impact spark: body lean + fully extended fist + burst radius.
    final w = _stickmanWidthPx();
    final h = _stickmanHeightPx();
    final s = min(w, h) * 0.5;
    final smashRange = 0.97 * w + 1.6 * s;

    // Destroy obstacles within smash range (in front of stickman).
    double? firstHitX;
    double? firstHitY;
    int hitCount = 0;
    _obstacles.removeWhere((o) {
      final dist = o.x - _stickman.x;
      if (dist < 0 || dist > smashRange) return false;

      // Vertical reach follows the stickman's current height so the punch
      // can smash flying obstacles while the stickman is airborne.
      final verticalHit =
          o.y + o.height > _stickman.y - _stickmanHeightPx() * 1.6;
      if (!verticalHit) return false;

      _spawnSmashDebris(o);
      if (firstHitX == null) {
        firstHitX = o.x + o.width / 2;
        firstHitY = o.y + o.height / 2;
      }
      hitCount++;
      return true;
    });

    // Only award points and show a popup when an obstacle was actually defeated.
    if (hitCount > 0) {
      // Combo: consecutive smash streaks without taking a hit amplify score.
      if (_skills.comboRamp > 0) {
        _comboWindowSec = _skills.comboWindowSec;
        _comboCount = min(_comboCount + 1, _skills.comboCap);
        final k = _comboCount;
        _comboMult = 1.0 + (0.5 * _skills.comboRamp) * (k - 1);
      }

      // Overdrive: a brief invulnerability window after striking.
      if (_skills.overdrive > 0) {
        _overdriveSec = max(_overdriveSec, _skills.overdriveWindowSec);
      }

      final mult = _comboMult;
      final gained = (5 * hitCount * mult).round();
      _score += gained;
      _smashScorePopups.add(
        SmashScorePopup(
          x: firstHitX!,
          y: firstHitY!,
          remainingSec: 0.8,
          score: gained,
        ),
      );
    }
  }

  /// Spawns particle debris at the obstacle's center for the shatter effect.
  /// Debris flies outward in the direction from the stickman toward the obstacle.
  void _spawnSmashDebris(Obstacle o) {
    const debrisCount = 10;
    final cx = o.x + o.width / 2;
    final cy = o.y + o.height / 2;

    // Direction from stickman center to obstacle center.
    final stickmanCenterY = _stickman.y - _stickmanHeightPx() * 0.4;
    final dx = cx - _stickman.x;
    final dy = cy - stickmanCenterY;
    final baseAngle = atan2(dy, dx);

    for (int i = 0; i < debrisCount; i++) {
      // Spread debris ±72° around the stickman→obstacle direction.
      final spread = (_rng.nextDouble() - 0.5) * pi * 0.8;
      final angle = baseAngle + spread;
      final speed = 180 + _rng.nextDouble() * 420;
      _smashDebris.add(
        SmashDebris(
          x: cx,
          y: cy,
          vx: cos(angle) * speed,
          vy: sin(angle) * speed,
          remainingSec: 0.3 + _rng.nextDouble() * 0.2,
          size: 3.0 + _rng.nextDouble() * 7.0,
          obstacleType: o.type,
        ),
      );
    }
  }

  /// Updates smash debris positions, lifetimes, and removes expired particles.
  void _updateSmashDebris(double dtSec) {
    for (int i = _smashDebris.length - 1; i >= 0; i--) {
      final d = _smashDebris[i];
      final newRemaining = d.remainingSec - dtSec;
      if (newRemaining <= 0) {
        _smashDebris.removeAt(i);
        continue;
      }
      _smashDebris[i] = d.copyWith(
        x: d.x + d.vx * dtSec,
        y: d.y + d.vy * dtSec,
        vy: d.vy + 800 * dtSec, // gravity
        remainingSec: newRemaining,
      );
    }
  }

  /// Updates smash score popups (float upward, fade, and removes expired ones).
  void _updateSmashScorePopups(double dtSec) {
    for (int i = _smashScorePopups.length - 1; i >= 0; i--) {
      final p = _smashScorePopups[i];
      final newRemaining = p.remainingSec - dtSec;
      if (newRemaining <= 0) {
        _smashScorePopups.removeAt(i);
        continue;
      }
      // Float upward at ~45 px/s.
      _smashScorePopups[i] = p.copyWith(
        y: p.y - 45 * dtSec,
        remainingSec: newRemaining,
      );
    }
  }

  void tick(double dtSec) {
    if (_status != GameStatus.running) {
      _timeSec += dtSec;
      return;
    }

    _timeSec += dtSec;
    _levelTimeSec += dtSec;

    // RANDOM/endless level: rotate the visual theme every 500 meters, with a
    // cinematic transition. Themes are drawn from a shuffled bag (a fresh
    // shuffle of all five scenes) so no theme repeats until the whole set has
    // been shown.
    if (_level.levelIndex == 6) {
      // Scene duration scales by 2x each scene: scene 1 = 2, scene 2 = 4,
      // scene 3 = 6, scene 4 = 8 ... multipliers of a 250m base, i.e.
      // 500m, 1000m, 1500m, 2000m, ... The next milestone is the cumulative
      // sum of those intervals. Themes are drawn from a shuffled bag (a fresh
      // shuffle of all five scenes) so no theme repeats until all are shown.
      final nextScene = _randomThemeBand + 1;
      final nextMilestoneMeters = 100 * (nextScene * (nextScene + 1) ~/ 2);
      if (_distanceMeters >= nextMilestoneMeters) {
        _randomThemeBand = nextScene;
        _randomThemeIndexPrev = _randomThemeIndex;
        _randomThemeIndex = _nextRandomTheme();
        _themeTransitionSec = themeTransitionDurationSec;
      }
    }
    _themeTransitionSec = max(0, _themeTransitionSec - dtSec);
    _entranceCinematicSec = max(0, _entranceCinematicSec - dtSec);

    _collisionGraceSec = max(0, _collisionGraceSec - dtSec);
    _postJumpCollisionGraceSec = max(0, _postJumpCollisionGraceSec - dtSec);
    _damageGraceSec = max(0, _damageGraceSec - dtSec);
    _damageFlashSec = max(0, _damageFlashSec - dtSec);
    _healFlashSec = max(0, _healFlashSec - dtSec);

    _crawlRemainingSec = max(0, _crawlRemainingSec - dtSec);
    _smashActiveSec = max(0, _smashActiveSec - dtSec);
    _smashCooldownSecRemaining = max(0, _smashCooldownSecRemaining - dtSec);

    // Decay temporary skill-driven buffs.
    _overdriveSec = max(0, _overdriveSec - dtSec);
    _perfectLandingBoostSec = max(0, _perfectLandingBoostSec - dtSec);
    _coinStreakBurstSec = max(0, _coinStreakBurstSec - dtSec);

    // End a combo chain when it has been inactive past its window.
    if (_comboWindowSec > 0) {
      _comboWindowSec -= dtSec;
      if (_comboWindowSec <= 0) {
        _comboWindowSec = 0;
        _comboCount = 0;
        _comboMult = 1.0;
      }
    }
    if (_magnetRemainingSec <= 0 && _coinStreakBurstSec > 0) {
      _magnetRemainingSec = _coinStreakBurstSec;
      _coinStreakBurstSec = 0;
    }

    _initialObstacleDelaySec = max(0, _initialObstacleDelaySec - dtSec);

    // Update smash debris particles.
    _updateSmashDebris(dtSec);
    _updateSmashScorePopups(dtSec);

    _recomputeSpawnCadence();

    _updatePowerUps(dtSec);
    _updateStickmanPhysics(dtSec);
    _updateWorld(dtSec);
    _handleCollisionsAndCollect();

    // Safety clamp.
    if (_stickman.y > _groundY) {
      _stickman = _stickman.copyWith(y: _groundY, vy: 0);
    }
  }

  /// Running speed rises at each 100-meter milestone reached, for every level —
  /// matching the endless scene cadence. Bumped +5% per step, capped so endless
  /// runs don't spiral out of control.
  double _steppedSpeed() {
    final step = (_distanceMeters / 200.0).floor().clamp(0, 12);
    final base = _level.tuning.speed;
    final rampMult = _level.levelIndex == 6
        ? _skills.speedRampMult
        : 1.0;
    final boosted =
        _perfectLandingBoostSec > 0 ? _skills.perfectLandingBoostPx : 0.0;
    return base * (1 + step * 0.1 * rampMult) + boosted;
  }

  void _recomputeSpawnCadence() {
    // Difficulty: ramp spawn rate slightly as coins increase.
    final base = _level.tuning.obstacleSpawnEvery;

    // Make obstacles a bit more frequent over time.
    final timeRamp = min(0.35, _levelTimeSec / 90.0 * 0.35);
    final coinRampSpawn = min(0.25, _coinsCollected / 35.0 * 0.25);

    _baseSpawnEverySec = max(0.55, base * (1 - timeRamp - coinRampSpawn));
  }

  /// Rolls a random spawn interval so obstacle gaps vary: sometimes close
  /// together, sometimes far apart (0.6x to 2.0x the base cadence).
  void _rollNextSpawnInterval() {
    _nextSpawnEverySec = _baseSpawnEverySec * (0.6 + _rng.nextDouble() * 1.4);
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
      _airJumpsLeft = 1;
      // Perfect landing: coming down after a jump grants a speed burst.
      if (_skills.perfectLanding > 0 && _wasAirborne) {
        _perfectLandingBoostSec = _skills.perfectLandingDurationSec;
      }
      _wasAirborne = false;
      return;
    }

    _wasAirborne = true;
    _stickman = _stickman.copyWith(y: nextY, vy: nextVy);
  }

  void _updateWorld(double dtSec) {
    // Move and spawn with world scrolling:
    // Obstacles/coins/powerups move left, stickman stays horizontally.
    final speed = _steppedSpeed();

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
        _rollNextSpawnInterval();
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

    // Magnet pull: attract coins toward the stickman's head, moving diagonally
    // anywhere on screen (50% of the screen) — no ground forcing.
    if (_magnetRemainingSec > 0 && _coins.isNotEmpty) {
      final magnetRange = max(_width, _height) * 0.5 * _skills.magnetRangeMult;
      final targetX = _stickman.x;
      final targetY = _stickman.y - _stickmanHeightPx() / 2;
      const double pullStrength = 500.0;
      const double angularVelocity = 2.0;
      for (var i = 0; i < _coins.length; i++) {
        final c = _coins[i];
        final dx = targetX - c.x;
        final dy = targetY - c.y;
        final dist = sqrt(dx * dx + dy * dy);
        if (dist > magnetRange || dist < 1) continue;

        final pullX = (dx / dist) * pullStrength * dtSec;
        final pullY = (dy / dist) * pullStrength * dtSec;
        final orbitX = (-dy / dist) * angularVelocity * dist * dtSec;
        final orbitY = (dx / dist) * angularVelocity * dist * dtSec;

        _coins[i] = c.copyWith(
          x: c.x + pullX + orbitX,
          y: c.y + pullY + orbitY,
        );
      }
    }

    _distanceMeters += dx / 100.0;

    // Shield charge skill: regenerate a partial shield over distance.
    if (_skills.shieldCharge > 0 && _shieldRemainingSec <= 0) {
      _shieldChargeMeters += dx / 100.0;
      if (_shieldChargeMeters >= _skills.shieldChargeEveryMeters) {
        _shieldChargeMeters = 0;
        _shieldRemainingSec = max(_shieldRemainingSec, _skills.shieldChargeAmount);
      }
    }

    // Remove out-of-screen entities.
    final leftKill = -140.0;
    _obstacles.removeWhere((o) => o.x + o.width < leftKill);
    _coins.removeWhere((c) => c.x + c.radius < leftKill);
    _powerUps.removeWhere((p) => p.x + p.size * 0.5 < leftKill);
  }

  void _spawnObstacleColumn() {
    // Choose a rule index using ruleOrder progression.
    final ruleIndex =
        _level.ruleOrder[(_spawnTick ~/ 3) % _level.ruleOrder.length];
    final candidateRuleIndices = _level.obstacleRules
        .asMap()
        .entries
        .where((e) => e.key == ruleIndex)
        .map((e) => e.key)
        .toList();

    final chosenRule = candidateRuleIndices.isEmpty
        ? _pickWeightedRule()
        : _level.obstacleRules[candidateRuleIndices.first];

    // Spawn columns from the far right edge of the screen.
    // For the very first column, spawn much further right so it enters
    // the viewport from the right side (not appearing mid-screen).
    // Add random variation (±60px) so obstacle distances aren't identical.
    final baseX = (_spawnTick <= 1) ? (_width + 260) : (_width + 60);
    final colX = baseX + (_rng.nextDouble() - 0.5) * 200;

    final stickmanBottom = _groundY;
    final r = _rng.nextDouble();

    // Spawn coins near columns if allowed.
    if (chosenRule.spawnCoins && r <= _level.tuning.coinChance) {
      _spawnCoinsAroundColumn(colX: colX, bottomY: stickmanBottom);
    }

    // Spawn power-ups.
    if (chosenRule.powerUps.isNotEmpty &&
        _rng.nextDouble() <= _level.tuning.powerUpChance) {
      _spawnPowerUpNearColumn(
        colX: colX,
        bottomY: stickmanBottom,
        available: chosenRule.powerUps,
      );
    }

    // Spawn 1-2 obstacles depending on spawnTick & difficulty.
    final obstacleCount = (_spawnTick % 8 == 0) ? 2 : 1;

    for (var j = 0; j < obstacleCount; j++) {
      final obstacleType = chosenRule
          .obstacleTypes[_rng.nextInt(chosenRule.obstacleTypes.length)];
      final obstacle = _makeObstacle(
        type: obstacleType,
        x: colX + j * 30,
        bottomY: stickmanBottom,
      );
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

    final needsForeground =
        type == ObstacleType.rollingRock || type == ObstacleType.pendulumMine;

    final rotation = (type == ObstacleType.pendulumMine)
        ? (_rng.nextDouble() - 0.5) * 0.6
        : 0.0;
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
    final total = _level.obstacleRules.fold<double>(
      0,
      (sum, r) => sum + r.weight,
    );
    final target = _rng.nextDouble() * (total == 0 ? 1 : total);

    double acc = 0;
    for (final r in _level.obstacleRules) {
      acc += r.weight;
      if (target <= acc) return r;
    }
    return _level.obstacleRules.last;
  }

  void _spawnCoinsAroundColumn({
    required double colX,
    required double bottomY,
  }) {
    // Spawn 1-3 coins.
    final count = 1 + _rng.nextInt(3);
    final baseY = bottomY - (80 + _rng.nextDouble() * 110);

    for (var i = 0; i < count; i++) {
      final radius = (5.5 + _rng.nextDouble() * 2.5) * _coinRadiusMultiplier;
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
    final stickmanH = _crawlRemainingSec > 0
        ? baseStickmanH * 0.58
        : baseStickmanH;

    // Magnet: if active, coins become easier to collect and are pulled
    // toward the stickman within a wide radius (50% of the screen).
    final magnetPull = _magnetRemainingSec > 0;

    // Coin collection.
    if (_coins.isNotEmpty) {
      final magnetRange =
          magnetPull ? max(_width, _height) * 0.5 * _skills.magnetRangeMult : 42.0;
      _coins.removeWhere((c) {
        final dx = (c.x - _stickman.x).abs();
        if (dx > magnetRange) return false;

        final coinRect = c.collisionRect();
        final stickRect = _stickman.collisionRect(
          width: stickmanW,
          height: stickmanH,
        );
        final hit =
            coinRect.intersects(stickRect) || dx < 18 && _stickman.y < c.y + 18;

        if (hit) {
          _coinsCollected += 1;
          final coinGain = (10 * _skills.coinValueMult).round();
          var scoreGain = (coinGain * _skills.scoreMult).round();
          // Skill: coin streak triggers a magnet burst.
          if (_skills.coinStreak > 0) {
            _coinStreak += 1;
            if (_coinStreak % _skills.coinStreakEvery == 0) {
              _coinStreakBurstSec = _skills.coinStreakBurstSec;
            }
          }
          scoreGain = (scoreGain * _comboMult).round();
          _score += scoreGain;
          _smashScorePopups.add(
            SmashScorePopup(x: c.x, y: c.y, remainingSec: 0.8, score: scoreGain),
          );
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
          _score += (25 * _skills.scoreMult).round();
        } else if (p.type == PowerUpType.magnet) {
          _magnetRemainingSec = max(
            _magnetRemainingSec,
            6.0 * _skills.magnetDurationMult,
          );
          _score += (25 * _skills.scoreMult).round();
        } else if (p.type == PowerUpType.heal25) {
          _lifePercent = min(100.0, _lifePercent + 25 + _skills.healBonus);
          _score += (15 * _skills.scoreMult).round();
          _healFlashSec = max(_healFlashSec, 0.35);
        } else if (p.type == PowerUpType.heal50) {
          _lifePercent = min(100.0, _lifePercent + 50 + _skills.healBonus);
          _score += (15 * _skills.scoreMult).round();
          _healFlashSec = max(_healFlashSec, 0.45);
        }

        return true;
      });
    }

    // Obstacle collisions.
    final destroyedByShield = <Obstacle>[];
    for (final o in _obstacles) {
      // If we're moving upward, make collision non-lethal so late taps don't
      // instantly kill before the jump is visually confirmed.
      if (_stickman.vy < 0) continue;

      if (_collisionGraceSec > 0 || _postJumpCollisionGraceSec > 0) continue;

      final or = o.collisionRect();
      final sr = _stickman.collisionRect(width: stickmanW, height: stickmanH);
      if (!or.intersects(sr)) continue;

      if (_shieldRemainingSec > 0) {
        destroyedByShield.add(o);
        continue;
      }

      // Invulnerable right after taking damage (grace window) so a single
      // touching column can't drain all life at once.
      if (_damageGraceSec > 0) continue;

      // Overdrive window: invulnerable right after a smash.
      if (_overdriveSec > 0) continue;

      _lifePercent = max(0, _lifePercent - _obstacleDamage(o.type));
      _damageGraceSec = 0.5 + _skills.damageGraceBonus;
      _damageFlashSec = 0.35;
      _hitCount += 1;
      // Getting hit resets the combo chain.
      _comboCount = 0;
      _comboMult = 1.0;
      _smashScorePopups.add(
        SmashScorePopup(
          x: o.x + o.width / 2,
          y: o.y + o.height / 2,
          remainingSec: 0.8,
          score: -_obstacleDamage(o.type),
        ),
      );

      if (_lifePercent <= 0) {
        _status = GameStatus.gameOver;
        return;
      }
    }

    if (destroyedByShield.isNotEmpty) {
      for (final o in destroyedByShield) {
        _spawnSmashDebris(o);
        _score += 5;
        _smashScorePopups.add(
          SmashScorePopup(
            x: o.x + o.width / 2,
            y: o.y + o.height / 2,
            remainingSec: 0.8,
            score: 5,
          ),
        );
      }
      _obstacles.removeWhere(destroyedByShield.contains);
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

  /// Life lost on collision. Big obstacles -10, small -5.
  int _obstacleDamage(ObstacleType type) {
    switch (type) {
      case ObstacleType.stalagmite:
      case ObstacleType.cactus:
      case ObstacleType.rollingRock:
      case ObstacleType.pendulumMine:
        return 10;
      case ObstacleType.spike:
      case ObstacleType.drone:
      case ObstacleType.laser:
      case ObstacleType.bat:
      case ObstacleType.fireJet:
      case ObstacleType.fireball:
        return 5;
    }
  }
}
