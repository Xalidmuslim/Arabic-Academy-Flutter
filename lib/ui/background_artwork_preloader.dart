import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Opportunistic, bounded image warm-up AFTER the first visible Flutter frame.
///
/// Asset loading and image decoding are asynchronous; Flutter's engine decodes
/// image codecs off the UI thread. We schedule only two next-use illustrations
/// while the frame scheduler is idle, instead of decoding an asset gallery on
/// the critical cold-start path or adding permanent GPU image layers.
class BackgroundArtworkPreloader extends StatefulWidget {
  const BackgroundArtworkPreloader({
    super.key,
    required this.artworkPaths,
    required this.child,
    this.imageLoader,
    this.maxImages = 2,
  });

  final List<String> artworkPaths;
  final Widget child;

  /// Bounded priority queue; no artwork decoding on the first UI frame.
  final int maxImages;

  // Must exactly match cacheWidth used by Image.asset in the home widgets.
  // Precache of a raw AssetImage has a *different cache key* than a
  // resized Image.asset, wasting a full-resolution decode and GPU memory.
  static int cacheWidthFor(String path) => switch (path) {
    'assets/artwork/home_quick/course.webp' => 256,
    'assets/artwork/home_quick/review.webp' ||
    'assets/artwork/home_quick/next.webp' => 144,
    'assets/artwork/vocabulary.webp' ||
    'assets/artwork/lessons.webp' ||
    'assets/artwork/progress.webp' ||
    'assets/artwork/exercises.webp' => 360,
    _ => 360,
  };

  /// Injected only by widget tests to avoid real image-codec work in the
  /// fake-async test binding. Production uses Flutter's precacheImage.
  final Future<void> Function(BuildContext context, String path)? imageLoader;

  @override
  State<BackgroundArtworkPreloader> createState() =>
      _BackgroundArtworkPreloaderState();
}

class _BackgroundArtworkPreloaderState
    extends State<BackgroundArtworkPreloader> {
  bool _scheduled = false;
  bool _scrolling = false;
  Timer? _pauseTimer;
  Completer<void>? _pauseCompleter;

  Future<void> _pause(Duration duration) {
    final completed = Completer<void>();
    _pauseCompleter = completed;
    _pauseTimer = Timer(duration, () {
      _pauseTimer = null;
      _pauseCompleter = null;
      if (!completed.isCompleted) completed.complete();
    });
    return completed.future;
  }

  @override
  void dispose() {
    // Cancel pending image-preload work when the learner leaves the screen.
    // An orphaned Future.delayed timer also fails Flutter widget test teardown.
    _pauseTimer?.cancel();
    final sleeper = _pauseCompleter;
    if (sleeper != null && !sleeper.isCompleted) sleeper.complete();
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      _scrolling = true;
    } else if (notification is ScrollEndNotification) {
      _scrolling = false;
    }
    // Let other scroll listeners and floating navigation work as before.
    return false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scheduled || widget.artworkPaths.isEmpty) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.imageLoader != null) {
        // Widget tests use a deterministic callback rather than enqueuing
        // Priority.idle work, which can starve the fake-async test scheduler.
        // Production still preloads only when the real scheduler is idle.
        unawaited(_warmSequentially());
        return;
      }
      SchedulerBinding.instance.scheduleTask<void>(
        () {
          if (mounted) unawaited(_warmSequentially());
        },
        Priority.idle,
        debugLabel: 'bayna-idle-image-preload',
      );
    });
  }

  Future<void> _warmSequentially() async {
    // Defer every remaining decode if the user is actively scrolling.
    // The previous 4-image cap omitted three high-resolution home tiles,
    // causing first-scroll decodes. Keep a bounded sequential warmup.
    for (final path in widget.artworkPaths.take(
      widget.maxImages.clamp(0, 9).toInt())) {
      if (!mounted) return;
      // Never schedule the next image decode during a vertical fling.
      while (mounted && _scrolling) {
        await _pause(const Duration(milliseconds: 140));
      }
      if (!mounted) return;
      try {
        if (widget.imageLoader != null) {
          await widget.imageLoader!(context, path);
        } else {
          await precacheImage(
            ResizeImage.resizeIfNeeded(
              BackgroundArtworkPreloader.cacheWidthFor(path),
              null,
              AssetImage(path),
            ),
            context,
            onError: (error, stackTrace) {
              // Missing optional illustration must not block the reader.
            },
          );
        }
      } catch (_) {
        // Opportunistic cache work is never a startup requirement.
      }
      // Leave time for gestures/navigation before attempting another decode.
      await _pause(const Duration(milliseconds: 120));
    }
  }

  @override
  Widget build(BuildContext context) => NotificationListener<ScrollNotification>(
    onNotification: _onScroll,
    child: widget.child,
  );
}
