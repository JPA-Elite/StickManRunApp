import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import 'sound_effects.dart';

/// Abstract one-shot SFX backend. Production uses SoLoud (in-memory decoded
/// voices, single native call per play); tests substitute [FakeSfxEngine].
abstract class SfxEngine {
  Future<void> init();
  Future<void> preloadAll({required double volume});
  void play(SoundEffect effect);
  void setVolume(double volume);
  void stopAll();
  Future<void> dispose();
  bool get isReady;
}

/// SoLoud-backed SFX: all 22 WAVs decoded into memory once, then
/// `play(source)` fires a polyphonic voice natively — no stop+play pair,
/// no per-effect players, no disk on the hot path.
class SoLoudSfxEngine implements SfxEngine {
  SoLoudSfxEngine();

  final Map<SoundEffect, AudioSource> _sources = {};
  final List<SoundEffect> _pending = [];
  final Set<SoundEffect> _failed = {};
  final Set<SoundHandle> _liveHandles = {};
  bool _ready = false;
  bool _initStarted = false;
  double _volume = 1.0;
  bool _disposed = false;

  @override
  bool get isReady => _ready;

  static const _critical = {
    SoundEffect.jump,
    SoundEffect.buttonClick,
    SoundEffect.coinCollect,
    SoundEffect.hit,
    SoundEffect.smash,
    SoundEffect.gameOver,
  };

  @override
  Future<void> init() async {
    if (_initStarted) return;
    _initStarted = true;
    try {
      if (!SoLoud.instance.isInitialized) {
        await SoLoud.instance.init(lowLatency: true);
      }
    } catch (e) {
      debugPrint('SoLoudSfxEngine: init failed: $e');
      return;
    }
    // Critical first so first taps are instant; rest in background.
    await _loadMany(_critical);
    if (_disposed) return;
    _ready = true;
    _flushPending();
    unawaited(_loadMany(
      SoundEffect.values.toSet().difference(_critical),
    ));
  }

  Future<void> _loadMany(Set<SoundEffect> effects) async {
    for (final effect in effects) {
      if (_disposed) return;
      if (_sources.containsKey(effect)) continue;
      try {
        final source = await SoLoud.instance.loadAsset(effect.assetPath);
        _sources[effect] = source;
        _failed.remove(effect);
      } catch (e) {
        _failed.add(effect);
        debugPrint('SoLoudSfxEngine: load failed ${effect.name}: $e');
      }
    }
  }

  @override
  Future<void> preloadAll({required double volume}) async {
    _volume = volume.clamp(0.0, 1.0);
    await init();
  }

  void _flushPending() {
    if (_pending.isEmpty) return;
    final queued = List<SoundEffect>.of(_pending);
    _pending.clear();
    for (final effect in queued) {
      play(effect);
    }
  }

  @override
  void play(SoundEffect effect) {
    if (_disposed) return;
    if (!_ready) {
      if (_pending.length < 64) _pending.add(effect);
      return;
    }
    final source = _sources[effect];
    if (source == null) {
      // Heal once in background, play when ready if still wanted.
      if (!_failed.contains(effect)) _failed.add(effect);
      unawaited(() async {
        try {
          final reloaded = await SoLoud.instance.loadAsset(effect.assetPath);
          if (_disposed) return;
          _sources[effect] = reloaded;
          _failed.remove(effect);
        } catch (e) {
          debugPrint('SoLoudSfxEngine: reload failed ${effect.name}: $e');
        }
      }());
      return;
    }
    try {
      // Single native call; overlapping same-source voices mix natively.
      final handle = SoLoud.instance.play(source, volume: _volume);
      _liveHandles.add(handle);
      if (_liveHandles.length > 64) {
        _liveHandles.remove(_liveHandles.first);
      }
    } catch (e) {
      debugPrint('SoLoudSfxEngine: play failed ${effect.name}: $e');
    }
  }

  @override
  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
  }

  @override
  void stopAll() {
    if (_disposed) return;
    // Short one-shots finish naturally; best-effort stop of live voices.
    final handles = List<SoundHandle>.of(_liveHandles);
    _liveHandles.clear();
    for (final handle in handles) {
      unawaited(() async {
        try {
          await SoLoud.instance.stop(handle);
        } catch (_) {}
      }());
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _pending.clear();
    // Keep sources for app lifetime; engine deinit owned by process.
  }
}
