import 'package:flutter/material.dart';

import '../settings/game_settings.dart';
import '../settings/settings_controller.dart';

/// All things the guide can describe: every obstacle type plus the
/// collectibles (coins and power-ups).
enum GuideKind {
  spike,
  cactus,
  stalagmite,
  rollingRock,
  drone,
  laser,
  bat,
  fireJet,
  fireball,
  pendulumMine,
  coin,
  shield,
  magnet,
}

class GuideItem {
  final GuideKind kind;
  final String name;
  final String definition;

  const GuideItem({
    required this.kind,
    required this.name,
    required this.definition,
  });
}

const List<GuideItem> _obstacleItems = [
  GuideItem(
    kind: GuideKind.spike,
    name: 'SPIKE',
    definition: 'Sharp floor spike. Jump over it.',
  ),
  GuideItem(
    kind: GuideKind.cactus,
    name: 'CACTUS',
    definition: 'Tall desert plant. Jump over it.',
  ),
  GuideItem(
    kind: GuideKind.stalagmite,
    name: 'STALAGMITE',
    definition: 'Rock pillar rising from the ground. Jump over it.',
  ),
  GuideItem(
    kind: GuideKind.rollingRock,
    name: 'ROLLING ROCK',
    definition: 'Tumbling boulder. Jump over it or smash it.',
  ),
  GuideItem(
    kind: GuideKind.drone,
    name: 'DRONE',
    definition: 'Hovering bot at head height. Jump under it or smash it.',
  ),
  GuideItem(
    kind: GuideKind.laser,
    name: 'LASER',
    definition: 'Horizontal beam. Jump over it.',
  ),
  GuideItem(
    kind: GuideKind.bat,
    name: 'BAT',
    definition: 'Swooping bat. Time your jump or smash it.',
  ),
  GuideItem(
    kind: GuideKind.fireJet,
    name: 'FIRE JET',
    definition: 'Flame jet from the ground. Jump over it.',
  ),
  GuideItem(
    kind: GuideKind.fireball,
    name: 'FIREBALL',
    definition: 'Bouncing fireball. Time your jump.',
  ),
  GuideItem(
    kind: GuideKind.pendulumMine,
    name: 'PENDULUM MINE',
    definition: 'Swinging mine. Pass under it or smash it.',
  ),
];

const List<GuideItem> _collectibleItems = [
  GuideItem(
    kind: GuideKind.coin,
    name: 'COIN',
    definition: 'Collect for +10 points. Use the magnet to grab more.',
  ),
  GuideItem(
    kind: GuideKind.shield,
    name: 'SHIELD',
    definition: 'Grants 6s of protection that blocks one hit.',
  ),
  GuideItem(
    kind: GuideKind.magnet,
    name: 'MAGNET',
    definition: 'Pulls nearby coins toward you for 6s.',
  ),
];

/// Dark arcade-style page listing every obstacle and collectible with a
/// mini glyph and a short definition. The header holds a back icon.
class ObstacleGuideScreen extends StatelessWidget {
  const ObstacleGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 16, 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Expanded(
                    child: Text(
                      'OBSTACLE GUIDE',
                      style: TextStyle(
                        color: Colors.yellow,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const Divider(color: Colors.yellow, height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SectionHeader('HOW TO PLAY'),
                    const _HowToItems(),
                    const SizedBox(height: 14),
                    const _SectionHeader('OBSTACLES'),
                    for (final item in _obstacleItems) _GuideRow(item: item),
                    const SizedBox(height: 14),
                    const _SectionHeader('COINS & POWER-UPS'),
                    for (final item in _collectibleItems) _GuideRow(item: item),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;

  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 2),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.yellow,
          fontWeight: FontWeight.w900,
          fontSize: 12,
          letterSpacing: 1.6,
        ),
      ),
    );
  }
}

/// How-to-play rows. Jump/crawl instructions follow the active control
/// scheme so players see exactly what to do.
class _HowToItems extends StatelessWidget {
  const _HowToItems();

