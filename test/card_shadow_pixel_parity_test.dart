import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:arabic_academy/ui/cached_card_shadow.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Uint8List> raster(Size size, double dpr,
    void Function(Canvas canvas) paint) async {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder)..scale(dpr));
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    (size.width * dpr).ceil(), (size.height * dpr).ceil(),
  );
  picture.dispose();
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final emphasized in [false, true]) {
    for (final dark in [false, true]) {
      final name = emphasized ? 'emphasized' : 'regular';
      final tone = dark ? 'dark' : 'light';
      test('$name $tone keeps v50 visible pixels at 1x and 3x', () async {
        final data = await rootBundle.load(
          'assets/artwork/shadow_cache/card__${name}_$tone.png',
        );
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final image = (await codec.getNextFrame()).image;
        codec.dispose();
        addTearDown(image.dispose);
        final radius = emphasized ? 21.0 : 22.0;
        final painter = CardShadowPainter(image: image, radius: radius);
        addTearDown(painter.dispose);
        // Tall dialogue, compact tile, tiny surface and fractional layout.
        for (final card in [const Size(330, 430), const Size(164, 180),
            const Size(32, 28), const Size(329.5, 431.25)]) {
          const margin = CachedCardShadow.margin;
          final size = Size(card.width + margin * 2, card.height + margin * 2);
          for (final dpr in [1.0, 3.0]) {
            void foreground(Canvas canvas) {
              canvas.drawRRect(RRect.fromRectAndRadius(
                Rect.fromLTWH(margin, margin, card.width, card.height),
                Radius.circular(radius),
              ), Paint()..color = dark
                  ? const Color(0xFF29372E) : const Color(0xFFFBF7EF));
            }
            final before = await raster(size, dpr, (canvas) {
              canvas.drawImageNine(image,
                Rect.fromLTWH(margin + radius, margin + radius, 2, 2),
                Offset.zero & size, Paint()..filterQuality = FilterQuality.low);
              foreground(canvas);
            });
            final after = await raster(size, dpr, (canvas) {
              painter.paint(canvas, size);
              foreground(canvas);
            });
            var maximumDelta = 0;
            var changedChannels = 0;
            for (var i = 0; i < before.length; i++) {
              final delta = (before[i] - after[i]).abs();
              maximumDelta = math.max(maximumDelta, delta);
              if (delta > 1) changedChannels++;
            }
            expect(maximumDelta, lessThanOrEqualTo(2),
                reason: '$card at $dpr: preserve the original visible shadow');
            expect(changedChannels / before.length, lessThan(0.001),
                reason: 'only subpixel texture interpolation rounding differs');
          }
        }
      });
    }
  }

  test('large shadow leaves its covered centre transparent', () async {
    final data = await rootBundle.load(
      'assets/artwork/shadow_cache/card__regular_dark.png',
    );
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final image = (await codec.getNextFrame()).image;
    codec.dispose();
    addTearDown(image.dispose);
    final painter = CardShadowPainter(image: image, radius: 22);
    addTearDown(painter.dispose);
    const size = Size(442, 542);
    final bytes = await raster(size, 1, (canvas) => painter.paint(canvas, size));
    expect(bytes[(271 * 442 + 221) * 4 + 3], 0,
        reason: 'do not rasterize the 286 × 386 covered centre');
    expect(bytes.where((value) => value > 0), isNotEmpty,
        reason: 'the visible matte shadow must still be painted');
  });
}
