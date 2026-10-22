import 'package:arabic_academy/ui/background_artwork_preloader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('home preloader uses the same resized cache keys as cards', () {
    expect(BackgroundArtworkPreloader.cacheWidthFor(
      'assets/artwork/home_quick/course.webp'), 256);
    expect(BackgroundArtworkPreloader.cacheWidthFor(
      'assets/artwork/home_quick/review.webp'), 144);
    expect(BackgroundArtworkPreloader.cacheWidthFor(
      'assets/artwork/home_quick/next.webp'), 144);
    for (final name in ['vocabulary', 'lessons', 'progress', 'exercises']) {
      expect(BackgroundArtworkPreloader.cacheWidthFor(
        'assets/artwork/$name.webp'), 360);
    }
  });

  testWidgets('background image warmup never delays the first interactive '
      'screen or changes layout', (tester) async {
    var taps = 0;
    final warmed = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: BackgroundArtworkPreloader(
        artworkPaths: const [
          'assets/artwork/lessons.webp',
          'assets/artwork/grammar.webp',
          'assets/artwork/unused.webp',
        ],
        imageLoader: (context, path) async {
          warmed.add(path); // Real async image codecs are not used in tests.
        },
        child: Scaffold(
          body: Center(
            child: TextButton(
              key: const ValueKey('preload-interactive-control'),
              onPressed: () => taps++,
              child: const Text('Продолжить'),
            ),
          ),
        ),
      ),
    ));
    // The first frame is available while optional artwork is being decoded.
    expect(find.text('Продолжить'), findsOneWidget);
    await tester.tap(find.byKey(
      const ValueKey('preload-interactive-control')));
    await tester.pump();
    expect(taps, 1);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    expect(warmed.length, lessThanOrEqualTo(2));
    expect(warmed, isNot(contains('assets/artwork/unused.webp')));
    expect(find.byType(BackgroundArtworkPreloader), findsOneWidget);
    expect(find.text('Продолжить'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('idle preloading prioritizes four home images without blocking taps',
      (tester) async {
    final seen = <String>[];
    var presses = 0;
    await tester.pumpWidget(MaterialApp(
      home: BackgroundArtworkPreloader(
        maxImages: 4,
        artworkPaths: const [
          'assets/artwork/home_quick/course.webp',
          'assets/artwork/home_quick/review.webp',
          'assets/artwork/home_quick/next.webp',
          'assets/artwork/vocabulary.webp',
          'assets/artwork/unused.webp',
        ],
        imageLoader: (context, path) async => seen.add(path),
        child: Scaffold(body: TextButton(
          onPressed: () => presses++,
          child: const Text('Главный экран'),
        )),
      ),
    ));
    expect(find.text('Главный экран'), findsOneWidget);
    await tester.tap(find.text('Главный экран'));
    expect(presses, 1);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 160));
    }
    expect(seen, [
      'assets/artwork/home_quick/course.webp',
      'assets/artwork/home_quick/review.webp',
      'assets/artwork/home_quick/next.webp',
      'assets/artwork/vocabulary.webp',
    ]);
    expect(tester.takeException(), isNull);
  });

}
