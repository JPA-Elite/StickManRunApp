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
/// price, and the input combo that triggers it.
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

  const LegendaryDef({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    required this.cost,
    required this.comboLabel,
    this.combo = const [],
  });

  static const List<LegendaryDef> all = [
    LegendaryDef(
      id: LegendarySkill.autoStrike,
      name: 'AUTO-STRIKE',
      icon: '★',
      description:
          'Jump, jump, attack: the stickman auto-smashes oncoming obstacles for 5 seconds.',
      cost: 9000,
      comboLabel: 'jump · jump · attack',
      combo: [ComboAction.jump, ComboAction.jump, ComboAction.smash],
    ),
    LegendaryDef(
      id: LegendarySkill.reverseRun,
      name: 'TIME REWIND',
      icon: '⟲',
      description:
          'Hold steady on the screen to rewind the world for 3 seconds — obstacles scroll back away while you regain distance and stay safe.',
      cost: 9000,
      comboLabel: 'hold ⟲ to rewind',
    ),
    LegendaryDef(
      id: LegendarySkill.roadSweep,
      name: 'ROAD SWEEP',
      icon: '☄',
      description:
          'Attack, jump, jump: for 3 seconds fireballs rain from the sky, '
          'wiping every obstacle off the road.',
      cost: 8000,
      comboLabel: 'attack · jump · jump',
      combo: [ComboAction.smash, ComboAction.jump, ComboAction.jump],
    ),
    LegendaryDef(
      id: LegendarySkill.tempest,
      name: 'TEMPEST',
      icon: '⚡',
      description:
          'Jump, attack, jump: become invincible and slow the world to a crawl for 4 seconds.',
      cost: 7000,
      comboLabel: 'jump · attack · jump',
      combo: [ComboAction.jump, ComboAction.smash, ComboAction.jump],
    ),
    LegendaryDef(
      id: LegendarySkill.goldRush,
      name: 'GOLD RUSH',
      icon: '◈',
      description:
          'Attack, attack, jump: for 5 seconds every on-screen obstacle '
          'is converted into a burst of coins.',
      cost: 6000,
      comboLabel: 'attack · attack · jump',
      combo: [ComboAction.smash, ComboAction.smash, ComboAction.jump],
    ),
  ];

  static LegendaryDef forId(LegendarySkill id) =>
      all.firstWhere((s) => s.id == id);
}