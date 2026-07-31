import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engine/entities.dart';
import '../engine/stickman_run_engine.dart';
import '../settings/game_settings.dart';
import '../settings/settings_controller.dart';
import 'obstacle_guide.dart';
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
  double _buttonBottom = 16;
  double _jumpSpacing = 60;

  bool _paused = false;
  bool _showPauseCard = false;

  StickmanRunSnapshot _snapshot = StickmanRunSnapshot(
    status: GameStatus.ready,
    levelIndex: 1,
    score: 0,
    coins: 0,
    distanceMeters: 0,
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
  );

  int _levelIndex = 1;
  late GameSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = SettingsController.instance.settings;
    _engine = StickmanRunEngine(settings: _settings);
    _engine.start(levelIndex: widget.initialLevel);
    _levelIndex = widget.initialLevel;
    SettingsController.instance.addListener(_onSettingsChanged);

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
    super.dispose();
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
    _engine.tick(dtSec);

    setState(() {
      _snapshot = _engine.snapshot();
    });

    // Vibrate when the smash actually impacts (animation starts).
    if (!_wasSmashActive && _snapshot.smashActive) {
      if (_settings.vibrationsEnabled) {
        HapticFeedback.heavyImpact();
      }
    }
    _wasSmashActive = _snapshot.smashActive;

    // Vibrate when the stickman hits an obstacle (game over).
    if (wasRunning && _snapshot.status == GameStatus.gameOver) {
      if (_settings.vibrationsEnabled) {
        HapticFeedback.heavyImpact();
      }
    }
  }

  int _lastJumpMicros = 0;
  static const int _jumpCooldownMicros = 180000; // ~180ms

  void _onJump() {
    debugPrint('StickmanRunScreen: _onJump fired');

    final nowMicros = DateTime.now().microsecondsSinceEpoch;
    if (nowMicros - _lastJumpMicros < _jumpCooldownMicros) return;
    _lastJumpMicros = nowMicros;

    _engine.startRunning();
    _engine.jump();
    _engine.tick(1 / 60.0);

    if (_settings.vibrationsEnabled) {
      HapticFeedback.heavyImpact();
    }

    setState(() {
      _snapshot = _engine.snapshot();
    });
  }

  void _onSmash() {
    if (_snapshot.status != GameStatus.running) return;
    if (_snapshot.smashCooldownSec > 0) return;

    _engine.smash();
    setState(() => _snapshot = _engine.snapshot());
  }

  /// Tap-to-jump has been removed; use the JUMP button (buttons mode)
  /// or swipe gestures to jump.
  bool get _canTapToJump => false;

  /// In gestures mode a single tap smashes (cooldown handled by the engine).
  bool get _canTapToSmash =>
      _settings.controlScheme == ControlScheme.gestures &&
      _snapshot.status == GameStatus.running &&
      !_paused;

  /// True when swipe gestures control jump/crawl (running and not paused).
  bool get _gesturesActive =>
      _settings.controlScheme == ControlScheme.gestures &&
      _snapshot.status == GameStatus.running &&
      !_paused;

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
    _engine.crawl();
    if (_settings.vibrationsEnabled) {
      HapticFeedback.lightImpact();
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
    _controller.repeat();
    setState(() {});
  }

  void _restartLevel() {
    _engine.start(levelIndex: _levelIndex);
    _engine.startRunning();
    _paused = false;
    _showPauseCard = false;
    _lastTime = 0;
    _controller.repeat();
    setState(() {
      _snapshot = _engine.snapshot();
    });
  }

  /// Opens the obstacle guide page. From the in-game hint button the run is
  /// frozen while the guide is open and resumes when it closes; from the
  /// pause card the game stays paused.
  Future<void> _openGuide() async {
    if (!_paused) {
      _paused = true;
      _controller.stop();
      setState(() {});
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ObstacleGuideScreen(),
      ),
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
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _canTapToJump
                        ? _onJump
                        : (_canTapToSmash ? _onSmash : null),
                    onVerticalDragEnd: _gesturesActive ? _onVerticalSwipe : null,
                    child: CustomPaint(
                      painter: StickmanRunPainter(
                        snapshot: _snapshot,
                        level:
                            _engine.snapshot().levelIndex ==
                                _snapshot.levelIndex
                            ? _engine.levels[_levelIndex - 1]
                            : _engine.levels[(_snapshot.levelIndex - 1).clamp(
                                0,
                                _engine.levels.length - 1,
                              )],
                        width: width,
                        height: height,
                        stickmanColor: Color(_settings.stickmanColor),
                        highContrast: _settings.highContrast,
                      ),
                    ),
                  ),
                ),
                _buildOverlay(),
                _buildTopButtons(),
                _buildPauseOverlay(),
                _buildSmashButton(width: width, height: height),
                _buildJumpButton(),
                _buildCrawlButton(),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Pause + guide buttons, centered at the top. Visible only while running.
  Widget _buildTopButtons() {
    final isRunning = _snapshot.status == GameStatus.running;
    if (!isRunning || _paused) return const SizedBox.shrink();

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _TopCircleButton(
              icon: Icons.pause_rounded,
              tooltip: 'Pause',
              onTap: _pause,
            ),
            const SizedBox(width: 12),
            _TopCircleButton(
              icon: Icons.help_outline,
              tooltip: 'Obstacle guide',
              onTap: _openGuide,
            ),
          ],
        ),
      ),
    );
  }

  /// Full-screen pause card that blocks input while the game is paused.
  Widget _buildPauseOverlay() {
    if (!_showPauseCard) return const SizedBox.shrink();

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
                    onTap: _restartLevel,
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
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
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
    final isRunning = _snapshot.status == GameStatus.running;
    final canSmash = isRunning && _snapshot.smashCooldownSec <= 0;
    final ready = canSmash && !_paused;
    final fill = (1 - _snapshot.smashCooldownSec / 1.2).clamp(0.0, 1.0);

    // Position below the stickman on the ground (stable — doesn't follow jumps).
    final stickmanX = _snapshot.stickman.x;
    final groundY = height * 0.78;
    const indicatorWidth = 86.0;
    final left = (stickmanX - indicatorWidth / 2).clamp(4.0, width - indicatorWidth - 4.0);
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

  Widget _buildJumpButton() {
    if (_settings.controlScheme == ControlScheme.gestures) {
      return const SizedBox.shrink();
    }
    final isRunning = _snapshot.status == GameStatus.running;
    return Positioned(
      right: 30,
      bottom: _buttonBottom + _jumpSpacing,
      child: SizedBox(
        width: 52,
        height: 52,
        child: ElevatedButton(
          onPressed: isRunning ? _onJump : null,
          style: _circleBtnStyle(
            isRunning: isRunning,
            activeColor: Colors.yellow,
          ),
          child: const Icon(Icons.arrow_upward, size: 28, weight: 900),
        ),
      ),
    );
  }

  Widget _buildCrawlButton() {
    if (_settings.controlScheme == ControlScheme.gestures) {
      return const SizedBox.shrink();
    }
    final isRunning = _snapshot.status == GameStatus.running;
    return Positioned(
      right: 30,
      bottom: _buttonBottom,
      child: SizedBox(
        width: 52,
        height: 52,
        child: ElevatedButton(
          onPressed: isRunning ? _onCrawl : null,
          style: _circleBtnStyle(
            isRunning: isRunning,
            activeColor: Colors.cyanAccent,
          ),
          child: const Icon(
            Icons.subdirectory_arrow_left,
            size: 26,
            weight: 900,
          ),
        ),
      ),
    );
  }

  Widget _buildSmashButton({required double width, required double height}) {
    if (_settings.controlScheme == ControlScheme.gestures) {
      return _buildSmashIndicator(width: width, height: height);
    }
    final isRunning = _snapshot.status == GameStatus.running;
    final canSmash = isRunning && _snapshot.smashCooldownSec <= 0;
    final activeRed = const Color.fromARGB(255, 220, 50, 50);
    final glowRed = const Color.fromARGB(180, 255, 80, 80);

    return Positioned(
      left: 30,
      bottom: _buttonBottom,
      child: SizedBox(
        width: 64,
        height: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cooldown bar — thick, rounded, with glow when ready.
            SizedBox(
              width: 58,
              height: 6,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: isRunning ? (1 - _snapshot.smashCooldownSec / 1.2) : 1,
                  backgroundColor: Colors.white.withOpacity(0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    canSmash ? glowRed : Colors.grey.withOpacity(0.5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Glowing outer ring.
            Container(
              width: 60,
              height: 60,
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
                onPressed: canSmash
                    ? () {
                        _engine.smash();
                        if (_settings.vibrationsEnabled) {
                          HapticFeedback.heavyImpact();
                        }
                        setState(() => _snapshot = _engine.snapshot());
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
                      width: 3,
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
                    size: 30,
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

    final subtitle = isReady
        ? 'Survive & collect coins'
        : isOver
        ? 'Score: ${_snapshot.score} • Coins: ${_snapshot.coins}'
        : 'Nice! Score: ${_snapshot.score} • Coins: ${_snapshot.coins}';

    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _canTapToJump ? _onJump : null,
                child: Center(
                  child: SizedBox(
                    width: min(340.0, MediaQuery.of(context).size.width - 32),
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
                              color: Colors.black.withOpacity(0.5),
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
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 1,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    subtitle,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
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
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 12,
                                        ),
                                      ),
                                      onPressed: () {
                                        _engine.start(levelIndex: _levelIndex);
                                        _engine.startRunning();
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
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
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
                                          if (_settings.vibrationsEnabled) {
                                            HapticFeedback.heavyImpact();
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
                                        backgroundColor: const Color.fromARGB(
                                          255,
                                          230,
                                          70,
                                          70,
                                        ),
                                        foregroundColor: Colors.black,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
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
                                      padding: const EdgeInsets.only(top: 10),
                                      child: Text(
                                        'Tap to start the next run (same level for now)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white.withOpacity(0.85),
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
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Icon(icon, color: Colors.white, size: 26),
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
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: red
              ? const Color.fromARGB(255, 230, 70, 70)
              : Colors.yellow,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: red ? Colors.white : Colors.yellow, width: 2),
          ),
          elevation: 4,
        ),
      ),
    );
  }
}
