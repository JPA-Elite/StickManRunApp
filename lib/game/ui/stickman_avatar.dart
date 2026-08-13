import 'dart:math';

import 'package:flutter/material.dart';

import '../settings/settings_controller.dart';

/// Circular avatar that redraws the in-game boxing-guard stickman pose using
/// the user's chosen stickman color, framed by a neon cyan ring.
class StickmanAvatar extends StatelessWidget {
  final double size;

  /// Optional override for the stickman stroke color. Defaults to the player's
  /// customized stickman color from [SettingsController].
  final Color? color;

  const StickmanAvatar({super.key, required this.size, this.color});

  @override
  Widget build(BuildContext context) {
    final Color strokeColor =
        color ?? Color(SettingsController.instance.settings.stickmanColor);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xAA000000),
        border: Border.all(
          color: const Color(0xFF4DD8FF),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4DD8FF).withValues(alpha: 0.45),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipOval(
        child: CustomPaint(
          size: Size.square(size),
          painter: _StickmanAvatarPainter(color: strokeColor),
        ),
      ),
    );
  }
}

class _StickmanAvatarPainter extends CustomPainter {
  final Color color;

  _StickmanAvatarPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.075
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final ground = size.height * 0.86;
    final h = size.height * 0.62;
    final bob = size.height * 0.02;

    // Head circle (matches game proportion: radius ≈ h * 0.09 → scaled).
    final headR = h * 0.13;
    final headCy = ground - h * 0.78 + bob;
    canvas.drawCircle(Offset(cx, headCy), headR, stroke);

    // Torso tilted forward.
    final shoulderX = cx + size.width * 0.03;
    final hipX = cx - size.width * 0.03;
    final torsoTop = headCy + headR * 0.9;
    final hipY = ground - h * 0.38 + bob;
    canvas.drawLine(
      Offset(shoulderX, torsoTop),
      Offset(hipX, hipY),
      stroke,
    );

    // Boxing guard: both fists up & forward (two segments per arm).
    final s = min(size.width, size.height) * 0.28;
    final leadElbow = Offset(cx + size.width * 0.10, torsoTop + s * 0.30);
    final leadFist = Offset(cx + size.width * 0.20, torsoTop + s * 0.06);
    final rearElbow = Offset(cx - size.width * 0.05, torsoTop + s * 0.34);
    final rearFist = Offset(cx + size.width * 0.04, torsoTop + s * 0.12);
    canvas.drawLine(Offset(shoulderX, torsoTop), leadElbow, stroke);
    canvas.drawLine(leadElbow, leadFist, stroke);
    canvas.drawLine(Offset(shoulderX, torsoTop), rearElbow, stroke);
    canvas.drawLine(rearElbow, rearFist, stroke);

    // Legs.
    final kneeY = ground - h * 0.18 + bob;
    canvas.drawLine(Offset(hipX, hipY), Offset(hipX - size.width * 0.06, kneeY), stroke);
    canvas.drawLine(
      Offset(hipX - size.width * 0.06, kneeY),
      Offset(hipX - size.width * 0.02, ground),
      stroke,
    );
    canvas.drawLine(
      Offset(hipX, hipY),
      Offset(hipX + size.width * 0.05, kneeY),
      stroke,
    );
    canvas.drawLine(
      Offset(hipX + size.width * 0.05, kneeY),
      Offset(hipX + size.width * 0.09, ground),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _StickmanAvatarPainter oldDelegate) =>
      oldDelegate.color != color;
}
