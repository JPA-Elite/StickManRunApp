import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// How strong a haptic/vibration pulse should be.
enum HapticIntensity { light, medium, heavy }

/// Issues haptic/vibration feedback.
///
/// On Android this goes through a native [MethodChannel] that talks directly to
/// the system `Vibrator`. That is far more reliable than Flutter's
/// [HapticFeedback], which some devices (notably Samsung / One UI) route
/// through the system "touch vibration" setting and may silently ignore.
///
/// On non-Android platforms (or if the native channel is missing) it falls back
/// to [HapticFeedback].
Future<void> vibrateFeedback(HapticIntensity intensity) async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    final (ms, amp) = switch (intensity) {
      HapticIntensity.light => (30, 80),
      HapticIntensity.medium => (50, 150),
      HapticIntensity.heavy => (90, 255),
    };
    try {
      const channel = MethodChannel('stickmanrun/vibration');
      await channel.invokeMethod<void>('vibrate', {
        'durationMs': ms,
        'amplitude': amp,
      });
      return;
    } catch (_) {
      // Channel not wired up — fall through to HapticFeedback.
    }
  }

  switch (intensity) {
    case HapticIntensity.light:
      HapticFeedback.lightImpact();
    case HapticIntensity.medium:
      HapticFeedback.mediumImpact();
    case HapticIntensity.heavy:
      HapticFeedback.heavyImpact();
  }
}

/// Fire-and-forget wrapper so call sites don't need to await.
void vibrate(HapticIntensity intensity) {
  unawaited(vibrateFeedback(intensity));
}
