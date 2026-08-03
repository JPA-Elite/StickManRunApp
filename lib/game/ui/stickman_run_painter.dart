import 'dart:math';

import 'package:flutter/material.dart';

import '../engine/entities.dart';
import '../engine/level_config.dart' as lc;
import '../engine/stickman_run_engine.dart';

class StickmanRunPainter extends CustomPainter {
  final StickmanRunSnapshot snapshot;
  final lc.LevelConfig level;
  final double width;
  final double height;
  final Color stickmanColor;
  final bool highContrast;

  StickmanRunPainter({
    super.repaint,
    required this.snapshot,
    required this.level,
    required this.width,
    required this.height,
    this.stickmanColor = Colors.white,
    this.highContrast = false,
  });

  /// Duration of the smash punch window (matches the engine's smash duration).
  static const double _smashWindowSec = 0.18;

  /// Latest punching fist position + strength, used by the streak trail.
  Offset? _punchFist;
  double _punchStrength = 0;

  @override
  void paint(Canvas canvas, Size size) {
    // Cinematic screen shake around the punch impact.
    if (snapshot.smashActive && snapshot.smashRemainingSec > 0) {
      final p = (1 - snapshot.smashRemainingSec / _smashWindowSec)
          .clamp(0.0, 1.0);
      final impact = (1 - (p - 0.35).abs() / 0.35).clamp(0.0, 1.0);
      if (impact > 0.05) {
        final t = snapshot.timeSec * 130.0;
        canvas.translate(
          sin(t) * impact * 6.0,
          cos(t * 0.8) * impact * 3.5,
        );
      }
    }

    // Shake + red vignette while the stickman is taking damage.
    if (snapshot.damageFlashSec > 0) {
      final p = (snapshot.damageFlashSec / 0.35).clamp(0.0, 1.0);
      final t = snapshot.timeSec * 90.0;
      canvas.translate(
        sin(t) * p * 5.0,
        cos(t * 0.7) * p * 3.0,
      );
    }

    final groundY = height * 0.78;

    // Background.
    _fillBackground(canvas);

    // Ground band.
    final groundPaint = Paint()
      ..color = _flutterColor(level.visuals.groundColor);
    canvas.drawRect(
      Rect.fromLTWH(0, groundY, width, height - groundY),
      groundPaint,
    );

    // “Highway” animation: single horizontal dashed line.
    final dashPaint = Paint()
      ..color = Colors.black.withOpacity(0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    final yLine = groundY + 28;

    const dashLen = 26.0;
    const gapLen = 26.0;
    const period = dashLen + gapLen;

    // Animate dashes with distance so it feels like the ground is moving.
    final shift = (snapshot.distanceMeters * 100.0) % period;

    for (double x = -period; x < width + period; x += period) {
      final startX = x - shift;
      canvas.drawLine(
        Offset(startX, yLine),
        Offset(startX + dashLen, yLine),
        dashPaint,
      );
    }

    _drawLevelLabel(canvas);

    // Order: background obstacles first, then foreground.
    final obstacles = snapshot.obstacles.toList()
      ..sort((a, b) {
        if (a.foreground == b.foreground) return 0;
        return a.foreground ? 1 : -1;
      });

    for (final o in obstacles) {
      _drawObstacle(canvas, o);
    }

    // Coins.
    for (final c in snapshot.coinsOnTrack) {
      _drawCoin(canvas, c);
    }

    // Power-ups.
    for (final p in snapshot.powerUps) {
      _drawPowerUp(canvas, p);
    }

    // Smash debris particles.
    _drawSmashDebris(canvas);

    // Floating score popups.
    _drawSmashScorePopups(canvas);

    // Stickman. During post-hit invulnerability the body fades in and out
    // (flicker) to communicate the grace window.
    if (snapshot.damageGraceSec > 0) {
      final flickerAlpha = 0.25 + 0.6 * (0.5 + 0.5 * sin(snapshot.timeSec * 24));
      final flickerRect = Rect.fromLTWH(
        snapshot.stickman.x - _stickmanWidthPx(),
        snapshot.stickman.y - _stickmanHeightPx() * 1.1,
        _stickmanWidthPx() * 2,
        _stickmanHeightPx() * 1.1,
      );
      canvas.saveLayer(
        flickerRect,
        Paint()..color = Colors.white.withValues(alpha: flickerAlpha),
      );
      _drawStickman(canvas, snapshot.stickman);
      canvas.restore();
    } else {
      _drawStickman(canvas, snapshot.stickman);
    }

    // Speed-streak trail behind the punching fist.
    if (snapshot.smashActive) {
      _drawPunchStreaks(canvas);
    }

    // HUD ornaments (top-right).
    // Hide HUD when the overlay is showing (ready/game-over/level-complete)
    // to prevent SCORE/COINS from overlapping the overlay card.
    if (snapshot.status == GameStatus.running) {
      _drawHud(canvas, groundY: groundY);
      _drawLifeBar(canvas, groundY: groundY);
    }

    // Red flash overlay while taking damage.
    if (snapshot.damageFlashSec > 0) {
      final alpha = (snapshot.damageFlashSec / 0.35).clamp(0.0, 1.0);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, width, height),
        Paint()..color = Colors.red.withValues(alpha: alpha * 0.18),
      );
    }

