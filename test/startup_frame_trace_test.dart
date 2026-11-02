import 'package:arabic_academy/ui/startup_frame_trace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('p95 intervals distinguish smooth and half-rate Flutter frames', () {
    final sample = StartupTraceWindow();
    sample.startScroll();
    sample.add(ui: 2400, raster: 4300, vsyncMicros: 100000);
    sample.add(ui: 2800, raster: 5200, vsyncMicros: 108333);
    sample.add(ui: 3100, raster: 6200, vsyncMicros: 125000);
    expect(sample.count, 3);
    expect(sample.uiP95, 3.1);
    expect(sample.rasterP95, 6.2);
    expect(sample.intervalP95, closeTo(16.667, .001));
  });

  test('gaps between scrolls do not count as delayed frames', () {
    final sample = StartupTraceWindow();
    sample.add(ui: 1000, raster: 1000, vsyncMicros: 100);
    sample.add(ui: 1000, raster: 1000, vsyncMicros: 16000);
    sample.endScroll();
    sample.startScroll();
    sample.add(ui: 1000, raster: 1000, vsyncMicros: 900000);
    expect(sample.intervalsMicros, [15900]);
    expect(StartupTraceWindow.p95([]), isNull);
  });
}
