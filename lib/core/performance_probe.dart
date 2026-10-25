import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'scroll_frame_sample.dart';

/// Immutable stats for one bounded sample of Flutter frame timings.
/// Durations do not establish delivered FPS; they identify which thread
/// exceeded the 8.33ms budget of a 120 Hz display.
@immutable
class FramePerformanceReport {
  const FramePerformanceReport({
    required this.frameCount,
    required this.uiP50Ms,
    required this.uiP95Ms,
    required this.rasterP50Ms,
    required this.rasterP95Ms,
    required this.over60Budget,
    required this.over120Budget,
    this.cadence,
  });

  final int frameCount;
  final double uiP50Ms;
  final double uiP95Ms;
  final double rasterP50Ms;
  final double rasterP95Ms;
  final int over60Budget;
  final int over120Budget;
  final FrameCadence? cadence;

  static FramePerformanceReport fromMicros(
    List<int> uiMicros,
    List<int> rasterMicros, {
    FrameCadence? cadence,
  }) {
    if (uiMicros.isEmpty || uiMicros.length != rasterMicros.length) {
      throw ArgumentError('Requires paired nonempty UI and raster samples');
    }
    final ui = List<int>.of(uiMicros)..sort();
    final raster = List<int>.of(rasterMicros)..sort();
    int percentile(List<int> sorted, double factor) =>
        sorted[((sorted.length - 1) * factor).round()];
    var above60 = 0;
    var above120 = 0;
    for (var i = 0; i < uiMicros.length; i++) {
      if (uiMicros[i] > 16667 || rasterMicros[i] > 16667) above60++;
      if (uiMicros[i] > 8333 || rasterMicros[i] > 8333) above120++;
    }
    return FramePerformanceReport(
      frameCount: uiMicros.length,
      uiP50Ms: percentile(ui, .50) / 1000,
      uiP95Ms: percentile(ui, .95) / 1000,
      rasterP50Ms: percentile(raster, .50) / 1000,
      rasterP95Ms: percentile(raster, .95) / 1000,
      over60Budget: above60,
      over120Budget: above120,
      cadence: cadence,
    );
  }
}

/// Diagnostic comparison modes. These do not affect production appearance.
enum ShadowComparisonMode {
  all,
  noCardShadows,
  noArtworkShadow,
  none;

  bool get cardsEnabled =>
      this == ShadowComparisonMode.all ||
      this == ShadowComparisonMode.noArtworkShadow;

  bool get artworkEnabled =>
      this == ShadowComparisonMode.all ||
      this == ShadowComparisonMode.noCardShadows;

  String get label => switch (this) {
    ShadowComparisonMode.all => 'Карточки ВКЛ · Рисунки ВКЛ',
    ShadowComparisonMode.noCardShadows => 'Карточки ВЫКЛ · Рисунки ВКЛ',
    ShadowComparisonMode.noArtworkShadow => 'Карточки ВКЛ · Рисунки ВЫКЛ',
    ShadowComparisonMode.none => 'Карточки ВЫКЛ · Рисунки ВЫКЛ',
  };
}

/// Opt-in metrics only. Ordinary release users incur zero frame callbacks.
///
/// Build with --dart-define=BAYNA_PERF_DIAGNOSTICS=true.
/// These timings are measured build/raster work, NOT a measured display FPS.
abstract final class PerformanceProbe {
  static const enabled =
      bool.fromEnvironment('BAYNA_PERF_DIAGNOSTICS', defaultValue: false);

  static final ValueNotifier<FramePerformanceReport?> lastReport =
      ValueNotifier<FramePerformanceReport?>(null);
  static final ValueNotifier<double?> nativeVsyncHz = ValueNotifier(null);
  static final ValueNotifier<bool> touchResampling = ValueNotifier(false);
  static final ValueNotifier<bool> silhouetteBlurEnabled = ValueNotifier(true);
  static final ValueNotifier<ShadowComparisonMode> shadowComparisonMode =
      ValueNotifier(ShadowComparisonMode.all);

  static const _native = MethodChannel('bayna.scroll_cadence');
  static final _scrollFrames = ScrollFrameSample();
  static WidgetsBinding? _binding;
  static bool _scrolling = false;
  static int _generation = 0;

