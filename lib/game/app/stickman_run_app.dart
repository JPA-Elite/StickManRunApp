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
  final PageController _pageController = PageController(viewportFraction: 0.75);
  int _selectedLevel = 1;
  bool _showLevelSelect = false;

  @override
  void dispose() {
    _pageController.dispose();
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
      home: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _MenuBackdropPainter(levelCount: levels.length),
                ),
              ),

              // Brand card pinned at top
              Positioned(
                top: 8,
                left: 16,
                right: 16,
                child: _BrandCard(),
              ),

              // Main content — centered vertically
              LayoutBuilder(
                builder: (context, constraints) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!_showLevelSelect) ...[
                            // Big title (no brand card in way)
                            const Text(
                              'STICKMAN\nRUN',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 52,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 2,
                                height: 1.1,
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
                              onTap: () => setState(() => _showLevelSelect = true),
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: Colors.yellow,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.yellow.withOpacity(0.4),
                                      blurRadius: 24,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.play_arrow,
                                  size: 56,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ] else ...[
                            // Level select area
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _ArrowButton(
                                  icon: Icons.arrow_left,
                                  onTap: () {
                                    final idx = levels.indexWhere((l) => l.levelIndex == _selectedLevel);
                                    final prev = (idx > 0) ? idx - 1 : levels.length - 1;
                                    setState(() => _selectedLevel = levels[prev].levelIndex);
                                    _pageController.animateToPage(
                                      prev,
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                ),
                                Text(
                                  'LEVEL SELECT',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                    letterSpacing: 2,
                                  ),
                                ),
                                _ArrowButton(
                                  icon: Icons.arrow_right,
                                  onTap: () {
                                    final idx = levels.indexWhere((l) => l.levelIndex == _selectedLevel);
                                    final next = (idx < levels.length - 1) ? idx + 1 : 0;
                                    setState(() => _selectedLevel = levels[next].levelIndex);
                                    _pageController.animateToPage(
                                      next,
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: min(260, constraints.maxHeight * 0.40),
                              child: PageView.builder(
                                controller: _pageController,
                                itemCount: levels.length,
                                onPageChanged: (index) {
                                  setState(() => _selectedLevel = levels[index].levelIndex);
                                },
                                itemBuilder: (context, index) {
                                  final l = levels[index];
                                  final isActive = l.levelIndex == _selectedLevel;
                                  return _CarouselLevelCard(
                                    level: l,
                                    isActive: isActive,
                                    starCount: (l.levelIndex.clamp(1, 5)),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () {
                                _navigatorKey.currentState!.push(
                                  MaterialPageRoute(
                                    builder: (_) => StickmanRunScreen(initialLevel: _selectedLevel),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.play_arrow, color: Colors.black),
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
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                              ),
                            ),
                          ],
                        ],
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

class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ArrowButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Icon(icon, color: Colors.white, size: 32),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 3),
              borderRadius: BorderRadius.circular(14),
              color: Colors.black.withOpacity(0.35),
            ),
            child: const Text(
              'STICKMAN RUN',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'CHALLENGE LEVELS',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _CarouselLevelCard extends StatelessWidget {
  final engine.LevelConfig level;
  final bool isActive;
  final int starCount;

  const _CarouselLevelCard({
    required this.level,
    required this.isActive,
    required this.starCount,
  });

  @override
  Widget build(BuildContext context) {
    final stripeTop = Color(level.visuals.topColor);
    final stripeBottom = Color(level.visuals.bottomColor);
    final border = isActive ? Colors.yellow : Colors.white;
    final scale = isActive ? 1.0 : 0.88;

    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 250),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: border, width: isActive ? 4 : 3),
            borderRadius: BorderRadius.circular(20),
            color: Colors.black.withOpacity(0.35),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black, width: 3),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.yellow.withOpacity(0.15),
                    ),
                    child: const Icon(Icons.star, color: Colors.yellow, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 8,
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
              const SizedBox(height: 10),
              Text(
                level.visuals.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: List.generate(5, (i) {
                  final filled = i < starCount;
                  return Padding(
                    padding: const EdgeInsets.only(right: 3),
                    child: Icon(
                      Icons.star,
                      size: 20,
                      color: filled ? Colors.yellow : Colors.white.withOpacity(0.25),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.bolt, size: 16, color: Colors.yellow),
                  const SizedBox(width: 6),
                  Text(
                    'Shield + Magnet',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
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
