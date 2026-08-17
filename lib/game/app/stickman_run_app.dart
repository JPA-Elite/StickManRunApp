import 'dart:math';

import 'package:flutter/material.dart';

import '../settings/rank.dart';
import '../settings/score_history.dart';
import '../settings/settings_controller.dart';
import '../settings/skill_controller.dart';
import '../ui/daily_streak_screen.dart';
import '../ui/menu_backdrop.dart';
import '../ui/profile_screen.dart';
import '../ui/shop_screen.dart';
import '../ui/stickman_guide.dart';
import '../ui/score_history_screen.dart';
import '../ui/settings_screen.dart';
import '../ui/skills_screen.dart';
import '../ui/stickman_avatar.dart';
import '../ui/stickman_run_screen.dart';
import '../../game/engine/level_config.dart' as engine;

class StickmanRunApp extends StatefulWidget {
  const StickmanRunApp({super.key});

  @override
  State<StickmanRunApp> createState() => _StickmanRunAppState();
}

class _StickmanRunAppState extends State<StickmanRunApp>
    with TickerProviderStateMixin {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final PageController _pageController = PageController(viewportFraction: 0.6);
  int _selectedLevel = 1;
  bool _showLevelSelect = false;

  /// Fires the level-up check whenever a pushed route (e.g. a finished run)
  /// is popped back to the homepage, where [initState] would not re-run.
  late final NavigatorObserver _levelUpObserver = _LevelUpObserver(
    onReturnToHome: _maybeCelebrateLevelUp,
  );

  late final AnimationController _backdropController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();

  /// Monotonic clock (seconds) for the backdrop so parallax scrolls forward
  /// continuously instead of looping back each tick.
  final Stopwatch _backdropClock = Stopwatch()..start();

  /// Drives the one-time "level up" cinematic celebration overlay.
  late final AnimationController _celebrationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );

  /// Rank tier to celebrate (1-based). Null when no celebration is pending.
  int? _pendingCelebrationTier;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeCelebrateLevelUp());
  }

  void _maybeCelebrateLevelUp() {
    // Only celebrate on the level-select homepage, never on the very first
    // landing page before the home page, and never for the starting rank L1.
    if (!_showLevelSelect) return;
    final history = ScoreHistoryController.instance;
    final total = _totalScore(history);
    final tier = rankForScore(total).level;
    if (tier > history.lastCelebratedTier && tier > 1) {
      history.setLastCelebratedTier(tier);
      setState(() => _pendingCelebrationTier = tier);
      _celebrationController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _backdropController.dispose();
    _celebrationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: false,
      scaffoldBackgroundColor: Colors.black,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: Colors.yellow,
        onPrimary: Colors.black,
        secondary: Colors.cyanAccent,
        onSecondary: Colors.black,
        surface: Colors.black,
        onSurface: Colors.white,
        error: Colors.red,
        onError: Colors.white,
      ),
      fontFamily: 'monospace',
    );

    final levels = engine.LevelConfig.all();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      navigatorKey: _navigatorKey,
      navigatorObservers: [_levelUpObserver],
      home: ListenableBuilder(
        listenable: ScoreHistoryController.instance,
        builder: (context, _) => Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: MenuBackdropPainter(
                    levelCount: levels.length,
                    timeNow: () => _backdropClock.elapsedMilliseconds / 1000.0,
                    repaint: _backdropController,
                  ),
                ),
              ),
              // Full-width layout centered in the actual screen width
              // (no SafeArea, so header/cards/footer are not shifted by
              // asymmetric system padding).
              Stack(
                children: [
                  // Full-width header bar (level select page only).
                  if (_showLevelSelect)
                    Positioned(top: 0, left: 0, right: 0, child: _BrandCard()),
                  // Main content — fills the screen so cards can grow as
                  // large as possible.
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          if (!_showLevelSelect) ...[
                            const Spacer(flex: 3),                            // Big title (no brand card in way)
                            const Text(
                              'STICKMAN\nRUN',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 52,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 2,
                                height: 1.1,
                                shadows: [
                                  Shadow(color: Colors.black, blurRadius: 10),
                                  Shadow(
                                    color: Color(0xFF4DD8FF),
                                    blurRadius: 26,
                                  ),
                                  Shadow(
                                    color: Colors.yellowAccent,
                                    blurRadius: 14,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Jump obstacles • Collect coins',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 28),
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _showLevelSelect = true),
                              child: AnimatedBuilder(
                                animation: _backdropController,
                                builder: (context, _) {
                                  final t = _backdropController.value * 2 * pi;
                                  final pulse = 0.5 + 0.5 * sin(t);
                                  return Container(
                                    width: 100 + pulse * 6,
                                    height: 100 + pulse * 6,
                                    decoration: BoxDecoration(
                                      color: Colors.yellow,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 4,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.yellow.withOpacity(
                                            0.35 + pulse * 0.3,
                                          ),
                                          blurRadius: 24 + pulse * 14,
                                          spreadRadius: 2 + pulse * 3,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.play_arrow,
                                      size: 56,
                                      color: Colors.black,
                                    ),
                                  );
                                },
                              ),
                            ),
                            const Spacer(flex: 4),
                          ] else ...[
                            // Room for the full-width header bar rendered above.
                            const SizedBox(height: 64),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Positioned.fill(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                      ),
                                      child: PageView.builder(
                                        controller: _pageController,
                                        itemCount: levels.length,
                                        onPageChanged: (index) {
                                          setState(
                                            () => _selectedLevel =
                                                levels[index].levelIndex,
                                          );
                                        },
                                        itemBuilder: (context, index) {
                                          final l = levels[index];
                                          final isActive =
                                              l.levelIndex == _selectedLevel;
                                          return _CarouselLevelCard(
                                            level: l,
                                            isActive: isActive,
                                            bestScore: ScoreHistoryController
                                                .instance
                                                .bestForLevel(l.levelIndex),
                                            starCount: (l.levelIndex.clamp(
                                              1,
                                              5,
                                            )),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 24),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: _PressableScale(
                                        child: _CinematicOrbit(
                                          accent: const Color(0xFFFFD54F),
                                          child: IconButton(
                                            icon: const Icon(
                                              Icons.emoji_events,
                                              color: Colors.yellow,
                                              size: 26,
                                            ),
                                            tooltip: 'Score History',
                                            onPressed: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      const ScoreHistoryScreen(),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                _PressableScale(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      _navigatorKey.currentState!.push(
                                        MaterialPageRoute(
                                          builder: (_) => StickmanRunScreen(
                                            initialLevel: _selectedLevel,
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.play_arrow,
                                      color: Colors.black,
                                    ),
                                    label: const Text(
                                      'PLAY LEVEL',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.yellow,
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          16,
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 32,
                                        vertical: 10,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 24),
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: _PressableScale(
                                        child: _CinematicOrbit(
                                          accent: const Color(0xFF4DD8FF),
                                          child: IconButton(
                                            icon: const Icon(
                                              Icons.menu_book,
                                              color: Colors.white,
                                              size: 26,
                                            ),
                                            tooltip: 'Skills',
                                            onPressed: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      const SkillsScreen(),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (_pendingCelebrationTier != null)
                _LevelUpCelebration(
                  tier: _pendingCelebrationTier!,
                  controller: _celebrationController,
                  onDismiss: () =>
                      setState(() => _pendingCelebrationTier = null),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withOpacity(0.06),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          const _RunnerProfile(),
          const SizedBox(width: 12),
          const Spacer(),
          // Permanent coin wallet badge — always visible in the home header.
          // Tapping it opens the coin shop.
          _PressableScale(
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ShopScreen()),
                );
              },
              child: ListenableBuilder(
                listenable: SkillController.instance,
                builder: (context, _) {
                  final wallet = SkillController.instance.wallet;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.45),
                      ),
                      color: Colors.white.withValues(alpha: 0.06),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x1F_D7FF_FF),
                          Color(0x0A_FFFFFF),
                        ],
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.monetization_on,
                          color: Color(0xFFFFD700),
                          size: 18,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          formatCoinAmount(wallet),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white, size: 24),
            tooltip: 'How to Play',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StickmanGuideScreen()),
              );
            },
          ),
          ListenableBuilder(
            listenable: SettingsController.instance,
            builder: (context, _) {
              final muted =
                  !SettingsController.instance.settings.vibrationsEnabled;
              return IconButton(
                icon: Icon(
                  muted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                  size: 24,
                ),
                tooltip: muted ? 'Sound: Off' : 'Sound: On',
                onPressed: () {
                  SettingsController.instance.setVibrationsEnabled(muted);
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.local_fire_department,
              color: Colors.orangeAccent,
              size: 24,
            ),
            tooltip: 'Daily Streak',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DailyStreakScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white, size: 24),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
          const SizedBox(width: 9          ),
        ],
      ),
    );
  }
}

/// Wraps [child] with a tactile press scale: it shrinks to [scale] while
/// pressed and springs back on release. Uses raw [Listener] pointer events so
/// the wrapped button's own tap handling is never interfered with.
class _PressableScale extends StatefulWidget {
  final Widget child;
  final double scale;

  const _PressableScale({
    required this.child,
    this.scale = 0.9,
  });

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Cinematic orbit ring that wraps a trailing icon button (e.g. trophy or
/// skills) with a steady accent ring and a soft glow. Keeps the child's tap
/// target exactly where it was.
class _CinematicOrbit extends StatelessWidget {
  const _CinematicOrbit({
    required this.child,
    required this.accent,
  });

  final Widget child;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    const s = 60.0;
    return SizedBox(
      width: s,
      height: s,
      child: CustomPaint(
        painter: _OrbitPainter(accent: accent),
        child: Center(child: child),
      ),
    );
  }
}

/// Paints a steady orbit ring with a soft glow for [_CinematicOrbit].
class _OrbitPainter extends CustomPainter {
  _OrbitPainter({required this.accent});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final ringR = size.width * 0.40;

    // 1) Soft ambient glow under the ring.
    canvas.drawCircle(
      center,
      ringR * 1.15,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: 0.20),
            accent.withValues(alpha: 0.0),
          ],
        ).createShader(
          Rect.fromCircle(center: center, radius: ringR * 1.15),
        ),
    );

    // 2) Steady conic-gradient ring (accent + white highlights, no rotation).
    canvas.drawCircle(
      center,
      ringR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: 2 * pi,
          colors: [
            accent.withValues(alpha: 0.25),
            accent,
            Colors.white.withValues(alpha: 0.95),
            accent,
            accent.withValues(alpha: 0.25),
          ],
          stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
        ).createShader(
          Rect.fromCircle(center: center, radius: ringR),
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) =>
      oldDelegate.accent != accent;
}

/// Lifetime total score accumulated across all recorded runs (survives
/// clearing the score history).
int _totalScore(ScoreHistoryController history) => history.accumulatedScore;

/// Fires [onReturnToHome] whenever a pushed route is popped and the homepage
/// becomes current again, so the level-up celebration can trigger after a run
/// finishes (initState only runs once at app launch).
class _LevelUpObserver extends NavigatorObserver {
  final VoidCallback onReturnToHome;

  _LevelUpObserver({required this.onReturnToHome});

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null && previousRoute.isCurrent) {
      // Defer past the locked navigation transition; calling setState from
      // didPop synchronously would rebuild the Navigator while it is locked.
      WidgetsBinding.instance.addPostFrameCallback((_) => onReturnToHome());
    }
    super.didPop(route, previousRoute);
  }
}


