import 'dart:developer' as developer;
import 'dart:ui';

import 'package:flutter/widgets.dart';

/// Opt-in metrics only. Ordinary release users incur zero frame callbacks.
///
/// Launch a profile APK with --dart-define=BAYNA_PERF_DIAGNOSTICS=true.
/// Android "am start -W" includes native work; this probe separately records
/// elapsed time from Dart main() to the first rasterized Flutter frame.
/// Timings are real Flutter UI/raster frame timings, not inferred FPS.
abstract final class PerformanceProbe {
  static const enabled =
      bool.fromEnvironment('BAYNA_PERF_DIAGNOSTICS', defaultValue: false);

  static void attach(WidgetsBinding binding, Stopwatch sinceMain) {
    if (!enabled) return;

    binding.waitUntilFirstFrameRasterized.then((_) {
      developer.log('first_flutter_raster_ms=${sinceMain.elapsedMilliseconds}',
          name: 'BaynaPerf');
    });

    final uiUs = <int>[];
    final rasterUs = <int>[];

    binding.addTimingsCallback((timings) {
      for (final timing in timings) {
        uiUs.add(timing.buildDuration.inMicroseconds);
        rasterUs.add(timing.rasterDuration.inMicroseconds);
      }
      // Emit a bounded rolling report rather than unlimited frame history.
      if (uiUs.length < 120) return;

      final statsUi = _percentiles(uiUs);
      final statsRaster = _percentiles(rasterUs);
      final over60Hz = List.generate(uiUs.length, (i) =>
          uiUs[i] > 16667 || rasterUs[i] > 16667)
          .where((slow) => slow).length;
      final over120Hz = List.generate(uiUs.length, (i) =>
          uiUs[i] > 8333 || rasterUs[i] > 8333)
          .where((slow) => slow).length;
      developer.log(
        'frames=${uiUs.length} '
        'ui_p50_ms=${(statsUi.$1 / 1000).toStringAsFixed(2)} '
        'ui_p95_ms=${(statsUi.$2 / 1000).toStringAsFixed(2)} '
        'raster_p50_ms=${(statsRaster.$1 / 1000).toStringAsFixed(2)} '
        'raster_p95_ms=${(statsRaster.$2 / 1000).toStringAsFixed(2)} '
        'over_60hz_budget=$over60Hz over_120hz_budget=$over120Hz',
        name: 'BaynaPerf',
      );
      uiUs.clear();
      rasterUs.clear();
    });
  }

  static (int, int) _percentiles(List<int> values) {
    values.sort();
    final p50 = ((values.length - 1) * .50).round();
    final p95 = ((values.length - 1) * .95).round();
    return (values[p50], values[p95]);
  }
}
