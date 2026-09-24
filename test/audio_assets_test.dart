import 'dart:io';

import 'package:flutter_app/game/audio/background_music.dart';
import 'package:flutter_app/game/audio/sound_effects.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards against "asset not found" runtime errors: every enum entry must
/// exist on disk AND be declared in pubspec.yaml.
void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();

  group('SFX asset integrity', () {
    test('all 22 effects exist on disk and are declared in pubspec', () {
      expect(SoundEffect.values, hasLength(22));
      for (final effect in SoundEffect.values) {
        final file = File(effect.assetPath);
        expect(file.existsSync(), isTrue,
            reason: '${effect.assetPath} missing on disk');
        expect(pubspec.contains(effect.assetPath), isTrue,
            reason: '${effect.assetPath} not declared in pubspec.yaml');
      }
    });

    test('every SFX is a .wav under assets/audio/sfx/', () {
      for (final effect in SoundEffect.values) {
        expect(effect.assetPath, startsWith('assets/audio/sfx/'));
        expect(effect.assetPath, endsWith('.wav'));
      }
    });
  });

  group('Background music asset integrity', () {
    test('all 6 tracks exist on disk and are declared in pubspec', () {
      expect(BackgroundMusic.values, hasLength(6));
      for (final track in BackgroundMusic.values) {
        final file = File(track.assetPath);
        expect(file.existsSync(), isTrue,
            reason: '${track.assetPath} missing on disk');
        expect(pubspec.contains(track.assetPath), isTrue,
            reason: '${track.assetPath} not declared in pubspec.yaml');
        // MP3 is the universal primary; OGG fallback must also exist.
        expect(track.assetPath, endsWith('.mp3'));
        expect(File(track.fallbackAssetPath).existsSync(), isTrue,
            reason: '${track.fallbackAssetPath} fallback missing on disk');
        expect(pubspec.contains(track.fallbackAssetPath), isTrue,
            reason:
                '${track.fallbackAssetPath} fallback not in pubspec.yaml');
      }
    });

    test('exactly one menu theme + five biome tracks with unique indices',
        () {
      final gameplay =
          BackgroundMusic.values.where((t) => t.isGameplayTrack).toList();
      expect(gameplay, hasLength(5));
      expect(
        gameplay.map((t) => t.biomeIndex).toSet(),
        {0, 1, 2, 3, 4},
      );
      final menus =
          BackgroundMusic.values.where((t) => !t.isGameplayTrack).toList();
      expect(menus, [BackgroundMusic.menuTheme]);
    });
  });
}