/// Header profile chip: stickman avatar + rank label + neon progress bar +
/// accumulated score caption. Replaces the old "STICKMAN RUN" brand badge.
class _RunnerProfile extends StatelessWidget {
  const _RunnerProfile();

  @override
  Widget build(BuildContext context) {
    // Rebuilds on score changes (rank/progress) AND settings changes
    // (e.g. a new stickman color chosen in Settings).
    return ListenableBuilder(
      listenable: Listenable.merge([
        ScoreHistoryController.instance,
        SettingsController.instance,
      ]),
      builder: (context, _) {
        final history = ScoreHistoryController.instance;
        final total = _totalScore(history);
        final tier = rankForScore(total);
        final prevMilestone = (tier.level - 1) * 10000;
        final progress =
            tier.level >= rankTierNames.length
                ? 1.0
                : ((total - prevMilestone) / 10000).clamp(0.0, 1.0);

        // Tapping the avatar (or the rank chip) opens the profile page.
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const StickmanAvatar(size: 46),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${tier.name} LV ${tier.level}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                    color: Color(0xFFFFD700),
                    shadows: [
                      Shadow(color: Colors.black, blurRadius: 6),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                SizedBox(
                  width: 92,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF4DD8FF),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${total} / ${tier.nextMilestone}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One-time cinematic "LEVEL UP" celebration shown on the homepage when the
/// player's rank tier increases. Bloom + banner + confetti, auto-dismisses.
class _LevelUpCelebration extends StatelessWidget {
  final int tier;
  final AnimationController controller;
  final VoidCallback onDismiss;

  const _LevelUpCelebration({
    required this.tier,
    required this.controller,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final rank = rankForScore((tier - 1) * 10000);

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onDismiss,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final p = controller.value;
            final appear = Curves.easeOutCubic.transform(
              ((p - 0.0) / 0.25).clamp(0.0, 1.0),
            );
            final fadeOut = ((p - 0.75) / 0.25).clamp(0.0, 1.0);
            final opacity = (1.0 - fadeOut).clamp(0.0, 1.0);

            if (p >= 1.0) {
              WidgetsBinding.instance.addPostFrameCallback((_) => onDismiss());
            }

            return Opacity(
              opacity: opacity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Cinematic bloom.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.2),
                        radius: 1.0,
                        colors: [
                          const Color(0xFFFFD700).withValues(
                            alpha: 0.45 * appear,
                          ),
                          Colors.black.withValues(alpha: 0.75 * appear),
                        ],
                        stops: const [0.0, 1.0],
                      ),
                    ),
                  ),
                  // Confetti.
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _ConfettiPainter(progress: p),
                    ),
                  ),
                  // Banner.
                  Center(
                    child: Transform.scale(
                      scale: 0.6 + 0.4 * appear,
                      child: Opacity(
                        opacity: appear,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'LEVEL UP',
                              style: TextStyle(
                                fontSize: 46,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 6,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: const Color(0xFFFFD700).withValues(
                                      alpha: 0.9,
                                    ),
                                    blurRadius: 30,
                                  ),
                                  Shadow(
                                    color: const Color(0xFF4DD8FF).withValues(
                                      alpha: 0.8,
                                    ),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${rank.name} LV ${tier}',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                                color: const Color(0xFFFFD700),
                                shadows: [
                                  Shadow(
                                    color: Colors.black,
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFF4DD8FF),
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                color: Colors.black.withValues(alpha: 0.5),
                              ),
                              child: Text(
                                'TAP TO CONTINUE',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final _Random _rng = _Random(1337);

  _ConfettiPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.01 || progress >= 1.0) return;
    final paint = Paint();
    const colors = [
      Color(0xFFFFD700),
      Color(0xFF4DD8FF),
      Color(0xFFFF6B6B),
      Color(0xFF9B5DE5),
      Color(0xFF00F5A0),
    ];
    for (var i = 0; i < 60; i++) {
      final x = _rng.nextDouble() * size.width;
      final fall = ((progress + _rng.nextDouble() * 0.2) % 1.0) * size.height;
      final sway = sin((progress + i) * 6) * size.width * 0.03;
      final w = 4 + _rng.nextDouble() * 5;
      final h = 2 + _rng.nextDouble() * 3;
      paint.color = colors[i % colors.length];
      canvas.save();
      canvas.translate(x + sway, fall);
      canvas.rotate(progress * 8 + i);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: w, height: h),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Tiny seeded RNG so confetti is stable across frames.
class _Random {
  int _seed;

  _Random(this._seed);

  double nextDouble() {
    _seed = (_seed * 1103515245 + 12345) & 0x7fffffff;
    return _seed / 0x7fffffff;
  }
}

class _CarouselLevelCard extends StatelessWidget {
  final engine.LevelConfig level;
  final bool isActive;
  final int bestScore;
  final int starCount;

  const _CarouselLevelCard({
    required this.level,
    required this.isActive,
    required this.bestScore,
    required this.starCount,
  });

  /// Corner radius applied to the card background images so their tips match
  /// the card's rounded corners (the card itself uses BorderRadius.circular(20)).
  static const double _imageRadius = 20;

  /// Maps a level to its background image asset. Level 6 (ENDLESS) reuses the
  /// volcano scene as its representative backdrop.
  static const List<String> _endlessBackdrops = [
    'assets/images/forest_background.png',
    'assets/images/desert_background.png',
    'assets/images/nightcity_background.png',
    'assets/images/darkcave_background.png',
    'assets/images/volcano_background.png',
  ];

  static const List<String> _endlessLabels = [
    'FOREST',
    'DESERT',
    'NIGHT CITY',
    'DARK CAVE',
    'VOLCANO',
  ];

  /// Per-strip horizontal sampling so each narrow strip shows a different part
  /// of its (landscape) background image instead of the same centered crop.
  static const List<Alignment> _endlessAlignments = [
    Alignment(-0.9, 0),
    Alignment(-0.45, 0),
    Alignment(0.0, 0),
    Alignment(0.45, 0),
    Alignment(0.9, 0),
  ];

  static String _levelBackdropAsset(int levelIndex) =>
      _endlessBackdrops[(levelIndex - 1).clamp(
        0,
        _endlessBackdrops.length - 1,
      )];

  /// Difficulty tier shown on each card (mirrors the level's difficulty ramp).
  static const List<String> _difficultyLabels = [
    'CASUAL',
    'EASY',
    'MEDIUM',
    'HARD',
    'EXTREME',
    'NIGHTMARE',
  ];

  static String _difficultyLabel(int levelIndex) =>
      _difficultyLabels[(levelIndex - 1).clamp(
        0,
        _difficultyLabels.length - 1,
      )];

  /// Thematic icon shown in each card's top-right corner, matching the icon the
  /// game draws next to the level title during play (see _drawLevelLabel).
  static IconData _levelIcon(int levelIndex) {
    switch (levelIndex) {
      case 1:
        return Icons.forest; // FOREST
      case 2:
        return Icons.wb_sunny; // DESERT (cactus is drawn manually in-game)
      case 3:
        return Icons.nightlight_round; // NIGHT CITY
      case 4:
        return Icons.brightness_3; // DARK CAVE (bat is drawn manually in-game)
      case 5:
        return Icons.local_fire_department; // VOLCANO
      default:
        return Icons.casino; // RANDOM / ENDLESS
    }
  }

  /// Accent color used for the level's in-game title glow, derived from the
  /// level's sky color (mirrors StickmanRunPainter._levelAccentColor).
  static Color _levelAccent(int topColor) {
    final base = Color(topColor);
    final hsl = HSLColor.fromColor(base);
    return hsl
        .withLightness((hsl.lightness * 0.55 + 0.6).clamp(0.0, 1.0))
        .withSaturation(0.85)
        .toColor();
  }

  @override
  Widget build(BuildContext context) {
    final border = isActive ? Colors.yellow : Colors.white;
    final scale = isActive ? 1.0 : 0.92;
    final accent = _levelAccent(level.visuals.topColor);

    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 250),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            border: Border.all(color: border, width: isActive ? 4 : 3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (level.levelIndex == 6)
                // Clip the whole strip row once so all five backdrops share one
                // smooth rounded outline (top AND bottom) instead of each strip
                // being rounded individually.
                ClipRRect(
                  borderRadius: BorderRadius.circular(_imageRadius),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Row(
                        children: [
                          for (
                            var i = 0;
                            i < _endlessBackdrops.length;
                            i++
                          ) ...[
                            if (i > 0)
                              const SizedBox(
                                width: 2,
                                height: double.infinity,
                                child: ColoredBox(color: Color(0xFF0B0E13)),
                              ),
                            Expanded(
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.asset(
                                    _endlessBackdrops[i],
                                    fit: BoxFit.cover,
                                    alignment: _endlessAlignments[i],
                                    gaplessPlayback: true,
                                  ),
                                  Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 3),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.6,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          _endlessLabels[i],
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 8,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const Positioned.fill(
                        child: ColoredBox(color: Color(0x59000000)),
                      ),
                    ],
                  ),
                )
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(_imageRadius),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        _levelBackdropAsset(level.levelIndex),
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                      const Positioned.fill(
                        child: ColoredBox(color: Color(0x59000000)),
                      ),
                    ],
                  ),
                ),
              LayoutBuilder(
                builder: (context, constraints) {
                  return FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    color: Colors.black.withValues(alpha: 0.25),
                                  ),
                                  child: Text(
                                    level.visuals.themeTag,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                const SizedBox(width: 8),
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.black,
                                      width: 3,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    color: accent.withValues(alpha: 0.28),
                                  ),
                                  child: Icon(
                                    _levelIcon(level.levelIndex),
                                    color: accent,
                                    size: 24,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    level.visuals.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 24,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: List.generate(5, (i) {
                                      final filled = i < starCount;
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          right: 3,
                                        ),
                                        child: Icon(
                                          Icons.star,
                                          size: 24,
                                          color: filled
                                              ? Colors.yellow
                                              : Colors.white.withValues(
                                                  alpha: 0.25,
                                                ),
                                        ),
                                      );
                                    }),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.bolt,
                                        size: 20,
                                        color: Colors.yellow,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _difficultyLabel(level.levelIndex),
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.85,
                                          ),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                      const Spacer(),
                                      const Icon(
                                        Icons.emoji_events,
                                        size: 18,
                                        color: Colors.yellow,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        bestScore > 0
                                            ? 'BEST $bestScore'
                                            : 'NO RECORD',
                                        style: const TextStyle(
                                          color: Colors.yellow,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
