import 'dart:math';

import 'package:flutter/material.dart';

import '../engine/entities.dart';
import '../engine/stickman_run_engine.dart';
import 'stickman_run_painter.dart';

class StickmanRunScreen extends StatefulWidget {
  final int initialLevel;

  const StickmanRunScreen({
    super.key,
    required this.initialLevel,
  });

  @override
  State<StickmanRunScreen> createState() => _StickmanRunScreenState();
}

class _StickmanRunScreenState extends State<StickmanRunScreen> with SingleTickerProviderStateMixin {
  late final StickmanRunEngine _engine;
  late final AnimationController _controller;
  double _buttonBottom = 16;
  double _jumpSpacing = 60;

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
    smashCooldownSec: 0,
    stickman: Stickman(x: 0, y: 0, vy: 0),
    obstacles: [],
    coinsOnTrack: [],
    powerUps: [],
    timeSec: 0,
  );

  int _levelIndex = 1;

  @override
  void initState() {
    super.initState();
    _engine = StickmanRunEngine();
    _engine.start(levelIndex: widget.initialLevel);
    _levelIndex = widget.initialLevel;

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
    _controller.dispose();
    super.dispose();
  }

  double _lastTime = 0;

  void _tick() {
    final now = _controller.lastElapsedDuration?.inMicroseconds.toDouble() ?? 0;
    if (_lastTime == 0) {
      _lastTime = now;
      return;
    }

    final dtMicro = now - _lastTime;
    _lastTime = now;

    final dtSec = max(0.0001, dtMicro / 1e6);
    _engine.tick(dtSec);

    setState(() {
      _snapshot = _engine.snapshot();
    });
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

    setState(() {
      _snapshot = _engine.snapshot();
    });
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
                  child: CustomPaint(
                    painter: StickmanRunPainter(
                      snapshot: _snapshot,
                      level: _engine.snapshot().levelIndex == _snapshot.levelIndex
                          ? _engine.levels[_levelIndex - 1]
                          : _engine.levels[(_snapshot.levelIndex - 1).clamp(0, _engine.levels.length - 1)],
                      width: width,
                      height: height,
                    ),
                  ),
                ),
                _buildOverlay(),
                _buildSmashButton(),
                _buildJumpButton(),
                _buildCrawlButton(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildJumpButton() {
    final isRunning = _snapshot.status == GameStatus.running;
    return Positioned(
      right: 14,
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
    final isRunning = _snapshot.status == GameStatus.running;
    return Positioned(
      right: 14,
      bottom: _buttonBottom,
      child: SizedBox(
        width: 52,
        height: 52,
        child: ElevatedButton(
          onPressed: isRunning
              ? () {
                  _engine.crawl();
                  setState(() => _snapshot = _engine.snapshot());
                }
              : null,
          style: _circleBtnStyle(
            isRunning: isRunning,
            activeColor: Colors.cyanAccent,
          ),
          child: const Icon(Icons.subdirectory_arrow_left, size: 26, weight: 900),
        ),
      ),
    );
  }

  Widget _buildSmashButton() {
    final isRunning = _snapshot.status == GameStatus.running;
    final canSmash = isRunning && _snapshot.smashCooldownSec <= 0;
    final activeRed = const Color.fromARGB(255, 220, 50, 50);
    final glowRed = const Color.fromARGB(180, 255, 80, 80);

    return Positioned(
      left: 10,
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
                onPressed: canSmash ? () {
                  _engine.smash();
                  setState(() => _snapshot = _engine.snapshot());
                } : null,
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
                child: Icon(
                  Icons.sports_kabaddi,
                  size: 30,
                  weight: 900,
                  color: canSmash ? Colors.white : Colors.white.withOpacity(0.3),
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
        ? 'Tap anywhere to JUMP • Survive & collect coins'
        : isOver
            ? 'Score: ${_snapshot.score} • Coins: ${_snapshot.coins}'
            : 'Nice! Score: ${_snapshot.score} • Coins: ${_snapshot.coins}';

    return Positioned(
      left: 0,
      right: 0,
      top: 80,
      child: Center(
        child: SizedBox(
          width: min(420.0, MediaQuery.of(context).size.width - 32),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Back button positioned top-left of the card.
              Positioned(
                top: 0,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                  ),
                ),
              ),
              // The main overlay card.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  border: Border.all(color: Colors.white.withOpacity(0.9), width: 3),
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
                            backgroundColor: Colors.yellow,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      if (isReady)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.9),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          onPressed: () {
                            _engine.startRunning();
                            _engine.jump();
                            _engine.tick(1 / 60.0);
                            setState(() {
                              _snapshot = _engine.snapshot();
                            });
                          },
                          child: const Text(
                            'START RUN',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      // EXIT button.
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.exit_to_app, color: Colors.black),
                          onPressed: () => Navigator.of(context).pop(),
                          label: const Text('EXIT', style: TextStyle(fontWeight: FontWeight.w900)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(255, 230, 70, 70),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(color: Colors.white, width: 2),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                            elevation: 6,
                            shadowColor: Colors.redAccent.withOpacity(0.5),
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
            ],
          ),
        ),
      ),
    );
  }
}
