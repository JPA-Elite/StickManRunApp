import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import 'audio_player_adapter.dart';
import 'background_music.dart';
import 'sfx_engine.dart';
import 'sound_effects.dart';

/// Creates platform players. Overridable in tests so playback can be verified
/// without touching real audio hardware.
typedef AudioPlayerFactory = AudioPlayerAdapter Function();

/// Owns every sound the game plays: one looping music player (audioplayers,
/// good for long streamed loops) plus SoLoud in-memory voices for one-shot
/// SFX (single native call per play, polyphonic, no per-effect players).
class AudioController extends ChangeNotifier {
  AudioController({
    AudioPlayerFactory? playerFactory,
    SfxEngine? sfxEngine,
  })  : _playerFactory = playerFactory ?? _defaultMusicFactory,
        _sfxEngine = sfxEngine ?? SoLoudSfxEngine(),
        _isTestHarness = playerFactory != null || sfxEngine != null {
    _musicPlayer = _createMusicPlayer();
  }

  static AudioPlayerAdapter _defaultMusicFactory() =>
      AudioplayersAdapter.music();

  static final AudioController instance = AudioController();

  @visibleForTesting
  static AudioController? testInstance;

  static AudioController get effectiveInstance => testInstance ?? instance;

  final AudioPlayerFactory _playerFactory;
  final SfxEngine _sfxEngine;
  final bool _isTestHarness;
  late AudioPlayerAdapter _musicPlayer;

  /// C2: split started vs complete. `_initStarted` guards idempotence,
  /// `_initialized` (complete) gates playback. Plays/music during preload
  /// are deferred, never raced with preload loads.
  bool _initStarted = false;
  bool _initialized = false;
  bool _disposed = false;
  Future<void> _initFuture = Future.value();

  bool _musicPendingSync = false;

  bool _musicEnabled = true;
  bool _sfxEnabled = true;
  double _musicVolume = 0.7;
  double _sfxVolume = 1.0;

  double get _effectiveMusicVolume => _musicEnabled ? _musicVolume : 0.0;
  double get _effectiveSfxVolume => _sfxEnabled ? _sfxVolume : 0.0;

  BackgroundMusic? _currentMusic;
  BackgroundMusic? _desiredMusic;
  int _gameplayRefCount = 0;
  bool _explicitlyPaused = false;
  bool _backgroundPaused = false;
  bool _runEnded = false;
  int _musicToken = 0;
  Future<void> _chain = Future.value();
  Timer? _fadeTimer;
  int _fadeToken = 0;
  double _fadeBaseVolume = 0.7;

  // SFX readiness/queue owned by [_sfxEngine]; no controller-level pools.

  String? _lastMusicError;
  String? get lastMusicError => _lastMusicError;

  bool _userInteracted = false;

  BackgroundMusic? get currentMusic => _currentMusic;
  bool get isGameplayActive => _gameplayRefCount > 0;
  bool get isMusicEnabled => _musicEnabled;
  bool get isSfxEnabled => _sfxEnabled;
  bool get isInitialized => _initialized;

  /// Test access to the SFX backend (fake in tests).
  @visibleForTesting
  SfxEngine get sfxEngineForTest => _sfxEngine;

  AudioPlayerAdapter _createMusicPlayer() => _playerFactory();

  Future<void> initialize() async {
    if (_initStarted) return _initFuture;
    _initStarted = true;
    _initFuture = _doInitialize();
    return _initFuture;
  }

