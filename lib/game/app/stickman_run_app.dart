import 'dart:math';

import 'package:flutter/material.dart';

import '../ui/stickman_run_screen.dart';
import '../../game/engine/level_config.dart' as engine;

class StickmanRunApp extends StatefulWidget {
  const StickmanRunApp({super.key});

  @override
  State<StickmanRunApp> createState() => _StickmanRunAppState();
}

class _StickmanRunAppState extends State<StickmanRunApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  int _selectedLevel = 1;

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
    final selectedIdx = (levels.indexWhere((l) => l.levelIndex == _selectedLevel)).clamp(0, levels.length - 1);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      navigatorKey: _navigatorKey,
      home: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _MenuBackdropPainter(levelCount: levels.length),
                ),
              ),

              // Main content
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 780;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      children: [
                        // Top row: branding + levels
                        Expanded(
                          child: isNarrow
                              ? SingleChildScrollView(
                                  child: Column(
                                    children: [
                                      _BrandCard(),
                                      const SizedBox(height: 14),
                                      _LevelsColumn(
                                        levels: levels,
                                        selectedLevel: levels[selectedIdx].levelIndex,
                                        onSelectLevel: (i) => setState(() => _selectedLevel = i),
                                        onPlay: () {
                                          // Ensure Navigator is present via a new builder context.
                                          _navigatorKey.currentState!.push(
                                            MaterialPageRoute(
                                              builder: (_) => StickmanRunScreen(initialLevel: _selectedLevel),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                )
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Left branding
                                    SizedBox(
                                      width: max(360, constraints.maxWidth * 0.38),
                                      child: _BrandCard(),
                                    ),
                                    const SizedBox(width: 14),

                                    // Right levels
                                    Expanded(
                                      child: _LevelsColumn(
                                        levels: levels,
                                        selectedLevel: levels[selectedIdx].levelIndex,
                                        onSelectLevel: (i) => setState(() => _selectedLevel = i),
                                        onPlay: () {
                                          _navigatorKey.currentState!.push(
                                            MaterialPageRoute(
                                              builder: (_) => StickmanRunScreen(initialLevel: _selectedLevel),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                        ),

                        const SizedBox(height: 10),

                      ],
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

class _BrandCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white, width: 3),
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withOpacity(0.06),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "STICKMAN RUN" brutal typography
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 3),
              borderRadius: BorderRadius.circular(16),
              color: Colors.black.withOpacity(0.35),
            ),
            child: const Text(
              'STICKMAN RUN',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Big stacked "STICK"/"RUN" look-alike
          const Text(
            'STICKMAN',
            style: TextStyle(
              fontSize: 54,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -1.0,
            ),
            maxLines: 1,
            overflow: TextOverflow.clip,
          ),
          const SizedBox(height: 6),
          const Text(
            'RUN',
            style: TextStyle(
              fontSize: 58,
              fontWeight: FontWeight.w900,
              color: Colors.yellow,
              letterSpacing: -2.0,
            ),
            maxLines: 1,
            overflow: TextOverflow.clip,
          ),

          const SizedBox(height: 16),

          // Sub card: challenge copy
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 3),
              borderRadius: BorderRadius.circular(18),
              color: Colors.black.withOpacity(0.35),
            ),
            child: const Text(
              'CHALLENGE LEVELS\n\nJump over obstacles.\nCollect coins.\nGrab power-ups when things get spicy.',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelsColumn extends StatelessWidget {
  final List<engine.LevelConfig> levels;
  final int selectedLevel;
  final ValueChanged<int> onSelectLevel;
  final VoidCallback onPlay;

  const _LevelsColumn({
    required this.levels,
    required this.selectedLevel,
    required this.onSelectLevel,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white, width: 3),
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withOpacity(0.06),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'LEVEL SELECT',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: onPlay,
                icon: const Icon(Icons.play_arrow, color: Colors.black),
                label: const Text(
                  'PLAY',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellow,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Stacked level panels (scroll to prevent RenderFlex overflow).
          // IMPORTANT: do NOT use Expanded here; _LevelsColumn can be inside an
          // unbounded scroll (small devices), which can cause zero-size boxes
          // and "Cannot hit test a render box with no size".
          SizedBox(
            height: max(
              220,
              MediaQuery.of(context).size.height * 0.42,
            ),
            child: SingleChildScrollView(
              child: Column(
                children: levels
                    .map(
                      (l) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _LevelPanel(
                          level: l,
                          isActive: l.levelIndex == selectedLevel,
                          onTap: () => onSelectLevel(l.levelIndex),
                          starCount: (l.levelIndex.clamp(1, 5)),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),

          // Small helper text (kept minimal to reduce overflow risk).
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Tap a level to customize.\nThen hit PLAY.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelPanel extends StatelessWidget {
  final engine.LevelConfig level;
  final bool isActive;
  final VoidCallback onTap;
  final int starCount;

  const _LevelPanel({
    required this.level,
    required this.isActive,
    required this.onTap,
    required this.starCount,
  });

  @override
  Widget build(BuildContext context) {
    // Map level colors to a solid “card” stripe.
    final stripeTop = Color(level.visuals.topColor);
    final stripeBottom = Color(level.visuals.bottomColor);

    final border = isActive ? Colors.yellow : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: border, width: isActive ? 4 : 3),
          borderRadius: BorderRadius.circular(18),
          color: Colors.black.withOpacity(0.30),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 3),
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.white.withOpacity(0.06),
                  ),
                  child: Text(
                    level.visuals.themeTag,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 3),
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.yellow.withOpacity(0.15),
                  ),
                  child: const Icon(Icons.star, color: Colors.yellow, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Stripe
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 10,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 3),
                  color: stripeTop,
                ),
                foregroundDecoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 3),
                  color: stripeBottom.withOpacity(0.65),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Name + stars row
            Row(
              children: [
                Expanded(
                  child: Text(
                    level.visuals.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 0.4,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (i) {
                    final filled = i < starCount;
                    return Padding(
                      padding: const EdgeInsets.only(left: 3),
                      child: Icon(
                        Icons.star,
                        size: 18,
                        color: filled ? Colors.yellow : Colors.white.withOpacity(0.25),
                      ),
                    );
                  }),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Tiny "Power" hint icons (brutalist).
            Row(
              children: [
                const Icon(Icons.bolt, size: 16, color: Colors.yellow),
                const SizedBox(width: 8),
                Text(
                  'Shield + Magnet',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuBackdropPainter extends CustomPainter {
  final int levelCount;

  _MenuBackdropPainter({required this.levelCount});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final rng = Random(levelCount * 999);

    for (int i = 0; i < 35; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final w = 40 + rng.nextDouble() * 140;
      final h = 16 + rng.nextDouble() * 70;
      canvas.drawRect(Rect.fromLTWH(x, y, w, h), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
