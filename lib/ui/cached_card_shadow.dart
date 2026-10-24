import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// The same pre-blurred card texture as v50, with its covered centre omitted.
///
/// The parent paints an opaque rounded card on top. Only use this behind that
/// card: the missing centre is deliberately not a complete standalone shadow.
class CachedCardShadow extends StatefulWidget {
  const CachedCardShadow({
    super.key,
    required this.image,
    required this.radius,
  });

  static const margin = 56.0;
  final ImageProvider image;
  final double radius;

  @override
  State<CachedCardShadow> createState() => _CachedCardShadowState();
}

class _CachedCardShadowState extends State<CachedCardShadow> {
  ImageStream? _stream;
  ImageInfo? _image;
  CardShadowPainter? _painter;
  late final _listener = ImageStreamListener(_onImage);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
  }

  @override
  void didUpdateWidget(CachedCardShadow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) _resolveImage();
    if (oldWidget.radius != widget.radius) _replacePainter();
  }

  void _resolveImage() {
    final stream = widget.image.resolve(createLocalImageConfiguration(context));
    if (_stream?.key == stream.key) return;
    _stream?.removeListener(_listener);
    _stream = stream;
    stream.addListener(_listener);
  }

  void _onImage(ImageInfo image, bool synchronousCall) {
    setState(() {
      _painter?.dispose();
      _painter = null;
      _image?.dispose();
      _image = image;
      _replacePainter();
    });
  }

  void _replacePainter() {
    _painter?.dispose();
    final image = _image;
    _painter = image == null ? null : CardShadowPainter(
      image: image.image,
      scale: image.scale,
      radius: widget.radius,
    );
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _painter?.dispose();
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _painter);
}

/// One textured mesh replaces Impeller's nine separate ImageNine draws.
/// Geometry is reused while scrolling and rebuilt only when the size changes.
class CardShadowPainter extends CustomPainter {
  CardShadowPainter({
    required this.image,
    required this.radius,
    this.scale = 1,
  }) : _shader = ui.ImageShader(
      image, TileMode.clamp, TileMode.clamp, Matrix4.identity().storage,
      filterQuality: FilterQuality.low,
    ) {
    _paint.shader = _shader;
  }

  final ui.Image image;
  final double radius;
  final double scale;
  final ui.ImageShader _shader;
  final Paint _paint = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.low;
  ui.Vertices? _vertices;
  Size? _size;

  ui.Vertices _mesh(Size size) {
    final start = (CachedCardShadow.margin + radius) * scale;
    final end = start + 2 * scale;
    final sx = [0.0, start, end, image.width.toDouble()];
    final sy = [0.0, start, end, image.height.toDouble()];
    List<double> destination(double extent, List<double> source) {
      final leading = source[1] / scale;
      final trailing = (source[3] - source[2]) / scale;
      final fit = math.min(1.0, extent / (leading + trailing));
      return [0, leading * fit, extent - trailing * fit, extent];
    }
    final dx = destination(size.width, sx);
    final dy = destination(size.height, sy);
    final positions = <Offset>[];
    final texture = <Offset>[];
    final indices = <int>[];
    for (var y = 0; y < 3; y++) {
      for (var x = 0; x < 3; x++) {
        // This rectangle is inside the opaque foreground, including corners.
        if (x == 1 && y == 1) continue;
        final first = positions.length;
        positions.addAll([
          Offset(dx[x], dy[y]), Offset(dx[x + 1], dy[y]),
          Offset(dx[x + 1], dy[y + 1]), Offset(dx[x], dy[y + 1]),
        ]);
        texture.addAll([
          Offset(sx[x], sy[y]), Offset(sx[x + 1], sy[y]),
          Offset(sx[x + 1], sy[y + 1]), Offset(sx[x], sy[y + 1]),
        ]);
        indices.addAll([first, first + 1, first + 2,
          first, first + 2, first + 3]);
      }
    }
    return ui.Vertices(ui.VertexMode.triangles, positions,
      textureCoordinates: texture, indices: indices);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    if (_size != size) {
      _vertices?.dispose();
      _vertices = _mesh(size);
      _size = size;
    }
    canvas.drawVertices(_vertices!, BlendMode.srcOver, _paint);
  }

  @override
  bool? hitTest(Offset position) => false;

  @override
  bool shouldRepaint(CardShadowPainter oldDelegate) =>
      image != oldDelegate.image || radius != oldDelegate.radius ||
      scale != oldDelegate.scale;

  void dispose() {
    _vertices?.dispose();
    _shader.dispose();
  }
}
