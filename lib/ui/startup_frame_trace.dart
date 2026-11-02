import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Diagnostic only. Measures Flutter frame work and production intervals,
/// not Android compositor presentation or guaranteed screen FPS.
class StartupTraceWindow {
  static const int maxSamples = 720;
  final List<int> uiMicros = [];
  final List<int> rasterMicros = [];
  final List<int> intervalsMicros = [];
  int? _lastVsync;

  int get count => uiMicros.length;
  void endScroll() => _lastVsync = null;
  void startScroll() => _lastVsync = null;

  void add({required int ui, required int raster, required int vsyncMicros}) {
    if (count >= maxSamples) {
      uiMicros.removeAt(0);
      rasterMicros.removeAt(0);
    }
    uiMicros.add(ui);
    rasterMicros.add(raster);
    final previous = _lastVsync;
    if (previous != null && vsyncMicros > previous) {
      final delta = vsyncMicros - previous;
      // Don't confuse a pause between gestures with a missed frame.
      if (delta <= 100000) {
        if (intervalsMicros.length >= maxSamples) intervalsMicros.removeAt(0);
        intervalsMicros.add(delta);
      }
    }
    _lastVsync = vsyncMicros;
  }

  static double? p95(List<int> values) {
    if (values.isEmpty) return null;
    final sorted = List<int>.of(values)..sort();
    return sorted[(sorted.length * 0.95).ceil() - 1] / 1000;
  }

  double? get uiP95 => p95(uiMicros);
  double? get rasterP95 => p95(rasterMicros);
  double? get intervalP95 => p95(intervalsMicros);
}

const startupTraceEnabled =
    bool.fromEnvironment('BAYNA_STARTUP_TRACE', defaultValue: false);

/// Compares time windows during cold start with those after the first
/// background/foreground cycle. No work is scheduled per measured frame.
class StartupFrameTrace extends StatefulWidget {
  const StartupFrameTrace({super.key, required this.child});
  final Widget child;

  @override
  State<StartupFrameTrace> createState() => _StartupFrameTraceState();
}

class _StartupFrameTraceState extends State<StartupFrameTrace>
    with WidgetsBindingObserver {
  final Stopwatch _coldClock = Stopwatch()..start();
  final List<StartupTraceWindow> _cold = [
    StartupTraceWindow(), StartupTraceWindow(),
  ];
  final List<StartupTraceWindow> _resume = [
    StartupTraceWindow(), StartupTraceWindow(),
  ];
  Stopwatch? _resumeClock;
  Timer? _timer;
  bool _backgrounded = false;
  bool _foreground = true;
  bool _scrolling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _scheduleUi();
  }

  void _scheduleUi() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) return;
      setState(() {}); // Only once every 2 sec, never in a frame callback.
      if ((_resumeClock ?? _coldClock).elapsedMilliseconds >= 12000) {
        timer.cancel();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _backgrounded = true;
      _foreground = false;
      _scrolling = false;
      for (final bucket in [..._cold, ..._resume]) {
        bucket.endScroll();
      }
    } else if (state == AppLifecycleState.resumed && _backgrounded) {
      _foreground = true;
      _scrolling = false;
      _resumeClock = Stopwatch()..start();
      _resume[0] = StartupTraceWindow();
      _resume[1] = StartupTraceWindow();
      _scheduleUi();
      if (mounted) setState(() {});
    }
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is ScrollStartNotification) {
      _scrolling = true;
      for (final bucket in [..._cold, ..._resume]) {
        bucket.startScroll();
      }
    } else if (notification is ScrollEndNotification) {
      _scrolling = false;
      for (final bucket in [..._cold, ..._resume]) {
        bucket.endScroll();
      }
    }
    return false;
  }

  void _onTimings(List<FrameTiming> timings) {
    if (!_foreground || !_scrolling || timings.isEmpty) return;
    final elapsed = (_resumeClock ?? _coldClock).elapsedMilliseconds;
    if (elapsed >= 10000) return;
    final buckets = _resumeClock == null ? _cold : _resume;
    final target = buckets[elapsed < 5000 ? 0 : 1];
    for (final frame in timings) {
      target.add(
        ui: frame.buildDuration.inMicroseconds,
        raster: frame.rasterDuration.inMicroseconds,
        vsyncMicros: frame.timestampInMicroseconds(FramePhase.vsyncStart),
      );
    }
    // Do not paint or sort any timings inside this callback.
  }

  String _summary(String title, StartupTraceWindow bucket) {
    if (bucket.count == 0) return title + ': нет кадров прокрутки';
    String fmt(double? value) => value?.toStringAsFixed(1) ?? '—';
    return title + ': ' + bucket.count.toString() + ' к · UI ' +
        fmt(bucket.uiP95) + ' · R ' + fmt(bucket.rasterP95) +
        ' · Δ ' + fmt(bucket.intervalP95) + ' мс';
  }

  @override
  Widget build(BuildContext context) {
    final displays = WidgetsBinding.instance.platformDispatcher.displays;
    final hz = displays.isEmpty ? 0.0 : displays.first.refreshRate;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(fit: StackFit.expand, children: [
        NotificationListener<ScrollNotification>(
          onNotification: _onScroll, child: widget.child,
        ),
        Positioned(
          left: 8, right: 8, top: 4,
          child: SafeArea(child: IgnorePointer(child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xE91D2A27),
              borderRadius: BorderRadius.circular(9)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              child: Text(
                'СТАРТ/ВОЗВРАТ · экран ' + hz.toStringAsFixed(0) + ' Гц\n' +
                _summary('Запуск 0–5', _cold[0]) + '\n' +
                _summary('Запуск 5–10', _cold[1]) + '\n' +
                _summary('Возврат 0–5', _resume[0]) + '\n' +
                _summary('Возврат 5–10', _resume[1]) + '\n' +
                'Δ = интервал кадров Flutter (p95), не FPS дисплея',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white, fontSize: 10.5, height: 1.2,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none),
              ),
            ),
          ))),
        ),
      ]),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
