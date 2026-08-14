import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/game/settings/legendary_defs.dart';
import 'package:flutter_app/game/settings/skill_controller.dart';
import 'package:flutter_app/game/ui/stickman_run_screen.dart';

/// Verifies the ROAD SWEEP legendary combo (attack · jump · jump) fires
/// from the buttons control scheme and that the fire-rain cinematic (falling
/// fireballs + impact explosions) renders without crashing.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('ROAD SWEEP triggers in button mode via ATTACK,JUMP,JUMP', (
    tester,
  ) async {
    final sc = SkillController.instance;
    sc.debugResetForTests();
    await sc.awardCoins(100000);
    // Purchase = auto-equips the only slot, so the run engine owns it.
    await sc.purchase(LegendarySkill.roadSweep);
    expect(sc.isActive(LegendarySkill.roadSweep), isTrue);

    // Let real async (sprite decoding) settle before pumping the screen.
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));

    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: StickmanRunScreen(initialLevel: 1)),
    );
    await tester.pump();

    // Start the run (default control scheme is BUTTONS).
    await tester.tap(find.text('START RUN'));
    await tester.pump();
    // Let the entrance cinematic finish so the buttons become visible.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2));

    expect(
      find.byIcon(Icons.arrow_upward),
      findsOneWidget,
      reason: 'JUMP button',
    );
    expect(
      find.byIcon(Icons.sports_mma),
      findsOneWidget,
      reason: 'ATTACK button',
    );

    // Attack -> jump -> jump. The jump input has a ~180ms REAL-time micro
    // cooldown, so wait it out for real between the two jumps (pump() only
    // advances the fake clock). No need to wait out the smash cooldown.
    await tester.tap(find.byIcon(Icons.sports_mma));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump(const Duration(milliseconds: 100));

    // The legend fired: it entered the shared 20s cooldown...
    expect(
      sc.legendaryCooldownRemainingSec(LegendarySkill.roadSweep),
      greaterThan(0),
    );
    // ...and the game HUD shows the ROAD SWEEP countdown pill.
    expect(find.textContaining('ROAD SWEEP'), findsWidgets);

    // Pump through the 3s sweep window so the fireballs rain, explode and
    // wipe out obstacles — exercises the new engine + painter paths.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
  });
}
