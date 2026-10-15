import 'package:arabic_academy/core/practice_generator.dart';
import 'package:arabic_academy/ui/fitted_study_artwork.dart';
import 'package:arabic_academy/ui/course_unit_art.dart';
import 'package:arabic_academy/ui/study_art_asset.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('lesson artwork is entirely visible without cropping and has soft shadows',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: FittedStudyArtwork(
        image: AssetImage('assets/artwork/lessons.webp'), size: 132,
      ))),
    ));
    final image = tester.widget<Image>(
        find.byKey(const ValueKey('fitted-study-image')));
    expect(image.fit, BoxFit.contain);
    final wrapper = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('fitted-study-artwork')));
    final decor = wrapper.decoration as BoxDecoration;
    expect(decor.boxShadow, isNotEmpty);
    expect(decor.boxShadow!.first.blurRadius, greaterThan(12));
    expect(decor.borderRadius, isNotNull);
  });

  test('do not show an unrelated animal or room image as a vocabulary match', () {
    expect(IllustratedTerm.concept('قِطَّةٌ'), isNull);
    expect(IllustratedTerm.concept('بَقَرَةٌ'), isNull);
    expect(IllustratedTerm.concept('حِصَانٌ'), isNull);
    expect(IllustratedTerm.concept('مَطْبَخٌ'), isNull);
    expect(IllustratedTerm.concept('كِتَابٌ'), 'book');
    expect(IllustratedTerm.concept('كُرْسِيٌّ'), 'chair');
  });

  test('only individually bundled generated scene paths are accepted', () {
    expect(StudyArtAsset.valid('assets/artwork/lesson_generated/u1_greeting.webp'),
        'assets/artwork/lesson_generated/u1_greeting.webp');
    expect(StudyArtAsset.valid('assets/artwork/lessons.webp'), isNull);
    expect(StudyArtAsset.valid('../assets/artwork/lesson_generated/u1.webp'), isNull);
    expect(StudyArtAsset.valid('assets/artwork/lesson_generated/a.png'), isNull);
    expect(StudyArtAsset.valid(null), isNull);
  });

  testWidgets('compact topic art uses full-image fitting without cropping',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: CourseUnitArt(
        unitId: 'u12',
        imageAsset: 'assets/artwork/lesson_generated/u12_hobbies.webp',
      )),
    ));
    final artwork = tester.widget<FittedStudyArtwork>(
        find.byType(FittedStudyArtwork));
    expect(artwork.size, 78);
    final picture = tester.widget<Image>(
        find.byKey(const ValueKey('fitted-study-image')));
    expect(picture.fit, BoxFit.contain);
    expect(artwork.image, isA<AssetImage>());
  });

    test('course art matches unit identity instead of repeating generic images', () {
    expect(CourseUnitArt.iconFor('u1'), Icons.waving_hand_rounded);
    expect(CourseUnitArt.iconFor('u9'), Icons.shopping_bag_outlined);
    expect(CourseUnitArt.iconFor('u10'), Icons.cloud_outlined);
    expect(CourseUnitArt.iconFor('u13'), Icons.flight_takeoff_outlined);
    expect(CourseUnitArt.iconFor('u14'), Icons.mosque_outlined);
    expect(CourseUnitArt.iconFor('u15'), Icons.health_and_safety_outlined);
    expect(CourseUnitArt.iconFor('unknown'), Icons.menu_book_outlined);
  });
}
