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
