import 'package:arabic_academy/ui/neumorphic_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('matte cards have a beveled gradient and three shadow layers', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: NeumorphicSurface(child: Text('Карточка')),
          ),
        ),
      ),
    );

    final surface = find.byKey(const ValueKey('matte-3d-surface'));
    expect(surface, findsOneWidget);
    final outer = tester.widget<DecoratedBox>(surface);
    final outerDecoration = outer.decoration as BoxDecoration;
    expect(outerDecoration.gradient, isA<LinearGradient>());
    expect(outerDecoration.boxShadow, hasLength(3));
    expect(outerDecoration.boxShadow![1].offset.dy, greaterThan(0));

    final inner = find.descendant(
      of: surface,
      matching: find.byType(DecoratedBox),
    );
    final innerDecoration =
        tester.widget<DecoratedBox>(inner.first).decoration as BoxDecoration;
    expect(innerDecoration.gradient, isA<LinearGradient>());
    expect(innerDecoration.border, isNotNull);
  });

  testWidgets('feature tile keeps navigation tap with subtle press animation', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 220,
              height: 230,
              child: NeumorphicFeatureTile(
                title: 'Уроки',
                subtitle: 'Изучение языка',
                image: 'assets/artwork/lessons.webp',
                onTap: () => taps++,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final tile = find.byType(NeumorphicFeatureTile);
    final animation = find.descendant(
      of: tile,
      matching: find.byType(AnimatedScale),
    );
    expect(tester.widget<AnimatedScale>(animation).scale, 1.0);

    final gesture = await tester.startGesture(tester.getCenter(tile));
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.widget<AnimatedScale>(animation).scale, lessThan(1.0));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(tester.widget<AnimatedScale>(animation).scale, 1.0);
  });
}
