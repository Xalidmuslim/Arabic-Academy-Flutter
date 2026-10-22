import 'package:arabic_academy/core/performance_probe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('frame diagnostic computes UI and raster p95 independently', () {
    final report = FramePerformanceReport.fromMicros(
      [for (var i = 0; i < 19; i++) 4000, 19000],
      [for (var i = 0; i < 19; i++) 12000, 25000],
    );
    expect(report.frameCount, 20);
    expect(report.uiP95Ms, 4);
    expect(report.rasterP95Ms, 12);
    expect(report.over120Budget, 20,
      reason: 'raster can miss 120 Hz even if the UI thread is fast');
    expect(report.over60Budget, 1);
  });

  test('frame diagnostic retains sample and never mutates its inputs', () {
    final ui = [14000, 1000, 9000];
    final raster = [2000, 3000, 4000];
    final report = FramePerformanceReport.fromMicros(ui, raster);
    expect(report.frameCount, 3);
    expect(report.uiP95Ms, 14);
    expect(report.rasterP95Ms, 4);
    expect(ui, [14000, 1000, 9000]);
    expect(raster, [2000, 3000, 4000]);
  });
}
