import 'package:arabic_academy/ui/fitted_study_artwork.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const staticMode = bool.fromEnvironment(
    'BAYNA_STATIC_SHADOW_ASSETS',
    defaultValue: false,
  );
  const artwork = 'assets/artwork/lesson_generated/u1_greeting.webp';
  const mask = 'assets/artwork/shadow_cache/lesson_generated__u1_greeting.png';

  testWidgets('release uses pre-blurred alpha mask rather than an expensive '
      'live GPU blur while keeping the original 3D illustration', (tester) async {
    expect(staticMode, isTrue,
        reason: 'run with --dart-define=BAYNA_STATIC_SHADOW_ASSETS=true');
    await rootBundle.load(mask); // The build must package the generated mask.
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: FittedStudyArtwork(
        image: AssetImage(artwork),
        size: 88,
      )),
    ));
    await tester.pump();
    expect(find.byType(ImageFiltered), findsNothing);
    expect(find.byKey(const ValueKey('fitted-study-image')), findsOneWidget);

    final paths = find.byType(Image).evaluate().map((element) {
      final provider = (element.widget as Image).image;
      if (provider is ResizeImage && provider.image is AssetImage) {
        return (provider.image as AssetImage).assetName;
      }
      return provider is AssetImage ? provider.assetName : '';
    }).toList();
    expect(paths, contains(artwork));
    expect(paths, contains(mask));
  });

  testWidgets('diagnostic shadows OFF disables the generated blur mask '
      'without hiding the source illustration', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: FittedStudyArtwork(
        image: AssetImage(artwork),
        blurSilhouette: false,
        size: 88,
      )),
    ));
    await tester.pump();
    expect(find.byType(ImageFiltered), findsNothing);
    expect(find.byKey(const ValueKey('fitted-study-image')), findsOneWidget);
  });
}
