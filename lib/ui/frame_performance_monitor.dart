import 'dart:collection';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Build and raster times are measured by the Flutter engine. The display
/// refresh rate is reported by Android to the Flutter view, not a forced FPS.
@immutable
class FrameCost {
  const FrameCost({required this.buildMicros, required this.rasterMicros});
  final int buildMicros;
  final int rasterMicros;
}

@immutable
class FramePerformanceReport {
  const FramePerformanceReport({
    required this.displayHz,
    required this.samples,
    required this.uiP95Ms,
    required this.rasterP95Ms,
    required this.overBudgetPercent,
  });
  final double displayHz;
  final int samples;
  final double uiP95Ms;
  final double rasterP95Ms;
  final double overBudgetPercent;

  double get frameBudgetMs => 1000 / displayHz;
}

/// Pure function, independently unit-testable without a connected handset.
/// Slow means at least one pipeline phase exceeded one refresh interval.
FramePerformanceReport summarizeFrameCosts(
    Iterable<FrameCost> costs, double displayHz) {
  final hz = displayHz.isFinite && displayHz > 0 ? displayHz : 60.0;
  final data = costs.toList(growable: false);
  if (data.isEmpty) {
    return FramePerformanceReport(
      displayHz: hz, samples: 0, uiP95Ms: 0,
      rasterP95Ms: 0, overBudgetPercent: 0);
  }
  final ui = data.map((s) => s.buildMicros).toList()..sort();
  final gpu = data.map((s) => s.rasterMicros).toList()..sort();
  final index = (data.length * .95).ceil() - 1;
  final budgetUs = 1000000 / hz;
  final over = data.where((s) =>
      s.buildMicros > budgetUs || s.rasterMicros > budgetUs).length;
  return FramePerformanceReport(
    displayHz: hz,
    samples: data.length,
    uiP95Ms: ui[index] / 1000,
    rasterP95Ms: gpu[index] / 1000,
    overBudgetPercent: 100 * over / data.length,
  );
}

/// Opt-in observer. Release builds otherwise run with no timing callback.
/// Frame timings are batched by Flutter, so this never updates per paint.
class FramePerformanceMonitor extends ValueNotifier<FramePerformanceReport> {
  FramePerformanceMonitor()
      : super(summarizeFrameCosts(const <FrameCost>[], 60));

  final Queue<FrameCost> _window = Queue<FrameCost>();
  bool _active = false;
  static const _maxFrames = 180;

  double get displayHz {
    final displays = WidgetsBinding.instance.platformDispatcher.displays;
    if (displays.isEmpty) return 60;
    final rate = displays.first.refreshRate;
    return rate.isFinite && rate > 0 ? rate : 60;
  }

  void start() {
    if (_active) return;
    _active = true;
    _window.clear();
    value = summarizeFrameCosts(_window, displayHz);
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void stop() {
    if (!_active) return;
    _active = false;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _window.clear();
    value = summarizeFrameCosts(_window, displayHz);
  }

  void _onTimings(List<FrameTiming> frames) {
    if (!_active) return;
    for (final frame in frames) {
      _window.add(FrameCost(
        buildMicros: frame.buildDuration.inMicroseconds,
        rasterMicros: frame.rasterDuration.inMicroseconds,
      ));
      if (_window.length > _maxFrames) _window.removeFirst();
    }
    if (frames.isNotEmpty) {
      value = summarizeFrameCosts(_window, displayHz);
    }
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
