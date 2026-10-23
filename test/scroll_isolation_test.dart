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
    // SliverList.builder supplies a child repaint boundary by default.
    // It should own the scrolling cache, not a second nested GPU layer
    // inside every animated card.
    final sliverBoundaries = find.ancestor(
      of: tile, matching: find.byType(RepaintBoundary));
    expect(sliverBoundaries, findsWidgets);
    expect(find.descendant(
      of: tile, matching: find.byType(RepaintBoundary)), findsNothing);
    final list = find.byType(CustomScrollView);
    await tester.drag(list, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(NeumorphicFeatureTile), findsWidgets);
  });

  testWidgets('3D illustration shadow and subject use one scroll cache region',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: CustomScrollView(slivers: [
        SliverList(delegate: SliverChildListDelegate.fixed([
          FittedStudyArtwork(
            image: AssetImage('assets/artwork/lessons.webp'),
            size: 120,
          ),
        ])),
      ]),
    )));
    await tester.pump();
    final art = find.byType(FittedStudyArtwork);
    expect(find.ancestor(of: art, matching: find.byType(RepaintBoundary)),
        findsWidgets,
        reason: 'the sliver still isolates its cached scrolling element');
    expect(find.descendant(of: art, matching: find.byType(RepaintBoundary)),
        findsNothing,
        reason: 'the alpha-shaped shadow must not force another GPU layer');
    expect(find.descendant(of: art, matching: find.byType(ImageFiltered)),
        findsOneWidget,
        reason: 'soft silhouette blur remains unchanged');
    expect(tester.takeException(), isNull);
  });
}
