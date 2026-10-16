import 'dart:typed_data';

import 'package:flutter/material.dart';

/// A single gesture owner for an original PDF fragment. The parent vertical
/// ListView is temporarily locked when two fingers are down or the fragment
/// is zoomed. Double tap zooms in or resets without moving the outer page.
class OriginalPdfZoomImage extends StatefulWidget {
  const OriginalPdfZoomImage({
    super.key,
    required this.image,
    required this.viewerKey,
    this.onScrollLockChanged,
  });

  final Uint8List image;
  final Key viewerKey;
  final ValueChanged<bool>? onScrollLockChanged;

  @override
  State<OriginalPdfZoomImage> createState() => _OriginalPdfZoomImageState();
}

class _OriginalPdfZoomImageState extends State<OriginalPdfZoomImage> {
  final TransformationController _zoom = TransformationController();
  final Set<int> _activePointers = <int>{};
  Offset _doubleTapPosition = Offset.zero;
  bool _locked = false;
  double _scale = 1;
  Size _viewport = Size.zero;

  @override
  void initState() {
    super.initState();
    _zoom.addListener(_onTransform);
  }

  @override
  void didUpdateWidget(covariant OriginalPdfZoomImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.image, oldWidget.image)) {
      _zoom.value = Matrix4.identity();
    }
  }

  void _onTransform() {
    final scale = _zoom.value.getMaxScaleOnAxis();
    if ((scale - _scale).abs() > 0.015) {
      _scale = scale;
      _updateLock();
    }
  }

  void _updateLock() {
    final shouldLock = _activePointers.length > 1 || _scale > 1.025;
    if (_locked == shouldLock) return;
    _locked = shouldLock;
    widget.onScrollLockChanged?.call(shouldLock);
  }

  void _onPointerEnd(int pointer) {
    _activePointers.remove(pointer);
    _updateLock();
  }

  void _scaleAt(double factor, Offset focal) {
    final next = factor.clamp(1.0, 5.0).toDouble();
    _zoom.value = Matrix4.identity()
      ..translateByDouble(-focal.dx * (next - 1),
          -focal.dy * (next - 1), 0, 1)
      ..scaleByDouble(next, next, 1, 1);
  }

  void _toggleZoom() {
    if (_scale > 1.1) {
      _zoom.value = Matrix4.identity();
    } else {
      _scaleAt(2.25, _doubleTapPosition);
    }
  }
  @override
  void dispose() {
    _zoom.removeListener(_onTransform);
    _zoom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = constraints.biggest;
        return Stack(
          children: [
            Positioned.fill(
              child: Listener(
                onPointerDown: (event) {
                  _activePointers.add(event.pointer);
                  _updateLock();
                },
                onPointerUp: (event) => _onPointerEnd(event.pointer),
                onPointerCancel: (event) => _onPointerEnd(event.pointer),
                child: InteractiveViewer(
                  key: widget.viewerKey,
                  transformationController: _zoom,
                  minScale: 1,
                  maxScale: 5,
                  panEnabled: true,
                  scaleEnabled: true,
                  boundaryMargin: const EdgeInsets.all(20),
                  interactionEndFrictionCoefficient: 0.000008,
                  clipBehavior: Clip.hardEdge,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onDoubleTapDown: (details) =>
                        _doubleTapPosition = details.localPosition,
                    onDoubleTap: _toggleZoom,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      child: Image.memory(
                        widget.image,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 6,
              right: 6,
              child: Material(
                color: const Color(0xEAFDF8DC),
                borderRadius: BorderRadius.circular(20),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: const ValueKey('original-pdf-zoom-in'),
                      icon: const Icon(Icons.add),
                      tooltip: 'Увеличить фрагмент',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _scaleAt(
                        _scale < 1.1 ? 2 : _scale * 1.5,
                        Offset(_viewport.width / 2, _viewport.height / 2),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('original-pdf-zoom-reset'),
                      icon: const Icon(Icons.fit_screen_outlined),
                      tooltip: 'Сбросить масштаб',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _zoom.value = Matrix4.identity(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
