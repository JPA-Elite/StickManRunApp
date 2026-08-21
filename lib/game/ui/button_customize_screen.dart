import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/entities.dart';
import '../engine/level_config.dart' as lc;
import '../engine/stickman_run_engine.dart';
import '../settings/game_settings.dart';
import '../settings/settings_controller.dart';
import 'stickman_run_painter.dart';

/// Full-screen button placement editor.
///
/// Shows the exact in-game scene (road, level, HUD, stickman) with the real
/// SMASH / JUMP / CRAWL buttons overlaid, so the player can drag each button
/// to its preferred spot exactly like it will appear while playing.
class ButtonCustomizeScreen extends StatefulWidget {
  const ButtonCustomizeScreen({super.key});

  @override
  State<ButtonCustomizeScreen> createState() => _ButtonCustomizeScreenState();
}

class _ButtonCustomizeScreenState extends State<ButtonCustomizeScreen> {
  final GlobalKey _areaKey = GlobalKey();

  /// Working copy of the button layout. Only committed to the
  /// [SettingsController] (and persisted) when the user taps SAVE CHANGES.
  late GameSettings _draft;

  /// True while the draft is being persisted, so the SAVE button shows a
  /// loading spinner and ignores further taps.
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _draft = SettingsController.instance.settings;
  }

  StickmanRunSnapshot _previewSnapshot(double width, double height) {
    final groundY = height * 0.78;
    return StickmanRunSnapshot(
      status: GameStatus.running,
      levelIndex: 1,
      score: 1250,
      coins: 34,
      distanceMeters: 120,
      lifePercent: 80,
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
      stickman: Stickman(x: width * 0.22, y: groundY, vy: 0),
      obstacles: [
        Obstacle(
          type: ObstacleType.cactus,
          x: width * 0.5,
          y: groundY - 80,
          width: 34,
          height: 80,
        ),
        Obstacle(
          type: ObstacleType.spike,
          x: width * 0.62,
          y: groundY - 30,
          width: 40,
          height: 30,
        ),
        Obstacle(
          type: ObstacleType.drone,
          x: width * 0.8,
          y: groundY - 110,
          width: 30,
          height: 24,
        ),
      ],
      coinsOnTrack: [
        Coin(x: width * 0.55, y: groundY - 130, radius: 10, phase: 0),
        Coin(x: width * 0.58, y: groundY - 95, radius: 10, phase: 1),
      ],
      powerUps: const [],
      smashDebris: const [],
      smashScorePopups: const [],
      timeSec: 0,
      hitCount: 0,
      skillDamageCount: 0,
      randomThemeIndex: 0,
      randomThemeIndexPrev: 0,
      themeTransitionSec: 0,
    );
  }

  void _handleDrag(Offset globalPosition, {required String which}) {
    final box = _areaKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final size = box.size;
    if (size.width <= 0 || size.height <= 0) return;
    final local = box.globalToLocal(globalPosition);
    final dx = (local.dx / size.width).clamp(0.0, 1.0);
    final dy = (local.dy / size.height).clamp(0.0, 1.0);
    setState(() {
      switch (which) {
        case 'attack':
          _draft = _draft.copyWith(attackButtonDx: dx, attackButtonDy: dy);
        case 'jump':
          _draft = _draft.copyWith(jumpButtonDx: dx, jumpButtonDy: dy);
        case 'crawl':
          _draft = _draft.copyWith(crawlButtonDx: dx, crawlButtonDy: dy);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = _draft;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            return Stack(
              key: _areaKey,
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: StickmanRunPainter(
                        snapshot: _previewSnapshot(width, height),
                        level: lc.LevelConfig.all().first,
                        width: width,
                        height: height,
                        stickmanColor: Color(s.stickmanColor),
                        highContrast: s.highContrast,
                      ),
                    ),
                  ),
                ),
                _buildResizableButton(
                  width: width,
                  height: height,
                  dx: s.jumpButtonDx,
                  dy: s.jumpButtonDy,
                  which: 'jump',
                  scale: s.jumpButtonScale,
                  buttonW: 52,
                  buttonH: 52,
                  button: _buildJumpVisual(scale: s.jumpButtonScale),
                ),
                _buildResizableButton(
                  width: width,
                  height: height,
                  dx: s.crawlButtonDx,
                  dy: s.crawlButtonDy,
                  which: 'crawl',
                  scale: s.crawlButtonScale,
                  buttonW: 52,
                  buttonH: 52,
                  button:
                      _buildCrawlVisual(scale: s.crawlButtonScale),
                ),
                _buildResizableButton(
                  width: width,
                  height: height,
                  dx: s.attackButtonDx,
                  dy: s.attackButtonDy,
                  which: 'attack',
                  scale: s.attackButtonScale,
                  buttonW: 64,
                  buttonH: 72,
                  button: _buildSmashButtonVisual(
                    scale: s.attackButtonScale,
                  ),
                ),
                _buildTopBar(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        color: Colors.black.withValues(alpha: 0.72),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 4),
            const Expanded(
              child: Text(
                'BUTTON PLACEMENT',
                style: TextStyle(
                  color: Colors.yellow,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _draft = const GameSettings();
                });
              },
              child: const Text(
                'RESET',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _saving ? null : _saveChanges,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _saving ? Colors.yellow.withValues(alpha: 0.5) : Colors.yellow,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_saving) ...[
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      _saving ? 'SAVING...' : 'SAVE CHANGES',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  /// Commits the draft button layout to the settings controller (persisted)
  /// and returns to the settings screen.
  Future<void> _saveChanges() async {
    if (_saving) return;
    setState(() => _saving = true);
    await Future.wait([
      SettingsController.instance.applyButtonLayout(_draft),
      Future.delayed(const Duration(seconds: 1)),
    ]);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Widget _buildJumpVisual({required double scale}) {
    return SizedBox(
      width: 52 * scale,
      height: 52 * scale,
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.yellow,
          foregroundColor: Colors.black,
          shape: const CircleBorder(),
          elevation: 6,
          padding: EdgeInsets.zero,
        ),
        child: Icon(Icons.arrow_upward, size: 28 * scale, weight: 900),
      ),
    );
  }

  Widget _buildCrawlVisual({required double scale}) {
    return SizedBox(
      width: 52 * scale,
      height: 52 * scale,
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.cyanAccent,
          foregroundColor: Colors.black,
          shape: const CircleBorder(),
          elevation: 6,
          padding: EdgeInsets.zero,
        ),
        child: Icon(
          Icons.subdirectory_arrow_left,
          size: 26 * scale,
          weight: 900,
        ),
      ),
    );
  }

  Widget _buildSmashButtonVisual({required double scale}) {
    final glowRed = const Color.fromARGB(180, 255, 80, 80);
    final activeRed = const Color.fromARGB(255, 220, 50, 50);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 58 * scale,
          height: 6 * scale,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3 * scale),
            child: LinearProgressIndicator(
              value: 1,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(glowRed),
            ),
          ),
        ),
        SizedBox(height: 4 * scale),
        Container(
          width: 60 * scale,
          height: 60 * scale,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.5),
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: activeRed,
              foregroundColor: Colors.white,
              shape: CircleBorder(
                side: BorderSide(
                  color: Colors.white.withOpacity(0.7),
                  width: 3 * scale,
                ),
              ),
              elevation: 12,
              shadowColor: Colors.redAccent.withOpacity(0.6),
              padding: EdgeInsets.zero,
            ),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..rotateZ(3.141592653589793 / 4)
                ..scale(-1.0, 1.0, 1.0),
              child: Icon(Icons.sports_mma, size: 30 * scale, weight: 900),
            ),
          ),
        ),
      ],
    );
  }

  void _changeScale(String which, double delta) {
    final current = switch (which) {
      'attack' => _draft.attackButtonScale,
      'jump' => _draft.jumpButtonScale,
      _ => _draft.crawlButtonScale,
    };
    final next = (current + delta).clamp(0.5, 1.5);
    setState(() {
      switch (which) {
        case 'attack':
          _draft = _draft.copyWith(attackButtonScale: next);
        case 'jump':
          _draft = _draft.copyWith(jumpButtonScale: next);
        case 'crawl':
          _draft = _draft.copyWith(crawlButtonScale: next);
      }
    });
  }

  Widget _buildResizableButton({
    required double width,
    required double height,
    required double dx,
    required double dy,
    required String which,
    required double scale,
    required double buttonW,
    required double buttonH,
    required Widget button,
  }) {
    const controlW = 100.0;
    const controlH = 26.0;
    final bw = buttonW * scale;
    final bh = buttonH * scale;
    final totalW = math.max(bw, controlW);
    // Keep the whole control + button fully on-screen even when maximized.
    final left = (dx * width - totalW / 2)
        .clamp(0.0, math.max(0.0, width - totalW))
        .toDouble();
    final top = (dy * height - bh / 2 - controlH)
        .clamp(0.0, math.max(0.0, height - controlH - bh))
        .toDouble();
    return _PlacementButton(
      left: left,
      top: top,
      width: totalW,
      height: controlH + bh,
      onPanUpdate: (d) => _handleDrag(d.globalPosition, which: which),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ResizeControl(
            scale: scale,
            onMinus: () => _changeScale(which, -0.1),
            onPlus: () => _changeScale(which, 0.1),
          ),
          button,
        ],
      ),
    );
  }
}

