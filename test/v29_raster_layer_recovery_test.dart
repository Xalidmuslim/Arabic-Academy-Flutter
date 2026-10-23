import 'package:arabic_academy/ui/fitted_study_artwork.dart';
import 'package:arabic_academy/ui/neumorphic_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('v29 equivalent: artwork needs no nested forced raster layer',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: FittedStudyArtwork(
          image: AssetImage('assets/artwork/lessons.webp'),
          size: 88,
        ),
      ),
    ));
    await tester.pump();
    final art = find.byType(FittedStudyArtwork);
    expect(find.descendant(
      of: art,
      matching: find.byType(RepaintBoundary),
    ), findsNothing,
       reason: 'the lazy list already adds a boundary per visible child; '
         'nesting another around every 3D illustration adds GPU layers');
    expect(find.descendant(of: art, matching: find.byType(ImageFiltered)),
        findsOneWidget,
        reason: 'keep the exact original alpha-silhouette 3D blur');
    expect(find.byKey(const ValueKey('fitted-study-image')), findsOneWidget);
  });

  testWidgets('v29 equivalent: animated dashboard tile has no redundant layer',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 240,
          width: 220,
          child: NeumorphicFeatureTile(
            title: 'Диалоги',
            subtitle: 'Тренировка речи',
            image: 'assets/artwork/lessons.webp',
            onTap: () {},
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(find.descendant(
      of: find.byType(NeumorphicFeatureTile),
      matching: find.byType(RepaintBoundary),
    ), findsNothing,
      reason: 'the grid sliver owns child boundaries; an animated nested '
        'boundary can trigger avoidable layer compositing');
    final card = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('matte-3d-surface')),
    );
    expect((card.decoration as BoxDecoration).boxShadow, hasLength(3),
      reason: 'retain approved soft matte relief');
  });
}
