import 'package:arabic_academy/ui/fitted_study_artwork.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('3D art and its soft shadow share one screen-sized decode',
      (tester) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: FittedStudyArtwork(
            image: AssetImage('assets/artwork/lessons.webp'),
            size: 88,
          ),
        ),
      ),
    ));
    await tester.pump();
    final images = tester.widgetList<Image>(
      find.descendant(
        of: find.byType(FittedStudyArtwork),
        matching: find.byType(Image),
      ),
    ).toList();
    expect(images, hasLength(2),
        reason: 'matte artwork retains both subject and silhouette shadow');
    expect(images[0].image, same(images[1].image),
        reason: 'soft shadow and subject must share one decoded cache entry');
    expect(images[0].image, isA<ResizeImage>(),
        reason: 'the original full-resolution asset must not be decoded for '
          'an 88dp scrolling row');
    expect((images[0].image as ResizeImage).width, 264,
        reason: '88dp x devicePixelRatio=3 preserves screen-level sharpness');
    expect(find.byType(ImageFiltered), findsOneWidget,
        reason: 'do not sacrifice the transparent 3D silhouette blur');
    expect(find.byType(RepaintBoundary), findsWidgets);
  });
  testWidgets('diagnostic shadow A/B leaves original artwork intact',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: FittedStudyArtwork(
          image: AssetImage('assets/artwork/lessons.webp'),
          size: 88,
          blurSilhouette: false,
        ),
      ),
    ));
    await tester.pump();
    expect(find.byType(ImageFiltered), findsNothing,
        reason: 'diagnostic comparison can remove only expensive blur');
    expect(find.byKey(const ValueKey('fitted-study-image')), findsOneWidget,
        reason: 'the original 3D illustration must always remain visible');
    expect(find.descendant(
      of: find.byType(FittedStudyArtwork),
      matching: find.byType(Image),
    ), findsOneWidget,
        reason: 'OFF must remove the tinted shadow duplicate, not just the blur');
    expect(find.descendant(
      of: find.byType(FittedStudyArtwork),
      matching: find.byType(ColorFiltered),
    ), findsNothing,
        reason: 'OFF must not pay for a shadow color filter');
  });

}
