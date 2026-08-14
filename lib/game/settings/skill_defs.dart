import 'dart:math';

import 'package:flutter/foundation.dart';

/// Identifiers for every purchasable skill. All owned skills are always active;
/// there is no loadout/equip step.
enum SkillId {
  coinMagnet,
  healEfficiency,
  smashMastery,
  fortitude,
  coinBaron,
  endlessStamina,
  comboRamp,
  perfectLanding,
  rebound,
  shieldCharge,
  overdrive,
  coinStreak,
}

/// Describes one skill: its identity, display info, and tier cost ladder.
@immutable
class SkillDef {
  final SkillId id;
  final String name;
  final String description;
  final String icon;

  /// 5 upgrade tiers: cost to reach tier 1..5 from tier 0.
  final List<int> costs;

  const SkillDef({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.costs,
  });

  int get maxTier => costs.length;

  bool get isCombo =>
      id == SkillId.comboRamp ||
      id == SkillId.perfectLanding ||
      id == SkillId.rebound ||
      id == SkillId.shieldCharge ||
      id == SkillId.overdrive ||
      id == SkillId.coinStreak;

  static const List<SkillDef> all = [
    SkillDef(
      id: SkillId.coinMagnet,
      name: 'COIN MAGNET',
      icon: '◆',
      description: 'Raises the magnet power-up pull range and duration.',
      costs: [50, 150, 350, 700, 1200],
    ),
    SkillDef(
      id: SkillId.healEfficiency,
      name: 'HEAL EFFICIENCY',
      icon: '✚',
      description: 'Small heals restore more life and you start with extra HP.',
      costs: [50, 150, 350, 700, 1200],
    ),
    SkillDef(
      id: SkillId.smashMastery,
      name: 'SMASH MASTERY',
      icon: '☊',
      description: 'Shortens the smash cooldown so you can strike more often.',
      costs: [50, 150, 350, 700, 1200],
    ),
    SkillDef(
      id: SkillId.coinBaron,
      name: 'COIN BARON',
      icon: '◈',
      description: 'Raises the value of every coin and score gained.',
      costs: [50, 150, 350, 700, 1200],
    ),
    SkillDef(
      id: SkillId.endlessStamina,
      name: 'ENDLESS STAMINA',
      icon: '∞',
      description: 'Slower speed ramp and a longer safety window in endless mode.',
      costs: [50, 150, 350, 700, 1200],
    ),
    SkillDef(
      id: SkillId.comboRamp,
      name: 'COMBO RAMP',
      icon: '✖',
      description: 'Builds a score multiplier by smashing without taking a hit.',
      costs: [50, 150, 350, 700, 1200],
    ),
    SkillDef(
      id: SkillId.perfectLanding,
      name: 'PERFECT LANDING',
      icon: '⇓',
      description: 'Landing after a clean jump grants a short burst of speed.',
      costs: [50, 150, 350, 700, 1200],
    ),
    SkillDef(
      id: SkillId.rebound,
      name: 'REBOUND',
      icon: '↻',
      description: 'Extends the post-hit grace window before the next hit counts.',
      costs: [50, 150, 350, 700, 1200],
    ),
    SkillDef(
      id: SkillId.shieldCharge,
      name: 'SHIELD CHARGE',
      icon: '◉',
      description: 'Regenerates a partial shield charge as you cover distance.',
      costs: [50, 150, 350, 700, 1200],
    ),
    SkillDef(
      id: SkillId.overdrive,
      name: 'OVERDRIVE',
      icon: '⚡',
      description: 'After a smash you are briefly invulnerable to the next hit.',
      costs: [50, 150, 350, 700, 1200],
    ),
    SkillDef(
      id: SkillId.coinStreak,
      name: 'COIN STREAK',
      icon: '♢',
      description: 'Every coin streak triggers a short magnet burst.',
      costs: [50, 150, 350, 700, 1200],
    ),
  ];

  static SkillDef forId(SkillId id) => all.firstWhere((s) => s.id == id);
}

/// The concrete numeric effects derived from the player's owned skill tiers.
/// Always active once owned.
@immutable
class SkillConfig {
  static const int _maxTiers = 5;

  final int coinMagnet;
  final int healEfficiency;
  final int smashMastery;
  final int coinBaron;
  final int endlessStamina;
  final int comboRamp;
  final int perfectLanding;
  final int rebound;
  final int shieldCharge;
  final int overdrive;
  final int coinStreak;

