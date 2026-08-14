import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/game/engine/stickman_run_engine.dart';
import 'package:flutter_app/game/settings/legendary_defs.dart';
import 'package:flutter_app/game/settings/skill_controller.dart';

/// Verifies legendary skills are upgradable like standard skills: each tier
/// lengthens the effect window, shortens the cooldown, and raises damage for
/// offensive skills — and the run engine honors the upgraded stats.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('upgrade raises tier, shortens cooldown, scales duration and damage',
      () async {
    final sc = SkillController.instance;
    sc.debugResetForTests();
    await sc.awardCoins(100000);
    await sc.purchase(LegendarySkill.roadSweep);

    // Fresh purchase starts at tier 0 with the base 20s cooldown.
    expect(sc.legendaryTierOf(LegendarySkill.roadSweep), 0);
    expect(sc.legendaryCooldownSec(LegendarySkill.roadSweep), 20);

    final ok = await sc.upgradeLegendary(LegendarySkill.roadSweep);
    expect(ok, isTrue);
    expect(sc.legendaryTierOf(LegendarySkill.roadSweep), 1);
    // Cooldown: 20s base - 2s per tier.
    expect(sc.legendaryCooldownSec(LegendarySkill.roadSweep), 18);
    // Next upgrade is ladder step 2; road sweep (8000◆) is a premium skill.
    expect(sc.legendaryNextCost(LegendarySkill.roadSweep), 250);
    expect(sc.legendaryIsMaxed(LegendarySkill.roadSweep), isFalse);

    // Stat scaling at tier 1: 3s base + 0.5s duration, 1.2x damage.
    final def = LegendaryDef.forId(LegendarySkill.roadSweep);
    expect(def.durationSec(1), closeTo(3.5, 0.001));
    expect(def.damageMult(1), closeTo(1.2, 0.001));
    expect(def.cooldownSec(1), closeTo(18, 0.001));

    // Cost ladder: premium skills (>= 8000◆) climb 250/350/450/550 after the
    // first 100◆; cheaper skills stay at 100/200/300/400/500.
    expect(LegendaryDef.forId(LegendarySkill.roadSweep).costs,
        [100, 250, 350, 450, 550]);
    expect(LegendaryDef.forId(LegendarySkill.goldRush).costs,
        [100, 200, 300, 400, 500]);
  });

  test('engine uses tier-scaled legendary duration', () {
    final engine = StickmanRunEngine(
      legendaries: {LegendarySkill.roadSweep},
      legendaryTiers: {LegendarySkill.roadSweep: 3},
      seed: 42,
    );
    engine.resize(400, 700);
    engine.start(levelIndex: 1);
    engine.startRunning();
    expect(engine.triggerLegendary(LegendarySkill.roadSweep), isTrue);
    // 3s base + 3 tiers * 0.5s = 4.5s window.
    expect(engine.snapshot().roadSweepSec, closeTo(4.5, 0.001));
  });

  test('support skills gain tier-scaled damage from upgrades', () {
    // TEMPEST storm-zap and TIME REWIND paradox-burst damage scale with tier.
    final tempest = LegendaryDef.forId(LegendarySkill.tempest);
    expect(tempest.damagePerTier, greaterThan(0));
    expect(tempest.damageMult(5), closeTo(1 + tempest.damagePerTier * 5, 0.001));

    final rewind = LegendaryDef.forId(LegendarySkill.reverseRun);
    expect(rewind.damagePerTier, greaterThan(0));
    expect(rewind.damageMult(3), closeTo(1 + rewind.damagePerTier * 3, 0.001));
  });

  test('engine uses base duration when legendary has no upgrade tiers', () {
    final engine = StickmanRunEngine(
      legendaries: {LegendarySkill.goldRush},
      seed: 7,
    );
    engine.resize(400, 700);
    engine.start(levelIndex: 1);
    engine.startRunning();
    expect(engine.triggerLegendary(LegendarySkill.goldRush), isTrue);
    // 5s base, tier 0.
    expect(engine.snapshot().goldRushSec, closeTo(5.0, 0.001));
  });
}
