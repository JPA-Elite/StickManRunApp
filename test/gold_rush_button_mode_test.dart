import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/game/settings/legendary_defs.dart';
import 'package:flutter_app/game/settings/skill_controller.dart';
import 'package:flutter_app/game/ui/stickman_run_screen.dart';

/// Verifies the GOLD RUSH legendary combo (attack · attack · jump) fires
/// from the buttons control scheme, where the player taps the on-screen
/// ATTACK and JUMP buttons instead of swiping.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('GOLD RUSH triggers in button mode via ATTACK,ATTACK,JUMP', (
    tester,
  ) async {
    final sc = SkillController.instance;
    sc.debugResetForTests();
    await sc.awardCoins(100000);
    // Purchase = auto-equips the only slot, so the run engine owns it.
    await sc.purchase(LegendarySkill.goldRush);
    expect(sc.isActive(LegendarySkill.goldRush), isTrue);
    expect(
      sc.legendaryCooldownRemainingSec(LegendarySkill.goldRush),
      0,
      reason: 'cooldown must start clear before the combo',
    );

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

    expect(find.byIcon(Icons.arrow_upward), findsOneWidget, reason: 'JUMP button');
    expect(find.byIcon(Icons.sports_mma), findsOneWidget, reason: 'ATTACK button');

    // Attack -> attack -> jump. The second attack lands while the smash is
    // still cooling down (<= 0.5s); its combo input must still register so
    // the pattern fires without waiting out the cooldown between presses.
    await tester.tap(find.byIcon(Icons.sports_mma));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byIcon(Icons.sports_mma));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump(const Duration(milliseconds: 100));

    // The legend fired: it entered the shared 20s cooldown...
    expect(
      sc.legendaryCooldownRemainingSec(LegendarySkill.goldRush),
      greaterThan(0),
    );
    // ...and the game HUD shows the GOLD RUSH countdown pill.
    expect(find.textContaining('GOLD RUSH'), findsWidgets);
  });
}