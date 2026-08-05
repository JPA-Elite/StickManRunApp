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
          body: Stack(
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
              SafeArea(
                child: Stack(
                  children: [
                    // Main content — fills the screen so cards can grow as
                    // large as possible.
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
                        // Level select header lives in the column flow so the
                        // card sits naturally between it and the play button,
                        // with equal top & bottom margins.
                        _BrandCard(),
                        const SizedBox(height: 8),
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
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ),
              ],
            ),
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
          const Spacer(),
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
      _endlessBackdrops[(levelIndex - 1).clamp(0, _endlessBackdrops.length - 1)];

  @override
  Widget build(BuildContext context) {
    final border = isActive ? Colors.yellow : Colors.white;
    final scale = isActive ? 1.0 : 0.92;

    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 250),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                  child: Row(
                    children: [
                      for (var i = 0; i < _endlessBackdrops.length; i++) ...[
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
                                    color: Colors.black.withValues(alpha: 0.6),
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
                )
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(_imageRadius),
                  child: Image.asset(
                    _levelBackdropAsset(level.levelIndex),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
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
                                    color: Colors.yellow.withValues(alpha: 0.25),
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
                                        'Shield + Magnet',
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.85,
                                          ),
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