/// Minus / plus resize control shown at the top of each draggable button.
/// Tapping steps by one; holding down repeats the step continuously.
class _ResizeControl extends StatefulWidget {
  final double scale;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _ResizeControl({
    required this.scale,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  State<_ResizeControl> createState() => _ResizeControlState();
}

class _ResizeControlState extends State<_ResizeControl> {
  static const Duration _repeatInterval = Duration(milliseconds: 90);
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startRepeat(VoidCallback action) {
    _timer?.cancel();
    action();
    _timer = Timer.periodic(_repeatInterval, (_) => action());
  }

  void _stopRepeat() {
    _timer?.cancel();
    _timer = null;
  }

  Widget _stepButton(IconData icon, VoidCallback action) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _startRepeat(action),
      onTapUp: (_) => _stopRepeat(),
      onTapCancel: _stopRepeat,
      onLongPress: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 26,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white30),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _stepButton(Icons.remove, widget.onMinus),
          Text(
            '${widget.scale.toStringAsFixed(1)}x',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          _stepButton(Icons.add, widget.onPlus),
        ],
      ),
    );
  }
}

/// Positions a draggable button cluster within the full-screen area.
class _PlacementButton extends StatelessWidget {
  final double left;
  final double top;
  final double width;
  final double height;
  final Widget child;
  final void Function(DragUpdateDetails) onPanUpdate;

  const _PlacementButton({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.child,
    required this.onPanUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: onPanUpdate,
        child: SizedBox(width: width, height: height, child: child),
      ),
    );
  }
}
