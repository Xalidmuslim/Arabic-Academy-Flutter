import 'dart:developer' as developer;
import 'package:flutter/widgets.dart';

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
  });

  final int frameCount;
  final double uiP50Ms;
  final double uiP95Ms;
  final double rasterP50Ms;
  final double rasterP95Ms;
  final int over60Budget;
  final int over120Budget;

  static FramePerformanceReport fromMicros(
    List<int> uiMicros,
    List<int> rasterMicros,
  ) {
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
    );
  }
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

  /// Temporarily compare the cost of the silhouette Gaussian blur.
  /// Enabled by default. The app's normal appearance is unchanged.
  static final ValueNotifier<bool> silhouetteBlurEnabled =
      ValueNotifier<bool>(true);

  static int _sampleVersion = 0;
  static void toggleSilhouetteBlur() {
    silhouetteBlurEnabled.value = !silhouetteBlurEnabled.value;
    _sampleVersion++;
    lastReport.value = null;
  }

  static void attach(WidgetsBinding binding, Stopwatch sinceMain) {
    if (!enabled) return;
    binding.waitUntilFirstFrameRasterized.then((_) {
      developer.log(
        'first_flutter_raster_ms=${sinceMain.elapsedMilliseconds}',
        name: 'BaynaPerf',
      );
    });

    final uiUs = <int>[];
    final rasterUs = <int>[];
    var observedVersion = _sampleVersion;
    binding.addTimingsCallback((timings) {
      if (observedVersion != _sampleVersion) {
        uiUs.clear();
        rasterUs.clear();
        observedVersion = _sampleVersion;
      }
      for (final timing in timings) {
        uiUs.add(timing.buildDuration.inMicroseconds);
        rasterUs.add(timing.rasterDuration.inMicroseconds);
      }
      if (uiUs.length < 120) return;
      final report = FramePerformanceReport.fromMicros(uiUs, rasterUs);
      lastReport.value = report;
      developer.log(
        'frames=${report.frameCount} '
        'ui_p50_ms=${report.uiP50Ms.toStringAsFixed(2)} '
        'ui_p95_ms=${report.uiP95Ms.toStringAsFixed(2)} '
        'raster_p50_ms=${report.rasterP50Ms.toStringAsFixed(2)} '
        'raster_p95_ms=${report.rasterP95Ms.toStringAsFixed(2)} '
        'over_60hz_budget=${report.over60Budget} '
        'over_120hz_budget=${report.over120Budget}',
        name: 'BaynaPerf',
      );
      uiUs.clear();
      rasterUs.clear();
    });
  }
}
