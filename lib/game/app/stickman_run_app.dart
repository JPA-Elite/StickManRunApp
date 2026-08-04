import 'dart:math';

import 'package:flutter/material.dart';

import '../settings/score_history.dart';
import '../ui/menu_backdrop.dart';
import '../ui/score_history_screen.dart';
import '../ui/settings_screen.dart';
import '../ui/stickman_run_screen.dart';
import '../../game/engine/level_config.dart' as engine;

class StickmanRunApp extends StatefulWidget {
  const StickmanRunApp({super.key});

  @override
  State<StickmanRunApp> createState() => _StickmanRunAppState();
}

class _StickmanRunAppState extends State<StickmanRunApp>
    with SingleTickerProviderStateMixin {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final PageController _pageController = PageController(viewportFraction: 0.88);
  int _selectedLevel = 1;
  bool _showLevelSelect = false;

  late final AnimationController _backdropController =
      AnimationController(vsync: this, duration: const Duration(seconds: 1))
        ..repeat();

  @override
  void dispose() {
    _pageController.dispose();
    _backdropController.dispose();
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
      home: ListenableBuilder(
        listenable: ScoreHistoryController.instance,
        builder: (context, _) => Scaffold(
          body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: MenuBackdropPainter(
                    levelCount: levels.length,
                    timeNow: () =>
                        _backdropController.value *
                        _backdropController.duration!.inMicroseconds /
                        1e6,
                    repaint: _backdropController,
                  ),
                ),
              ),

              // Brand card pinned at top (level select page only)
              if (_showLevelSelect)
                Positioned(top: 12, left: 16, right: 16, child: _BrandCard()),

              // Main content — fills the screen so cards can grow as large
              // as possible.
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      if (!_showLevelSelect) ...[
                        const Spacer(flex: 3),
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
                            shadows: [
                              Shadow(
                                color: Colors.black,
                                blurRadius: 10,
                              ),
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
                          onTap: () => setState(() => _showLevelSelect = true),
                          child: AnimatedBuilder(
                            animation: _backdropController,
                            builder: (context, _) {
                              final t =
                                  _backdropController.value * 2 * pi;
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
                        // Level select area
                        const SizedBox(height: 76),
                        Expanded(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned.fill(
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
                                      starCount: (l.levelIndex.clamp(1, 5)),
                                    );
                                  },
                                ),
                              ),
                              Positioned(
                                left: 0,
                                child: _ArrowButton(
                                  icon: Icons.arrow_left,
                                  onTap: () {
                                    final idx = levels.indexWhere(
                                      (l) => l.levelIndex == _selectedLevel,
                                    );
                                    final prev = (idx > 0)
                                        ? idx - 1
                                        : levels.length - 1;
                                    setState(
                                      () => _selectedLevel =
                                          levels[prev].levelIndex,
                                    );
                                    _pageController.animateToPage(
                                      prev,
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                ),
                              ),
                              Positioned(
                                right: 0,
                                child: _ArrowButton(
                                  icon: Icons.arrow_right,
                                  onTap: () {
                                    final idx = levels.indexWhere(
                                      (l) => l.levelIndex == _selectedLevel,
                                    );
                                    final next = (idx < levels.length - 1)
                                        ? idx + 1
                                        : 0;
                                    setState(
                                      () => _selectedLevel =
                                          levels[next].levelIndex,
                                    );
                                    _pageController.animateToPage(
                                      next,
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
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
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 10,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
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
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Icon(icon, color: Colors.white, size: 28),
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
        mainAxisSize: MainAxisSize.max,
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
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: const Text(
                'LEVEL SELECT',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.emoji_events, color: Colors.yellow, size: 24),
            tooltip: 'Score History',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ScoreHistoryScreen(),
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
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final stripeTop = Color(level.visuals.topColor);
    final stripeBottom = Color(level.visuals.bottomColor);
    final border = isActive ? Colors.yellow : Colors.white;
    final scale = isActive ? 1.0 : 0.92;

    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 250),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: border, width: isActive ? 4 : 3),
            borderRadius: BorderRadius.circular(20),
            color: Colors.black.withOpacity(0.35),
          ),
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: SizedBox(
                  width: constraints.maxWidth,
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
                              border: Border.all(color: Colors.white, width: 3),
                              borderRadius: BorderRadius.circular(14),
                              color: Colors.white.withOpacity(0.06),
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
                          if (level.levelIndex == 6)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.redAccent,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                color: Colors.redAccent.withOpacity(0.15),
                              ),
                              child: const Text(
                                'HARDEST',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.black, width: 3),
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.yellow.withOpacity(0.15),
                            ),
                            child: Icon(
                              level.levelIndex == 6
                                  ? Icons.casino
                                  : Icons.star,
                              color: Colors.yellow,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 12,
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
                      const SizedBox(height: 12),
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
                            padding: const EdgeInsets.only(right: 3),
                            child: Icon(
                              Icons.star,
                              size: 24,
                              color: filled
                                  ? Colors.yellow
                                  : Colors.white.withOpacity(0.25),
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
                            'Shield + Magnet',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
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
                            bestScore > 0 ? 'BEST $bestScore' : 'NO RECORD',
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
              );
            },
          ),
        ),
      ),
    );
  }
}
