import 'package:flutter_app/game/audio/audio_controller.dart';
import 'package:flutter_app/game/audio/background_music.dart';
import 'package:flutter_app/game/audio/sound_effects.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_audio_players.dart';

(AudioController, List<FakeAudioPlayer>, FakeSfxEngine) newHarness() {
  final all = <FakeAudioPlayer>[];
  final sfx = FakeSfxEngine();
  final controller = AudioController(
    playerFactory: () {
      final fake = FakeAudioPlayer();
      all.add(fake);
      return fake;
    },
    sfxEngine: sfx,
  );
  return (controller, all, sfx);
}

void main() {
  late AudioController controller;
  late List<FakeAudioPlayer> all;
  late FakeAudioPlayer music;
  late FakeSfxEngine sfx;

  setUp(() {
    final harness = newHarness();
    controller = harness.$1;
    all = harness.$2;
    sfx = harness.$3;
    music = all.first;
  });

  Future<void> initAndEnterForest() async {
    await controller.initialize();
    controller.enterGameplay(0);
    await controller.settleForTest();
  }

  group('A. background music precedence & synchronization', () {
    test('entering gameplay loads and loops the level biome track', () async {
      await initAndEnterForest();

      expect(music.loads.last, BackgroundMusic.gameplayForest.assetPath);
      expect(music.playing, isTrue);
      expect(music.ops.contains('loop:true'), isTrue);
      expect(controller.currentMusic, BackgroundMusic.gameplayForest);
      expect(controller.isGameplayActive, isTrue);
    });

    test(
        'menu music request is IGNORED while a gameplay session is active '
        '(menu theme can never override the run)', () async {
      await initAndEnterForest();
      music.clear();
      final loadsBefore = music.loads.length;

      controller.requestMenuMusic(); // stray menu request mid-run
      await controller.settleForTest();

      expect(controller.currentMusic, BackgroundMusic.gameplayForest,
          reason: 'gameplay track must keep playing');
      expect(music.loads.length, loadsBefore, reason: 'no reload may happen');
      expect(music.wasStopped, isFalse,
          reason: 'the run track must not be stopped');
      expect(music.playing, isTrue);
    });

    test('exiting gameplay hands music back to the menu theme', () async {
      await initAndEnterForest();
      music.clear();

      controller.exitGameplay();
      await controller.settleForTest();

      // stop precedes the menu load — no overlap between tracks.
      final stopIdx = music.ops.indexOf('stop');
      final loadIdx =
          music.ops.indexOf('load:${BackgroundMusic.menuTheme.assetPath}');
      expect(stopIdx, greaterThanOrEqualTo(0));
      expect(loadIdx, greaterThan(stopIdx));
      expect(music.loads.last, BackgroundMusic.menuTheme.assetPath);
      expect(music.playing, isTrue);
      expect(controller.isGameplayActive, isFalse);
    });

    test('mid-run biome change switches to the matching track exactly once',
        () async {
      await initAndEnterForest();
      music.clear();

      controller.updateGameplayTheme(4); // forest -> volcano
      await controller.settleForTest();

      expect(music.loads, [BackgroundMusic.gameplayVolcano.assetPath]);
      expect(music.playing, isTrue);
      expect(controller.currentMusic, BackgroundMusic.gameplayVolcano);
    });

    test('rapid switch storm converges on the LAST requested track with a '
        'single load (token guard, no interleaving)', () async {
      await initAndEnterForest();
      music.clear();

      controller.updateGameplayTheme(1); // desert
      controller.updateGameplayTheme(2); // night city
      controller.updateGameplayTheme(3); // cave
      controller.updateGameplayTheme(4); // volcano (final)
      await controller.settleForTest();

      expect(music.loads, [BackgroundMusic.gameplayVolcano.assetPath],
          reason: 'superseded switches must be skipped entirely');
      expect(music.playing, isTrue);
    });
  });

  group('B. pause modal semantics', () {
    test('pause keeps source + position: pause only, no stop, no reload',
        () async {
      await initAndEnterForest();
      music.clear();

      controller.pauseMusic();
      await controller.settleForTest();

      expect(music.wasPaused, isTrue);
      expect(music.wasStopped, isFalse, reason: 'pause != stop');
      expect(music.loads, isEmpty, reason: 'no reload on pause');
      expect(music.playing, isFalse);
    });

    test('resume continues instantly: play only, no reload', () async {
      await initAndEnterForest();
      controller.pauseMusic();
      await controller.settleForTest();
      music.clear();

      controller.resumeMusic();
      await controller.settleForTest();

      expect(music.ops, contains('play'));
      expect(music.loads, isEmpty, reason: 'resume must never re-load');
      expect(music.playing, isTrue);
    });

    test('toggling music OFF retains the source; back ON resumes it', () async {
      await initAndEnterForest();
      final loadedSource = music.loadedSource;

      controller.applySettings(
        musicEnabled: false,
        sfxEnabled: true,
        musicVolume: 0.7,
        sfxVolume: 1.0,
      );
      await controller.settleForTest();
      expect(music.playing, isFalse);
      expect(music.loadedSource, loadedSource,
          reason: 'source retained while disabled');

      controller.applySettings(
        musicEnabled: true,
        sfxEnabled: true,
        musicVolume: 0.7,
        sfxVolume: 1.0,
      );
      await controller.settleForTest();
      expect(music.playing, isTrue);
      expect(music.loadedSource, loadedSource,
          reason: 'same track resumed, not reloaded');
    });

    test('background/foreground lifecycle pauses and restores music', () async {
      await initAndEnterForest();

      controller.handleAppPaused();
      await controller.settleForTest();
      expect(music.playing, isFalse);

      controller.handleAppResumed();
      await controller.settleForTest();
      expect(music.playing, isTrue);

      // Explicit user pause wins over foregrounding.
      controller.pauseMusic();
      controller.handleAppResumed();
      await controller.settleForTest();
      expect(music.playing, isFalse,
          reason: 'modal-held pause must survive an app resume');
    });
  });

  group('C. run-end fades & restart', () {
    test('fadeOutForRunEnd steps volume down then stops the music',
        () async {
      await initAndEnterForest();
      music.clear();

      controller.fadeOutForRunEnd();
      await Future<void>.delayed(const Duration(milliseconds: 750));
      await controller.settleForTest();

      expect(music.wasStopped, isTrue, reason: 'music fully stops after fade');
      expect(music.playing, isFalse);
      final volumeOps = music.ops.where((o) => o.startsWith('volume:'));
      expect(volumeOps.length, greaterThanOrEqualTo(10),
          reason: 'fade should step volume down gradually');
    });

    test('a newer request cancels an in-flight fade (no zombie timers)',
        () async {
      await initAndEnterForest();
      controller.fadeOutForRunEnd();
      controller.resumeMusic(); // supersedes the fade before it finishes
      await controller.settleForTest();
      final opsAtCancel = music.ops.length;

      await Future<void>.delayed(const Duration(milliseconds: 750));
      await controller.settleForTest();

      expect(music.ops.length, opsAtCancel,
          reason: 'cancelled fade must write no further operations');
      expect(music.playing, isTrue);
    });
  });

  group('D. sound effects correctness (SoLoud voices)', () {
    test('every SFX preloads its own asset into memory once', () async {
      await controller.initialize();

      for (final effect in SoundEffect.values) {
        expect(sfx.loadedSources[effect], effect.assetPath,
            reason: '${effect.name} must preload ${effect.assetPath}');
      }

      for (final effect in SoundEffect.values) {
        controller.play(effect);
      }
      await pumpEventQueue();

      for (final effect in SoundEffect.values) {
        expect(sfx.playCount(effect), 1,
            reason: '${effect.name}: exactly one voice fires');
      }
    });

    test('rapid same-source plays overlap as separate voices (no cutoff)',
        () async {
      await controller.initialize();

      for (var i = 0; i < 8; i++) {
        controller.play(SoundEffect.coinCollect);
      }
      await pumpEventQueue();

      // SoLoud mixes natively: all 8 voices count, none cut each other.
      expect(sfx.playCount(SoundEffect.coinCollect), 8);
    });

    test('disabled SFX produce zero play calls', () async {
      await controller.initialize();
      controller.applySettings(
        musicEnabled: true,
        sfxEnabled: false,
        musicVolume: 0.7,
        sfxVolume: 1.0,
      );

      controller.play(SoundEffect.jump);
      controller.play(SoundEffect.coinCollect);
      await pumpEventQueue();

      expect(sfx.playCount(SoundEffect.jump), 0);
      expect(sfx.playCount(SoundEffect.coinCollect), 0);
    });

    test('volume settings apply as pure setVolume ops (no re-source)',
        () async {
      await controller.initialize();
      music.clear();

      controller.applySettings(
        musicEnabled: true,
        sfxEnabled: true,
        musicVolume: 0.25,
        sfxVolume: 0.5,
      );
      await pumpEventQueue();

      expect(music.ops, contains('volume:0.25'));
      expect(sfx.volumeOps, contains(0.5));
      expect(music.loads, isEmpty, reason: 'volume-only change');
    });

    test('error isolation: failing load never throws and the system recovers',
        () async {
      await controller.initialize();
      music.failOnLoad = true;

      // Must not throw into the caller.
      controller.enterGameplay(0);
      await controller.settleForTest();
      expect(controller.currentMusic, isNull,
          reason: 'failed transition degrades to silence');

      // Heal the fake and hand back to the menu — system recovers.
      music.failOnLoad = false;
      music.clear();
      controller.exitGameplay();
      await controller.settleForTest();

      // The wedged player was replaced by a rebuilt one during self-heal;
      // the recovery load lands on that fresh player.
      final recovered = all.where((f) => f != music).last;
      expect(recovered.loads.last, BackgroundMusic.menuTheme.assetPath);
      expect(recovered.playing, isTrue);
    });

    test('SFX play calls never throw (fire-and-forget)', () async {
      await controller.initialize();

      // Fire-and-forget contract: no exception escapes play().
      controller.play(SoundEffect.jump);
      await pumpEventQueue();
      expect(sfx.playCount(SoundEffect.jump), 1);
    });
  });

  group('E. biome mapping integrity', () {
    test('all five engine biomes resolve to distinct gameplay tracks', () {
      final tracks = [
        BackgroundMusic.forBiomeIndex(0),
        BackgroundMusic.forBiomeIndex(1),
        BackgroundMusic.forBiomeIndex(2),
        BackgroundMusic.forBiomeIndex(3),
        BackgroundMusic.forBiomeIndex(4),
      ];
      expect(tracks.every((t) => t != null), isTrue);
      expect(tracks.toSet(), hasLength(5));
      expect(BackgroundMusic.forBiomeIndex(99), isNull);
    });
  });
}
