import 'package:flutter_test/flutter_test.dart';
import 'package:bayna_dictionary/ui/startup_diagnostics.dart';

void main() {
  test('frame callback stores samples but does not compute p95 until requested', () {
    final sample = StartupTimingBucket();
    sample.record(buildMicros: 2000, rasterMicros: 4200, vsyncMicros: 100000);
    sample.record(buildMicros: 2300, rasterMicros: 4900, vsyncMicros: 108333);
    sample.record(buildMicros: 3000, rasterMicros: 5100, vsyncMicros: 125000);
    expect(sample.count, 3);
    expect(sample.buildP95, 3);
    expect(sample.rasterP95, 5.1);
    expect(sample.intervalP95, closeTo(16.667, 0.001));
    expect(sample.intervals, 2);
  });

  test('no samples are not reported as measured FPS', () {
    final sample = StartupTimingBucket();
    expect(sample.count, 0);
    expect(sample.buildP95, isNull);
    expect(sample.intervalP95, isNull);
    expect(sample.summary, contains('cadence=—'));
  });

  test('idle gaps and repeated timestamps are not counted as dropped frames', () {
    final sample = StartupTimingBucket();
    sample.record(buildMicros: 1000, rasterMicros: 1000, vsyncMicros: 100);
    sample.record(buildMicros: 1000, rasterMicros: 1000, vsyncMicros: 100);
    sample.record(buildMicros: 1000, rasterMicros: 1000, vsyncMicros: 300000);
    expect(sample.intervals, 0);
    sample.record(buildMicros: 1000, rasterMicros: 1000, vsyncMicros: 308333);
    expect(sample.intervals, 1);
    expect(sample.intervalP95, closeTo(8.333, 0.001));
  });
}
