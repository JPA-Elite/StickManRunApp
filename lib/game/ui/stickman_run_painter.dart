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

  const StickmanRunPainter({
    super.repaint,
    required this.snapshot,
    required this.level,
    required this.width,
    required this.height,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final groundY = height * 0.78;

    // Background.
    _fillBackground(canvas);

    // Ground band.
    final groundPaint = Paint()..color = _flutterColor(level.visuals.groundColor);
    canvas.drawRect(Rect.fromLTWH(0, groundY, width, height - groundY), groundPaint);

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

    // Stickman.
    _drawStickman(canvas, snapshot.stickman);

    // Shield-swoosh effect when smash is active (Captain America style).
    if (snapshot.smashActive) {
      _drawSmashShield(canvas, snapshot.stickman);
    }

    // HUD ornaments (top-right).
    // Hide HUD when the overlay is showing (ready/game-over/level-complete)
    // to prevent SCORE/COINS from overlapping the overlay card.
    if (snapshot.status == GameStatus.running) {
      _drawHud(canvas, groundY: groundY);
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
    Offset baseTopLeft,
    {
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

    final trunkRect = Rect.fromLTWH(baseTopLeft.dx + 6 * scale, baseTopLeft.dy + trunkH, trunkW, trunkH * 0.9);

    // Leaves: triangle stack.
    final trunkPaint = Paint()..color = trunkFill;
    final leafPaint = Paint()..color = leafFill;

    final tip = Offset(baseTopLeft.dx + 16 * scale, baseTopLeft.dy);
    final left = Offset(baseTopLeft.dx + 6 * scale, baseTopLeft.dy + 28 * scale);
    final right = Offset(baseTopLeft.dx + 26 * scale, baseTopLeft.dy + 28 * scale);

    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(right.dx, right.dy)
      ..lineTo(left.dx, left.dy)
      ..close();

    canvas.drawPath(path, leafPaint);
    canvas.drawPath(path, outline);

    final trunkOutline = outline;
    final trunkR = RRect.fromRectAndRadius(trunkRect, Radius.circular(4 * scale));
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
    final roofPeak = Offset(topLeft.dx + widthPx / 2, topLeft.dy - heightPx * 0.18);
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

    final win1 = Rect.fromLTWH(topLeft.dx + widthPx * 0.18, topLeft.dy + heightPx * 0.36, winW, winH);
    final win2 = Rect.fromLTWH(topLeft.dx + widthPx * 0.64, topLeft.dy + heightPx * 0.36, winW, winH);
    final win3 = Rect.fromLTWH(topLeft.dx + widthPx * 0.18, topLeft.dy + heightPx * 0.62, winW, winH);
    final win4 = Rect.fromLTWH(topLeft.dx + widthPx * 0.64, topLeft.dy + heightPx * 0.62, winW, winH);

    for (final r in [win1, win2, win3, win4]) {
      canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(3)), wPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(3)), wOutline);
    }

    // Chimney.
    final chimW = widthPx * 0.12;
    final chimH = heightPx * 0.22;
    final chimRect = Rect.fromLTWH(topLeft.dx + widthPx * 0.72, topLeft.dy - chimH * 0.02, chimW, chimH);
    canvas.drawRRect(RRect.fromRectAndRadius(chimRect, Radius.circular(3)), Paint()..color = Colors.black.withOpacity(0.9));
    canvas.drawRRect(RRect.fromRectAndRadius(chimRect, Radius.circular(3)), wOutline);
  }

  void _drawLevelLabel(Canvas canvas) {
    final label = 'LEVEL ${snapshot.levelIndex}';
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

    textPainter.paint(
      canvas,
      Offset(rect.left + pad, rect.top + pad),
    );
  }

  void _drawStickman(Canvas canvas, Stickman stickman) {
    final w = _stickmanWidthPx();
    final h = _stickmanHeightPx();
    final effectiveH = snapshot.crawlingActive ? h * 0.58 : h;

    // Center stickman on X. stickman.y is bottom.
    final cx = stickman.x;
    final bottomY = stickman.y;
    // Connect body to the bottom of the head circle.
    // Pull torso up slightly so the head circle visually touches the body (no gap).
    // Put the torso start exactly where the head circle ends.
    final headCenterY = bottomY - effectiveH * 0.88;
    final torsoTop = headCenterY + effectiveH * 0.09;

    final outline = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final fillPaint = Paint()..color = Colors.white;

    // Head.
    canvas.drawCircle(
      Offset(cx, headCenterY),
      effectiveH * 0.09,
      fillPaint,
    );

    // Body.
    canvas.drawLine(Offset(cx, torsoTop), Offset(cx, bottomY - effectiveH * 0.18), outline);

    // Running animation: swing arms + legs with a more “natural” gait.
    final isRunning = snapshot.status == GameStatus.running;
    final crawlFactor = snapshot.crawlingActive ? 0.22 : 1.0;

    // If we're in the air (jumping), reduce the run cycle so it feels believable.
    final inAirFactor = stickman.vy < -5 ? 0.45 : 1.0;

    final phase = snapshot.timeSec * 10.0;
    final swing = isRunning ? sin(phase) : 0.0;
    final pulse = (1 + cos(phase)) * 0.5; // 0..1

    final armSwing = swing * crawlFactor * inAirFactor;
    final legSwing = -swing * crawlFactor * inAirFactor;

    // --- Arms (2 segments) ---
    final shoulderY = torsoTop;
    final elbowY = shoulderY + effectiveH * (0.06 + 0.04 * pulse);

    final armUpper = w * (0.38 + 0.10 * pulse);
    final armLower = w * (0.48 - 0.06 * pulse);

    // Connect arms to the torso center.
    final leftShoulder = Offset(cx, shoulderY);
    final rightShoulder = Offset(cx, shoulderY);

    final leftForward = armSwing >= 0 ? 1.0 : -1.0;
    final rightForward = -leftForward;

    final leftElbow = Offset(leftShoulder.dx - armUpper * armSwing, elbowY);
    final rightElbow = Offset(rightShoulder.dx + armUpper * armSwing, elbowY);

    final handY = shoulderY + effectiveH * (0.03 + 0.01 * pulse);

    final leftHand = Offset(leftElbow.dx - armLower * leftForward, handY);
    final rightHand = Offset(rightElbow.dx + armLower * rightForward, handY);

    canvas.drawLine(leftShoulder, leftElbow, outline);
    canvas.drawLine(leftElbow, leftHand, outline);
    canvas.drawLine(rightShoulder, rightElbow, outline);
    canvas.drawLine(rightElbow, rightHand, outline);

    // --- Legs (2 segments) ---
    final hipY = bottomY - effectiveH * 0.18;

    final leftForwardLeg = legSwing > 0 ? 1.0 : -1.0;
    final rightForwardLeg = -leftForwardLeg;

    final stepOut = w * (0.16 + 0.14 * pulse);
    final kneeLift = effectiveH * (0.05 + 0.07 * pulse);

    // Forward leg: higher knee + bigger step.
    final leftKneeY = hipY + kneeLift * (leftForwardLeg > 0 ? 1.0 : 0.25);
    final rightKneeY = hipY + kneeLift * (rightForwardLeg > 0 ? 1.0 : 0.25);

    // Connect legs to the torso center.
    final leftHip = Offset(cx, hipY);
    final leftKnee = Offset(leftHip.dx - leftForwardLeg * stepOut * 0.35, leftKneeY);
    final leftFoot = Offset(leftKnee.dx - leftForwardLeg * stepOut * 0.62, bottomY);

    final rightHip = Offset(cx, hipY);
    final rightKnee = Offset(rightHip.dx - rightForwardLeg * stepOut * 0.35, rightKneeY);
    final rightFoot = Offset(rightKnee.dx - rightForwardLeg * stepOut * 0.62, bottomY);

    canvas.drawLine(leftHip, leftKnee, outline);
    canvas.drawLine(leftKnee, leftFoot, outline);
    canvas.drawLine(rightHip, rightKnee, outline);
    canvas.drawLine(rightKnee, rightFoot, outline);

    // “Jump” hint: if moving up, draw a small dash.
    if (snapshot.status == GameStatus.running && stickman.vy < -50) {
      final dashPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5;
      canvas.drawLine(
        Offset(cx - w * 0.25, bottomY - effectiveH * 0.3),
        Offset(cx + w * 0.25, bottomY - effectiveH * 0.3),
        dashPaint,
      );
    }

    // If shield active, draw halo.
    if (snapshot.shieldActive) {
      final haloPaint = Paint()
        ..color = Colors.yellow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5;
      canvas.drawCircle(Offset(cx, headCenterY), effectiveH * 0.22, haloPaint);
    }
  }

  void _drawObstacle(Canvas canvas, Obstacle o) {
    final outline = Paint()
      ..color = Colors.black
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
      ..color = Colors.black
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
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawLine(Offset((x1 + x2) / 2, y1 + 8), Offset((x1 + x2) / 2, y2 - 10), crack);
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
    canvas.drawRect(Rect.fromLTWH(x1 + o.width * 0.28, eyeY, eyeW, 6), eyePaint);
    canvas.drawRect(Rect.fromLTWH(x1 + o.width * 0.56, eyeY, eyeW, 6), eyePaint);
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
      ..quadraticBezierTo(x1 + o.width * 0.22, y1 + o.height * 0.35, midX, y1 + 2)
      ..quadraticBezierTo(x1 + o.width * 0.78, y1 + o.height * 0.35, x2, y2)
      ..close();

    canvas.drawPath(path, fill);
    canvas.drawPath(path, outline);

    // Tail hook
    final hook = Paint()
      ..color = Colors.black
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
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    canvas.drawLine(topAnchor, center, rope);

    // Mine body
    canvas.drawOval(Rect.fromLTRB(x1, y1, x2, y2), fill);
    canvas.drawOval(Rect.fromLTRB(x1, y1, x2, y2), outline);

    // Spikes
    final spikePaint = Paint()
      ..color = Colors.black
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

      canvas.drawLine(Offset(cx, cy - s * 0.15), Offset(cx + s * 0.18, cy + s * 0.2), bolt);
      canvas.drawLine(Offset(cx - s * 0.02, cy - s * 0.05), Offset(cx + s * 0.22, cy - s * 0.05), bolt);
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
    canvas.drawLine(Offset(cx, cy - half * 0.65), Offset(cx, cy + half * 0.65), bar);
    canvas.drawLine(Offset(cx - half * 0.35, cy), Offset(cx + half * 0.35, cy), bar);
  }

  void _drawHud(Canvas canvas, {required double groundY}) {
    final outline = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final badgeFill = Paint()
      ..color = Colors.white.withOpacity(0.18);

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
    final rrect = RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), const Radius.circular(12));
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
    valuePainter.paint(canvas, Offset(x + 12, valueCenterY - valuePainter.height / 2));
  }

  void _drawSmashShield(Canvas canvas, Stickman stickman) {
    final cx = stickman.x;
    final w = _stickmanWidthPx();
    final h = _stickmanHeightPx();
    final effectiveH = snapshot.crawlingActive ? h * 0.58 : h;
    final bottomY = stickman.y;

    // Shield center: in front of the stickman's torso (right side).
    final shieldCx = cx + w * 0.52;
    final shieldCy = bottomY - effectiveH * 0.52;
    final r = w * 0.46;

    // Metallic shield fill (blue/red/silver rings).
    final ring1 = Paint()..color = const Color.fromARGB(170, 60, 120, 255);
    final ring2 = Paint()..color = const Color.fromARGB(170, 220, 60, 60);
    final ring3 = Paint()..color = const Color.fromARGB(170, 200, 200, 210);
    final outline = Paint()
      ..color = Colors.black.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw 3 concentric rings.
    canvas.drawCircle(Offset(shieldCx, shieldCy), r, ring1);
    canvas.drawCircle(Offset(shieldCx, shieldCy), r, outline);
    canvas.drawCircle(Offset(shieldCx, shieldCy), r * 0.72, ring2);
    canvas.drawCircle(Offset(shieldCx, shieldCy), r * 0.72, outline);
    canvas.drawCircle(Offset(shieldCx, shieldCy), r * 0.42, ring3);
    canvas.drawCircle(Offset(shieldCx, shieldCy), r * 0.42, outline);

    // Center star (small).
    final starPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(shieldCx, shieldCy), r * 0.18, starPaint);

    // Swoosh lines extending outward to give a “thrown shield” effect.
    final swooshPaint = Paint()
      ..color = Colors.white.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final t = snapshot.timeSec * 24.0; // rapid animation phase
    final arcR = r * 1.35;

    // 3 swoosh arcs at different angles.
    for (int i = 0; i < 3; i++) {
      final baseAngle = -0.5 + i * 0.35 + sin(t + i * 2.1) * 0.2;
      final aStart = baseAngle;
      final aEnd = baseAngle + 0.5 + sin(t * 0.7 + i * 1.3) * 0.15;

      canvas.drawArc(
        Rect.fromCircle(center: Offset(shieldCx, shieldCy), radius: arcR + i * 12),
        aStart,
        aEnd,
        false,
        swooshPaint..color = Colors.white.withOpacity(0.35 + 0.15 * (1 - i * 0.3)),
      );
    }

    // Quick outward “thrust” lines.
    final thrustPaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final thrustPhase = sin(t * 1.5);
    for (int i = 0; i < 3; i++) {
      final angle = -0.4 + i * 0.35 + thrustPhase * 0.1;
      final len = 14 + i * 6;
      canvas.drawLine(
        Offset(
          shieldCx + (r + 4) * cos(angle),
          shieldCy + (r + 4) * sin(angle),
        ),
        Offset(
          shieldCx + (r + 4 + len) * cos(angle),
          shieldCy + (r + 4 + len) * sin(angle),
        ),
        thrustPaint,
      );
    }
  }

  double _stickmanWidthPx() => max(32.0, width * 0.12);
  double _stickmanHeightPx() => max(90.0, height * 0.22);

  Color _obstacleFill(ObstacleType type) {
    switch (type) {
      case ObstacleType.spike:
        return Colors.white70;
      case ObstacleType.cactus:
        return const Color.fromARGB(255, 18, 124, 32);
      case ObstacleType.stalagmite:
        return const Color.fromARGB(255, 64, 10, 96);
      case ObstacleType.rollingRock:
        return Colors.brown;
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
    }
  }

  Color _powerFill(PowerUpType type) {
    switch (type) {
      case PowerUpType.shield:
        return Colors.yellow;
      case PowerUpType.magnet:
        return Colors.cyanAccent;
    }
  }

  @override
  bool shouldRepaint(covariant StickmanRunPainter oldDelegate) {
    return oldDelegate.snapshot != snapshot || oldDelegate.level != level;
  }
}
