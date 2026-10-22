import 'package:arabic_academy/ui/neumorphic_components.dart';
import 'package:arabic_academy/ui/fitted_study_artwork.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('scrolling matte 3D feature tiles are individually isolated',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: CustomScrollView(slivers: [
        SliverList.builder(
          itemCount: 30,
          itemBuilder: (_, index) => SizedBox(height: 200,
            child: NeumorphicFeatureTile(
              title: 'Урок $index',
              subtitle: 'Обучение',
              image: 'assets/artwork/lessons.webp',
              onTap: () {},
            ),
          ),
        ),
      ]),
    )));
    await tester.pump();
    final tile = find.byType(NeumorphicFeatureTile).first;
    final boundaries = find.descendant(
      of: tile, matching: find.byType(RepaintBoundary));
    expect(boundaries, findsWidgets);
    final list = find.byType(CustomScrollView);
    await tester.drag(list, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(NeumorphicFeatureTile), findsWidgets);
  });

  testWidgets('3D illustration shadow and subject use one scroll cache region',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: FittedStudyArtwork(
        image: AssetImage('assets/artwork/lessons.webp'),
        size: 120,
      ),
    )));
    await tester.pump();
    final art = find.byType(FittedStudyArtwork);
    expect(find.descendant(of: art, matching: find.byType(RepaintBoundary)),
        findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
