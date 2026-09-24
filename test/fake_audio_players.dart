import 'package:flutter_app/game/audio/audio_player_adapter.dart';
import 'package:flutter_app/game/audio/sfx_engine.dart';
import 'package:flutter_app/game/audio/sound_effects.dart';

/// Recording fake player used by the audio tests. Logs every operation so
/// tests can assert exact playback sequences without audio hardware.
class FakeAudioPlayer implements AudioPlayerAdapter {
  FakeAudioPlayer({this.label = 'player'});

  /// Tag used by tests to identify which role this player fills.
  final String label;

  /// Every performed operation in order, e.g. `load:assets/...`,
  /// `play`, `pause`, `stop`, `volume:0.70`.
  final List<String> ops = [];

  bool playing = false;
  String? loadedSource;
  double volume = 1.0;
  bool disposed = false;

  /// When true, [load] throws — used to verify error isolation.
  bool failOnLoad = false;

  int get playCount =>
      ops.where((o) => o == 'play').length;
  List<String> get loads => ops
      .where((o) => o.startsWith('load:'))
      .map((o) => o.substring('load:'.length))
      .toList();
  bool get wasPaused => ops.contains('pause');
  bool get wasStopped => ops.contains('stop');

  void clear() => ops.clear();

  @override
  bool get isPlaying => playing;

  @override
  Future<void> load(String assetPath) async {
    ops.add('load:$assetPath');
    if (failOnLoad) {
      throw StateError('simulated load failure ($label)');
    }
    loadedSource = assetPath;
    playing = false;
  }

  @override
  Future<void> play() async {
    if (disposed) throw StateError('play after dispose ($label)');
    ops.add('play');
    playing = true;
  }

  @override
  Future<void> pause() async {
    ops.add('pause');
    playing = false;
  }

  @override
  Future<void> stop() async {
    ops.add('stop');
    playing = false;
  }

  @override
  Future<void> setLoop(bool loop) async {
    ops.add('loop:$loop');
  }

  @override
  Future<void> setVolume(double value) async {
    ops.add('volume:${value.toStringAsFixed(2)}');
    volume = value;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    playing = false;
  }
}

/// Recording fake SoLoud backend: preloaded in memory, polyphonic voices.
/// `play` is a single synchronous call — overlapping same-source plays all
/// count (no round-robin pools needed).
class FakeSfxEngine implements SfxEngine {
  final Map<SoundEffect, String> loadedSources = {};
  final Map<SoundEffect, int> playCounts = {};
  final List<SoundEffect> playOrder = [];
  final List<double> volumeOps = [];
  int stopAllCount = 0;
  bool ready = false;
  bool failOnLoad = false;
  double volume = 1.0;

  int playCount(SoundEffect e) => playCounts[e] ?? 0;

  @override
  bool get isReady => ready;

  @override
  Future<void> init() async {
    ready = true;
  }

  @override
  Future<void> preloadAll({required double volume}) async {
    this.volume = volume;
    volumeOps.add(volume);
    await init();
    if (failOnLoad) return;
    for (final e in SoundEffect.values) {
      loadedSources[e] = e.assetPath;
    }
  }

  @override
  void play(SoundEffect effect) {
    playCounts[effect] = (playCounts[effect] ?? 0) + 1;
    playOrder.add(effect);
  }

  @override
  void setVolume(double v) {
    volume = v;
    volumeOps.add(v);
  }

  @override
  void stopAll() {
    stopAllCount++;
  }

  @override
  Future<void> dispose() async {}
}
