import 'dart:ui' as ui;

import 'package:arabic_academy/core/performance_probe.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('late pre-toggle timings never become the new mode report',
      (tester) async {
    if (!PerformanceProbe.enabled) return;
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
    final binding = tester.binding;
    final before = binding.platformDispatcher.onReportTimings;
    addTearDown(() => binding.platformDispatcher.onReportTimings = before);
    PerformanceProbe.attach(binding, Stopwatch()..start());
    PerformanceProbe.setShadowMode(ShadowComparisonMode.noCardShadows);
    addTearDown(() => PerformanceProbe.setShadowMode(ShadowComparisonMode.all));
    final cutoff = binding.currentSystemFrameTimeStamp.inMicroseconds;
    // Release timing callbacks arrive in batches after the frames were drawn.
    // All these expensive frames belong to the previous mode or route.
    binding.platformDispatcher.onReportTimings!([
      for (var i = 0; i < 120; i++)
        ui.FrameTiming(
          vsyncStart: cutoff - 4000000 + i * 20000,
          buildStart: cutoff - 4000000 + i * 20000,
          buildFinish: cutoff - 4000000 + i * 20000 + 2000,
          rasterStart: cutoff - 4000000 + i * 20000 + 2000,
          rasterFinish: cutoff - 4000000 + i * 20000 + 32000,
          rasterFinishWallTime: cutoff - 4000000 + i * 20000 + 32000,
        ),
    ]);
    expect(PerformanceProbe.lastReport.value, isNull,
        reason: 'old raster work must not be labelled as the new shadow mode');
  });
}
