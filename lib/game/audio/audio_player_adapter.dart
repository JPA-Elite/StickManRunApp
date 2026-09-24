import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// Minimal playback surface the audio system needs, abstracted behind an
/// interface so tests can substitute recording fakes instead of driving real
/// platform players (which require running audio hardware/plugins).
abstract class AudioPlayerAdapter {
  /// Whether the underlying player is currently producing sound.
  bool get isPlaying;

  /// Loads (and caches) an asset so subsequent [play] calls start instantly
  /// with zero disk access on the hot path.
  Future<void> load(String assetPath);

  /// Starts (or resumes) playback from the beginning of the loaded source.
  Future<void> play();

  /// Whether playback should loop forever (music) or stop after one pass.
  Future<void> setLoop(bool loop);

  /// Pauses playback keeping the loaded source and position.
  Future<void> pause();

  /// Stops playback and rewinds to the start; the source stays loaded.
  Future<void> stop();

  Future<void> setVolume(double volume);

  Future<void> dispose();
}

/// Production [AudioPlayerAdapter] backed by the audioplayers plugin.
class AudioplayersAdapter implements AudioPlayerAdapter {
  /// Creates an adapter around a fresh platform player configured for [mode]:
  /// [PlayerMode.lowLatency] for short one-shot SFX, [PlayerMode.mediaPlayer]
  /// for looping background music.
  ///
  /// Use the named constructors [AudioplayersAdapter.music] and
  /// [AudioplayersAdapter.sfx] so callers cannot accidentally give SFX the
  /// high-latency media path.
  AudioplayersAdapter({PlayerMode mode = PlayerMode.mediaPlayer})
      : _player = AudioPlayer(),
        _mode = mode {
    // L5: do NOT fire-and-forget here; applied awaitedly on first load()
    // so the mode is guaranteed before the first setSource.
  }

  /// Looping background-music player (long tracks, full event stream).
  factory AudioplayersAdapter.music() =>
      AudioplayersAdapter(mode: PlayerMode.mediaPlayer);

  /// One-shot SFX player (short clips, minimal latency, resources kept).
  factory AudioplayersAdapter.sfx() =>
      AudioplayersAdapter(mode: PlayerMode.lowLatency);

  /// Configures a shared global audio session once at startup so phone calls,
  /// other apps and the silent switch behave predictably. Best-effort: never
  /// throws.
  static Future<void> configureGlobalAudioSession() async {
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.game,
            audioFocus: AndroidAudioFocus.gain,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
          ),
        ),
      );
    } catch (_) {
      // Audio still works with platform defaults.
    }
  }

  final AudioPlayer _player;
  final PlayerMode _mode;
  bool _modeApplied = false;

  // Optimistic mirror of playback state. Platform `state` updates arrive
  // asynchronously over an event channel, so immediately after `play()` it
  // can still read `stopped`. Without this, rapid reuse of a pooled SFX
  // player skips the required `stop()` and the second tap is lost (see
  // audioplayers #1489: lowLatency needs stop-before-resume).
  bool _optimisticPlaying = false;

  @override
  bool get isPlaying =>
      _optimisticPlaying || _player.state == PlayerState.playing;

  @override
  Future<void> load(String assetPath) async {
    if (!_modeApplied) {
      _modeApplied = true;
      try {
        await _player.setPlayerMode(_mode);
      } catch (_) {}
      if (_mode == PlayerMode.lowLatency) {
        try {
          await _player.setReleaseMode(ReleaseMode.stop);
        } catch (_) {}
      }
    }
    // AssetSource expects paths relative to the assets/ bundle root.
    return _player.setSource(AssetSource(assetPath.replaceFirst('assets/', '')));
  }

  @override
  Future<void> play() async {
    _optimisticPlaying = true;
    try {
      await _player.resume();
    } catch (_) {
      _optimisticPlaying = false;
      rethrow;
    }
  }

  @override
  Future<void> setLoop(bool loop) => _player.setReleaseMode(
        // STOP (not RELEASE) for one-shots: keeps the preloaded source so
        // replays never re-buffer from disk on the hot path.
        loop ? ReleaseMode.loop : ReleaseMode.stop,
      );

  @override
  Future<void> pause() async {
    _optimisticPlaying = false;
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    _optimisticPlaying = false;
    await _player.stop();
  }

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> dispose() async {
    _optimisticPlaying = false;
    await _player.dispose();
  }
}