  const SkillConfig({
    this.coinMagnet = 0,
    this.healEfficiency = 0,
    this.smashMastery = 0,
    this.coinBaron = 0,
    this.endlessStamina = 0,
    this.comboRamp = 0,
    this.perfectLanding = 0,
    this.rebound = 0,
    this.shieldCharge = 0,
    this.overdrive = 0,
    this.coinStreak = 0,
  });

  /// Builds a fully-typed config from a map of owned tiers.
  factory SkillConfig.fromTiers(Map<SkillId, int> tiers) {
    int t(SkillId id) => tiers[id]?.clamp(0, _maxTiers) ?? 0;
    return SkillConfig(
      coinMagnet: t(SkillId.coinMagnet),
      healEfficiency: t(SkillId.healEfficiency),
      smashMastery: t(SkillId.smashMastery),
      coinBaron: t(SkillId.coinBaron),
      endlessStamina: t(SkillId.endlessStamina),
      comboRamp: t(SkillId.comboRamp),
      perfectLanding: t(SkillId.perfectLanding),
      rebound: t(SkillId.rebound),
      shieldCharge: t(SkillId.shieldCharge),
      overdrive: t(SkillId.overdrive),
      coinStreak: t(SkillId.coinStreak),
    );
  }

  bool get anyOwned =>
      coinMagnet > 0 ||
      healEfficiency > 0 ||
      smashMastery > 0 ||
      coinBaron > 0 ||
      endlessStamina > 0 ||
      comboRamp > 0 ||
      perfectLanding > 0 ||
      rebound > 0 ||
      shieldCharge > 0 ||
      overdrive > 0 ||
      coinStreak > 0;

  // ---- Derived numeric effects ----

  /// Magnet pull radius multiplier (base is ~50% of screen).
  double get magnetRangeMult => 1 + 0.15 * coinMagnet;

  /// Magnet active duration multiplier (base 6.0s).
  double get magnetDurationMult => 1 + 0.2 * coinMagnet;

  /// Bonus HP added to the start-of-run life and to each heal pickup.
  double get healBonus => 5.0 * healEfficiency;
  double get startLife => (90 + 10.0 * healEfficiency).clamp(0, 100);

  /// Smash cooldown seconds (base 0.5 → down to ~0.3 at max).
  double get smashCooldownSec => (0.5 - 0.04 * smashMastery).clamp(0.25, 0.5);

  /// Coin value score multiplier (base coin = 10 → up to +50%).
  double get coinValueMult => 1 + 0.10 * coinBaron;

  /// Score gained is multiplied by this (coin + power-up score).
  double get scoreMult => 1 + 0.06 * coinBaron;

  /// Endless speed-ramp reduction and start grace (seconds).
  double get speedRampMult => 1 - 0.1 * endlessStamina;
  double get endlessStartGraceSec => 1.0 * endlessStamina;

  /// Combo multiplier support: window and cap.
  int get comboCap => 2 + comboRamp; // 2,3,4,5,6,7
  double get comboWindowSec => 2.0 + 0.6 * comboRamp;

  /// Score multiplier at max combo (base 2x, grows with tiers).
  double get comboMaxScoreMult => 1 + 0.5 * (comboRamp + 1);

  /// Perfect landing speed burst (px/s added) + window ticks.
  double get perfectLandingBoostPx => 70.0 * perfectLanding;
  double get perfectLandingDurationSec => 0.8 + 0.1 * perfectLanding;

  /// Extra post-hit grace (base 0.5s).
  double get damageGraceBonus => 0.2 * rebound;

  /// Shield that regenerates every N meters (~300m base, shrinks with tiers).
  double get shieldChargeEveryMeters {
    final m = (300 - 40 * shieldCharge).clamp(100, 300);
    return m.toDouble();
  }
  double get shieldChargeAmount => 3.0 * shieldCharge;

  /// Invulnerability windows after smash (seconds).
  double get overdriveWindowSec => 0.5 + 0.3 * overdrive;

  /// Coins needed per streak to trigger a burst. Starts at 100 coins at
  /// level 1 and drops by 15 per tier down to 25 at max.
  int get coinStreakEvery => max(10, 100 - 15 * coinStreak);
  double get coinStreakBurstSec => 2.0 + 0.4 * coinStreak;
}