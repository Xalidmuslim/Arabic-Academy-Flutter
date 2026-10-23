import 'package:arabic_academy/ui/course_unit_art.dart';
import 'package:arabic_academy/ui/fitted_study_artwork.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('textbook artwork A/B preserves original illustration while '
      'avoiding image blur in diagnostic mode', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: CourseUnitArt(
          unitId: 'u5',
          size: 88,
          imageAsset: 'assets/artwork/lesson_generated/u5_food.webp',
          blurSilhouette: false,
        ),
      ),
    ));
    await tester.pump();
    expect(find.byType(FittedStudyArtwork), findsOneWidget);
    expect(tester.widget<FittedStudyArtwork>(
      find.byType(FittedStudyArtwork),
    ).blurSilhouette, isFalse);
    expect(find.byType(ImageFiltered), findsNothing);
    expect(find.byKey(const ValueKey('fitted-study-image')), findsOneWidget,
        reason: 'the original 3D artwork must stay in the card');
  });

  testWidgets('ordinary textbook artwork retains soft 3D Gaussian shadow',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: CourseUnitArt(
          unitId: 'u5',
          size: 88,
          imageAsset: 'assets/artwork/lesson_generated/u5_food.webp',
        ),
      ),
    ));
    await tester.pump();
    expect(find.byType(ImageFiltered), findsOneWidget);
  });
}
