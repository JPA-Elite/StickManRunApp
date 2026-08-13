import 'package:flutter/foundation.dart';

enum ObstacleType {
  spike,
  cactus,
  rollingRock,
  drone,
  laser,
  bat,
  stalagmite,
  fireJet,
  fireball,
  pendulumMine,
}

enum PowerUpType {
  shield,
  magnet,
  heal25,
  heal50,
}

@immutable
class RectF {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const RectF({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  bool intersects(RectF other) {
    return !(other.left > right || other.right < left || other.top > bottom || other.bottom < top);
  }
}

@immutable
class Obstacle {
  final ObstacleType type;

  /// World-space x coordinate (left edge).
  final double x;

  /// World-space y coordinate (top edge).
  final double y;

  final double width;
  final double height;

  /// When true, obstacle is visually “in front” (purely for painter ordering).
  final bool foreground;

  /// Optional rotation angle (for pendulums).
  final double rotation;

  /// Optional animation phase (fireball bobbing, drones, etc).
  final double phase;

  const Obstacle({
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.foreground = false,
    this.rotation = 0,
    this.phase = 0,
  });

  RectF collisionRect() {
    // Slight shrink to feel better for stickman collisions.
    final inset = width * 0.08;
    return RectF(
      left: x + inset,
      right: x + width - inset,
      top: y + height * 0.05,
      bottom: y + height * 0.95,
    );
  }

  Obstacle copyWith({
    double? x,
    double? y,
    double? rotation,
    double? phase,
  }) {
    return Obstacle(
      type: type,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width,
      height: height,
      foreground: foreground,
      rotation: rotation ?? this.rotation,
      phase: phase ?? this.phase,
    );
  }
}

@immutable
class Coin {
  final double x;
  final double y;
  final double radius;
  final double phase;

  const Coin({
    required this.x,
    required this.y,
    required this.radius,
    required this.phase,
  });

  RectF collisionRect() {
    final r = radius;
    return RectF(
      left: x - r,
      right: x + r,
      top: y - r,
      bottom: y + r,
    );
  }

  Coin copyWith({double? x, double? y, double? phase}) {
    return Coin(
      x: x ?? this.x,
      y: y ?? this.y,
      radius: radius,
      phase: phase ?? this.phase,
    );
  }
}

@immutable
class PowerUp {
  final PowerUpType type;
  final double x;
  final double y;
  final double size;
  final double phase;

  const PowerUp({
    required this.type,
    required this.x,
    required this.y,
    required this.size,
    required this.phase,
  });

  RectF collisionRect() {
    final s = size;
    return RectF(
      left: x - s * 0.5,
      right: x + s * 0.5,
      top: y - s * 0.5,
      bottom: y + s * 0.5,
    );
  }

  PowerUp copyWith({double? x, double? y, double? phase}) {
    return PowerUp(
      type: type,
      x: x ?? this.x,
      y: y ?? this.y,
      size: size,
      phase: phase ?? this.phase,
    );
  }
}

@immutable
class SmashDebris {
  final double x;
  final double y;
  final double vx;
  final double vy;
  final double remainingSec;
  final double size;
  final ObstacleType obstacleType;

  const SmashDebris({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.remainingSec,
    required this.size,
    required this.obstacleType,
  });

  SmashDebris copyWith({
    double? x,
    double? y,
    double? vy,
    double? remainingSec,
  }) {
    return SmashDebris(
      x: x ?? this.x,
      y: y ?? this.y,
      vx: vx,
      vy: vy ?? this.vy,
      remainingSec: remainingSec ?? this.remainingSec,
      size: size,
      obstacleType: obstacleType,
    );
  }
}

@immutable
class SmashScorePopup {
  final double x;
  final double y;
  final double remainingSec;
  final int score;

  const SmashScorePopup({
    required this.x,
    required this.y,
    required this.remainingSec,
    required this.score,
  });

  SmashScorePopup copyWith({
    double? y,
    double? remainingSec,
  }) {
    return SmashScorePopup(
      x: x,
      y: y ?? this.y,
      remainingSec: remainingSec ?? this.remainingSec,
      score: score,
    );
  }
}

@immutable
class Stickman {
  final double x; // fixed horizontal position (center)
  final double y; // world-space y coordinate of stickman's bottom
  final double vy;

  const Stickman({
    required this.x,
    required this.y,
    required this.vy,
  });

  RectF collisionRect({
    required double width,
    required double height,
  }) {
    return RectF(
      left: x - width * 0.5,
      right: x + width * 0.5,
      top: y - height,
      bottom: y,
    );
  }

  Stickman copyWith({double? x, double? y, double? vy}) {
    return Stickman(
      x: x ?? this.x,
      y: y ?? this.y,
      vy: vy ?? this.vy,
    );
  }
}