  @override
  Widget build(BuildContext context) {
    final scheme = SettingsController.instance.settings.controlScheme;
    final gestures = scheme == ControlScheme.gestures;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HowToRow(
          icon: Icons.arrow_upward,
          title: 'JUMP',
          definition: gestures
              ? 'Swipe up on the screen to jump over obstacles.'
              : 'Press the up button (bottom-right) to jump over obstacles.',
        ),
        _HowToRow(
          icon: Icons.subdirectory_arrow_left,
          title: 'CRAWL',
          definition: gestures
              ? 'Swipe down on the screen to crawl under high obstacles.'
              : 'Press the crawl button to duck under high obstacles.',
        ),
        _HowToRow(
          icon: Icons.sports_mma,
          title: 'SMASH',
          definition: 'Press the red smash button to destroy obstacles.',
        ),
        _HowToRow(
          icon: Icons.star,
          title: 'SCORE',
          definition: 'Collect coins for +10 each and grab shield/magnet boosts.',
        ),
      ],
    );
  }
}

class _HowToRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String definition;

  const _HowToRow({
    required this.icon,
    required this.title,
    required this.definition,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            height: 38,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.yellow.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.yellow, width: 1.5),
              ),
              child: Icon(icon, color: Colors.yellow, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  definition,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideRow extends StatelessWidget {
  final GuideItem item;

  const _GuideRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            height: 38,
            child: _GuideGlyph(kind: item.kind),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.definition,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small silhouette of a guide entry, drawn in the game's cartoon style.
class _GuideGlyph extends StatelessWidget {
  final GuideKind kind;

  const _GuideGlyph({required this.kind});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(38, 38),
      painter: _GuideGlyphPainter(kind),
    );
  }
}

class _GuideGlyphPainter extends CustomPainter {
  final GuideKind kind;

  const _GuideGlyphPainter(this.kind);

