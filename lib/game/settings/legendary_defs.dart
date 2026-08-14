import 'package:flutter/foundation.dart';

/// Identifiers for every purchasable legendary skill. Legendaries are one-time
/// purchases (no tier upgrades) that are far more expensive than normal
/// skills, and each is triggered in-game by a specific input combo or hold
/// gesture rather than being continuously active.
enum LegendarySkill {
  autoStrike,
  reverseRun,
  roadSweep,
  tempest,
  goldRush,
}

/// The set of distinct input actions a combo can be built from.
enum ComboAction { jump, smash, crawl }

/// Describes one legendary skill: identity, display info, single purchase
/// price, the input combo that triggers it, and its upgrade tier ladder.
/// Legendaries upgrade like standard skills: each tier lengthens the effect
/// window, shortens the cooldown, and (for offensive skills) raises damage.
@immutable
class LegendaryDef {
  final LegendarySkill id;
  final String name;
  final String icon;
  final String description;
  final int cost;

  /// The trigger as a labelled human string, e.g. "jump · jump · attack".
  final String comboLabel;

  /// The ordered list of actions that trigger this legendary. Every
  /// legendary is triggered by a combo; the field is always non-empty.
  final List<ComboAction> combo;


  /// Effect window seconds at tier 0.
  final double baseDurationSec;

  /// Extra effect-window seconds gained per upgrade tier.
  final double durationPerTier;

  /// Cooldown seconds between uses at tier 0.
  final double baseCooldownSec;

  /// Cooldown seconds shaved off per upgrade tier.
  final double cooldownReductionPerTier;

  /// Bonus damage/coin multiplier added per upgrade tier (1.0 at tier 0).
  /// Offensive skills (auto-strike, road sweep, gold rush) use it; support
  /// skills (tempest, time rewind) leave it at 0.
  final double damagePerTier;

  const LegendaryDef({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    required this.cost,
    required this.comboLabel,
    required this.baseDurationSec,
    required this.durationPerTier,
    required this.baseCooldownSec,
    required this.cooldownReductionPerTier,
    this.damagePerTier = 0,
    this.combo = const [],
  });

  /// 5 upgrade tiers: cost to reach tier 1..5 from tier 0. The first upgrade
  /// always costs 100◆ and each next one adds 100◆; pricier skills (purchase
  /// >= 8000◆) climb an extra 50◆ per step after the first — expensive ones
  /// run 100/250/350/450/550, cheaper ones 100/200/300/400/500.
  List<int> get costs => [
        for (var i = 0; i < 5; i++)
          100 + 100 * i + (i > 0 && cost >= 8000 ? 50 : 0),
      ];

  int get maxTier => costs.length;

  /// Effect window seconds at the given tier.
  double durationSec(int tier) => baseDurationSec + durationPerTier * tier;

  /// Cooldown seconds between uses at the given tier (never below 8s).
  double cooldownSec(int tier) =>
      (baseCooldownSec - cooldownReductionPerTier * tier).clamp(8.0, baseCooldownSec);

  /// Damage/coin multiplier at the given tier (1.0 = base).
  double damageMult(int tier) => 1.0 + damagePerTier * tier;

  static const List<LegendaryDef> all = [
    LegendaryDef(
      id: LegendarySkill.autoStrike,
      name: 'AUTO-STRIKE',
      icon: '★',
      description:
          'Jump, jump, attack: the stickman auto-smashes oncoming obstacles.',
      cost: 9000,
      comboLabel: 'jump · jump · attack',
      combo: [ComboAction.jump, ComboAction.jump, ComboAction.smash],
      baseDurationSec: 5,
      durationPerTier: 1.0,
      baseCooldownSec: 20,
      cooldownReductionPerTier: 2,
      damagePerTier: 0.15,
    ),
    LegendaryDef(
      id: LegendarySkill.reverseRun,
      name: 'TIME REWIND',
      icon: '⟲',
      description:
          'Hold steady on the screen to rewind the world — obstacles scroll '
          'back away; when the window ends a temporal shockwave blasts '
          'nearby obstacles.',
      cost: 9000,
      comboLabel: 'hold ⟲ to rewind',
      baseDurationSec: 3,
      durationPerTier: 0.5,
      baseCooldownSec: 20,
      cooldownReductionPerTier: 2,
      damagePerTier: 0.2,
    ),
    LegendaryDef(
      id: LegendarySkill.roadSweep,
      name: 'ROAD SWEEP',
      icon: '☄',
      description:
          'Attack, jump, jump: fireballs rain from the sky, wiping every '
          'obstacle off the road.',
      cost: 8000,
      comboLabel: 'attack · jump · jump',
      combo: [ComboAction.smash, ComboAction.jump, ComboAction.jump],
      baseDurationSec: 3,
      durationPerTier: 0.5,
      baseCooldownSec: 20,
      cooldownReductionPerTier: 2,
      damagePerTier: 0.2,
    ),
    LegendaryDef(
      id: LegendarySkill.tempest,
      name: 'TEMPEST',
      icon: '⚡',
      description:
          'Jump, attack, jump: become invincible and slow the world — '
          'lightning strikes nearby obstacles.',
      cost: 7000,
      comboLabel: 'jump · attack · jump',
      combo: [ComboAction.jump, ComboAction.smash, ComboAction.jump],
      baseDurationSec: 4,
      durationPerTier: 0.5,
      baseCooldownSec: 20,
      cooldownReductionPerTier: 2,
      damagePerTier: 0.15,
    ),
    LegendaryDef(
      id: LegendarySkill.goldRush,
      name: 'GOLD RUSH',
      icon: '◈',
      description:
          'Attack, attack, jump: every on-screen obstacle is converted into '
          'a burst of coins.',
      cost: 6000,
      comboLabel: 'attack · attack · jump',
      combo: [ComboAction.smash, ComboAction.smash, ComboAction.jump],
      baseDurationSec: 5,
      durationPerTier: 0.5,
      baseCooldownSec: 20,
      cooldownReductionPerTier: 2,
      damagePerTier: 0.25,
    ),
  ];

  static LegendaryDef forId(LegendarySkill id) =>
      all.firstWhere((s) => s.id == id);
}