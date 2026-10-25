import 'dart:ui' as ui;

import 'package:arabic_academy/core/performance_probe.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('scroll report distinguishes fast work from 60 Hz frame cadence',
      (tester) async {
    if (!PerformanceProbe.enabled) return;
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
    final binding = tester.binding;
    final detach = PerformanceProbe.attach(binding, Stopwatch()..start());
    addTearDown(detach);
    const channel = MethodChannel('bayna.scroll_cadence');
    var session = 0;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'start') {
        session = (call.arguments as Map)['session'] as int;
        return null;
      }
      return {'session': session, 'hz': 60.0};
    });
    addTearDown(() =>
        binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
    final context = tester.element(find.byType(SizedBox).first);
    final metrics = FixedScrollMetrics(
      minScrollExtent: 0, maxScrollExtent: 2000, pixels: 100,
      viewportDimension: 600, axisDirection: AxisDirection.down,
      devicePixelRatio: 1,
    );
    expect(PerformanceProbe.onScrollNotification(
      ScrollStartNotification(metrics: metrics, context: context),
    ), isFalse, reason: 'diagnostics must not consume scroll notifications');
    final cutoff = binding.currentSystemFrameTimeStamp.inMicroseconds;
    binding.platformDispatcher.onReportTimings!([
      for (var i = 1; i <= 60; i++)
        ui.FrameTiming(
          vsyncStart: cutoff + i * 16667,
          buildStart: cutoff + i * 16667,
          buildFinish: cutoff + i * 16667 + 2000,
          rasterStart: cutoff + i * 16667 + 2000,
          rasterFinish: cutoff + i * 16667 + 5000,
          rasterFinishWallTime: cutoff + i * 16667 + 5000,
        ),
    ]);
    final report = PerformanceProbe.lastReport.value!;
    expect(report.uiP95Ms, 2);
    expect(report.rasterP95Ms, 3);
    expect(report.cadence!.framesPerSecond, closeTo(60, .01));
    await tester.pump(const Duration(seconds: 2));
    PerformanceProbe.onScrollNotification(
      ScrollEndNotification(metrics: metrics, context: context),
    );
    await tester.pump();
    expect(PerformanceProbe.nativeVsyncHz.value, 60);
  });

  testWidgets('late pre-toggle timings never become the new mode report',
      (tester) async {
    if (!PerformanceProbe.enabled) return;
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
    final binding = tester.binding;
    final detach = PerformanceProbe.attach(binding, Stopwatch()..start());
    addTearDown(detach);
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