  Color _fillColor() {
    switch (kind) {
      case GuideKind.spike:
        return const Color(0xFFE8E8E8);
      case GuideKind.cactus:
        return const Color(0xFF127C20);
      case GuideKind.stalagmite:
        return const Color(0xFFCE93D8);
      case GuideKind.rollingRock:
        return const Color(0xFF9E6B45);
      case GuideKind.drone:
        return Colors.cyanAccent;
      case GuideKind.laser:
        return Colors.redAccent;
      case GuideKind.bat:
        return Colors.purpleAccent;
      case GuideKind.fireJet:
        return Colors.orangeAccent;
      case GuideKind.fireball:
        return Colors.deepOrangeAccent;
      case GuideKind.pendulumMine:
        return Colors.grey.shade300;
      case GuideKind.coin:
        return const Color(0xFFFFBF00);
      case GuideKind.shield:
        return Colors.yellow;
      case GuideKind.magnet:
        return Colors.cyanAccent;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 24.0;
    Offset p(double x, double y) => Offset(x * u, y * u);

    final fill = Paint()..color = _fillColor();
    final outline = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    switch (kind) {
      case GuideKind.spike:
        final path = Path()
          ..moveTo(4, 22)
          ..lineTo(12, 3)
          ..lineTo(20, 22)
          ..close();
        canvas.drawPath(path, fill);
        canvas.drawPath(path, outline);
        canvas.drawLine(p(4, 22), p(20, 22), outline);
        break;

      case GuideKind.cactus:
        final body = RRect.fromRectAndRadius(
          Rect.fromLTRB(10, 5, 14, 22),
          const Radius.circular(3),
        );
        canvas.drawRRect(body, fill);
        canvas.drawRRect(body, outline);
        // arms
        final arm = RRect.fromRectAndRadius(
          Rect.fromLTRB(6, 9, 10, 13),
          const Radius.circular(2),
        );
        canvas.drawRRect(arm, fill);
        canvas.drawRRect(arm, outline);
        final arm2 = RRect.fromRectAndRadius(
          Rect.fromLTRB(14, 9, 18, 13),
          const Radius.circular(2),
        );
        canvas.drawRRect(arm2, fill);
        canvas.drawRRect(arm2, outline);
        break;

      case GuideKind.stalagmite:
        final path = Path()
          ..moveTo(4, 22)
          ..lineTo(12, 4)
          ..lineTo(20, 22)
          ..close();
        canvas.drawPath(path, fill);
        canvas.drawPath(path, outline);
        canvas.drawLine(p(12, 6), p(12, 18), outline);
        break;

      case GuideKind.rollingRock:
        final c = p(12, 13);
        canvas.drawCircle(c, 8 * u, fill);
        canvas.drawCircle(c, 8 * u, outline);
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: 8 * u),
          0.4,
          1.4,
          false,
          outline,
        );
        break;

      case GuideKind.drone:
        final body = Rect.fromLTRB(3, 8, 21, 16);
        canvas.drawOval(body, fill);
        canvas.drawOval(body, outline);
        final eye = Paint()..color = Colors.black;
        canvas.drawRect(Rect.fromLTRB(8, 10, 11, 12.5), eye);
        canvas.drawRect(Rect.fromLTRB(13, 10, 16, 12.5), eye);
        break;

      case GuideKind.laser:
        final body = Rect.fromLTRB(2, 10, 22, 14);
        canvas.drawRect(body, fill);
        canvas.drawRect(body, outline);
        final teeth = Paint()
          ..color = Colors.black
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;
        for (int i = 0; i < 5; i++) {
          final x = 3 + i * 4.0;
          canvas.drawLine(p(x, 14), p(x + 3, 16), teeth);
        }
        break;

      case GuideKind.bat:
        final path = Path()
          ..moveTo(2, 20)
          ..quadraticBezierTo(6, 6, 12, 4)
          ..quadraticBezierTo(18, 6, 22, 20)
          ..lineTo(19, 20)
          ..quadraticBezierTo(15, 13, 12, 13)
          ..quadraticBezierTo(9, 13, 5, 20)
          ..close();
        canvas.drawPath(path, fill);
        canvas.drawPath(path, outline);
        break;

      case GuideKind.fireJet:
        final body = Rect.fromLTRB(3, 14, 21, 19);
        canvas.drawRect(body, fill);
        canvas.drawRect(body, outline);
        final flame = Paint()
          ..color = Colors.black
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;
        for (int i = 0; i < 5; i++) {
          final x = 4 + i * 4.0;
          canvas.drawLine(p(x, 14), p(x + 3, 9), flame);
        }
        break;

      case GuideKind.fireball:
        final c = p(12, 14);
        canvas.drawCircle(c, 7 * u, fill);
        canvas.drawCircle(c, 7 * u, outline);
        final flame = Paint()..color = Colors.amber;
        final flamePath = Path()
          ..moveTo(10, 7)
          ..quadraticBezierTo(12, 1, 14, 7)
          ..quadraticBezierTo(12, 4, 10, 7);
        canvas.drawPath(flamePath, flame);
        break;

      case GuideKind.pendulumMine:
        canvas.drawLine(p(12, 2), p(12, 10), outline);
        final c = p(12, 15);
        canvas.drawCircle(c, 6 * u, fill);
        canvas.drawCircle(c, 6 * u, outline);
        final spike = Paint()..color = Colors.black;
        canvas.drawCircle(p(10, 15), 1.8 * u, spike);
        canvas.drawCircle(p(14, 15), 1.8 * u, spike);
        break;

      case GuideKind.coin:
        final c = p(12, 12);
        canvas.drawCircle(c, 8 * u, fill);
        canvas.drawCircle(c, 8 * u, outline);
        final shine = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: 6 * u),
          0.2,
          1.2,
          false,
          shine,
        );
        break;

      case GuideKind.shield:
        final body = RRect.fromRectAndRadius(
          Rect.fromLTRB(6, 4, 18, 20),
          const Radius.circular(4),
        );
        canvas.drawRRect(body, fill);
        canvas.drawRRect(body, outline);
        final bolt = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2;
        canvas.drawLine(p(12, 8), p(12, 14), bolt);
        canvas.drawLine(p(12, 14), p(14, 11), bolt);
        canvas.drawLine(p(14, 11), p(14, 8), bolt);
        break;

      case GuideKind.magnet:
        final path = Path()
          ..moveTo(12, 3)
          ..lineTo(21, 12)
          ..lineTo(12, 21)
          ..lineTo(3, 12)
          ..close();
        canvas.drawPath(path, fill);
        canvas.drawPath(path, outline);
        final bar = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2;
        canvas.drawLine(p(12, 8), p(12, 16), bar);
        canvas.drawLine(p(9, 11), p(15, 11), bar);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _GuideGlyphPainter oldDelegate) =>
      oldDelegate.kind != kind;
}
