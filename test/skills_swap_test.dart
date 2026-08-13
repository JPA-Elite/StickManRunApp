import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/game/settings/legendary_defs.dart';
import 'package:flutter_app/game/settings/skill_controller.dart';
import 'package:flutter_app/game/ui/skills_screen.dart';
import 'package:flutter_app/game/ui/stickman_avatar.dart';

/// Resets the singleton [SkillController] to a clean wallet + empty collection,
/// then awards enough coins and auto-purchases the first two legendaries
/// (AUTO-STRIKE + TEMPEST) so both equip slots are filled.
Future<void> seedTwoActive() async {
  final sc = SkillController.instance;
  sc.debugResetForTests();
  await sc.awardCoins(100000);
  await sc.purchase(LegendarySkill.autoStrike); // 9000, auto-equipped (slot 1)
  await sc.purchase(LegendarySkill.tempest); // 7000, auto-equipped (slot 2)
}

/// Pumps [SkillsScreen] at phone size and switches to the LEGENDARY tab.
Future<void> openLegendaryTab(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const MaterialApp(home: SkillsScreen()));
  await tester.pumpAndSettle();
  await tester.tap(find.text('★ LEGENDARY'));
  await tester.pumpAndSettle();
}

void main() {
  // shared_preferences hangs when called against the real plugin channel in
  // `flutter test`; seed it with the in-memory mock so reads/writes are instant.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('loadout shows avatar and two equipped slots', (tester) async {
    await seedTwoActive();
    await openLegendaryTab(tester);

    // Stickman avatar on the left of the active loadout...
    expect(find.byType(StickmanAvatar), findsOneWidget);
    // ...and both equipped slots render their info affordance.
    expect(find.text('TAP FOR INFO'), findsNWidgets(2));
  });

  testWidgets('slot tap shows info dialog and DONE closes it', (tester) async {
    await seedTwoActive();
    await openLegendaryTab(tester);

    await tester.tap(find.text('TAP FOR INFO').first);
    await tester.pumpAndSettle();

    // The read-only detail dialog shows the equipped skill's purchase cost line.
    expect(find.textContaining('to buy · equipped & ready'), findsOneWidget);
    await tester.tap(find.text('DONE'));
    await tester.pumpAndSettle();
    expect(find.textContaining('to buy · equipped & ready'), findsNothing);
  });

  testWidgets('buying a third legendary works at full slots', (tester) async {
    await seedTwoActive();
    await openLegendaryTab(tester);
    final sc = SkillController.instance;
    await sc.purchase(LegendarySkill.roadSweep); // 8000, owns it but slots full
    await tester.pumpAndSettle();

    // The third purchase joins the collection even with both slots busy.
    expect(sc.hasLegendary(LegendarySkill.roadSweep), isTrue);
    expect(
      sc.isActive(LegendarySkill.roadSweep),
      isFalse,
      reason: 'Slots are full, so it joins the collection unequipped',
    );
    // Its card now offers EQUIP (already owned) rather than BUY.
    expect(find.text('EQUIP'), findsWidgets);
  });

  testWidgets('upgrading a standard skill shows a success modal', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final sc = SkillController.instance;
    await sc.awardCoins(100000);

    // The STANDARD tab is the default tab.
    await tester.pumpWidget(const MaterialApp(home: SkillsScreen()));
    await tester.pumpAndSettle();

    final upgrade = find.textContaining('UPGRADE').first;
    expect(upgrade, findsWidgets);
    await tester.ensureVisible(upgrade);
    await tester.tap(upgrade);
    // Spinner holds for ~1s before the success modal appears.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // The upgrade success modal appears and can be dismissed.
    expect(find.text('UPGRADED!'), findsOneWidget);
    await tester.tap(find.text('DONE'));
    await tester.pumpAndSettle();
    expect(find.text('UPGRADED!'), findsNothing);
  });

  testWidgets('equip from card replaces an active skill for free', (
    tester,
  ) async {
    await seedTwoActive();
    await openLegendaryTab(tester);
    final sc = SkillController.instance;
    await sc.purchase(LegendarySkill.roadSweep);

    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('ROAD SWEEP'));
    await tester.tap(find.text('EQUIP').first);
    await tester.pumpAndSettle();

    // Slots are full: equipping prompts which active skill to evict.
    expect(find.text('REPLACE ACTIVE SKILL'), findsOneWidget);
    final options = find.descendant(
      of: find.byType(Dialog),
      matching: find.text('ACTIVE'),
    );
    expect(options, findsNWidgets(2));
    await tester.tap(options.last); // evict TEMPEST
    await tester.pumpAndSettle();

    expect(sc.isActive(LegendarySkill.roadSweep), isTrue);
    expect(sc.isActive(LegendarySkill.tempest), isFalse);

    // Equipping now finishes with a modal (not a SnackBar).
    expect(find.text('EQUIPPED!'), findsOneWidget);
    expect(
      find.text('ROAD SWEEP equipped — free, ready for your next run.'),
      findsOneWidget,
    );
    await tester.tap(find.text('DONE'));
    await tester.pumpAndSettle();
    expect(find.text('EQUIPPED!'), findsNothing);
  });

  testWidgets('cancel from replace dialog aborts', (tester) async {
    await seedTwoActive();
    await openLegendaryTab(tester);
    final sc = SkillController.instance;
    await sc.purchase(LegendarySkill.roadSweep);

    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('ROAD SWEEP'));
    await tester.tap(find.text('EQUIP').first);
    await tester.pumpAndSettle();

    expect(find.text('REPLACE ACTIVE SKILL'), findsOneWidget);
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();

    // Equipping was aborted: nothing changed.
    expect(find.text('REPLACE ACTIVE SKILL'), findsNothing);
    expect(sc.isActive(LegendarySkill.roadSweep), isFalse);
    expect(sc.isActive(LegendarySkill.autoStrike), isTrue);
    expect(sc.isActive(LegendarySkill.tempest), isTrue);
  });

  testWidgets('empty slots render placeholders and tap flashes a shop card', (
    tester,
  ) async {
    final sc = SkillController.instance;
    sc.debugResetForTests();
    await openLegendaryTab(tester);

    // No legendaries owned: both slots render the EMPTY placeholder.
    expect(find.text('EMPTY'), findsNWidgets(2));

    // Tapping an empty slot flashes the first unowned shop card (AUTO-STRIKE).
    await tester.tap(find.text('EMPTY').first);
    await tester.pumpAndSettle();
    expect(find.text('AUTO-STRIKE'), findsWidgets);
  });

  testWidgets('empty slot is exactly as tall as the filled slot', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // One owned + auto-equipped legendary -> one filled slot, one empty slot.
    final sc = SkillController.instance;
    sc.debugResetForTests();
    await sc.awardCoins(100000);
    await sc.purchase(LegendarySkill.roadSweep);

    await tester.pumpWidget(const MaterialApp(home: SkillsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('★ LEGENDARY'));
    await tester.pumpAndSettle();

    final filledSlot = find
        .ancestor(
          of: find.text('TAP FOR INFO'),
          matching: find.byType(GestureDetector),
        )
        .first;
    final emptySlot = find
        .ancestor(
          of: find.text('EMPTY'),
          matching: find.byType(GestureDetector),
        )
        .first;

    final filledHeight = tester.getSize(filledSlot).height;
    final emptyHeight = tester.getSize(emptySlot).height;
    debugPrint(
      'REPRO: filled=${filledHeight.toStringAsFixed(1)}px '
      'empty=${emptyHeight.toStringAsFixed(1)}px',
    );
    expect(
      emptyHeight,
      moreOrLessEquals(filledHeight, epsilon: 0.1),
      reason: 'Empty placeholder must match the filled skill slot height',
    );
  });

  testWidgets('legendary buy shows a loading dialog for ~1s', (tester) async {
    final sc = SkillController.instance;
    sc.debugResetForTests();
    await sc.awardCoins(100000);
    await openLegendaryTab(tester);

    final buyButton = find.text('BUY 9000◆').first;
    await tester.ensureVisible(buyButton);
    await tester.tap(buyButton);

    // The loading dialog is shown right after the tap.
    await tester.pump();
    expect(find.text('PROCESSING…'), findsOneWidget);

    // Still visible before the 1s hold elapses.
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('PROCESSING…'), findsOneWidget);

    // After ~1s the loading closes and the success modal appears.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('PROCESSING…'), findsNothing);
    expect(find.text('OWNED!'), findsOneWidget);
  });
}
