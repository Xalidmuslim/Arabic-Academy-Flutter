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
    // 2 images max: avoid a burst of large textures or unnecessary GPU work.
    for (final path in widget.artworkPaths.take(
      widget.maxImages.clamp(0, 6).toInt())) {
      if (!mounted) return;
      try {
        if (widget.imageLoader != null) {
          await widget.imageLoader!(context, path);
        } else {
          await precacheImage(
            AssetImage(path),
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
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