  static bool get _runningInFlutterTest {
    if (kIsWeb) return false;
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  Future<void> _doInitialize() async {
    if (!_isTestHarness && !_runningInFlutterTest) {
      unawaited(
        AudioplayersAdapter.configureGlobalAudioSession().timeout(
          const Duration(seconds: 2),
          onTimeout: () {},
        ),
      );
    }
    // SFX voices decoded into memory once (SoLoud engine owns its queue;
    // critical first inside the engine, rest background).
    _sfxEngine.setVolume(_effectiveSfxVolume);
    await _sfxEngine.preloadAll(volume: _effectiveSfxVolume);
    _initialized = true;
    if (_musicPendingSync) {
      _musicPendingSync = false;
      _syncMusic();
    }
    debugPrint(
      'AudioController: initialized (${SoundEffect.values.length} effects)',
    );
  }

  void notifyUserInteraction() {
    _userInteracted = true;
    _syncMusic();
  }

  void handleAppPaused() {
    if (_disposed) return;
    _backgroundPaused = true;
    _stopAllSfx();
    _syncMusic();
  }

  void handleAppInactive() => handleAppPaused();

  void handleAppResumed() {
    if (_disposed) return;
    _backgroundPaused = false;
    _syncMusic();
  }

  void _stopAllSfx() {
    try {
      _sfxEngine.stopAll();
    } catch (_) {}
  }

  void applySettings({
    required bool musicEnabled,
    required bool sfxEnabled,
    required double musicVolume,
    required double sfxVolume,
  }) {
    if (_disposed) return;
    final sfxWasEnabled = _sfxEnabled;
    _musicEnabled = musicEnabled;
    _sfxEnabled = sfxEnabled;
    _musicVolume = musicVolume.clamp(0.0, 1.0);
    _sfxVolume = sfxVolume.clamp(0.0, 1.0);

    if (_fadeTimer != null) {
      _fadeBaseVolume = _effectiveMusicVolume;
    }
    unawaited(_safeVolume(_musicPlayer, _effectiveMusicVolume));
    try {
      _sfxEngine.setVolume(_effectiveSfxVolume);
    } catch (_) {}
    if (sfxWasEnabled && !sfxEnabled) {
      _stopAllSfx();
    }
    final fading = _fadeTimer != null && _runEnded;
    _syncMusic(cancelFade: !fading);
    notifyListeners();
  }

  void requestMenuMusic() {
    if (_disposed) return;
    if (_gameplayRefCount > 0) {
      debugPrint('AudioController: menu music request ignored — '
          'gameplay session active');
      return;
    }
    _desiredMusic = BackgroundMusic.menuTheme;
    _syncMusic();
  }

  void enterGameplay(int initialBiomeIndex) {
    if (_disposed) return;
    _gameplayRefCount++;
    _explicitlyPaused = false;
    _runEnded = false;
    updateGameplayTheme(initialBiomeIndex);
  }

  void updateGameplayTheme(int biomeIndex) {
    if (_disposed) return;
    if (_gameplayRefCount <= 0) return;
    final track = BackgroundMusic.forBiomeIndex(biomeIndex) ??
        BackgroundMusic.gameplayForest;
    if (_desiredMusic != track) {
      _desiredMusic = track;
    }
    _syncMusic();
  }

  void exitGameplay() {
    if (_disposed) return;
    if (_gameplayRefCount > 0) _gameplayRefCount--;
    if (_gameplayRefCount > 0) return;
    _gameplayRefCount = 0;
    _explicitlyPaused = false;
    _runEnded = false;
    _desiredMusic = BackgroundMusic.menuTheme;
    _syncMusic();
  }

  void pauseMusic() {
    if (_disposed) return;
    _explicitlyPaused = true;
    _syncMusic();
  }

  void resumeMusic() {
    if (_disposed) return;
    _explicitlyPaused = false;
    _runEnded = false;
    _syncMusic();
  }

  void fadeOutForRunEnd() {
    if (_disposed) return;
    _explicitlyPaused = true;
    _runEnded = true;
    _cancelFade();
    const steps = 12;
    const stepMs = 50;
    var step = 0;
    _fadeBaseVolume = _effectiveMusicVolume;
    final token = ++_fadeToken;
    _fadeTimer = Timer.periodic(const Duration(milliseconds: stepMs), (timer) {
      if (token != _fadeToken) {
        timer.cancel();
        return;
      }
      step++;
      final target = (_fadeBaseVolume * (1 - step / steps)).clamp(0.0, 1.0);
      unawaited(_safeVolume(_musicPlayer, target));
      if (step >= steps) {
        timer.cancel();
        if (token == _fadeToken) {
          _fadeTimer = null;
          _syncMusic(cancelFade: false);
        }
      }
    });
  }

  /// C1: restart must NOT increment the refcount. It resets pause/run flags
  /// on the existing session so exitGameplay later balances exactly once.
  void notifyRunRestarted(int biomeIndex) {
    if (_disposed) return;
    if (_gameplayRefCount <= 0) {
      enterGameplay(biomeIndex);
      return;
    }
    _explicitlyPaused = false;
    _runEnded = false;
    final track = BackgroundMusic.forBiomeIndex(biomeIndex) ??
        BackgroundMusic.gameplayForest;
    _desiredMusic = track;
    _syncMusic();
  }

  void _syncMusic({bool cancelFade = true}) {
    if (_disposed) return;
    // C2: defer music transitions until preload-critical is done. Desired is
    // already stored; flush after init.
    if (!_initialized) {
      _musicPendingSync = true;
      if (cancelFade) _cancelFade();
      return;
    }
    if (cancelFade) _cancelFade();
    final token = ++_musicToken;
    final shouldPlay = _musicEnabled &&
        !_explicitlyPaused &&
        !_backgroundPaused &&
        (_userInteracted || !kIsWeb);
    final target = shouldPlay ? _desiredMusic : null;
    _chain = _chain.then((_) async {
      if (token != _musicToken) return;
      if (_disposed) return;
      await _transitionTo(target, token);
    });
  }

  Future<void> _transitionTo(BackgroundMusic? target, int token) async {
    bool superseded() => token != _musicToken || _disposed;
    try {
      if (target == null) {
        if (_currentMusic == null) return;
        if (_runEnded) {
          await _stopMusicSafely();
          if (superseded()) return;
          // L2: keep source for instant retry (don't null). Stop rewinds but
          // with ReleaseMode.loop/stop the source stays; restart resumes
          // via current==target without reload.
          // _currentMusic stays as-is (paused-at-0). Only drop on failure.
        } else {
          if (_musicPlayer.isPlaying) await _musicPlayer.pause();
          if (superseded()) return;
        }
        return;
      }
      if (_currentMusic == target) {
        if (!_musicPlayer.isPlaying) {
          await _musicPlayer.setVolume(_effectiveMusicVolume);
          if (superseded()) return;
          await _musicPlayer.play();
          if (superseded()) return;
        }
        _lastMusicError = null;
        return;
      }
      await _stopMusicSafely();
      if (superseded()) return;
      try {
        await _musicPlayer.load(target.assetPath);
      } catch (_) {
        if (superseded()) return;
        await _musicPlayer.load(target.fallbackAssetPath);
      }
      if (superseded()) return;
      await _musicPlayer.setLoop(true);
      if (superseded()) return;
      await _musicPlayer.setVolume(_effectiveMusicVolume);
      if (superseded()) return;
      await _musicPlayer.play();
      if (superseded()) return;
      _currentMusic = target;
      _lastMusicError = null;
    } catch (e) {
      // L4: surface instead of debugPrint-only.
      _lastMusicError = 'transition to ${target?.name ?? '<none>'}: $e';
      debugPrint('AudioController: $_lastMusicError');
      try {
        await _musicPlayer.dispose();
      } catch (_) {}
      if (_disposed) return;
      _musicPlayer = _rebuildMusicPlayer();
      _currentMusic = null;
      notifyListeners();
    }
  }

  /// Retries the currently desired track (used by UI after [lastMusicError]).
  void retryMusic() {
    if (_disposed) return;
    _syncMusic();
  }

  Future<void> _stopMusicSafely() async {
    try {
      await _musicPlayer.stop().timeout(const Duration(seconds: 3));
    } on TimeoutException {
      debugPrint('AudioController: music stop timed out — rebuilding player');
      try {
        await _musicPlayer.dispose();
      } catch (_) {}
      if (!_disposed) _musicPlayer = _rebuildMusicPlayer();
    } catch (e) {
      debugPrint('AudioController: music stop failed: $e');
    }
  }

  AudioPlayerAdapter _rebuildMusicPlayer() {
    final fresh = _createMusicPlayer();
    unawaited(_safeVolume(fresh, _effectiveMusicVolume));
    return fresh;
  }

  void _cancelFade() {
    _fadeToken++;
    _fadeTimer?.cancel();
    _fadeTimer = null;
  }

  /// Fast one-shot SFX via SoLoud in-memory voices: synchronous,
  /// fire-and-forget, single native call, polyphonic overlap natively.
  /// Engine queues internally until ready, so no controller-level queue.
  void play(SoundEffect effect) {
    if (_disposed) return;
    if (!_sfxEnabled || _sfxVolume <= 0) return;
    try {
      _sfxEngine.play(effect);
    } catch (e) {
      debugPrint('AudioController: play ${effect.name} failed: $e');
    }
  }

  Future<void> _safeVolume(AudioPlayerAdapter player, double volume) async {
    try {
      await player.setVolume(volume);
    } catch (e) {
      debugPrint('AudioController: setVolume failed: $e');
    }
  }

  @visibleForTesting
  Future<void> settleForTest() => _chain;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cancelFade();
    _musicToken++;
    unawaited(_chain.then((_) async {
      try {
        await _musicPlayer.dispose();
      } catch (_) {}
      try {
        await _sfxEngine.dispose();
      } catch (_) {}
    }));
    super.dispose();
  }
}
