import 'dart:math';

import 'package:flutter/material.dart';

/// Cinematic "neon dusk skyline" backdrop used by the homepage and the
/// in-game starting overlay. Painted each frame through a repaint listenable
/// ([timeNow] provides the animation clock).
class MenuBackdropPainter extends CustomPainter {
  MenuBackdropPainter({
    super.repaint,
    required this.levelCount,
    required this.timeNow,
  });

  final int levelCount;
  final double Function() timeNow;

  List<_Layer>? _layers;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final t = timeNow();
    final horizon = h * 0.6;

    _layers ??= _buildLayers(w, horizon);

    // 1) Dusk sky: deep violet -> magenta -> warm orange at the horizon.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B0620), Color(0xFF2A1240), Color(0xFF5A2050), Color(0xFFE0703C)],
          stops: [0.0, 0.42, 0.7, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // 2) Warm sun glow off-center, cinematic framing.
    final sunX = w * 0.68;
    final sunY = horizon - h * 0.04;
    final sunR = w * 0.2;
    canvas.drawCircle(
      Offset(sunX, sunY),
      sunR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFE2AE).withValues(alpha: 0.9),
            const Color(0xFFE0703C).withValues(alpha: 0.35),
            const Color(0xFFE0703C).withValues(alpha: 0.0),
          ],
        ).createShader(
          Rect.fromCircle(center: Offset(sunX, sunY), radius: sunR),
        ),
    );

    // 3) Twinkling stars in the upper sky.
    final starRng = Random(levelCount * 101 + 3);
    final starPaint = Paint();
    for (var i = 0; i < 42; i++) {
      final sx = starRng.nextDouble() * w;
      final sy = starRng.nextDouble() * h * 0.35;
      final twinkle = 0.5 + 0.5 * sin(t * 2 + i * 1.7);
      starPaint.color = Colors.white.withValues(alpha: 0.1 + twinkle * 0.4);
      canvas.drawCircle(
        Offset(sx, sy),
        0.8 + starRng.nextDouble() * 1.2,
        starPaint,
      );
    }

    // 4) Parallax layers: distant mountains, then two building skylines.
    for (final layer in _layers!) {
      layer.draw(canvas, w, h, horizon, t);
    }

    // 5) Atmosphere band right above the horizon.
    canvas.drawRect(
      Rect.fromLTWH(0, horizon - h * 0.05, w, h * 0.05),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00E0703C), Color(0x38FFC98A)],
        ).createShader(Rect.fromLTWH(0, horizon - h * 0.05, w, h * 0.05)),
    );

    // 6) Soft light shafts radiating from the sun.
    for (var i = 0; i < 4; i++) {
      final a = -0.62 + i * 0.16;
      final len = h * (0.55 + 0.2 * sin(t * 0.3 + i));
      final spread = 22.0 + i * 8;
      final path = Path()
        ..moveTo(sunX, sunY)
        ..lineTo(sunX + cos(a) * len, sunY + sin(a).abs() * len)
        ..lineTo(sunX + cos(a) * len + spread, sunY + sin(a).abs() * len)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = Colors.white.withValues(alpha: 0.05),
      );
    }

    // 7) Drifting mist ribbons near the ground.
    final mistRng = Random(levelCount * 73 + 5);
    for (var i = 0; i < 12; i++) {
      final mw = 80 + mistRng.nextDouble() * 180;
      final mh = 8 + mistRng.nextDouble() * 14;
      final mx = (mistRng.nextDouble() * (w + mw * 2) - mw * 2 +
              t * (12 + mistRng.nextDouble() * 16)) %
          (w + mw);
      final my = horizon + 4 + mistRng.nextDouble() * (h - horizon - 10);
      final mop = 0.05 + 0.06 * sin(t * 0.8 + i);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(mx - mw / 2, my, mw, mh),
          Radius.circular(mh / 2),
        ),
        Paint()..color = const Color(0xFFFFD9A0).withValues(alpha: mop),
      );
    }

    // 8) Vignette for a cinematic frame.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0.0, -0.12),
          radius: 0.95,
          colors: [Color(0x00000000), Color(0x00000000), Color(0xD9000000)],
          stops: [0.5, 0.78, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
  }

  List<_Layer> _buildLayers(double w, double horizon) {
    final tileW = w + 260.0;
    final baseRng = Random(levelCount * 7919 + 11);
    return [
      // Far: jagged mountain ridge, slow drift.
      _Layer.mountains(
        rng: Random(baseRng.nextInt(1 << 30)),
        tileW: tileW,
        horizon: horizon,
        speed: 7,
        color: const Color(0xFF2A1240),
        heightScale: 0.55,
      ),
      // Mid: low skyline with sparse windows.
      _Layer.buildings(
        rng: Random(baseRng.nextInt(1 << 30)),
        tileW: tileW,
        speed: 18,
        color: const Color(0xFF1E0E33),
        windowColor: const Color(0xFFF2A65A),
        windowChance: 0.12,
        widthScale: 0.7,
        heightScale: 0.6,
        windowSize: 3,
      ),
      // Near: tall skyline with bright neon windows.
      _Layer.buildings(
        rng: Random(baseRng.nextInt(1 << 30)),
        tileW: tileW,
        speed: 42,
        color: const Color(0xFF120826),
        windowColor: const Color(0xFFFFE9A8),
        windowChance: 0.3,
        widthScale: 1.0,
        heightScale: 1.0,
        windowSize: 5,
      ),
    ];
  }

  @override
  bool shouldRepaint(covariant MenuBackdropPainter oldDelegate) => true;
}

