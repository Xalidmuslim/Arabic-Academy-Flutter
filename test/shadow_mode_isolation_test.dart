import 'package:arabic_academy/core/performance_probe.dart';
import 'package:arabic_academy/ui/fitted_study_artwork.dart';
import 'package:arabic_academy/ui/neumorphic_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('four GPU modes independently isolate artwork and card shadow costs',
      () {
    expect(ShadowComparisonMode.values, hasLength(4));
    expect(ShadowComparisonMode.all.artworkEnabled, isTrue);
    expect(ShadowComparisonMode.all.cardsEnabled, isTrue);
    expect(ShadowComparisonMode.noCardShadows.artworkEnabled, isTrue);
    expect(ShadowComparisonMode.noCardShadows.cardsEnabled, isFalse);
    expect(ShadowComparisonMode.noArtworkShadow.artworkEnabled, isFalse);
    expect(ShadowComparisonMode.noArtworkShadow.cardsEnabled, isTrue);
    expect(ShadowComparisonMode.none.artworkEnabled, isFalse);
    expect(ShadowComparisonMode.none.cardsEnabled, isFalse);
  });

  testWidgets('cycling GPU modes updates the card shadow without changing '
      'the illustrated subject or card geometry', (tester) async {
    if (!PerformanceProbe.enabled) return;
    addTearDown(() {
      PerformanceProbe.setShadowMode(ShadowComparisonMode.all);
    });
    PerformanceProbe.setShadowMode(ShadowComparisonMode.all);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: NeumorphicSurface(
        child: ValueListenableBuilder<bool>(
          valueListenable: PerformanceProbe.silhouetteBlurEnabled,
          builder: (context, enabled, _) => FittedStudyArtwork(
            image: const AssetImage('assets/artwork/lessons.webp'),
            size: 88,
            blurSilhouette: enabled,
          ),
        ),
      )),
    ));
    BoxDecoration decoration() => tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('matte-3d-surface')),
    ).decoration as BoxDecoration;

    expect(decoration().boxShadow, hasLength(2));
    expect(find.byType(ImageFiltered), findsOneWidget);

    PerformanceProbe.setShadowMode(ShadowComparisonMode.noCardShadows);
    await tester.pump();
    expect(decoration().boxShadow, isEmpty);
    expect(find.byType(ImageFiltered), findsOneWidget,
        reason: 'first comparison isolates only card BoxShadow');

    PerformanceProbe.setShadowMode(ShadowComparisonMode.noArtworkShadow);
    await tester.pump();
    expect(decoration().boxShadow, hasLength(2));
    expect(find.byType(ImageFiltered), findsNothing,
        reason: 'second comparison isolates only the silhouette filter');

    PerformanceProbe.setShadowMode(ShadowComparisonMode.none);
    await tester.pump();
    expect(decoration().boxShadow, isEmpty);
    expect(find.byType(ImageFiltered), findsNothing);
    expect(find.byKey(const ValueKey('fitted-study-image')), findsOneWidget,
        reason: 'neither GPU diagnostic mode removes the actual artwork');
    PerformanceProbe.setShadowMode(ShadowComparisonMode.all);
    await tester.pump();
    expect(decoration().boxShadow, hasLength(2));
    expect(find.byType(ImageFiltered), findsOneWidget);
  });

  test('changing shadow mode clears stale sample metrics', () {
    final original = PerformanceProbe.shadowComparisonMode.value;
    addTearDown(() => PerformanceProbe.setShadowMode(original));
    PerformanceProbe.lastReport.value =
        FramePerformanceReport.fromMicros([2200], [18000]);
    PerformanceProbe.setShadowMode(ShadowComparisonMode.noCardShadows);
    expect(PerformanceProbe.lastReport.value, isNull);
  });
}
