import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app/game/audio/audio_controller.dart';
import 'package:flutter_app/game/audio/background_music.dart';
import 'package:flutter_app/game/audio/sound_effects.dart';
import 'package:flutter_app/game/settings/settings_controller.dart';
import 'package:flutter_app/game/settings/skill_controller.dart';
import 'package:flutter_app/game/ui/stickman_run_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_audio_players.dart';

/// Fully functional audio tests: they pump the REAL game screen, simulate
/// real taps (start run, pause modal, restart, exit) and assert exactly how
/// background music and sound effects behave end-to-end.

void main() {
  late List<FakeAudioPlayer> all;
  late FakeAudioPlayer music;
  late AudioController controller;
  late FakeSfxEngine sfx;

  bool jumpPlayed() => sfx.playCount(SoundEffect.jump) >= 1;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  Future<void> pumpGameScreen(WidgetTester tester) async {
    // Fresh fakes per test; swap the singleton BEFORE any settings
    // load so applySettings lands on the fake-backed controller.
    all = <FakeAudioPlayer>[];
    sfx = FakeSfxEngine();
    controller = AudioController(
      playerFactory: () {
        final fake = FakeAudioPlayer();
        all.add(fake);
        return fake;
      },
      sfxEngine: sfx,
    );
    AudioController.testInstance = controller;
    music = all.first;

    SharedPreferences.setMockInitialValues({});
    await SettingsController.instance.load();
    await SkillController.instance.load();
    // Production initializes via StickmanRunApp's post-frame callback; these
    // tests mount the game screen directly, so initialize explicitly.
    await controller.initialize();

    // Host the game screen on top of a home page so popping it back is a
    // clean, production-like navigation that really disposes the screen.
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Center(child: Text('MENU-HOME')))),
    );
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    // NOTE: never await push() — its future completes only when the route
    // is popped.
    unawaited(
      navigator.push(
        MaterialPageRoute(builder: (_) => StickmanRunScreen(initialLevel: 1)),
      ),
    );
    await tester.pump(); // post-frame callbacks (music request)
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Taps START RUN then pumps past the engine's 1.4s entrance cinematic so
  /// the HUD (pause button etc.) becomes visible.
  ///
  /// Why a loop instead of a single long pump: the game screen's ticker runs
  /// an `AnimationController.repeat()` with a 1s duration, and
  /// `lastElapsedDuration` wraps at every whole second. A single big pump
  /// (e.g. 1500ms + 800ms) therefore produces invalid, often-negative deltas
  /// in `_tick`, so the cinematic's countdown effectively never decrements and
  /// the pause button never shows. Pumping in small 50ms steps keeps the
  /// wrap-around glitch to one wasted frame per second and lets the cinematic
  /// finish normally.
  Future<void> startRun(WidgetTester tester) async {
    await tester.tap(find.text('START RUN'));
    await tester.pump();

    final pauseBtn = find.byTooltip('Pause');
    for (var i = 0; i < 60 && pauseBtn.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(pauseBtn, findsOneWidget,
        reason: 'pause button must appear after START RUN + cinematic');
  }

  tearDown(() {
    AudioController.testInstance = null;
  });

  group('functional: gameplay music lifecycle', () {
    testWidgets('mounting the game screen starts the level biome track',
        (tester) async {
      await pumpGameScreen(tester);

      expect(music.loads, contains(BackgroundMusic.gameplayForest.assetPath),
          reason: 'level 1 = forest biome track must be playing');
      expect(music.playing, isTrue);
      expect(controller.isGameplayActive, isTrue);

      // The menu theme must NOT be playing underneath or instead.
      expect(music.loads, isNot(contains(BackgroundMusic.menuTheme.assetPath)),
          reason: 'menu theme can never override gameplay music');
    });

    testWidgets('START RUN fires the jump SFX and the run keeps its track',
        (tester) async {
      await pumpGameScreen(tester);

      await startRun(tester);

      expect(jumpPlayed(), isTrue,
          reason: 'jump.wav must fire on START RUN');
      expect(music.playing, isTrue);
      expect(controller.currentMusic, BackgroundMusic.gameplayForest);
    });

    testWidgets('leaving the game screen swaps back to the menu theme '
        '(no orphaned gameplay loop)', (tester) async {
      await pumpGameScreen(tester);
      music.clear();

      final navigatorState =
          tester.state<NavigatorState>(find.byType(Navigator));
      navigatorState.pop();
      // Pump in small steps until the route's exit transition finishes and the
      // screen is actually disposed (dispose() hands music back to the menu).
      for (var i = 0;
          i < 20 && find.byType(StickmanRunScreen).evaluate().isNotEmpty;
          i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(StickmanRunScreen), findsNothing,
          reason: 'screen must be fully popped and disposed');
      await controller.settleForTest();

      expect(music.loads.last, BackgroundMusic.menuTheme.assetPath,
          reason: 'dispose() must hand music back to the menu theme');
      expect(controller.isGameplayActive, isFalse);
    });
  });

  group('functional: pause modal behaviour', () {
    testWidgets('PAUSE pauses music without stopping/reloading; RESUME '
        'continues instantly', (tester) async {
      await pumpGameScreen(tester);
      await startRun(tester);

      music.clear();
      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();

      expect(music.ops, contains('pause'),
          reason: 'pause modal pauses the music');
      expect(music.loads, isEmpty,
          reason: 'pausing must not re-load anything');
      expect(music.wasStopped, isFalse, reason: 'pause != stop');

      await tester.tap(find.text('RESUME'));
      await tester.pump();

      expect(music.ops, contains('play'), reason: 'resume continues playback');
      expect(music.loads, isEmpty,
          reason: 'resume must never reload — zero delay');
      expect(music.playing, isTrue);
    });

    testWidgets('RESTART LEVEL from the pause card cleanly restarts the '
        'biome track', (tester) async {
      await pumpGameScreen(tester);
      await startRun(tester);

      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      await tester.tap(find.text('RESTART LEVEL'));
      await tester.pump(); // confirm dialog appears

      music.clear();
      await tester.tap(find.text('RESTART')); // dialog confirmation
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await controller.settleForTest();

      // The biome track was only *held* by the pause, never stopped, so a
      // same-level restart must resume it instantly without a stop or reload.
      expect(music.playing, isTrue,
          reason: 'restart replays the held level track');
      expect(music.loads, isEmpty,
          reason: 'restart must not re-load the already-held track');
      expect(music.wasStopped, isFalse, reason: 'restart must not stop music');
      expect(controller.isGameplayActive, isTrue);
    });

    testWidgets('rapid PAUSE/RESUME spam converges to playing with no '
        'stuck state and no reloads', (tester) async {
      await pumpGameScreen(tester);
      await startRun(tester);

      for (var i = 0; i < 10; i++) {
        controller.pauseMusic();
        controller.resumeMusic();
      }
      await controller.settleForTest();

      expect(music.playing, isTrue, reason: 'final state = resumed');
      final forestLoads = music.loads
          .where((l) => l == BackgroundMusic.gameplayForest.assetPath)
          .length;
      expect(forestLoads, 1,
          reason: 'pause/resume spam must never trigger reloads');
    });
  });

  group('functional: settings affect live playback', () {
    testWidgets('toggling MUSIC off/on keeps the same loaded source',
        (tester) async {
      await pumpGameScreen(tester);
      final sourceBefore = music.loadedSource;

      SettingsController.instance.setMusicEnabled(false);
      await tester.pump(const Duration(milliseconds: 50));
      await controller.settleForTest();
      expect(music.playing, isFalse);
      expect(music.loadedSource, sourceBefore);

      SettingsController.instance.setMusicEnabled(true);
      await tester.pump(const Duration(milliseconds: 50));
      await controller.settleForTest();
      expect(music.playing, isTrue);
      expect(music.loadedSource, sourceBefore,
          reason: 'same track resumes — no reload delay');
    });

    testWidgets('toggling SFX off silences further effect calls',
        (tester) async {
      await pumpGameScreen(tester);
      SettingsController.instance.setSfxEnabled(false);
      await tester.pump(const Duration(milliseconds: 50));
      await controller.settleForTest();

      controller.play(SoundEffect.jump);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(sfx.playCount(SoundEffect.jump), 0,
          reason: 'disabled SFX must not play');
    });
  });
}
