import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

/// Opt-in Android input synchronization. Uses Flutter's normal sampling delay;
/// it does not change scroll physics, animations or the PDF gesture recognizers.
abstract final class TouchInputPolicy {
  static const optedIn = bool.fromEnvironment(
    'BAYNA_TOUCH_RESAMPLING', defaultValue: false,
  );

  static void initialize(GestureBinding binding) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android && optedIn) {
      binding.resamplingEnabled = true;
    }
  }
}
