import 'dart:ui' as ui;

import 'package:arabic_academy/core/scroll_frame_sample.dart';
import 'package:flutter_test/flutter_test.dart';

ui.FrameTiming frame(int time, {int raster = 3000}) => ui.FrameTiming(
  vsyncStart: time, buildStart: time, buildFinish: time + 2000,
  rasterStart: time + 2000, rasterFinish: time + 2000 + raster,
  rasterFinishWallTime: time + 2000 + raster,
);

void main() {
  test('fast raster work can still produce only 60 frames per second', () {
    final sample = ScrollFrameSample()..begin(0);
    sample.add([for (var i = 1; i <= 121; i++) frame(i * 16667)]);
    expect(sample.rasterMicros.every((value) => value == 3000), isTrue);
    expect(sample.cadence!.framesPerSecond, closeTo(60, .01));
    expect(sample.cadence!.intervalP50Ms, closeTo(16.667, .001));
  });

  test('120 Hz cadence is measured from frame starts, not drawing duration', () {
    final sample = ScrollFrameSample()..begin(0);
    sample.add([for (var i = 1; i <= 121; i++) frame(i * 8333)]);
    expect(sample.cadence!.framesPerSecond, closeTo(120, .01));
    expect(sample.cadence!.intervalP95Ms, closeTo(8.333, .001));
  });

  test('late batch includes only frames inside the scroll window', () {
    final sample = ScrollFrameSample()..begin(100000);
    sample.end(150000);
    sample.add([frame(80000, raster: 90000), frame(110000),
      frame(120000), frame(150000), frame(160000, raster: 90000)]);
    expect(sample.count, 3);
    expect(sample.rasterMicros, everyElement(3000));
    sample.add([frame(110000)]);
    expect(sample.count, 3, reason: 'replayed timings must not be counted twice');
  });

  test('new scroll or input mode discards old reports and idle gaps', () {
    final sample = ScrollFrameSample()..begin(0);
    sample.add([frame(10000), frame(20000)]);
    sample.begin(2000000);
    sample.add([frame(30000, raster: 90000), frame(2010000), frame(2020000)]);
    expect(sample.count, 2);
    expect(sample.cadence!.framesPerSecond, 100);
    expect(sample.rasterMicros, everyElement(3000));
    sample.clear();
    expect(sample.add([frame(2030000)]), isFalse);
    expect(sample.cadence, isNull);
  });

  test('long scroll keeps bounded recent history including real long gaps', () {
    final sample = ScrollFrameSample()..begin(0);
    sample.add([for (var i = 1; i <= 1000; i++) frame(i * 10000)]);
    expect(sample.count, ScrollFrameSample.capacity);
    expect(FrameCadence.fromStartMicros([0, 10000, 110000])!
        .intervalP95Ms, 100);
  });
}
