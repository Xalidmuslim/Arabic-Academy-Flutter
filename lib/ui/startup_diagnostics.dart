import 'dart:ui' as ui;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Pure bounded sample. Frame callbacks only append numbers.
class StartupTimingBucket {
  final List<int> _build = <int>[];
  final List<int> _raster = <int>[];
  final List<int> _intervals = <int>[];
  int? _previousVsync;
  static const maxFrames = 1200;

  int get count => _build.length;

  void record({
    required int buildMicros,
    required int rasterMicros,
    required int vsyncMicros,
  }) {
    if (_build.length >= maxFrames) return;
    _build.add(buildMicros);
    _raster.add(rasterMicros);
    final previous = _previousVsync;
    if (previous != null && vsyncMicros > previous) {
      final gap = vsyncMicros - previous;
      // Idle time between gestures is not a slow rendered frame.
      if (gap <= 100000) _intervals.add(gap);
    }
    _previousVsync = vsyncMicros;
  }

  static double? p95(List<int> values) {
    if (values.isEmpty) return null;
    final sorted = List<int>.of(values)..sort();
    return sorted[(sorted.length * .95).ceil() - 1] / 1000;
  }

  double? get buildP95 => p95(_build);
  double? get rasterP95 => p95(_raster);
  double? get intervalP95 => p95(_intervals);
  int get intervals => _intervals.length;

  String get summary {
    String fmt(double? v) => v == null ? '—' : v.toStringAsFixed(2);
    return 'n=$count, UI=${fmt(buildP95)}ms, '
        'raster=${fmt(rasterP95)}ms, cadence=${fmt(intervalP95)}ms, '
        'intervals=$intervals';
  }
}

/// No widget, overlay, scroll listener or periodic timer is installed.
/// Samples the first 20s of cold start and the first 20s after a pause/resume.
/// Captures Flutter-produced frames, NOT Android presented FPS.
class StartupFrameDiagnostics with WidgetsBindingObserver {
  StartupFrameDiagnostics._();

  static const enabled = bool.fromEnvironment(
    'BAYNA_STARTUP_TRACE', defaultValue: false);
  static final StartupFrameDiagnostics instance = StartupFrameDiagnostics._();

  final Stopwatch _startupClock = Stopwatch();
  final List<StartupTimingBucket> _startup =
      List.generate(3, (_) => StartupTimingBucket());
  final List<StartupTimingBucket> _afterResume =
      List.generate(3, (_) => StartupTimingBucket());
  final List<String> _events = [];
  Stopwatch? _resumeClock;
  bool _wasPaused = false;
  bool _foreground = true;
  bool _initialized = false;
  double _screenHzAtStart = 0;

  void initialize() {
    if (!enabled || _initialized) return;
    _initialized = true;
    _startupClock.start();
    final displays = WidgetsBinding.instance.platformDispatcher.displays;
    _screenHzAtStart = displays.isEmpty ? 0 : displays.first.refreshRate;
    WidgetsBinding.instance.addObserver(this);
    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_initialized) return;
    final at = _startupClock.elapsedMilliseconds;
    if (_events.length < 20) _events.add('${at}ms: ${state.name}');
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wasPaused = true;
      _foreground = false;
    } else if (state == AppLifecycleState.resumed) {
      _foreground = true;
      if (_wasPaused) {
        _wasPaused = false;
        _resumeClock = Stopwatch()..start();
        for (var i = 0; i < _afterResume.length; i++) {
          _afterResume[i] = StartupTimingBucket();
        }
      }
    }
  }

  void _onFrameTimings(List<ui.FrameTiming> frames) {
    if (!_foreground || frames.isEmpty) return;
    final clock = _resumeClock ?? _startupClock;
    final millis = clock.elapsedMilliseconds;
    if (millis >= 20000) return;
    final buckets = _resumeClock == null ? _startup : _afterResume;
    final index = millis < 5000 ? 0 : (millis < 10000 ? 1 : 2);
    final bucket = buckets[index];
    for (final timing in frames) {
      bucket.record(
        buildMicros: timing.buildDuration.inMicroseconds,
        rasterMicros: timing.rasterDuration.inMicroseconds,
        vsyncMicros:
            timing.timestampInMicroseconds(ui.FramePhase.vsyncStart),
      );
    }
    // Deliberately no setState, sort, I/O, timer or logging here.
  }

  String report({String app = 'Байна Ядайк'}) {
    final displays = WidgetsBinding.instance.platformDispatcher.displays;
    final currentHz = displays.isEmpty ? 0 : displays.first.refreshRate;
    final lines = <String>[
      'Startup vs resume · $app',
      'Screen initial=${_screenHzAtStart.toStringAsFixed(1)}Hz, '
          'current=${currentHz.toStringAsFixed(1)}Hz',
      'Flutter-produced timing, NOT Android presented FPS',
      'Cold start 0-5s: ${_startup[0].summary}',
      'Cold start 5-10s: ${_startup[1].summary}',
      'Cold start 10-20s: ${_startup[2].summary}',
      'After resume 0-5s: ${_afterResume[0].summary}',
      'After resume 5-10s: ${_afterResume[1].summary}',
      'After resume 10-20s: ${_afterResume[2].summary}',
      'Lifecycle: ${_events.isEmpty ? 'none' : _events.join(', ')}',
    ];
    return lines.join('\n');
  }
}
