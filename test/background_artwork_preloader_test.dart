import 'package:arabic_academy/ui/background_artwork_preloader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