    // Green flash overlay while collecting a heal power-up.
    if (snapshot.healFlashSec > 0) {
      final alpha = (snapshot.healFlashSec / 0.45).clamp(0.0, 1.0);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, width, height),
        Paint()..color = Colors.greenAccent.withValues(alpha: alpha * 0.16),
      );
    }
  }

  void _fillBackground(Canvas canvas) {
    final top = _flutterColor(level.visuals.topColor);
    final bottom = _flutterColor(level.visuals.bottomColor);

    // Solid two-tone bands for “brutalist cartoon” vibe (no gradients).
    final topRect = Rect.fromLTWH(0, 0, width, height * 0.58);
    final bottomRect = Rect.fromLTWH(0, height * 0.58, width, height * 0.42);

    final topPaint = Paint()..color = top;
    final bottomPaint = Paint()..color = bottom;

    canvas.drawRect(topRect, topPaint);
    canvas.drawRect(bottomRect, bottomPaint);

    // Simple texture dots/blocks.
    final dotPaint = Paint()
      ..color = Colors.black.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    final rng = Random(level.levelIndex * 1337);

    // Animate the sky texture by offsetting the deterministic dot positions.
    // This makes the “sky” feel like it's moving while the player runs.
    final skyScrollX = (snapshot.timeSec * 45.0) % width;
    final skyScrollY = (snapshot.timeSec * 12.0) % (height * 0.58);

    for (int i = 0; i < 90; i++) {
      final x0 = rng.nextDouble() * width;
      final y0 = rng.nextDouble() * (height * 0.58);
      final s = 3 + rng.nextDouble() * 7;

      final x = (x0 + skyScrollX) % width;
      final y = (y0 + skyScrollY) % (height * 0.58);

      canvas.drawRect(Rect.fromLTWH(x, y, s, s), dotPaint);
    }

    // Trees + houses removed (kept game background clean so obstacles stay readable).
  }

  void _drawVillageScene(
    Canvas canvas,
    double topY,
    double groundY, {
    required double scrollX,
  }) {
    // Deterministic layout per level.
    final rng = Random(level.levelIndex * 7777);

    // We avoid per-object modulo wrapping (which causes visible “popping/flicker”).
    // Instead we tile the scene twice (offset + span) so there is always a copy
    // covering the viewport while shift wraps.
    //
    // Far layer (smaller, further)
    final farCount = 18;
    final farSpan = width + 220;
    final farSpacing = farSpan / farCount;
    final farSpeed = 1.0;

    final farShift = (scrollX * farSpeed) % farSpan;

    for (int i = 0; i < farCount; i++) {
      final baseX = (i * farSpacing + rng.nextDouble() * 30) % farSpan;

      // Smaller/fainter so it doesn't intrude into the obstacle band.
      final size = 0.45 + rng.nextDouble() * 0.25;
      final y = groundY - (70 + rng.nextDouble() * 22) * size;

      final x1 = baseX - farShift - 110;
      final x2 = x1 + farSpan;

      if (x1 > -60 && x1 < width + 60) {
        _drawTree(
          canvas,
          Offset(x1, y),
          leafFill: const Color.fromARGB(255, 8, 92, 20),
          trunkFill: const Color.fromARGB(255, 62, 34, 0),
          scale: size,
          outlineAlpha: 0.9,
        );
      }
      if (x2 > -60 && x2 < width + 60) {
        _drawTree(
          canvas,
          Offset(x2, y),
          leafFill: const Color.fromARGB(255, 8, 92, 20),
          trunkFill: const Color.fromARGB(255, 62, 34, 0),
          scale: size,
          outlineAlpha: 0.9,
        );
      }
    }

    // Near layer (smaller + houses, but much fainter so obstacles stay readable)
    final nearCount = 12;
    final nearSpan = width + 240;
    final nearSpacing = nearSpan / nearCount;
    final nearSpeed = 1.15;

    final nearShift = (scrollX * nearSpeed) % nearSpan;

    for (int i = 0; i < nearCount; i++) {
      final baseX = (i * nearSpacing + rng.nextDouble() * 40) % nearSpan;

      // Smaller, so roofs/windows don't compete with obstacle silhouettes.
      final size = 0.55 + rng.nextDouble() * 0.22;

      // Push the whole layer upward.
      final y = groundY - (95 + rng.nextDouble() * 38) * size;

      // Mix: fewer items become houses.
      final isHouse = rng.nextDouble() < 0.25;

      final x1 = baseX - nearShift - 120;
      final x2 = x1 + nearSpan;

      if (isHouse) {
        final w = 34 + rng.nextDouble() * 18;
        final h = 26 + rng.nextDouble() * 18;

        if (x1 > -60 && x1 < width + 60) {
          _drawHouse(
            canvas,
            topLeft: Offset(x1, y),
            widthPx: w * size,
            heightPx: h * size,
            fill: const Color.fromARGB(255, 220, 220, 220),
            roof: const Color.fromARGB(255, 70, 70, 70),
            outline: Paint()
              ..color = Colors.black.withOpacity(0.95)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
            window: Colors.black.withOpacity(0.25),
          );
        }
        if (x2 > -60 && x2 < width + 60) {
          _drawHouse(
            canvas,
            topLeft: Offset(x2, y),
            widthPx: w * size,
            heightPx: h * size,
            fill: const Color.fromARGB(38, 220, 220, 220),
            roof: const Color.fromARGB(80, 70, 70, 70),
            outline: Paint()
              ..color = Colors.black.withOpacity(0.14)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.0,
            window: Colors.black.withOpacity(0.08),
          );
        }
      } else {
        if (x1 > -60 && x1 < width + 60) {
          _drawTree(
            canvas,
            Offset(x1, y),
            leafFill: const Color.fromARGB(70, 8, 112, 26),
            trunkFill: const Color.fromARGB(70, 86, 46, 0),
            scale: size,
            outlineAlpha: 0.4,
          );
        }
        if (x2 > -60 && x2 < width + 60) {
          _drawTree(
            canvas,
            Offset(x2, y),
            leafFill: const Color.fromARGB(255, 8, 112, 26),
            trunkFill: const Color.fromARGB(255, 86, 46, 0),
            scale: size,
            outlineAlpha: 1.0,
          );
        }
      }
    }
  }

  void _drawTree(
    Canvas canvas,
    Offset baseTopLeft, {
    required Color leafFill,
    required Color trunkFill,
    required double scale,
    required double outlineAlpha,
  }) {
    final outline = Paint()
      ..color = Colors.black.withOpacity(outlineAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final trunkW = 10 * scale;
    final trunkH = 30 * scale;

    final trunkRect = Rect.fromLTWH(
      baseTopLeft.dx + 6 * scale,
      baseTopLeft.dy + trunkH,
      trunkW,
      trunkH * 0.9,
    );

    // Leaves: triangle stack.
    final trunkPaint = Paint()..color = trunkFill;
    final leafPaint = Paint()..color = leafFill;

    final tip = Offset(baseTopLeft.dx + 16 * scale, baseTopLeft.dy);
    final left = Offset(
      baseTopLeft.dx + 6 * scale,
      baseTopLeft.dy + 28 * scale,
    );
    final right = Offset(
      baseTopLeft.dx + 26 * scale,
      baseTopLeft.dy + 28 * scale,
    );

    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(right.dx, right.dy)
      ..lineTo(left.dx, left.dy)
      ..close();

    canvas.drawPath(path, leafPaint);
    canvas.drawPath(path, outline);

    final trunkOutline = outline;
    final trunkR = RRect.fromRectAndRadius(
      trunkRect,
      Radius.circular(4 * scale),
    );
    canvas.drawRRect(trunkR, trunkPaint);
    canvas.drawRRect(trunkR, trunkOutline);
  }

  void _drawHouse(
    Canvas canvas, {
    required Offset topLeft,
    required double widthPx,
    required double heightPx,
    required Color fill,
    required Color roof,
    required Paint outline,
    required Color window,
  }) {
    final bodyRect = Rect.fromLTWH(topLeft.dx, topLeft.dy, widthPx, heightPx);
    final bodyPaint = Paint()..color = fill;

    // Roof = triangle.
    final roofPeak = Offset(
      topLeft.dx + widthPx / 2,
      topLeft.dy - heightPx * 0.18,
    );
    final roofLeft = Offset(topLeft.dx, topLeft.dy);
    final roofRight = Offset(topLeft.dx + widthPx, topLeft.dy);

    final roofPath = Path()
      ..moveTo(roofPeak.dx, roofPeak.dy)
      ..lineTo(roofRight.dx, roofRight.dy)
      ..lineTo(roofLeft.dx, roofLeft.dy)
      ..close();

    final houseOutlinePaint = outline;

    canvas.drawPath(roofPath, Paint()..color = roof);
    canvas.drawPath(roofPath, houseOutlinePaint);

    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, Radius.circular(6)),
      bodyPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, Radius.circular(6)),
      houseOutlinePaint,
    );

    // Windows: 2x2 blocks.
    final winW = widthPx * 0.18;
    final winH = heightPx * 0.18;

    final wPaint = Paint()..color = window;
    final wOutline = Paint()
      ..color = Colors.black.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final win1 = Rect.fromLTWH(
      topLeft.dx + widthPx * 0.18,
      topLeft.dy + heightPx * 0.36,
      winW,
      winH,
    );
    final win2 = Rect.fromLTWH(
      topLeft.dx + widthPx * 0.64,
      topLeft.dy + heightPx * 0.36,
      winW,
      winH,
    );
    final win3 = Rect.fromLTWH(
      topLeft.dx + widthPx * 0.18,
      topLeft.dy + heightPx * 0.62,
      winW,
      winH,
    );
    final win4 = Rect.fromLTWH(
      topLeft.dx + widthPx * 0.64,
      topLeft.dy + heightPx * 0.62,
      winW,
      winH,
    );

    for (final r in [win1, win2, win3, win4]) {
      canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(3)), wPaint);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(3)),
        wOutline,
      );
    }

    // Chimney.
    final chimW = widthPx * 0.12;
    final chimH = heightPx * 0.22;
    final chimRect = Rect.fromLTWH(
      topLeft.dx + widthPx * 0.72,
      topLeft.dy - chimH * 0.02,
      chimW,
      chimH,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(chimRect, Radius.circular(3)),
      Paint()..color = Colors.black.withOpacity(0.9),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(chimRect, Radius.circular(3)),
      wOutline,
    );
  }

  void _drawLevelLabel(Canvas canvas) {
    final label = level.visuals.name;
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final fill = Paint()..color = Colors.white.withOpacity(0.22);

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final pad = 12.0;
    final rect = RRect.fromLTRBR(
      16,
      16,
      16 + textPainter.width + pad * 2,
      16 + textPainter.height + pad * 2,
      const Radius.circular(10),
    );

    canvas.drawRRect(rect, fill);
    canvas.drawRRect(rect, paint);

    textPainter.paint(canvas, Offset(rect.left + pad, rect.top + pad));
  }

  void _drawStickman(Canvas canvas, Stickman stickman) {
    final w = _stickmanWidthPx();
    final h = _stickmanHeightPx();
    final effectiveH = snapshot.crawlingActive ? h * 0.58 : h;

    // Center stickman on X. stickman.y is bottom.
    final cx = stickman.x;
    final bottomY = stickman.y;

    final effectiveColor = _effectiveStickmanColor();

    final outline = Paint()
      ..color = effectiveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final fillPaint = Paint()..color = effectiveColor;

    // Run cycle.
    final isRunning = snapshot.status == GameStatus.running;
    final inAirFactor = stickman.vy < -5 ? 0.45 : 1.0;
    final phase = snapshot.timeSec * 10.0;

    // Realistic running body: bounce with each stride + forward lean.
    final bobAmp = effectiveH * 0.035;
    final bob = isRunning && !snapshot.crawlingActive
        ? -sin(phase).abs() * bobAmp * inAirFactor
        : 0.0;
    final bodyBottom = bottomY + bob;
    final runLeanPx = isRunning && !snapshot.crawlingActive ? w * 0.05 : 0.0;

    // Connect body to the bottom of the head circle.
    // Pull torso up slightly so the head circle visually touches the body (no gap).
    // Put the torso start exactly where the head circle ends.
    final headCenterY = bodyBottom - effectiveH * 0.88;
    final torsoTop = headCenterY + effectiveH * 0.09;
    final hipY = bodyBottom - effectiveH * 0.42;

    // --- Smash punch animation ---
    // Progress across the 0.18s smash window (0 = start, 1 = done).
    final smashActive = snapshot.smashActive;
    final smashProgress = smashActive
        ? (1 - snapshot.smashRemainingSec / _smashWindowSec).clamp(0.0, 1.0)
        : 0.0;
    // Triangle wave: fist extends fast (0→1 by ~35% of the window), holds
    // briefly, then recoils. This reads as a sharp, punchy strike.
    final punchExtend = smashActive
        ? (smashProgress < 0.35
            ? smashProgress / 0.35
            : ((1 - smashProgress) / 0.65).clamp(0.0, 1.0))
        : 0.0;

    // Body leans into the punch (smash) and tilts into the run.
    final bodyCx = cx + punchExtend * w * 0.10;
    final shoulderX = bodyCx + runLeanPx * 0.5;
    final hipX = bodyCx - runLeanPx * 0.5;

    // Head.
    canvas.drawCircle(Offset(shoulderX, headCenterY), effectiveH * 0.09, fillPaint);

    // Body: torso tilts forward while running.
    canvas.drawLine(
      Offset(shoulderX, torsoTop),
      Offset(hipX, hipY),
      outline,
    );

    // --- Arms (2 segments) — boxing guard: both fists up & forward,
    // elbows bent and tucked. Sized relative to the smaller of width/height
    // so the arms stay balanced with the body.
    final shoulderY = torsoTop;
    final s = min(w, effectiveH) * 0.5;

    // Small forward bob so the guard feels alive while running.
    final guardBob = isRunning ? sin(phase) * s * 0.02 : 0.0;

    if (smashActive) {
      // Cinematic cross punch: rear fist chambers, lead fist drives forward.
      final reach = w * (0.32 + punchExtend * 0.55);
      final raise = s * (0.04 - punchExtend * 0.10);

      final leadElbow = Offset(bodyCx + w * 0.02, shoulderY + s * 0.24);
      final leadFist = Offset(bodyCx + reach, shoulderY + s * 0.04 + raise);
      final rearElbow = Offset(bodyCx - w * 0.06, shoulderY + s * 0.28);
      final rearFist = Offset(bodyCx + w * 0.12, shoulderY + s * 0.16);

      canvas.drawLine(Offset(shoulderX, shoulderY), leadElbow, outline);
      canvas.drawLine(leadElbow, leadFist, outline);
      canvas.drawLine(Offset(shoulderX, shoulderY), rearElbow, outline);
      canvas.drawLine(rearElbow, rearFist, outline);

      // Glove: filled circle at the striking fist.
      canvas.drawCircle(
        leadFist,
        s * (0.10 + punchExtend * 0.04),
        fillPaint,
      );

      // Impact burst when the fist is fully extended.
      if (punchExtend > 0.55) {
        _drawImpactBurst(
          canvas,
          center: leadFist,
          size: s * (0.7 + punchExtend * 0.9),
          strength: (punchExtend - 0.55) / 0.45,
        );
      }

      // Expose fist position so the streak trail can follow it.
      _punchFist = leadFist;
      _punchStrength = punchExtend;
    } else {
      final rearElbow = Offset(cx - w * 0.03, shoulderY + s * 0.26);
      final leadElbow = Offset(cx + w * 0.08, shoulderY + s * 0.20);
      final rearFist = Offset(
        cx + w * 0.18,
        shoulderY + s * 0.12 + guardBob,
      );
      final leadFist = Offset(
        cx + w * 0.32,
        shoulderY + s * 0.04 - guardBob,
      );

      canvas.drawLine(Offset(shoulderX, shoulderY), rearElbow, outline);
      canvas.drawLine(rearElbow, rearFist, outline);
      canvas.drawLine(Offset(shoulderX, shoulderY), leadElbow, outline);
      canvas.drawLine(leadElbow, leadFist, outline);

      _punchFist = null;
      _punchStrength = 0;
    }

    // --- Legs — human running gait (2 segments + 2-bone IK) ---
    final hip = Offset(hipX, hipY);

    if (isRunning && !snapshot.crawlingActive) {
      final thighLen = effectiveH * 0.21;
      final shinLen = effectiveH * 0.22;
      final maxReach = thighLen + shinLen - 1.0;
      final strideLen = w * 0.14;
      final maxLift = effectiveH * 0.13;

      // Foot follows a triangle wave: lifts and reaches forward in a straight
      // line (piston-like), so the runner moves straight ahead with the foot
      // planted behind and the other planted in front.
      Offset footFor(double p) {
        final cycle = (p / pi) % 2.0;
        final tri = cycle < 1.0 ? cycle : 2.0 - cycle;
        final lift = tri * maxLift;
        // Reach forward while lifted, back behind the hip while planted.
        final fwd = (tri - 0.5) * 2.0;
        final fx = hip.dx + strideLen * fwd;
        return Offset(fx, bottomY - lift);
      }

      // Solve the knee so thigh+shin reach hip -> foot, bending the knee
      // up/forward like a real runner.
      Offset kneeFor(Offset foot) {
        final dx = foot.dx - hip.dx;
        final dy = foot.dy - hip.dy;
        final rawD = sqrt(dx * dx + dy * dy);
        // Pull the foot within the leg's reach so the shin never stretches.
        final scale = rawD > 1.0 ? min(1.0, maxReach / rawD) : 1.0;
        final fx = hip.dx + dx * scale;
        final fy = hip.dy + dy * scale;
        final d2 = (fx - hip.dx) * (fx - hip.dx) + (fy - hip.dy) * (fy - hip.dy);
        final D = max(1.0, sqrt(d2));
        final cosA = ((thighLen * thighLen + D * D - shinLen * shinLen) /
                (2 * thighLen * D))
            .clamp(-1.0, 1.0);
        final a = acos(cosA);
        final base = atan2(fy - hip.dy, fx - hip.dx);
        final knee1 = Offset(
          hip.dx + thighLen * cos(base + a),
          hip.dy + thighLen * sin(base + a),
        );
        final knee2 = Offset(
          hip.dx + thighLen * cos(base - a),
          hip.dy + thighLen * sin(base - a),
        );
        // Pick the knee that points up/forward (reads as a bent running knee).
        return knee1.dy <= knee2.dy ? knee1 : knee2;
      }

      final leftFoot = footFor(phase);
      final rightFoot = footFor(phase + pi);
      final leftKnee = kneeFor(leftFoot);
      final rightKnee = kneeFor(rightFoot);

      canvas.drawLine(hip, leftKnee, outline);
      canvas.drawLine(leftKnee, leftFoot, outline);
      canvas.drawLine(hip, rightKnee, outline);
      canvas.drawLine(rightKnee, rightFoot, outline);
    } else if (snapshot.crawlingActive) {
      // Crawl: short, bent legs tucked under the body.
      final leftKnee = Offset(hip.dx - w * 0.12, hipY + effectiveH * 0.14);
      final leftFoot = Offset(hip.dx - w * 0.22, bottomY);
      final rightKnee = Offset(hip.dx + w * 0.12, hipY + effectiveH * 0.14);
      final rightFoot = Offset(hip.dx + w * 0.22, bottomY);

      canvas.drawLine(hip, leftKnee, outline);
      canvas.drawLine(leftKnee, leftFoot, outline);
      canvas.drawLine(hip, rightKnee, outline);
      canvas.drawLine(rightKnee, rightFoot, outline);
    } else {
      // Standing: two straight legs slightly apart.
      canvas.drawLine(hip, Offset(hip.dx - w * 0.12, bottomY), outline);
      canvas.drawLine(hip, Offset(hip.dx + w * 0.12, bottomY), outline);
    }

    // If shield active, draw halo.
    if (snapshot.shieldActive) {
      final haloPaint = Paint()
        ..color = Colors.yellow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5;
      canvas.drawCircle(Offset(shoulderX, headCenterY), effectiveH * 0.22, haloPaint);

      // Shield countdown timer above the head.
      if (snapshot.shieldRemainingSec > 0) {
        final secs = snapshot.shieldRemainingSec.ceil();
        final textPainter = TextPainter(
          text: TextSpan(
            text: '$secs',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.0,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final badgeRadius = 11.0;
        final badgeCenter = Offset(
          shoulderX,
          headCenterY - effectiveH * 0.09 - badgeRadius - 5,
        );

        canvas.drawCircle(
          badgeCenter,
          badgeRadius,
          Paint()..color = const Color(0xE6141B2E),
        );
        canvas.drawCircle(
          badgeCenter,
          badgeRadius,
          Paint()
            ..color = Colors.yellow
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        textPainter.paint(
          canvas,
          Offset(
            badgeCenter.dx - textPainter.width / 2,
            badgeCenter.dy - textPainter.height / 2,
          ),
        );
      }
    }
  }

  /// Impact starburst drawn at the striking fist.
  void _drawImpactBurst(
    Canvas canvas, {
    required Offset center,
    required double size,
    required double strength,
  }) {
    final rayPaint = Paint()
      ..color = Colors.yellow.withOpacity(0.35 + strength * 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    const rays = 8;
    for (int i = 0; i < rays; i++) {
      final a = -pi / 2 + i * (2 * pi / rays) + 0.35;
      canvas.drawLine(
        center,
        Offset(
          center.dx + cos(a) * size,
          center.dy + sin(a) * size,
        ),
        rayPaint,
      );
    }

    canvas.drawCircle(
      center,
      size * 0.22,
      Paint()
        ..color = Colors.white.withOpacity(0.4 + strength * 0.6)
        ..style = PaintingStyle.fill,
    );
  }

  /// Horizontal speed streaks trailing behind the punching fist.
  void _drawPunchStreaks(Canvas canvas) {
    final fist = _punchFist;
    if (fist == null || _punchStrength <= 0) return;

    final paint = Paint()
      ..color = Colors.white.withOpacity(0.35 + _punchStrength * 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 3; i++) {
      final y = fist.dy + (i - 1) * 9.0;
      final len = 18 + i * 8.0;
      canvas.drawLine(
        Offset(fist.dx - len, y),
        Offset(fist.dx - 3, y),
        paint,
      );
    }
  }

  void _drawObstacle(Canvas canvas, Obstacle o) {
    final outline = Paint()
      ..color = _outlineColor()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final fill = Paint()..color = _obstacleFill(o.type);

    final x1 = o.x;
    final y1 = o.y;
    final x2 = o.x + o.width;
    final y2 = o.y + o.height;

    if (o.rotation != 0) {
      canvas.save();
      canvas.translate((x1 + x2) / 2, (y1 + y2) / 2);
      canvas.rotate(o.rotation);
      canvas.translate(-((x1 + x2) / 2), -((y1 + y2) / 2));

      // Draw as rect in rotated space.
      canvas.drawRect(Rect.fromLTRB(x1, y1, x2, y2), fill);
      canvas.drawRect(Rect.fromLTRB(x1, y1, x2, y2), outline);

      canvas.restore();
      return;
    }

    switch (o.type) {
      case ObstacleType.spike:
        _drawSpike(canvas, o, fill, outline);
        return;
      case ObstacleType.cactus:
        _drawCactus(canvas, o, fill, outline);
        return;
      case ObstacleType.stalagmite:
        _drawStalagmite(canvas, o, fill, outline);
        return;
      case ObstacleType.rollingRock:
        canvas.drawOval(Rect.fromLTRB(x1, y1, x2, y2), fill);
        canvas.drawOval(Rect.fromLTRB(x1, y1, x2, y2), outline);
        return;
      case ObstacleType.drone:
        _drawDrone(canvas, o, fill, outline);
        return;
      case ObstacleType.laser:
        canvas.drawRect(Rect.fromLTRB(x1, y1, x2, y2), fill);
        canvas.drawRect(Rect.fromLTRB(x1, y1, x2, y2), outline);
        // Teeth lines.
        final teeth = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        for (int i = 0; i < 5; i++) {
          final px = x1 + (o.width * (i + 0.5) / 5);
          canvas.drawLine(Offset(px, y1), Offset(px + 6, y2), teeth);
        }
        return;
      case ObstacleType.bat:
        _drawBat(canvas, o, fill, outline);
        return;
      case ObstacleType.fireJet:
        _drawFireJet(canvas, o, fill, outline);
        return;
      case ObstacleType.fireball:
        canvas.drawOval(Rect.fromLTRB(x1, y1, x2, y2), fill);
        canvas.drawOval(Rect.fromLTRB(x1, y1, x2, y2), outline);
        return;
      case ObstacleType.pendulumMine:
        _drawPendulumMine(canvas, o, fill, outline);
        return;
    }
  }

  Color _flutterColor(int argb) => Color(argb);

  /// Stickman color with automatic contrast: on a light/white background the
  /// stickman is drawn black so it stays clearly visible.
  Color _effectiveStickmanColor() {
    final bg = _flutterColor(level.visuals.topColor);
    final luminance =
        (0.299 * bg.red + 0.587 * bg.green + 0.114 * bg.blue) / 255.0;
    return luminance > 0.65 ? Colors.black : stickmanColor;
  }

  /// Obstacle outline color. High-contrast mode swaps the usual black
  /// outlines for white so obstacles pop against any background.
  Color _outlineColor() => highContrast ? Colors.white : Colors.black;

  void _drawSpike(Canvas canvas, Obstacle o, Paint fill, Paint outline) {
    final x1 = o.x;
    final y1 = o.y;
    final x2 = o.x + o.width;
    final y2 = o.y + o.height;

    final tip = Offset((x1 + x2) / 2, y1);
    final left = Offset(x1, y2);
    final right = Offset(x2, y2);

    final path = Path()
      ..moveTo(left.dx, left.dy)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(right.dx, right.dy)
      ..close();

    canvas.drawPath(path, fill);
    canvas.drawPath(path, outline);

    // small base line
    canvas.drawLine(Offset(x1, y2), Offset(x2, y2), outline);
  }

  void _drawCactus(Canvas canvas, Obstacle o, Paint fill, Paint outline) {
    final x1 = o.x;
    final y1 = o.y;
    final x2 = o.x + o.width;
    final y2 = o.y + o.height;

    final body = RRect.fromRectAndRadius(
      Rect.fromLTRB(x1, y1, x2, y2),
      const Radius.circular(10),
    );

    canvas.drawRRect(body, fill);
    canvas.drawRRect(body, outline);

    // arms
    final armPaint = Paint()
      ..color = fill.color
      ..style = PaintingStyle.fill;

    final armOutline = Paint()
      ..color = _outlineColor()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final midY = y1 + (y2 - y1) * 0.45;
    final armLen = o.width * 0.55;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x1 - armLen * 0.6, midY, armLen, o.height * 0.25),
        const Radius.circular(8),
      ),
      armPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x1 - armLen * 0.6, midY, armLen, o.height * 0.25),
        const Radius.circular(8),
      ),
      armOutline,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x2 - armLen * 0.4, midY, armLen, o.height * 0.25),
        const Radius.circular(8),
      ),
      armPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x2 - armLen * 0.4, midY, armLen, o.height * 0.25),
        const Radius.circular(8),
      ),
      armOutline,
    );
  }

  void _drawStalagmite(Canvas canvas, Obstacle o, Paint fill, Paint outline) {
    final x1 = o.x;
    final y1 = o.y;
    final x2 = o.x + o.width;
    final y2 = o.y + o.height;

    final path = Path()
      ..moveTo(x1, y2)
      ..lineTo((x1 + x2) / 2, y1)
      ..lineTo(x2, y2)
      ..close();

    canvas.drawPath(path, fill);
    canvas.drawPath(path, outline);

    // little cracks
    final crack = Paint()
      ..color = _outlineColor()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawLine(
      Offset((x1 + x2) / 2, y1 + 8),
      Offset((x1 + x2) / 2, y2 - 10),
      crack,
    );
  }

  void _drawDrone(Canvas canvas, Obstacle o, Paint fill, Paint outline) {
    final x1 = o.x;
    final y1 = o.y;
    final x2 = o.x + o.width;
    final y2 = o.y + o.height;

    final body = Rect.fromLTRB(x1, y1, x2, y2);
    canvas.drawOval(body, fill);
    canvas.drawOval(body, outline);

    final eyePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final eyeY = y1 + (o.height * 0.42);
    final eyeW = o.width * 0.18;
    canvas.drawRect(
      Rect.fromLTWH(x1 + o.width * 0.28, eyeY, eyeW, 6),
      eyePaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(x1 + o.width * 0.56, eyeY, eyeW, 6),
      eyePaint,
    );
  }

  void _drawBat(Canvas canvas, Obstacle o, Paint fill, Paint outline) {
    // A simple “W” wing shape.
    final x1 = o.x;
    final y1 = o.y;
    final x2 = o.x + o.width;
    final y2 = o.y + o.height;

    final midX = (x1 + x2) / 2;
    final path = Path()
      ..moveTo(x1, y2)
      ..quadraticBezierTo(
        x1 + o.width * 0.22,
        y1 + o.height * 0.35,
        midX,
        y1 + 2,
      )
      ..quadraticBezierTo(x1 + o.width * 0.78, y1 + o.height * 0.35, x2, y2)
      ..close();

    canvas.drawPath(path, fill);
    canvas.drawPath(path, outline);

    // Tail hook
    final hook = Paint()
      ..color = _outlineColor()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawLine(Offset(midX, y2), Offset(midX, y2 + 10), hook);
  }

  void _drawFireJet(Canvas canvas, Obstacle o, Paint fill, Paint outline) {
    final x1 = o.x;
    final y1 = o.y;
    final x2 = o.x + o.width;
    final y2 = o.y + o.height;

    canvas.drawRect(Rect.fromLTRB(x1, y1, x2, y2), fill);
    canvas.drawRect(Rect.fromLTRB(x1, y1, x2, y2), outline);

    // Flame teeth
    final flamePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    for (int i = 0; i < 6; i++) {
      final px = x1 + (o.width * (i + 0.5) / 6);
      canvas.drawLine(Offset(px, y1 + 3), Offset(px + 7, y2 - 2), flamePaint);
    }
  }

  void _drawPendulumMine(Canvas canvas, Obstacle o, Paint fill, Paint outline) {
    final x1 = o.x;
    final y1 = o.y;
    final x2 = o.x + o.width;
    final y2 = o.y + o.height;

    final topAnchor = Offset((x1 + x2) / 2, y1 - 38);
    final center = Offset((x1 + x2) / 2, (y1 + y2) / 2);

    final rope = Paint()
      ..color = _outlineColor()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    canvas.drawLine(topAnchor, center, rope);

    // Mine body
    canvas.drawOval(Rect.fromLTRB(x1, y1, x2, y2), fill);
    canvas.drawOval(Rect.fromLTRB(x1, y1, x2, y2), outline);

    // Spikes
    final spikePaint = Paint()
      ..color = _outlineColor()
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(center.dx - 6, center.dy), 3.5, spikePaint);
    canvas.drawCircle(Offset(center.dx + 6, center.dy), 3.5, spikePaint);
  }

  void _drawCoin(Canvas canvas, Coin c) {
    final r = c.radius;
    final fill = Paint()..color = const Color.fromARGB(255, 255, 191, 0);
    final outline = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final phase = c.phase;
    final bob = sin(phase) * 2.0;

    canvas.drawCircle(Offset(c.x, c.y + bob), r, fill);
    canvas.drawCircle(Offset(c.x, c.y + bob), r, outline);

    final shine = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(c.x, c.y + bob), radius: r),
      pi * 0.1,
      pi * 0.3,
      false,
      shine,
    );

    // Sparkle glint: a flickering 4-point twinkle over the coin.
    _drawSparkleGlint(
      canvas,
      center: Offset(c.x, c.y + bob),
      phase: phase,
      scale: r,
    );
  }

  /// A flickering 4-point twinkle used to highlight collectibles.
  /// [scale] sizes the glint relative to the underlying icon.
  void _drawSparkleGlint(
    Canvas canvas, {
    required Offset center,
    required double phase,
    required double scale,
  }) {
    final twinkle = (sin(snapshot.timeSec * 6.0 + phase) + 1) / 2; // 0..1
    final flare = 0.5 + twinkle * 0.7; // 0.5..1.2
    final sparklePaint = Paint()
      ..color = Colors.white.withOpacity(0.35 + twinkle * 0.6)
      ..style = PaintingStyle.fill;

    final fl = scale * 1.8 * flare;
    final sw = scale * 0.28;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(phase + snapshot.timeSec * 2.0);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: fl * 2, height: sw),
      sparklePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: sw, height: fl * 2),
      sparklePaint,
    );
    canvas.restore();
  }

  void _drawPowerUp(Canvas canvas, PowerUp p) {
    final outline = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final fill = Paint()..color = _powerFill(p.type);

    final cx = p.x;
    final cy = p.y;
    final s = p.size;

    if (p.type == PowerUpType.heal25 || p.type == PowerUpType.heal50) {
      // Heart: small for +25%, larger with sparkle for +50%.
      final isBig = p.type == PowerUpType.heal50;
      final r = s * (isBig ? 0.5 : 0.34);
      _drawHeart(canvas, center: Offset(cx, cy), radius: r, paint: fill);
      _drawHeart(
        canvas,
        center: Offset(cx, cy),
        radius: r,
        paint: outline,
      );
      // Highlight glint on both hearts so they read as collectible.
      _drawSparkleGlint(
        canvas,
        center: Offset(cx - s * 0.1, cy - s * 0.15),
        phase: p.phase,
        scale: s * (isBig ? 0.35 : 0.22),
      );
      return;
    }

    if (p.type == PowerUpType.shield) {
      // Shield = rounded pentagon-ish via arc strokes.
      final r = s * 0.5;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - r, cy - r, s, s),
          const Radius.circular(14),
        ),
        fill,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - r, cy - r, s, s),
          const Radius.circular(14),
        ),
        outline,
      );

      final bolt = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5;

      canvas.drawLine(
        Offset(cx, cy - s * 0.15),
        Offset(cx + s * 0.18, cy + s * 0.2),
        bolt,
      );
      canvas.drawLine(
        Offset(cx - s * 0.02, cy - s * 0.05),
        Offset(cx + s * 0.22, cy - s * 0.05),
        bolt,
      );
      _drawSparkleGlint(
        canvas,
        center: Offset(cx, cy),
        phase: p.phase,
        scale: s * 0.5,
      );
      return;
    }

    // Magnet = diamond with bars.
    final half = s * 0.5;
    final path = Path()
      ..moveTo(cx, cy - half)
      ..lineTo(cx + half, cy)
      ..lineTo(cx, cy + half)
      ..lineTo(cx - half, cy)
      ..close();

    canvas.drawPath(path, fill);
    canvas.drawPath(path, outline);

    final bar = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawLine(
      Offset(cx, cy - half * 0.65),
      Offset(cx, cy + half * 0.65),
      bar,
    );
    canvas.drawLine(
      Offset(cx - half * 0.35, cy),
      Offset(cx + half * 0.35, cy),
      bar,
    );
    _drawSparkleGlint(
      canvas,
      center: Offset(cx, cy),
      phase: p.phase,
      scale: s * 0.5,
    );
  }

  /// Draws a classic heart shape centered at [center] with the given radius.
  void _drawHeart(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Paint paint,
  }) {
    final r = radius;
    final cx = center.dx;
    final cy = center.dy;
    final path = Path()
      ..moveTo(cx, cy + r * 0.9)
      ..cubicTo(
        cx - r * 1.5,
        cy + r * 0.2,
        cx - r * 1.1,
        cy - r * 0.7,
        cx,
        cy - r * 0.15,
      )
      ..cubicTo(
        cx + r * 1.1,
        cy - r * 0.7,
        cx + r * 1.5,
        cy + r * 0.2,
        cx,
        cy + r * 0.9,
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawHud(Canvas canvas, {required double groundY}) {
    final outline = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final badgeFill = Paint()..color = Colors.white.withOpacity(0.18);

    double y = 18;
    double x = width - 182;

    // Score badge.
    _drawBadge(
      canvas,
      x: x,
      y: y,
      w: 166,
      h: 44,
      title: 'SCORE',
      value: snapshot.score.toString(),
      badgeFill: badgeFill,
      outline: outline,
      color: Colors.white,
    );
    y += 50;

    // Coins badge.
    _drawBadge(
      canvas,
      x: x,
      y: y,
      w: 166,
      h: 44,
      title: 'COINS',
      value: snapshot.coins.toString(),
      badgeFill: badgeFill,
      outline: outline,
      color: Colors.white,
    );
  }

  void _drawBadge(
    Canvas canvas, {
    required double x,
    required double y,
    required double w,
    required double h,
    required String title,
    required String value,
    required Paint badgeFill,
    required Paint outline,
    required Color color,
  }) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, w, h),
      const Radius.circular(12),
    );
    canvas.drawRRect(rrect, badgeFill);
    canvas.drawRRect(rrect, outline);

    final titlePainter = TextPainter(
      text: TextSpan(
        text: title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final valuePainter = TextPainter(
      text: TextSpan(
        text: value,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: Colors.yellow,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Layout inside badge: title near top, value around lower-middle.
    final titleY = y + 8;
    final valueCenterY = y + h * 0.62;
    titlePainter.paint(canvas, Offset(x + 12, titleY));
    valuePainter.paint(
      canvas,
      Offset(x + 12, valueCenterY - valuePainter.height / 2),
    );
  }

  double _stickmanWidthPx() => max(32.0, width * 0.12);
  double _stickmanHeightPx() => max(90.0, height * 0.22);

  /// Bottom-center life indicator: circular stickman head + HP bar + % text.
  /// Rendered in the ground band, below the dashed highway line.
  void _drawLifeBar(Canvas canvas, {required double groundY}) {
    // Slight scale-down so the indicator occupies less screen space.
    final s = 0.78;
    final barW = 230.0 * s;
    final barH = 46.0 * s;
    final bottomPad = 8.0;
    final left = (width - barW) / 2;
    final top = height - barH - bottomPad;

    // Guard against overlapping the right-side control buttons on narrow screens.
    if (left < 6) {
      return;
    }

    final life = snapshot.lifePercent.clamp(0.0, 100.0);

    // Container pill.
    final container = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, barW, barH),
      Radius.circular(barH / 2),
    );
    canvas.drawRRect(
      container,
      Paint()..color = const Color(0x99000000),
    );
    canvas.drawRRect(
      container,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Low-HP pulse: bar + text steady once life < 30%.
    final lowHp = life < 30;
    final pulse = lowHp ? (0.6 + 0.4 * (0.5 + 0.5 * sin(snapshot.timeSec * 8))) : 1.0;

    // Left: circular stickman head avatar.
    final headRadius = 16.0 * s;
    final headPadding = 30.0 * s;
    final headCenter = Offset(left + headPadding, top + barH / 2);
    canvas.drawCircle(
      headCenter,
      headRadius,
      Paint()
        ..color = snapshot.damageFlashSec > 0
            ? Colors.red
            : _effectiveStickmanColor(),
    );
    canvas.drawCircle(
      headCenter,
      headRadius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // Simple face so the avatar reads as the stickman's head.
    // Damage -> angry; collecting a heal -> happy; otherwise neutral.
    final angry = snapshot.damageGraceSec > 0 || snapshot.damageFlashSec > 0;
    final happy = snapshot.healFlashSec > 0;
    final eyePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    if (happy) {
      // Wide smiling eyes (shorter upward arcs).
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(headCenter.dx - 3.5 * s, headCenter.dy - 3 * s),
          width: 5 * s,
          height: 5 * s,
        ),
        pi,
        pi,
        false,
        eyePaint,
      );
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(headCenter.dx + 3.5 * s, headCenter.dy - 3 * s),
          width: 5 * s,
          height: 5 * s,
        ),
        pi,
        pi,
        false,
        eyePaint,
      );
    } else if (angry) {
      // Drooping (upside-down V) brows for an angry look.
      canvas.drawLine(
        Offset(headCenter.dx - 6 * s, headCenter.dy - 4 * s),
        Offset(headCenter.dx - 3 * s, headCenter.dy - 1 * s),
        eyePaint,
      );
      canvas.drawLine(
        Offset(headCenter.dx + 3 * s, headCenter.dy - 1 * s),
        Offset(headCenter.dx + 6 * s, headCenter.dy - 4 * s),
        eyePaint,
      );
    } else {
      canvas.drawLine(
        Offset(headCenter.dx - 5 * s, headCenter.dy - 2 * s),
        Offset(headCenter.dx - 2 * s, headCenter.dy - 2 * s),
        eyePaint,
      );
      canvas.drawLine(
        Offset(headCenter.dx + 2 * s, headCenter.dy - 2 * s),
        Offset(headCenter.dx + 5 * s, headCenter.dy - 2 * s),
        eyePaint,
      );
    }
    if (happy) {
      // Big happy smile.
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(headCenter.dx, headCenter.dy + 3 * s),
          width: 10 * s,
          height: 7 * s,
        ),
        0,
        pi,
        false,
        eyePaint,
      );
    } else if (angry) {
      // Frowning mouth curve.
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(headCenter.dx, headCenter.dy + 5 * s),
          width: 10 * s,
          height: 6 * s,
        ),
        pi + 0.15,
        pi - 0.3,
        false,
        eyePaint,
      );
    } else {
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(headCenter.dx, headCenter.dy + 3 * s),
          width: 10 * s,
          height: 6 * s,
        ),
        0.15,
        pi - 0.3,
        false,
        eyePaint,
      );
    }

    // Right: HP bar.
    final br = 9.0 * s;
    final barX = headCenter.dx + headRadius + br;
    final barW0 = barW - (barX - left) - br;
    final barHh = 14.0 * s;
    final barYB = top + barH / 2 - barHh / 2;
    final barRect = Rect.fromLTWH(barX, barYB, barW0, barHh);
    final track = RRect.fromRectAndRadius(barRect, Radius.circular(7 * s));
    canvas.drawRRect(track, Paint()..color = const Color(0x66000000));
    final fill = RRect.fromRectAndRadius(
      Rect.fromLTWH(barX, barYB, barW0 * life / 100, barHh),
      Radius.circular(7 * s),
    );
    canvas.drawRRect(
      fill,
      Paint()..color = _hpColor(life).withValues(alpha: 0.55 * pulse + 0.45),
    );

    // Percentage text centered inside the bar.
    final tp = TextPainter(
      text: TextSpan(
        text: '${life.round()}%',
        style: TextStyle(
          fontSize: 14.0 * s * pulse,
          fontWeight: FontWeight.w900,
          color: Colors.white.withValues(alpha: 0.6 * pulse + 0.4),
          shadows: const [
            Shadow(color: Colors.black, blurRadius: 0, offset: Offset(1, 1)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(
        barX + barW0 / 2 - tp.width / 2,
        top + barH / 2 - tp.height / 2,
      ),
    );
  }

  Color _hpColor(double life) {
    if (life < 25) return const Color(0xFFE74C3C);
    if (life < 50) return Color.lerp(const Color(0xFFF1C40F), const Color(0xFFE74C3C), (50 - life) / 25)!;
    return Color.lerp(const Color(0xFF2ECC71), const Color(0xFFF1C40F), (100 - life) / 50)!;
  }

  Color _obstacleFill(ObstacleType type) {
    switch (type) {
      case ObstacleType.spike:
        return Colors.white70;
      case ObstacleType.cactus:
        return const Color.fromARGB(255, 18, 124, 32);
      case ObstacleType.stalagmite:
        return const Color.fromARGB(255, 206, 147, 216);
      case ObstacleType.rollingRock:
        return Colors.brown;
      case ObstacleType.drone:
      case ObstacleType.laser:
      case ObstacleType.bat:
      case ObstacleType.fireJet:
      case ObstacleType.fireball:
      case ObstacleType.pendulumMine:
        return _flyingObstacleFill(type);
    }
  }

  /// Flying/hanging obstacles get bright, level-aware accent colors so they
  /// always stand out against each level's sky instead of blending in
  /// (e.g. black bat/drone were invisible on the dark blue Night City sky).
  Color _flyingObstacleFill(ObstacleType type) {
    switch (level.levelIndex) {
      case 1: // FOREST – dark green sky
        switch (type) {
          case ObstacleType.drone:
            return Colors.cyanAccent;
          case ObstacleType.bat:
            return Colors.purpleAccent;
          default:
            return _defaultFlyingFill(type);
        }
      case 2: // DESERT – tan sky
        switch (type) {
          case ObstacleType.pendulumMine:
            return Colors.grey.shade300;
          default:
            return _defaultFlyingFill(type);
        }
      case 3: // NIGHT CITY – dark blue sky
        switch (type) {
          case ObstacleType.drone:
            return Colors.yellowAccent;
          case ObstacleType.bat:
            return Colors.orangeAccent;
          default:
            return _defaultFlyingFill(type);
        }
      case 4: // DARK CAVE – purple sky
        switch (type) {
          case ObstacleType.drone:
            return Colors.cyanAccent;
          case ObstacleType.bat:
            return Colors.orangeAccent;
          case ObstacleType.pendulumMine:
            return Colors.grey.shade300;
          default:
            return _defaultFlyingFill(type);
        }
      case 5: // VOLCANO – dark red sky
        switch (type) {
          case ObstacleType.drone:
            return Colors.yellowAccent;
          case ObstacleType.laser:
            return Colors.cyanAccent;
          case ObstacleType.fireJet:
            return Colors.amber;
          case ObstacleType.fireball:
            return Colors.yellowAccent;
          default:
            return _defaultFlyingFill(type);
        }
      default:
        return _defaultFlyingFill(type);
    }
  }

  Color _defaultFlyingFill(ObstacleType type) {
    switch (type) {
      case ObstacleType.drone:
        return Colors.black87;
      case ObstacleType.laser:
        return Colors.redAccent;
      case ObstacleType.bat:
        return Colors.black;
      case ObstacleType.fireJet:
        return Colors.orangeAccent;
      case ObstacleType.fireball:
        return Colors.deepOrangeAccent;
      case ObstacleType.pendulumMine:
        return Colors.grey;
      default:
        return Colors.black;
    }
  }

  Color _powerFill(PowerUpType type) {
    switch (type) {
      case PowerUpType.shield:
        return Colors.yellow;
      case PowerUpType.magnet:
        return Colors.cyanAccent;
      case PowerUpType.heal25:
        return const Color(0xFFE74C3C);
      case PowerUpType.heal50:
        return const Color(0xFFFF2D55);
    }
  }

  /// Draws smash debris particles — small colored fragments that fly outward
  /// and fade out when an obstacle is destroyed.
  void _drawSmashDebris(Canvas canvas) {
    if (snapshot.smashDebris.isEmpty) return;

    for (final d in snapshot.smashDebris) {
      final alpha = (d.remainingSec / 0.5).clamp(0.0, 1.0);
      if (alpha <= 0.01) continue;

      final baseColor = _obstacleFill(d.obstacleType);
      final color = baseColor.withOpacity(alpha);

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(d.x, d.y);
      // Use position-based seed so rotation stays stable for each particle.
      canvas.rotate(((d.x * 1000 + d.y * 1000).toInt() % 628) / 100.0);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: d.size, height: d.size * 0.6),
        paint,
      );
      canvas.restore();
    }
  }

  /// Draws floating "+N" score popups that rise and fade when an obstacle
  /// is smashed.
  void _drawSmashScorePopups(Canvas canvas) {
    if (snapshot.smashScorePopups.isEmpty) return;

    for (final p in snapshot.smashScorePopups) {
      final t = 1 - (p.remainingSec / 0.8).clamp(0.0, 1.0); // 0 -> 1 over life
      final alpha = (1 - t).clamp(0.0, 1.0);
      if (alpha <= 0.01) continue;

      // Pop-in scale: grows from 0.6 -> 1.0 in the first 25% of life.
      final scale = t < 0.25 ? (0.6 + (t / 0.25) * 0.4) : 1.0;

      final text = p.score >= 0 ? '+${p.score}' : '${p.score}';
      final color = p.score >= 0 ? Colors.yellow : const Color(0xFFFF4D4D);
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: 22 * scale,
            fontWeight: FontWeight.w900,
            color: color.withOpacity(alpha),
            letterSpacing: 0.5,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(alpha * 0.8),
                offset: const Offset(1.5, 1.5),
                blurRadius: 0,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(p.x - tp.width / 2, p.y - tp.height / 2);
      tp.paint(canvas, Offset.zero);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant StickmanRunPainter oldDelegate) {
    return oldDelegate.snapshot != snapshot ||
        oldDelegate.level != level ||
        oldDelegate.stickmanColor != stickmanColor ||
        oldDelegate.highContrast != highContrast;
  }
}