class _Layer {
  final double speed;
  final bool isMountains;
  final List<_Building> buildings;
  final Path? ridge;
  final Color color;
  final Color windowColor;
  final double windowChance;
  final double windowSize;

  _Layer.mountains({
    required Random rng,
    required double tileW,
    required this.speed,
    required this.color,
    required double horizon,
    required double heightScale,
  }) : isMountains = true,
       buildings = const [],
       ridge = _buildRidge(rng, tileW, horizon, heightScale),
       windowColor = const Color(0x00000000),
       windowChance = 0,
       windowSize = 0;

  _Layer.buildings({
    required Random rng,
    required double tileW,
    required this.speed,
    required this.color,
    required this.windowColor,
    required this.windowChance,
    required double widthScale,
    required double heightScale,
    required this.windowSize,
  }) : isMountains = false,
       ridge = null,
       buildings = _buildBuildings(rng, tileW, widthScale, heightScale);

  static Path _buildRidge(
    Random rng,
    double tileW,
    double horizon,
    double heightScale,
  ) {
    final amp = horizon * 0.5;
    const step = 30.0;
    final path = Path()..moveTo(0, horizon);
    var x = 0.0;
    var i = 0;
    while (x <= tileW) {
      final y =
          horizon -
          amp * (0.35 + 0.65 * sin(x * 0.012 + rng.nextDouble() * 6.28)) *
              heightScale;
      path.lineTo(x, y);
      x += step;
      i++;
      if (i > 220) break;
    }
    path.lineTo(tileW, horizon);
    return path;
  }

  static List<_Building> _buildBuildings(
    Random rng,
    double tileW,
    double widthScale,
    double heightScale,
  ) {
    final list = <_Building>[];
    var x = 0.0;
    while (x < tileW) {
      final bw = (20 + rng.nextDouble() * 46) * widthScale;
      final bh = (70 + rng.nextDouble() * 150) * heightScale;
      list.add(
        _Building(
          x: x,
          w: bw,
          h: bh,
          seed: rng.nextInt(1 << 30),
        ),
      );
      x += bw + 6 + rng.nextDouble() * 26;
    }
    return list;
  }

  void draw(Canvas canvas, double w, double h, double horizon, double t) {
    if (isMountains) {
      final offset = (t * speed) % w;
      final fill = Paint()..color = color;
      canvas.save();
      canvas.translate(-offset, 0);
      // Scroll the ridge; tile two copies so no gap appears.
      for (var dup = 0; dup < 2; dup++) {
        canvas.drawPath(
          Path()
            ..addPath(ridge!, Offset.zero)
            ..lineTo(w + 300, horizon)
            ..lineTo(0, horizon)
            ..close(),
          fill,
        );
        canvas.translate(w, 0);
      }
      canvas.restore();
      return;
    }

    final tileW = w + 260.0;
    final offset = (t * speed) % tileW;
    final fill = Paint()..color = color;
    final window = Paint();
    for (final b in buildings) {
      var bx = b.x - offset;
      if (bx < -b.w) bx += tileW;
      if (bx + b.w < 0 || bx > w) continue;
      final top = horizon - b.h;
      canvas.drawRect(Rect.fromLTWH(bx, top, b.w, b.h), fill);

      // Neon windows (lit probabilistically, seeded per building).
      final cols = (b.w / 7).floor().clamp(1, 20);
      final rows = (b.h / 11).floor().clamp(1, 20);
      final rng = Random(b.seed);
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          if (rng.nextDouble() > windowChance) continue;
          final wl = bx + 2 + c * (b.w - 4) / cols;
          final wt = top + 3 + r * (b.h - 6) / rows;
          final pulse = 0.5 + 0.5 * sin(t * 3 + r * 0.7 + c);
          window.color = windowColor.withValues(alpha: 0.3 + pulse * 0.55);
          canvas.drawRect(
            Rect.fromLTWH(wl, wt, windowSize, windowSize),
            window,
          );
        }
      }
    }
  }
}

class _Building {
  final double x;
  final double w;
  final double h;
  final int seed;

  const _Building({
    required this.x,
    required this.w,
    required this.h,
    required this.seed,
  });
}
