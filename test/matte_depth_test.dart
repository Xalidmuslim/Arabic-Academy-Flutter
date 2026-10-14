import 'package:arabic_academy/ui/neumorphic_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('soft matte cards have warm relief and subtle pale edges', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(
        child: NeumorphicSurface(child: Text('Карточка')),
      )),
    ));
    final surface = find.byKey(const ValueKey('matte-3d-surface'));
    expect(surface, findsOneWidget);
    final outer = tester.widget<DecoratedBox>(surface);
    final decor = outer.decoration as BoxDecoration;
    expect(decor.color, const Color(0xFFFBF7EF));
    expect(decor.gradient, isNull);
    expect(decor.border, isNotNull);
    expect(decor.border!.top.color, const Color(0xE6FFFFFF));
    expect(decor.boxShadow, hasLength(2));
    expect(decor.boxShadow!.first.offset.dy, greaterThan(0));
    expect(decor.boxShadow!.last.blurRadius, greaterThan(20));
  });

  testWidgets('primary tiles have three softened shadow layers and a light edge', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 220, height: 230,
          child: NeumorphicFeatureTile(
            title: 'Уроки', subtitle: 'Изучение языка',
            image: 'assets/artwork/lessons.webp', onTap: () {},
          ),
        ),
      ),
    ));
    final surface = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('matte-3d-surface')),
    );
    final decoration = surface.decoration as BoxDecoration;
    expect(decoration.color, const Color(0xFFFBF7EF));
    expect(decoration.gradient, isNull);
    expect(decoration.border, isNotNull);
    expect(decoration.boxShadow, hasLength(3));
    expect(decoration.boxShadow![0].blurRadius,
        lessThan(decoration.boxShadow![1].blurRadius));
    expect(decoration.boxShadow![1].blurRadius,
        lessThan(decoration.boxShadow![2].blurRadius));
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
