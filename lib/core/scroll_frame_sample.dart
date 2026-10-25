import 'dart:ui' as ui;

/// Cadence of produced Flutter frames, not display Hz or presentation FPS.
class FrameCadence {
  const FrameCadence({
    required this.framesPerSecond,
    required this.intervalP50Ms,
    required this.intervalP95Ms,
  });

  final double framesPerSecond;
  final double intervalP50Ms;
  final double intervalP95Ms;

  static FrameCadence? fromStartMicros(List<int> starts) {
    final intervals = <int>[];
    for (var i = 1; i < starts.length; i++) {
      final delta = starts[i] - starts[i - 1];
      if (delta > 0) intervals.add(delta);
    }
    if (intervals.isEmpty) return null;
    final duration = intervals.fold<int>(0, (sum, value) => sum + value);
    intervals.sort();
    double percentile(double fraction) =>
        intervals[((intervals.length - 1) * fraction).round()] / 1000;
    return FrameCadence(
      framesPerSecond: intervals.length * 1000000 / duration,
      intervalP50Ms: percentile(.50),
      intervalP95Ms: percentile(.95),
    );
  }
}

/// One active scroll window. Match delayed batches by their frame timestamps,
/// not by the mode or route visible when a timing callback eventually arrives.
class ScrollFrameSample {
  static const capacity = 240;
  int? _start;
  int? _end;
  final _frames = <ui.FrameTiming>[];

  void clear() {
    _start = null;
    _end = null;
    _frames.clear();
  }

  void begin(int afterMicros) {
    clear();
    _start = afterMicros;
  }

  void end(int throughMicros) => _end = throughMicros;

  bool add(List<ui.FrameTiming> timings) {
    final start = _start;
    if (start == null) return false;
    final known = _frames.map((frame) =>
        frame.timestampInMicroseconds(ui.FramePhase.vsyncStart)).toSet();
    var changed = false;
    for (final frame in timings) {
      final time = frame.timestampInMicroseconds(ui.FramePhase.vsyncStart);
      if (time <= start || (_end != null && time > _end!) || !known.add(time)) {
        continue;
      }
      _frames.add(frame);
      changed = true;
    }
    _frames.sort((a, b) => a.timestampInMicroseconds(ui.FramePhase.vsyncStart)
        .compareTo(b.timestampInMicroseconds(ui.FramePhase.vsyncStart)));
    if (_frames.length > capacity) {
      _frames.removeRange(0, _frames.length - capacity);
    }
    return changed;
  }

  int get count => _frames.length;
  List<int> get uiMicros =>
      _frames.map((f) => f.buildDuration.inMicroseconds).toList();
  List<int> get rasterMicros =>
      _frames.map((f) => f.rasterDuration.inMicroseconds).toList();
  FrameCadence? get cadence => FrameCadence.fromStartMicros(_frames.map((f) =>
      f.timestampInMicroseconds(ui.FramePhase.vsyncStart)).toList());
}
