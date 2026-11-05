import 'dart:collection';
import 'dart:ui' as ui;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Build and raster times are measured by the Flutter engine. The display
/// refresh rate is reported by Android to the Flutter view, not a forced FPS.
@immutable
class FrameCost {
  const FrameCost({
    required this.buildMicros,
    required this.rasterMicros,
    this.vsyncMicros,
  });
  final int buildMicros;
  final int rasterMicros;
  /// Raw Flutter frame-vsync timestamp; does not indicate Android presentation.
  final int? vsyncMicros;
}

@immutable
class FramePerformanceReport {
  const FramePerformanceReport({
    required this.displayHz,
    required this.samples,
    required this.uiP95Ms,
    required this.rasterP95Ms,
    required this.overBudgetPercent,
    this.cadenceFps,
    this.cadenceP95Ms,
    this.longGapPercent,
    this.cadenceIntervals = 0,
  });
  final double displayHz;
  final int samples;
  final double uiP95Ms;
  final double rasterP95Ms;
  final double overBudgetPercent;
  /// Average Flutter-produced frame spacing during continuous scrolling.
  /// This is NOT measured SurfaceFlinger presentation FPS.
  final double? cadenceFps;
  final double? cadenceP95Ms;
  /// Percentage of Flutter frame-vsync gaps exceeding 1.5 display periods.
  final double? longGapPercent;
  final int cadenceIntervals;

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

  // Frame build and raster costs can both be low when the engine only
  // produces a frame every *other* 120Hz vsync. Compare consecutive
  // Flutter vsync timestamps independently of build/raster costs.
  final gaps = <int>[];
  int? previousVsync;
  var longGaps = 0;
  var totalGapMicros = 0;
  for (final sample in data) {
    final vsync = sample.vsyncMicros;
    if (vsync == null) continue;
    if (previousVsync != null) {
      final gap = vsync - previousVsync;
      // Ignore duplicate/non-monotonic stamps and long idle pauses.
      // Long stalls beyond this limit are not silently classified as FPS.
      if (gap > 0 && gap <= 100000) {
        gaps.add(gap);
        totalGapMicros += gap;
        if (gap > 1.5 * budgetUs) longGaps++;
      }
    }
    previousVsync = vsync;
  }
  gaps.sort();
  final hasCadence = gaps.isNotEmpty && totalGapMicros > 0;
  final cadenceFps = hasCadence
      ? gaps.length * 1000000.0 / totalGapMicros : null;
  final cadenceP95Ms = hasCadence
      ? gaps[(gaps.length * .95).ceil() - 1] / 1000 : null;
  final longGapPercent = hasCadence
      ? longGaps * 100.0 / gaps.length : null;
  return FramePerformanceReport(
    displayHz: hz,
    samples: data.length,
    uiP95Ms: ui[index] / 1000,
    rasterP95Ms: gpu[index] / 1000,
    overBudgetPercent: 100 * over / data.length,
    cadenceFps: cadenceFps,
    cadenceP95Ms: cadenceP95Ms,
    longGapPercent: longGapPercent,
    cadenceIntervals: gaps.length,
  );
}

/// Rate-limits the diagnostic widget's own invalidations. Without this,
/// instrumenting the renderer can itself cause repeated rendering work.
class FrameReportGate {
  FrameReportGate(this.interval);
  final Duration interval;
  DateTime? _lastPublication;

  bool shouldPublish(DateTime now) {
    final last = _lastPublication;
    if (last != null) {
      final elapsed = now.difference(last);
      if (!elapsed.isNegative && elapsed < interval) return false;
    }
    _lastPublication = now;
    return true;
  }

  void reset() => _lastPublication = null;
}

/// Opt-in observer. In release mode no callback is installed until the
/// user starts scrolling with diagnostics enabled. Overlay updates are
/// throttled to avoid generating frames just to measure those frames.
class FramePerformanceMonitor extends ValueNotifier<FramePerformanceReport> {
  FramePerformanceMonitor()
      : super(summarizeFrameCosts(const <FrameCost>[], 60));

  final Queue<FrameCost> _window = Queue<FrameCost>();
  final FrameReportGate _reportGate =
      FrameReportGate(const Duration(milliseconds: 1500));
  bool _active = false;
  bool _sampling = false;
  static const _maxFrames = 180;

  bool get isSampling => _sampling;

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
    _reportGate.reset();
    value = summarizeFrameCosts(_window, displayHz);
    // No callback until the list actually moves.
  }

  void setScrolling(bool scrolling) {
    if (!_active || _sampling == scrolling) return;
    _sampling = scrolling;
    if (scrolling) {
      SchedulerBinding.instance.addTimingsCallback(_onTimings);
    } else {
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
      // Publish the final scrolling window once, while sampling is OFF.
      // That paint cannot recursively feed another measurement.
      if (_window.isNotEmpty) {
        value = summarizeFrameCosts(_window, displayHz);
      }
    }
  }

  void stop() {
    if (!_active) return;
    setScrolling(false);
    _active = false;
    _window.clear();
    _reportGate.reset();
    value = summarizeFrameCosts(_window, displayHz);
  }

  void _onTimings(List<FrameTiming> frames) {
    if (!_sampling || frames.isEmpty) return;
    for (final frame in frames) {
      _window.add(FrameCost(
        buildMicros: frame.buildDuration.inMicroseconds,
        rasterMicros: frame.rasterDuration.inMicroseconds,
        vsyncMicros: frame.timestampInMicroseconds(ui.FramePhase.vsyncStart),
      ));
      if (_window.length > _maxFrames) _window.removeFirst();
    }
    // At most one panel refresh per 1.5 s during active scrolling.
    if (_reportGate.shouldPublish(DateTime.now())) {
      value = summarizeFrameCosts(_window, displayHz);
    }
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
