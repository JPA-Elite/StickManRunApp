import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/game/app/stickman_run_app.dart';
import 'package:flutter_app/game/audio/audio_controller.dart';

import 'fake_audio_players.dart';

void main() {
  testWidgets('StickmanRunApp renders (smoke test)', (WidgetTester tester) async {
    final fakes = <FakeAudioPlayer>[];
    final audio = AudioController(
      playerFactory: () {
        final f = FakeAudioPlayer();
        fakes.add(f);
        return f;
      },
      sfxEngine: FakeSfxEngine(),
    );
    AudioController.testInstance = audio;
    addTearDown(() => AudioController.testInstance = null);
    await audio.initialize();

    await tester.pumpWidget(const StickmanRunApp());

    // Home screen shows the two-line brand title and the big play button.
    expect(find.text('STICKMAN\nRUN'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });
}
