import 'package:bayna_dictionary/ui/frame_performance_monitor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('120Hz uses an 8.33ms budget, reports slow pipeline phases', () {
    final report = summarizeFrameCosts(const [
      FrameCost(buildMicros: 3000, rasterMicros: 4000),
      FrameCost(buildMicros: 6000, rasterMicros: 7000),
      FrameCost(buildMicros: 10000, rasterMicros: 7000),
      FrameCost(buildMicros: 5000, rasterMicros: 13000),
    ], 120);
    expect(report.samples, 4);
    expect(report.displayHz, 120);
    expect(report.frameBudgetMs, closeTo(8.3333, .01));
    expect(report.uiP95Ms, 10);
    expect(report.rasterP95Ms, 13);
    expect(report.overBudgetPercent, 50);
  });

  test('fallback and empty sample window do not pretend to measure FPS', () {
    final report = summarizeFrameCosts(const [], 0);
    expect(report.displayHz, 60);
    expect(report.samples, 0);
    expect(report.overBudgetPercent, 0);
    expect(report.frameBudgetMs, closeTo(16.6667, .01));
  });

  test('pipeline phases both must be inside the screen refresh budget', () {
    final report = summarizeFrameCosts(const [
      FrameCost(buildMicros: 10000, rasterMicros: 12000),
      FrameCost(buildMicros: 13000, rasterMicros: 4000),
    ], 60);
    expect(report.overBudgetPercent, 0);
    expect(report.samples, 2);
  });
  test('120Hz stream with an 8.33ms vsync gap reports near 120 Flutter frames per second', () {
    final report = summarizeFrameCosts(const [
      FrameCost(buildMicros: 2000, rasterMicros: 3000, vsyncMicros: 100000),
      FrameCost(buildMicros: 2000, rasterMicros: 3000, vsyncMicros: 108333),
      FrameCost(buildMicros: 2000, rasterMicros: 3000, vsyncMicros: 116667),
      FrameCost(buildMicros: 2000, rasterMicros: 3000, vsyncMicros: 125000),
    ], 120);
    expect(report.cadenceIntervals, 3);
    expect(report.cadenceFps, closeTo(120, 0.2));
    expect(report.cadenceP95Ms, closeTo(8.334, 0.01));
    expect(report.longGapPercent, 0);
  });

  test('120Hz display with a steady 16.67ms Flutter cadence reveals 60fps', () {
    final report = summarizeFrameCosts(const [
      FrameCost(buildMicros: 3000, rasterMicros: 4000, vsyncMicros: 100000),
      FrameCost(buildMicros: 3000, rasterMicros: 4000, vsyncMicros: 116667),
      FrameCost(buildMicros: 3000, rasterMicros: 4000, vsyncMicros: 133334),
      FrameCost(buildMicros: 3000, rasterMicros: 4000, vsyncMicros: 150001),
    ], 120);
    expect(report.overBudgetPercent, 0);
    expect(report.cadenceFps, closeTo(60, 0.2));
    expect(report.cadenceP95Ms, closeTo(16.667, 0.01));
    expect(report.longGapPercent, 100);
  });

  test('an idle gap is excluded so a short pause does not fabricate low FPS', () {
    final report = summarizeFrameCosts(const [
      FrameCost(buildMicros: 1000, rasterMicros: 1000, vsyncMicros: 0),
      FrameCost(buildMicros: 1000, rasterMicros: 1000, vsyncMicros: 8333),
      FrameCost(buildMicros: 1000, rasterMicros: 1000, vsyncMicros: 500000),
      FrameCost(buildMicros: 1000, rasterMicros: 1000, vsyncMicros: 508333),
    ], 120);
    expect(report.cadenceIntervals, 2);
    expect(report.cadenceFps, closeTo(120, .2));
    expect(report.longGapPercent, 0);
  });

  test('no timestamps and duplicate timestamps never pretend to measure fps', () {
    final empty = summarizeFrameCosts(const [
      FrameCost(buildMicros: 1000, rasterMicros: 1000),
    ], 120);
    expect(empty.cadenceIntervals, 0);
    expect(empty.cadenceFps, isNull);
    final repeated = summarizeFrameCosts(const [
      FrameCost(buildMicros: 1000, rasterMicros: 1000, vsyncMicros: 100000),
      FrameCost(buildMicros: 1000, rasterMicros: 1000, vsyncMicros: 100000),
    ], 120);
    expect(repeated.cadenceIntervals, 0);
    expect(repeated.cadenceFps, isNull);
  });

  test('report gate cannot invalidate overlay on every received frame batch', () {
    final gate = FrameReportGate(const Duration(milliseconds: 1500));
    final start = DateTime.utc(2026, 11, 2);
    expect(gate.shouldPublish(start), isTrue);
    expect(gate.shouldPublish(start.add(const Duration(milliseconds: 100))), isFalse);
    expect(gate.shouldPublish(start.add(const Duration(milliseconds: 1499))), isFalse);
    expect(gate.shouldPublish(start.add(const Duration(milliseconds: 1500))), isTrue);
    gate.reset();
    expect(gate.shouldPublish(start.add(const Duration(milliseconds: 1700))), isTrue);
  });

  testWidgets('frame diagnostics sample only while a list is scrolling',
      (tester) async {
    final monitor = FramePerformanceMonitor();
    addTearDown(monitor.dispose);
    monitor.start();
    expect(monitor.isSampling, isFalse);
    monitor.setScrolling(true);
    expect(monitor.isSampling, isTrue);
    monitor.setScrolling(false);
    expect(monitor.isSampling, isFalse);
    expect(monitor.value.samples, 0);
    monitor.stop();
    expect(monitor.isSampling, isFalse);
  });

}
