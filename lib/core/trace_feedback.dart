import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Raster proximity is a self-study guide, NOT handwriting recognition.
/// The score answers "how close are my ink strokes to the displayed glyph?"
/// It cannot certify direction, correct pen lifts, articulation or legibility.
class TraceFeedback {
  const TraceFeedback({
    required this.templateCoverage,
    required this.inkProximity,
    required this.message,
  });
  final double templateCoverage;
  final double inkProximity;
  final String message;
}

abstract final class TraceEvaluator {
  static Future<TraceFeedback> evaluate({
    required String glyph,
    required List<List<Offset>> strokes,
    required Size size,
  }) async {
    if (glyph.trim().isEmpty || strokes.every((s) => s.isEmpty)) {
      return const TraceFeedback(
        templateCoverage: 0,
        inkProximity: 0,
        message: 'Проведите пальцем по светлому образцу.',
      );
    }

    final width = size.width.ceil().clamp(1, 800);
    final height = size.height.ceil().clamp(1, 800);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final painter = TextPainter(
      text: TextSpan(text: glyph,
        style: const TextStyle(
          fontFamily: 'NotoNaskhArabic',
          fontSize: 170,
          color: Colors.black,
          height: 1.4,
        )),
      textDirection: TextDirection.rtl,
    )..layout();
    painter.paint(canvas, Offset(
      (size.width - painter.width) / 2,
      (size.height - painter.height) / 2,
    ));
    painter.dispose();
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    picture.dispose();
    if (bytes == null) {
      return const TraceFeedback(
        templateCoverage: 0, inkProximity: 0,
        message: 'Не удалось проверить близость линии к образцу.',
      );
    }
    final rgba = bytes.buffer.asUint8List(
      bytes.offsetInBytes, bytes.lengthInBytes,
    );

    bool filled(int x, int y) {
      if (x < 0 || y < 0 || x >= width || y >= height) return false;
      return rgba[(y * width + x) * 4 + 3] >= 100;
    }

    final points = <Offset>[];
    // Sample each stroke every ~3 logical pixels, even on rapid gestures
    // that deliver widely separated events.
    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      points.add(stroke.first);
      for (var i = 1; i < stroke.length; i++) {
        final from = stroke[i - 1];
        final to = stroke[i];
        final distance = (to - from).distance;
        final n = math.max(1, (distance / 3).ceil());
        for (var t = 1; t <= n; t++) {
          points.add(Offset(
            from.dx + (to.dx - from.dx) * t / n,
            from.dy + (to.dy - from.dy) * t / n,
          ));
        }
      }
    }

    if (points.isEmpty) {
      return const TraceFeedback(
        templateCoverage: 0, inkProximity: 0,
        message: 'Обведите букву по контуру.',
      );
    }

    var closeInk = 0;
    final visited = <int>{};
    // Small neighborhoods account for finger thickness. A stray stroke
    // away from the glyph loses proximity; mask coverage rewards actually
    // visiting each part of the glyph.
    for (final point in points) {
      final x = point.dx.round();
      final y = point.dy.round();
      var nearGlyph = false;
      for (var dy = -8; dy <= 8 && !nearGlyph; dy += 2) {
        for (var dx = -8; dx <= 8; dx += 2) {
          if (filled(x + dx, y + dy)) {
            nearGlyph = true;
            break;
          }
        }
      }
      if (nearGlyph) closeInk++;
      final minX = math.max(0, x - 7), maxX = math.min(width - 1, x + 7);
      final minY = math.max(0, y - 7), maxY = math.min(height - 1, y + 7);
      for (var cy = minY; cy <= maxY; cy += 3) {
        for (var cx = minX; cx <= maxX; cx += 3) {
          if (filled(cx, cy)) visited.add(cy * width + cx);
        }
      }
    }

    var glyphSamples = 0;
    var covered = 0;
    for (var y = 0; y < height; y += 3) {
      for (var x = 0; x < width; x += 3) {
        if (!filled(x, y)) continue;
        glyphSamples++;
        var touched = false;
        for (var dy = -2; dy <= 2 && !touched; dy++) {
          for (var dx = -2; dx <= 2; dx++) {
            if (visited.contains((y + dy) * width + x + dx)) {
              touched = true;
              break;
            }
          }
        }
        if (touched) covered++;
      }
    }
    final coverage = glyphSamples == 0 ? 0.0 :
        (covered / glyphSamples).clamp(0.0, 1.0);
    final proximity = (closeInk / points.length).clamp(0.0, 1.0);
    final message = proximity < .48
        ? 'Часть линий проходит далеко от светлого образца. '
          'Попробуйте писать медленнее, оставаясь внутри контура.'
        : coverage < .42
            ? 'Вы попали на контур, но не обвели всю букву. '
              'Обратите внимание на точки и нижние элементы.'
            : 'Обводка близка к образцу. Сравните форму, '
              'соединения и направление письма самостоятельно.';
    return TraceFeedback(
      templateCoverage: coverage,
      inkProximity: proximity,
      message: message,
    );
  }
}
