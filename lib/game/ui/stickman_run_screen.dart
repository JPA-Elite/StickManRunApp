import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engine/entities.dart';
import '../engine/stickman_run_engine.dart';
import '../settings/game_settings.dart';
import '../settings/legendary_defs.dart';
import '../settings/score_history.dart';
import '../settings/settings_controller.dart';
import '../settings/daily_mission.dart';
import '../settings/daily_streak.dart';
import '../settings/skill_controller.dart';
import 'haptics.dart';
import 'stickman_guide.dart';
import 'menu_backdrop.dart';
import 'settings_screen.dart';
import 'stickman_run_painter.dart';

class StickmanRunScreen extends StatefulWidget {
  final int initialLevel;

  const StickmanRunScreen({super.key, required this.initialLevel});

  @override
  State<StickmanRunScreen> createState() => _StickmanRunScreenState();
}

class _StickmanRunScreenState extends State<StickmanRunScreen>
    with SingleTickerProviderStateMixin {
  late final StickmanRunEngine _engine;
  late final AnimationController _controller;

  bool _paused = false;
  bool _showPauseCard = false;
  bool _confirmingRestart = false;

  /// Screen X where the smash indicator is pinned while AUTO-STRIKE is
  /// active (locked when the skill starts so it stays steady instead of
  /// chasing the teleporting stickman); null otherwise.
  double? _autoStrikeIndicatorX;

  StickmanRunSnapshot _snapshot = StickmanRunSnapshot(
    status: GameStatus.ready,
    levelIndex: 1,
    score: 0,
    coins: 0,
    distanceMeters: 0,
    lifePercent: 100,
    damageFlashSec: 0,
    damageGraceSec: 0,
    healFlashSec: 0,
    shieldActive: false,
    shieldRemainingSec: 0,
    magnetActive: false,
    magnetRemainingSec: 0,
    crawlingActive: false,
    crawlRemainingSec: 0,
    smashActive: false,
    smashRemainingSec: 0,
    smashCooldownSec: 0,
    stickman: Stickman(x: 0, y: 0, vy: 0),
    obstacles: [],
    coinsOnTrack: [],
    powerUps: [],
    smashDebris: [],
    smashScorePopups: [],
    timeSec: 0,
    hitCount: 0,
    randomThemeIndex: 0,
    randomThemeIndexPrev: 0,
    themeTransitionSec: 0,
  );

  int _levelIndex = 1;
  late GameSettings _settings;
  final Map<String, ui.Image> _sprites = {};
  final Map<String, Color> _spriteColors = {};

  static const List<String> _spriteAssets = [
    'assets/images/cactus_obstacle.png',
    'assets/images/spike_obstacle.png',
    'assets/images/stalagmite_obstacle.png',
    'assets/images/rollingrock_obstacle.png',
    'assets/images/drone_obstacle.png',
    'assets/images/laser_obstacle.png',
    'assets/images/bat_obstacle.png',
    'assets/images/firejet_obstacle.png',
    'assets/images/fireball_obstacle.png',
    'assets/images/pendulummine_obstacle.png',
    'assets/images/forest_background.png',
    'assets/images/desert_background.png',
    'assets/images/nightcity_background.png',
    'assets/images/darkcave_background.png',
    'assets/images/volcano_background.png',
  ];

  @override
  void initState() {
    super.initState();
    _settings = SettingsController.instance.settings;
    _engine = StickmanRunEngine(
      settings: _settings,
      skills: SkillController.instance.config,
      legendaries: SkillController.instance.active,
      legendaryTiers: SkillController.instance.legendaryTiers,
    );
    _engine.start(levelIndex: widget.initialLevel);
    _levelIndex = widget.initialLevel;
    SettingsController.instance.addListener(_onSettingsChanged);
    _loadSprites();

    _snapshot = _engine.snapshot();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _controller.addListener(_tick);
    // We start running after first frame so layout is known.
    WidgetsBinding.instance.addPostFrameCallback((_) => _controller.repeat());
  }

  @override
  void dispose() {
    SettingsController.instance.removeListener(_onSettingsChanged);
    _controller.dispose();
    for (final image in _sprites.values) {
      image.dispose();
    }
    _sprites.clear();
    _spriteColors.clear();
    super.dispose();
  }

  /// Decodes obstacle sprites for the painter. Until they finish loading, the
  /// painter falls back to the hand-drawn neon shapes.
  Future<void> _loadSprites() async {
    for (final asset in _spriteAssets) {
      await _loadSprite(asset);
    }
  }

  /// Decodes obstacle sprites at a small size so their crisp, high-res detail
  /// is softened into a gentle cartoon look during play (less harsh on the
  /// eyes) while also cutting memory and paint cost.
  Future<void> _loadSprite(String asset) async {
    try {
      final data = await rootBundle.load(asset);
      final bytes = data.buffer.asUint8List();
      final isBackground =
          asset == 'assets/images/forest_background.png' ||
          asset == 'assets/images/desert_background.png' ||
          asset == 'assets/images/nightcity_background.png' ||
          asset == 'assets/images/darkcave_background.png' ||
          asset == 'assets/images/volcano_background.png';
      final size = _pngSize(bytes);
      int? targetWidth;
      int? targetHeight;
      // Obstacle sprites are decoded small for a soft cartoon look, but the
      // level background keeps its full resolution so it stays sharp.
      if (size != null && !isBackground) {
        const maxSide = 128.0;
        final scale = maxSide / max(size.$1, size.$2);
        if (scale < 1) {
          targetWidth = (size.$1 * scale).round();
          targetHeight = (size.$2 * scale).round();
        }
      }
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );
      final frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      // Cartoonize the sprite (flat colors + ink outline) so the detailed
      // art reads as a soft cartoon during play. The laser and the level
      // background keep their original look.
      var sprite = frame.image;
      final cartoonized =
          asset != 'assets/images/laser_obstacle.png' &&
          asset != 'assets/images/cactus_obstacle.png' &&
          asset != 'assets/images/forest_background.png' &&
          asset != 'assets/images/desert_background.png' &&
          asset != 'assets/images/nightcity_background.png' &&
          asset != 'assets/images/darkcave_background.png' &&
          asset != 'assets/images/volcano_background.png';
      if (cartoonized) {
        try {
          final cartoon = await _cartoonize(frame.image);
          if (!identical(cartoon, frame.image)) {
            sprite = cartoon;
            frame.image.dispose();
          }
        } catch (_) {}
      } else if (asset == 'assets/images/cactus_obstacle.png' ||
          asset == 'assets/images/stalagmite_obstacle.png') {
        // Slightly darken the cactus/stalagmite art while keeping its
        // original colors.
        try {
          final darkened = await _darken(
            frame.image,
            factor: 0.72,
            alphaFactor: 0.9,
          );
          if (!identical(darkened, frame.image)) {
            sprite = darkened;
            frame.image.dispose();
          }
        } catch (_) {}
      }
      if (!mounted) {
        sprite.dispose();
        return;
      }
      final dominant = await _dominantColor(sprite);
      if (!mounted) {
        sprite.dispose();
        return;
      }
      setState(() {
        _sprites[asset] = sprite;
        if (dominant != null) _spriteColors[asset] = dominant;
      });
    } catch (_) {
      // Keep the neon fallback if a sprite can't be loaded.
    }
  }

  /// Converts a sprite to a flat cartoon: quantized colors, boosted
  /// saturation, and a dark ink outline around transparent edges.
  Future<ui.Image> _cartoonize(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return image;
    final src = data.buffer.asUint8List();
    final w = image.width;
    final h = image.height;
    final out = Uint8List(w * h * 4);

    const q = 64; // color levels per channel (4 bands).
    const sat = 1.35;

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = (y * w + x) * 4;
        final a = src[i + 3];
        if (a < 8) continue;
        final r = src[i].toDouble();
        final g = src[i + 1].toDouble();
        final b = src[i + 2].toDouble();
        final lum = 0.299 * r + 0.587 * g + 0.114 * b;
        out[i] = (lum + (r - lum) * sat).clamp(0.0, 255.0) ~/ q * q;
        out[i + 1] = (lum + (g - lum) * sat).clamp(0.0, 255.0) ~/ q * q;
        out[i + 2] = (lum + (b - lum) * sat).clamp(0.0, 255.0) ~/ q * q;
        out[i + 3] = a;
      }
    }

    // Ink outline: darken opaque pixels that touch transparent ones.
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = (y * w + x) * 4;
        if (out[i + 3] == 0) continue;
        var edge = false;
        for (var dy = -1; dy <= 1 && !edge; dy++) {
          for (var dx = -1; dx <= 1 && !edge; dx++) {
            if (dx == 0 && dy == 0) continue;
            final nx = x + dx;
            final ny = y + dy;
            if (nx < 0 || ny < 0 || nx >= w || ny >= h) {
              edge = true;
              break;
            }
            if (src[((ny * w + nx) * 4) + 3] < 64) {
              edge = true;
              break;
            }
          }
        }
        if (edge) {
          out[i] = 8;
          out[i + 1] = 8;
          out[i + 2] = 12;
          out[i + 3] = 255;
        }
      }
    }

    final buffer = await ui.ImmutableBuffer.fromUint8List(out);
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: w,
      height: h,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final codec = await descriptor.instantiateCodec();
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  /// Reads the PNG width/height from its IHDR header so we can decode at a
  /// smaller size. Returns null for non-PNG data.

  /// Multiplies the RGB of every opaque pixel by [factor] (0..1 darkens,
  /// >1 brightens) while leaving the alpha untouched. Used to gently darken
  /// sprites that keep their original detail.
  Future<ui.Image> _darken(
    ui.Image image, {
    required double factor,
    double alphaFactor = 1.0,
  }) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return image;
    final src = data.buffer.asUint8List();
    final w = image.width;
    final h = image.height;
    final out = Uint8List(w * h * 4);
    for (var i = 0; i < src.length; i += 4) {
      out[i] = (src[i] * factor).round().clamp(0, 255);
      out[i + 1] = (src[i + 1] * factor).round().clamp(0, 255);
      out[i + 2] = (src[i + 2] * factor).round().clamp(0, 255);
      out[i + 3] = (src[i + 3] * alphaFactor).round().clamp(0, 255);
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(out);
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: w,
      height: h,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final codec = await descriptor.instantiateCodec();
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  (int, int)? _pngSize(Uint8List bytes) {
    if (bytes.length < 24) return null;
    // PNG signature + IHDR length/type, then 4-byte big-endian width/height.
    if (bytes[0] != 0x89 ||
        bytes[1] != 0x50 ||
        bytes[2] != 0x4E ||
        bytes[3] != 0x47) {
      return null;
    }
    int readInt(int o) =>
        (bytes[o] << 24) |
        (bytes[o + 1] << 16) |
        (bytes[o + 2] << 8) |
        bytes[o + 3];
    return (readInt(16), readInt(20));
  }

  /// Approximates the sprite's main color by averaging its non-transparent
  /// pixels of a sampled subset (used for obstacle damage/debris color).
  Future<Color?> _dominantColor(ui.Image image) async {
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return null;
      final bytes = data.buffer.asUint8List();
      final pxCount = image.width * image.height;
      final stride = pxCount > 60000 ? (pxCount ~/ 60000) : 1;
      var r = 0.0, g = 0.0, b = 0.0, n = 0.0;
      for (var i = 0; i < pxCount; i += stride) {
        final o = i * 4;
        if (bytes[o + 3] < 16) continue;
        r += bytes[o];
        g += bytes[o + 1];
        b += bytes[o + 2];
        n += 1;
      }
      if (n == 0) return null;
      return Color.fromARGB(
        255,
        (r / n).round(),
        (g / n).round(),
        (b / n).round(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Reflects settings changed from the in-pause settings screen without
  /// losing the current run: rebuilds (controls/colors) and re-applies the
  /// engine-level settings (difficulty, coin size).
  void _onSettingsChanged() {
    setState(() {
      _settings = SettingsController.instance.settings;
    });
    _engine.updateSettings(_settings);
  }

  double _lastTime = 0;
  bool _wasSmashActive = false;
  int _lastHitCount = 0;

  // --- Legendary combo detection (in-memory, reset per run) ---
  static const int _comboWindowMicros =
      1300000; // 1.3s window for a 3-input combo
  final List<(ComboAction, int)> _comboBuffer = [];
  String _legendaryBanner = '';
  double _legendaryBannerSec = 0;

  /// Records an input action for legendary combo detection and fires a
  /// legendary skill when an owned combo is matched.
  void _recordComboInput(ComboAction action) {
    final now = DateTime.now().microsecondsSinceEpoch;
    _comboBuffer.add((action, now));
    _comboBuffer.removeWhere((e) => now - e.$2 > _comboWindowMicros);

    for (final def in LegendaryDef.all) {
      if (!_engine.owns(def.id)) continue;
      if (def.combo.isEmpty) continue; // no combo trigger (unused)
      if (action != def.combo[def.combo.length - 1]) continue;
      if (_comboMatches(def.combo)) {
        _tryTriggerLegendary(def);
        break;
      }
    }
  }

  bool _comboMatches(List<ComboAction> pattern) {
    if (_comboBuffer.length < pattern.length) return false;
    for (var i = 0; i < pattern.length; i++) {
      if (_comboBuffer[_comboBuffer.length - pattern.length + i].$1 !=
          pattern[i]) {
        return false;
      }
    }
    return true;
  }

  void _tryTriggerLegendary(LegendaryDef def) {
    if (SkillController.instance.legendaryCooldownRemainingSec(def.id) > 0) {
      return;
    }

    if (!_engine.triggerLegendary(def.id)) return;
    SkillController.instance.recordLegendaryUse(def.id);
    _comboBuffer.clear();

    if (_settings.vibrationsEnabled) {
      vibrate(HapticIntensity.heavy);
    }
    setState(() {
      _legendaryBanner = def.name;
      _legendaryBannerSec = 1.6;
      _snapshot = _engine.snapshot();
    });
  }

  void _tick() {
    final now = _controller.lastElapsedDuration?.inMicroseconds.toDouble() ?? 0;
    if (_lastTime == 0) {
      _lastTime = now;
      return;
    }

    final dtMicro = now - _lastTime;
    _lastTime = now;

    final dtSec = max(0.0001, dtMicro / 1e6);
    final wasRunning = _snapshot.status == GameStatus.running;
    final wasAutoStrike = _snapshot.autoStrikeSec > 0;
    _engine.tick(dtSec);

    setState(() {
      _snapshot = _engine.snapshot();
    });

    // While AUTO-STRIKE is active, pin the smash indicator to the position
    // it had when the skill started so it never jumps around with the
    // stickman's teleport leaps.
    if (_snapshot.autoStrikeSec > 0) {
      _autoStrikeIndicatorX ??= _snapshot.stickman.x;
    } else if (wasAutoStrike) {
      _autoStrikeIndicatorX = null;
    }

    // Vibrate when the smash actually impacts (animation starts).
    if (!_wasSmashActive && _snapshot.smashActive) {
      if (_settings.vibrationsEnabled) {
        vibrate(HapticIntensity.heavy);
      }
    }
    _wasSmashActive = _snapshot.smashActive;

    // Decay the legendary activation banner.
    if (_legendaryBannerSec > 0) {
      _legendaryBannerSec -= dtSec;
      if (_legendaryBannerSec <= 0) _legendaryBanner = '';
    }

    // Vibrate on every obstacle hit (damage taken), not just at game over.
    if (_snapshot.hitCount != _lastHitCount) {
      _lastHitCount = _snapshot.hitCount;
      if (_settings.vibrationsEnabled) {
        vibrate(HapticIntensity.light);
      }
    }

    // When a run ends (game over or level complete), record score, award coins,
    // and check the daily mission.
    if (wasRunning &&
        (_snapshot.status == GameStatus.gameOver ||
            _snapshot.status == GameStatus.levelComplete)) {
      // Vibrate on obstacle-hit death (not on level complete).
      if (_snapshot.status == GameStatus.gameOver &&
          _settings.vibrationsEnabled) {
        vibrate(HapticIntensity.heavy);
      }
      // Record the finished run for the score history.
      if (_snapshot.score > 0) {
        ScoreHistoryController.instance.add(
          ScoreRecord(
            score: _snapshot.score,
            coins: _snapshot.coins,
            distanceMeters: _snapshot.distanceMeters,
            levelIndex: _snapshot.levelIndex,
            timestamp: DateTime.now(),
          ),
        );
      }
      // Award collected coins to the skill wallet.
      SkillController.instance.awardCoins(_snapshot.coins);
      // Check daily mission score threshold.
      DailyMissionController.instance.checkScore(_snapshot.score);
      // Auto check-in for the daily streak when a run finishes.
      DailyStreakController.instance.checkIn();
      // Fully reset legendary cooldowns so no READY IN pills linger on the
      // game-over / level-complete screen and the next run starts fresh.
      SkillController.instance.resetLegendaryCooldowns();
    }
  }

  int _lastJumpMicros = 0;
  static const int _jumpCooldownMicros = 180000; // ~180ms

  void _onJump() {
    debugPrint('StickmanRunScreen: _onJump fired');

    final nowMicros = DateTime.now().microsecondsSinceEpoch;
    if (nowMicros - _lastJumpMicros < _jumpCooldownMicros) return;
    _lastJumpMicros = nowMicros;

    _recordComboInput(ComboAction.jump);

    _engine.startRunning();
    _engine.jump();
    _engine.tick(1 / 60.0);

    if (_settings.vibrationsEnabled) {
      vibrate(HapticIntensity.heavy);
    }

    setState(() {
      _snapshot = _engine.snapshot();
    });
  }

  void _onSmash() {
    if (_snapshot.status != GameStatus.running) return;

    // Register the input for legendary combos even while the smash is
    // cooling down, so combos like attack · attack · jump can be entered
    // back-to-back without waiting out the full smash cooldown between
    // presses. The actual smash effect is still gated by the cooldown.
    _recordComboInput(ComboAction.smash);

    if (_snapshot.smashCooldownSec > 0) return;

    _engine.smash();
    setState(() => _snapshot = _engine.snapshot());
  }

  /// Tap-to-jump has been removed; use the JUMP button (buttons mode)
  /// or swipe gestures to jump.
  bool get _canTapToJump => false;

  /// True while the cinematic entrance transition is playing (bloom + theme
  /// banner). The game HUD stays hidden until it finishes.
  bool get _cinematicActive => _snapshot.entranceCinematicSec > 0;

  /// In gestures mode a single tap smashes (cooldown handled by the engine).
  bool get _canTapToSmash =>
      _settings.controlScheme == ControlScheme.gestures &&
      _snapshot.status == GameStatus.running &&
      !_paused &&
      !_cinematicActive;

  /// True when swipe gestures control jump/crawl (running and not paused).
  bool get _gesturesActive =>
      _settings.controlScheme == ControlScheme.gestures &&
      _snapshot.status == GameStatus.running &&
      !_paused &&
      !_cinematicActive;

  /// True when a steady (long) press on the screen can trigger TIME REWIND:
  /// requires the skill, an active run, and no pause/cinematic overlay.
  bool get _canRewindHold =>
      _engine.owns(LegendarySkill.reverseRun) &&
      _snapshot.status == GameStatus.running &&
      !_paused &&
      !_cinematicActive;

  /// Steady long-press is the trigger for TIME REWIND. If it is ready it
  /// starts a timed rewind window and enters the shared legendary cooldown.
  void _onRewindHold() {
    _tryTriggerLegendary(LegendaryDef.forId(LegendarySkill.reverseRun));
  }

  /// Velocity (px/s) a swipe must exceed to count as jump or crawl.
  static const double _swipeVelocityThreshold = 400;

  void _onVerticalSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -_swipeVelocityThreshold) {
      _onJump();
    } else if (velocity > _swipeVelocityThreshold) {
      _onCrawl();
    }
  }

  void _onCrawl() {
    _recordComboInput(ComboAction.crawl);
    _engine.crawl();
    if (_settings.vibrationsEnabled) {
      vibrate(HapticIntensity.light);
    }
    setState(() => _snapshot = _engine.snapshot());
  }

  void _pause() {
    _paused = true;
    _showPauseCard = true;
    _controller.stop();
    setState(() {});
  }

  void _resume() {
    _paused = false;
    _showPauseCard = false;
    _lastTime = 0;
    _lastHitCount = 0;
    _controller.repeat();
    setState(() {});
  }

  Future<void> _confirmRestart() async {
    setState(() => _confirmingRestart = true);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111318),
        title: const Text(
          'Restart level?',
          style: TextStyle(
            color: Colors.yellow,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: const Text(
          'Your current progress in this level will be lost.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'CANCEL',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'RESTART',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
    setState(() => _confirmingRestart = false);
    if (ok == true) _restartLevel();
  }

  void _restartLevel() {
    _engine.start(levelIndex: _levelIndex);
    _engine.startRunning();
    _engine.triggerCinematic();
    _paused = false;
    _showPauseCard = false;
    _lastTime = 0;
    _lastHitCount = 0;
    _comboBuffer.clear();
    _legendaryBanner = '';
    _legendaryBannerSec = 0;
    _controller.repeat();
    setState(() {
      _snapshot = _engine.snapshot();
    });
  }

  /// Opens the stickman guide page. From the in-game hint button the run is
  /// frozen while the guide is open and resumes when it closes; from the
  /// pause card the game stays paused.
  Future<void> _openGuide() async {
    if (!_paused) {
      _paused = true;
      _controller.stop();
      setState(() {});
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const StickmanGuideScreen()),
    );
    if (!_showPauseCard) _resume();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        _engine.resize(width, height);

        return Scaffold(
          backgroundColor: Colors.black,
          body: SizedBox.expand(
            // The game surface rebuilds every animation frame (progress bars,
            // HUD pills, toggling controls). Feeding that churn into the
            // semantics tree each frame trips a framework assertion
            // (`!semantics.parentDataDirty`). Exclude the play-layer semantics
            // to keep the fast-changing widgets out of the semantics tree.
            // NOTE: Positioned children must stay direct Stack children, so the
            // ExcludeSemantics wraps the whole Stack rather than any overlay.
            child: ExcludeSemantics(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _canTapToJump
                          ? _onJump
                          : (_canTapToSmash ? _onSmash : null),
                      onVerticalDragEnd: _gesturesActive
                          ? _onVerticalSwipe
                          : null,
                      onLongPressStart: _canRewindHold
                          ? (_) => _onRewindHold()
                          : null,
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: StickmanRunPainter(
                            snapshot: _snapshot,
                            level:
                                _engine.snapshot().levelIndex ==
                                    _snapshot.levelIndex
                                ? _engine.levels[_levelIndex - 1]
                                : _engine.levels[(_snapshot.levelIndex - 1)
                                      .clamp(0, _engine.levels.length - 1)],
                            width: width,
                            height: height,
                            stickmanColor: Color(_settings.stickmanColor),
                            highContrast: _settings.highContrast,
                            sprites: _sprites,
                            spriteColors: _spriteColors,
                          ),
                        ),
                      ),
                    ),
                  ),
                  _buildOverlay(),
                  _buildTopButtons(),
                  _buildLegendaryHud(width: width),
                  _buildSmashButton(width: width, height: height),
                  _buildJumpButton(width: width, height: height),
                  _buildCrawlButton(width: width, height: height),
                  _buildPauseOverlay(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Pause + guide buttons, centered at the top. Visible only while running.
  Widget _buildTopButtons() {
    final isRunning = _snapshot.status == GameStatus.running;
    if (!isRunning || _paused || _cinematicActive)
      return const SizedBox.shrink();

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _TopCircleButton(
              icon: Icons.pause_rounded,
              tooltip: 'Pause',
              onTap: _pause,
            ),
            const SizedBox(width: 8),
            _TopCircleButton(
              icon: Icons.help_outline,
              tooltip: 'Stickman guide',
              onTap: _openGuide,
            ),
          ],
        ),
      ),
    );
  }

  /// Remaining seconds of the active duration window for [id] (0 when the
  /// skill is not currently running), used to keep READY IN pills from
  /// appearing while a skill's own duration is still on screen.
  double _activeLegendarySec(LegendarySkill id) {
    switch (id) {
      case LegendarySkill.autoStrike:
        return _snapshot.autoStrikeSec;
      case LegendarySkill.reverseRun:
        return _snapshot.reverseSec;
      case LegendarySkill.roadSweep:
        return _snapshot.roadSweepSec;
      case LegendarySkill.tempest:
        return _snapshot.tempestSec;
      case LegendarySkill.goldRush:
        return _snapshot.goldRushSec;
    }
  }

  /// Small top HUD showing the current legendary activation state: the
  Widget _buildLegendaryHud({required double width}) {
    // Never show legendary pills (duration banners or READY IN cooldowns)
    // once the run has ended — the overlay takes over the screen.
    if (_snapshot.status != GameStatus.running) return const SizedBox.shrink();

    final ownedReverse = _engine.owns(LegendarySkill.reverseRun);
    final showReverse = ownedReverse && _snapshot.reversing;
    final showAuto = _snapshot.autoStrikeSec > 0;
    final showTempest = _snapshot.tempestSec > 0;
    final showRoadSweep = _snapshot.roadSweepSec > 0;
    final showGoldRush = _snapshot.goldRushSec > 0;
    final showBanner = _legendaryBanner.isNotEmpty;

    // Cooldown pills for every owned legendary that is recharging.
    final cooldown = <Widget>[];
    for (final def in LegendaryDef.all) {
      if (!_engine.owns(def.id)) continue;
      // The cooldown pill only appears once the skill's own duration window
      // has finished, so the duration banner and READY IN never overlap.
      if (_activeLegendarySec(def.id) > 0) continue;
      final remaining = SkillController.instance.legendaryCooldownRemainingSec(
        def.id,
      );
      if (remaining <= 0) continue;
      cooldown.add(
        _hudPill(
          text:
              '${def.icon} ${def.name} READY IN ${remaining.toStringAsFixed(1)}s',
          color: const Color(0xFF9E9EA6),
        ),
      );
    }

    if (!showBanner &&
        !showReverse &&
        !showAuto &&
        !showTempest &&
        !showRoadSweep &&
        !showGoldRush &&
        cooldown.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 52,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showBanner)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3D0B22).withValues(alpha: 0.9),
                    border: Border.all(
                      color: const Color(0xFFFFD700),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'LEGENDARY!',
                    style: TextStyle(
                      color: Color(0xFFFFD700),
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              if (showAuto ||
                  showTempest ||
                  showReverse ||
                  showRoadSweep ||
                  showGoldRush ||
                  cooldown.isNotEmpty)
                const SizedBox(height: 6),
              Builder(
                builder: (_) {
                  final parts = <Widget>[];
                  if (showAuto) {
                    parts.add(
                      _hudPill(
                        text:
                            '★ AUTO-STRIKE ${_snapshot.autoStrikeSec.toStringAsFixed(1)}s',
                        color: const Color(0xFFFFD700),
                      ),
                    );
                  }
                  if (showTempest) {
                    parts.add(
                      _hudPill(
                        text:
                            '⚡ TEMPEST ${_snapshot.tempestSec.toStringAsFixed(1)}s',
                        color: const Color(0xFF4DD8FF),
                      ),
                    );
                  }
                  if (showReverse) {
                    parts.add(
                      _hudPill(
                        text:
                            '⟲ TIME REWIND ${_snapshot.reverseSec.toStringAsFixed(1)}s',
                        color: const Color(0xFFFF8A5C),
                      ),
                    );
                  }
                  if (showRoadSweep) {
                    parts.add(
                      _hudPill(
                        text:
                            '☄ ROAD SWEEP ${_snapshot.roadSweepSec.toStringAsFixed(1)}s',
                        color: const Color(0xFFFF5C8A),
                      ),
                    );
                  }
                  if (showGoldRush) {
                    parts.add(
                      _hudPill(
                        text:
                            '◈ GOLD RUSH ${_snapshot.goldRushSec.toStringAsFixed(1)}s',
                        color: const Color(0xFFFFD700),
                      ),
                    );
                  }
                  parts.addAll(cooldown);
                  return Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    children: parts,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hudPill({required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF111318).withValues(alpha: 0.85),
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  /// Full-screen pause card that blocks input while the game is paused.
  Widget _buildPauseOverlay() {
    if (!_showPauseCard || _confirmingRestart) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              width: min(340.0, MediaQuery.of(context).size.width - 32),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: const Color(0xFF111318),
                border: Border.all(color: Colors.yellow, width: 2),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'PAUSED',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.yellow,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Take a breather',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _PauseActionButton(
                    label: 'RESUME',
                    icon: Icons.play_arrow_rounded,
                    onTap: _resume,
                  ),
                  const SizedBox(height: 10),
                  _PauseActionButton(
                    label: 'RESTART LEVEL',
                    icon: Icons.replay_rounded,
                    onTap: () => _confirmRestart(),
                  ),
                  const SizedBox(height: 10),
                  _PauseActionButton(
                    label: 'GUIDE',
                    icon: Icons.help_outline,
                    onTap: _openGuide,
                  ),
                  const SizedBox(height: 10),
                  _PauseActionButton(
                    label: 'SETTINGS',
                    icon: Icons.settings,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _PauseActionButton(
                    label: 'EXIT',
                    icon: Icons.exit_to_app_rounded,
                    red: true,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSmashIndicator({required double width, required double height}) {
    if (_snapshot.status != GameStatus.running) return const SizedBox.shrink();
    final isRunning = _snapshot.status == GameStatus.running;
    final canSmash = isRunning && _snapshot.smashCooldownSec <= 0;
    final ready = canSmash && !_paused;
    final fill = (1 - _snapshot.smashCooldownSec / 1.2).clamp(0.0, 1.0);

    // Position below the stickman on the ground (stable — doesn't follow
    // jumps). During AUTO-STRIKE it stays locked to its original position
    // instead of following the teleporting stickman.
    final stickmanX = _snapshot.autoStrikeSec > 0 && _autoStrikeIndicatorX != null
        ? _autoStrikeIndicatorX!
        : _snapshot.stickman.x;
    final groundY = height * 0.78;
    const indicatorWidth = 86.0;
    final left = (stickmanX - indicatorWidth / 2).clamp(
      4.0,
      width - indicatorWidth - 4.0,
    );
    final top = groundY + 8;

    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: Container(
          width: 86,
          padding: const EdgeInsets.fromLTRB(10, 5, 10, 7),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: ready
                  ? Colors.red.withOpacity(0.9)
                  : Colors.white.withOpacity(0.15),
              width: 1.5,
            ),
            boxShadow: ready
                ? [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.5),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.sports_mma,
                size: 18,
                weight: 900,
                color: ready
                    ? Colors.redAccent
                    : Colors.white.withOpacity(0.45),
              ),
              const SizedBox(height: 3),
              SizedBox(
                width: 60,
                height: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: isRunning ? fill : 1,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      ready ? Colors.redAccent : Colors.white.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJumpButton({required double width, required double height}) {
    if (_settings.controlScheme == ControlScheme.gestures) {
      return const SizedBox.shrink();
    }
    if (_cinematicActive) return const SizedBox.shrink();
    if (_snapshot.status != GameStatus.running) return const SizedBox.shrink();
    final isRunning = _snapshot.status == GameStatus.running;
    final btn = 52.0 * _settings.jumpButtonScale;
    final left = (_settings.jumpButtonDx * width - btn / 2).clamp(
      0.0,
      width - btn,
    );
    final top = (_settings.jumpButtonDy * height - btn / 2).clamp(
      0.0,
      height - btn,
    );
    return Positioned(
      left: left,
      top: top,
      child: SizedBox(
        width: btn,
        height: btn,
        child: ElevatedButton(
          onPressed: isRunning && !_paused ? _onJump : null,
          style: _circleBtnStyle(
            isRunning: isRunning,
            activeColor: Colors.yellow,
          ),
          child: Icon(
            Icons.arrow_upward,
            size: 28 * _settings.jumpButtonScale,
            weight: 900,
          ),
        ),
      ),
    );
  }

  Widget _buildCrawlButton({required double width, required double height}) {
    if (_settings.controlScheme == ControlScheme.gestures) {
      return const SizedBox.shrink();
    }
    if (_cinematicActive) return const SizedBox.shrink();
    if (_snapshot.status != GameStatus.running) return const SizedBox.shrink();
    final isRunning = _snapshot.status == GameStatus.running;
    final btn = 52.0 * _settings.crawlButtonScale;
    final left = (_settings.crawlButtonDx * width - btn / 2).clamp(
      0.0,
      width - btn,
    );
    final top = (_settings.crawlButtonDy * height - btn / 2).clamp(
      0.0,
      height - btn,
    );
    return Positioned(
      left: left,
      top: top,
      child: SizedBox(
        width: btn,
        height: btn,
        child: ElevatedButton(
          onPressed: isRunning && !_paused ? _onCrawl : null,
          style: _circleBtnStyle(
            isRunning: isRunning,
            activeColor: Colors.cyanAccent,
          ),
          child: Icon(
            Icons.subdirectory_arrow_left,
            size: 26 * _settings.crawlButtonScale,
            weight: 900,
          ),
        ),
      ),
    );
  }

  Widget _buildSmashButton({required double width, required double height}) {
    if (_cinematicActive) return const SizedBox.shrink();
    if (_snapshot.status != GameStatus.running) return const SizedBox.shrink();
    if (_settings.controlScheme == ControlScheme.gestures) {
      return _buildSmashIndicator(width: width, height: height);
    }
    final isRunning = _snapshot.status == GameStatus.running;
    final canSmash = isRunning && _snapshot.smashCooldownSec <= 0;
    final activeRed = const Color.fromARGB(255, 220, 50, 50);
    final glowRed = const Color.fromARGB(180, 255, 80, 80);
    final s = _settings.attackButtonScale;
    final sw = 64.0 * s;
    final sh = 72.0 * s;

    return Positioned(
      left: (_settings.attackButtonDx * width - sw / 2).clamp(0.0, width - sw),
      top: (_settings.attackButtonDy * height - sh / 2).clamp(0.0, height - sh),
      child: SizedBox(
        width: sw,
        height: sh,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cooldown bar — thick, rounded, with glow when ready.
            SizedBox(
              width: 58 * s,
              height: 6 * s,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3 * s),
                child: LinearProgressIndicator(
                  value: isRunning ? (1 - _snapshot.smashCooldownSec / 1.2) : 1,
                  backgroundColor: Colors.white.withOpacity(0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    canSmash ? glowRed : Colors.grey.withOpacity(0.5),
                  ),
                ),
              ),
            ),
            SizedBox(height: 4 * s),
            // Glowing outer ring.
            Container(
              width: 60 * s,
              height: 60 * s,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: canSmash
                    ? [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.5),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: ElevatedButton(
                // Keep the button pressable during the smash cooldown so
                // legendary combos that start with repeated attacks (e.g.
                // GOLD RUSH: attack · attack · jump) can be entered without
                // waiting out the cooldown between presses.
                onPressed: isRunning && !_paused
                    ? () {
                        _onSmash();
                        if (_settings.vibrationsEnabled) {
                          vibrate(HapticIntensity.heavy);
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canSmash
                      ? activeRed
                      : activeRed.withOpacity(0.15),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white.withOpacity(0.3),
                  disabledBackgroundColor: activeRed.withOpacity(0.08),
                  shape: CircleBorder(
                    side: BorderSide(
                      color: canSmash
                          ? Colors.white.withOpacity(0.7)
                          : Colors.white.withOpacity(0.1),
                      width: 3 * s,
                    ),
                  ),
                  elevation: canSmash ? 12 : 2,
                  shadowColor: Colors.redAccent.withOpacity(0.6),
                  padding: EdgeInsets.zero,
                ),
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..rotateZ(pi / 4)
                    ..scale(-1.0, 1.0, 1.0),
                  child: Icon(
                    Icons.sports_mma,
                    size: 30 * s,
                    weight: 900,
                    color: canSmash
                        ? Colors.white
                        : Colors.white.withOpacity(0.3),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ButtonStyle _circleBtnStyle({
    required bool isRunning,
    required Color activeColor,
  }) {
    final disabled = activeColor.withOpacity(0.3);
    return ElevatedButton.styleFrom(
      backgroundColor: isRunning ? activeColor : disabled,
      foregroundColor: Colors.black,
      disabledForegroundColor: Colors.black.withOpacity(0.3),
      disabledBackgroundColor: disabled,
      shape: const CircleBorder(),
      elevation: 6,
      padding: EdgeInsets.zero,
    );
  }

  Widget _buildOverlay() {
    final isReady = _snapshot.status == GameStatus.ready;
    final isRunning = _snapshot.status == GameStatus.running;
    final isOver = _snapshot.status == GameStatus.gameOver;
    final isComplete = _snapshot.status == GameStatus.levelComplete;

    if (isRunning) return const SizedBox.shrink();

    final title = isReady
        ? 'STICKMAN RUN'
        : isOver
        ? 'GAME OVER'
        : 'LEVEL COMPLETE';

    final flicker =
        0.55 +
        0.45 *
            sin(
              (_controller.lastElapsedDuration?.inMicroseconds.toDouble() ??
                      0) /
                  1e6 *
                  7,
            );

    final subtitle = isReady
        ? 'TAP TO START'
        : isOver
        ? 'Score: ${_snapshot.score} • Coins: ${_snapshot.coins}'
        : 'Nice! Score: ${_snapshot.score} • Coins: ${_snapshot.coins}';

    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Cinematic dusk backdrop behind the overlay.
          CustomPaint(
            painter: MenuBackdropPainter(
              levelCount: _levelIndex,
              timeNow: () =>
                  (_controller.lastElapsedDuration?.inMicroseconds.toDouble() ??
                      0) /
                  1e6,
              repaint: _controller,
            ),
          ),
          // Letterbox bars (cinematic frame).
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 16,
            child: ColoredBox(color: Colors.black),
          ),
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 16,
            child: ColoredBox(color: Colors.black),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _canTapToJump ? _onJump : null,
                    child: Center(
                      child: SizedBox(
                        width: min(
                          340.0,
                          MediaQuery.of(context).size.width - 32,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            // The main overlay card.
                            GestureDetector(
                              onTap: _canTapToJump ? _onJump : null,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.9),
                                    width: 3,
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(height: 10),
                                      Text(
                                        title,
                                        style: TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: 1,
                                          shadows: [
                                            const Shadow(
                                              color: Colors.black,
                                              blurRadius: 8,
                                            ),
                                            Shadow(
                                              color: isReady
                                                  ? Colors.yellowAccent
                                                  : Colors.redAccent,
                                              blurRadius: 18,
                                            ),
                                          ],
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        subtitle,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white.withOpacity(
                                            isReady ? flicker : 1.0,
                                          ),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 14),
                                      if (!isReady)
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white
                                                .withOpacity(0.9),
                                            foregroundColor: Colors.black,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 12,
                                            ),
                                          ),
                                          onPressed: () {
                                            _engine.start(
                                              levelIndex: _levelIndex,
                                            );
                                            _engine.startRunning();
                                            _engine.triggerCinematic();
                                            setState(() {
                                              _snapshot = _engine.snapshot();
                                            });
                                          },
                                          child: const Text(
                                            'RETRY LEVEL',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      if (isReady)
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white
                                                .withOpacity(0.9),
                                            foregroundColor: Colors.black,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 12,
                                            ),
                                          ),
                                          onPressed: () {
                                            _engine.startRunning();
                                            _engine.jump();
                                            _engine.tick(1 / 60.0);
                                            _engine.triggerCinematic();
                                            if (_settings.vibrationsEnabled) {
                                              vibrate(HapticIntensity.heavy);
                                            }
                                            setState(() {
                                              _snapshot = _engine.snapshot();
                                            });
                                          },
                                          child: const Text(
                                            'START RUN',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      // EXIT button.
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: ElevatedButton.icon(
                                          icon: const Icon(
                                            Icons.exit_to_app,
                                            color: Colors.black,
                                          ),
                                          onPressed: () =>
                                              Navigator.of(context).pop(),
                                          label: const Text(
                                            'EXIT',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color.fromARGB(
                                                  255,
                                                  230,
                                                  70,
                                                  70,
                                                ),
                                            foregroundColor: Colors.black,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              side: const BorderSide(
                                                color: Colors.white,
                                                width: 2,
                                              ),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 22,
                                              vertical: 10,
                                            ),
                                            elevation: 6,
                                            shadowColor: Colors.redAccent
                                                .withOpacity(0.5),
                                          ),
                                        ),
                                      ),
                                      if (isComplete)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 10,
                                          ),
                                          child: Text(
                                            'Tap to start the next run (same level for now)',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white.withOpacity(
                                                0.85,
                                              ),
                                              fontWeight: FontWeight.w700,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TopCircleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _TopCircleButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _PauseActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool red;
  final VoidCallback onTap;

  const _PauseActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.red = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 20),
        onPressed: onTap,
        label: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: red
              ? const Color.fromARGB(255, 230, 70, 70)
              : Colors.yellow,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: red ? Colors.white : Colors.yellow,
              width: 2,
            ),
          ),
          elevation: 4,
        ),
      ),
    );
  }
}