  static void setShadowMode(ShadowComparisonMode mode) {
    shadowComparisonMode.value = mode;
    silhouetteBlurEnabled.value = mode.artworkEnabled;
    resetSample();
  }

  static void cycleShadowMode() {
    final values = ShadowComparisonMode.values;
    setShadowMode(values[(shadowComparisonMode.value.index + 1) % values.length]);
  }

  static void toggleSilhouetteBlur() => setShadowMode(
    shadowComparisonMode.value == ShadowComparisonMode.all
        ? ShadowComparisonMode.none : ShadowComparisonMode.all,
  );

  static void toggleTouchResampling() {
    final binding = GestureBinding.instance;
    binding.resamplingEnabled = !binding.resamplingEnabled;
    touchResampling.value = binding.resamplingEnabled;
    resetSample();
  }

  static int get _frameTime =>
      _binding?.currentSystemFrameTimeStamp.inMicroseconds ?? 0;

  static void cancelScroll() {
    _scrolling = false;
    resetSample();
  }

  static void resetSample() {
    if (enabled && _binding != null) unawaited(_stopNative(publish: false));
    _generation++;
    _scrollFrames.clear();
    lastReport.value = null;
    nativeVsyncHz.value = null;
    if (enabled && _scrolling && _binding != null) {
      _scrollFrames.begin(_frameTime);
      unawaited(_startNative());
    }
  }

  /// Observe a gesture/fling without consuming notifications or changing it.
  /// Reset on every new scroll; mode changes also invalidate in-flight batches.
  static bool onScrollNotification(ScrollNotification notification) {
    if (!enabled || notification.depth != 0) return false;
    _binding ??= WidgetsBinding.instance;
    if (notification is ScrollStartNotification) {
      _scrolling = true;
      resetSample();
    } else if (notification is ScrollEndNotification && _scrolling) {
      _scrolling = false;
      _scrollFrames.end(_frameTime);
      unawaited(_stopNative());
    }
    return false;
  }

  static Future<void> _startNative() async {
    try {
      await _native.invokeMethod<void>('start', {'session': _generation});
    } on MissingPluginException {
      // Non-Android platforms and widget tests have no native probe.
    } on PlatformException {
      // Optional diagnostics never block a gesture.
    }
  }

  static Future<void> _stopNative({bool publish = true}) async {
    final generation = _generation;
    try {
      final result = await _native.invokeMapMethod<String, dynamic>('stop');
      if (!publish || generation != _generation || result == null ||
          result['session'] != generation) {
        return;
      }
      final hz = (result['hz'] as num?)?.toDouble();
      if (hz != null && hz.isFinite && hz > 0) nativeVsyncHz.value = hz;
    } on MissingPluginException {
      // Optional diagnostics are unavailable in Flutter widget tests.
    } on PlatformException {
      // A disposed Android activity must not fail scrolling.
    }
  }

  static VoidCallback attach(WidgetsBinding binding, Stopwatch sinceMain) {
    if (!enabled) return () {};
    _binding = binding;
    touchResampling.value = GestureBinding.instance.resamplingEnabled;
    binding.waitUntilFirstFrameRasterized.then((_) {
      developer.log(
        'first_flutter_raster_ms=${sinceMain.elapsedMilliseconds}',
        name: 'BaynaPerf',
      );
    });

    void onTimings(List<ui.FrameTiming> timings) {
      if (!_scrollFrames.add(timings) || _scrollFrames.count < 24) return;
      final report = FramePerformanceReport.fromMicros(
        _scrollFrames.uiMicros, _scrollFrames.rasterMicros,
        cadence: _scrollFrames.cadence,
      );
      lastReport.value = report;
      developer.log(
        'scroll_frames=${report.frameCount} '
        'ui_p95_ms=${report.uiP95Ms.toStringAsFixed(2)} '
        'raster_p95_ms=${report.rasterP95Ms.toStringAsFixed(2)} '
        'produced_fps=${report.cadence?.framesPerSecond.toStringAsFixed(1)} '
        'interval_p95_ms=${report.cadence?.intervalP95Ms.toStringAsFixed(2)} '
        'over_120hz_budget=${report.over120Budget}',
        name: 'BaynaPerf',
      );
    }
    binding.addTimingsCallback(onTimings);
    return () {
      binding.removeTimingsCallback(onTimings);
      _scrolling = false;
      _scrollFrames.clear();
      _binding = null;
    };
  }
}
