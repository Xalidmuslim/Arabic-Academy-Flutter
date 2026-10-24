import 'package:arabic_academy/core/performance_probe.dart';
import 'package:arabic_academy/ui/neumorphic_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cached = bool.fromEnvironment(
    'BAYNA_CACHED_CARD_SHADOWS', defaultValue: false,
  );

  BoxDecoration surface(WidgetTester tester) =>
      tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('matte-3d-surface')),
      ).decoration as BoxDecoration;

  testWidgets('cached light card keeps the original color, geometry and border',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: SizedBox(
        width: 330, height: 160,
        child: NeumorphicSurface(child: Text('Арабский курс')),
      )),
    ));
    final decoration = surface(tester);
    expect(decoration.color, const Color(0xFFFBF7EF));
    expect(decoration.borderRadius, BorderRadius.circular(22));
    expect(decoration.border, isNotNull);
    expect(find.text('Арабский курс'), findsOneWidget);

    final image = find.byKey(const ValueKey('cached-card-shadow'));
    if (cached) {
      expect(decoration.boxShadow, isEmpty,
          reason: 'opt-in must avoid all runtime BoxShadow blur draws');
      expect(image, findsOneWidget);
      final widget = tester.widget<Image>(image);
      expect(widget.centerSlice, isNotNull);
      expect(widget.fit, BoxFit.fill);
      expect((widget.image as AssetImage).assetName,
          'assets/artwork/shadow_cache/card__regular_light.png');
    } else {
      expect(decoration.boxShadow, hasLength(2),
          reason: 'ordinary production uses the original matte 3D shadows');
      expect(image, findsNothing);
    }
  });

  testWidgets('emphasized and dark cards keep their original theme depth',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: SizedBox(width: 300, height: 170,
        child: NeumorphicSurface(
          radius: 21, emphasized: true,
          child: Text('Выбор'),
        ),
      )),
    ));
    expect(surface(tester).boxShadow, hasLength(cached ? 0 : 3));
    if (cached) {
      final image = tester.widget<Image>(
          find.byKey(const ValueKey('cached-card-shadow')));
      expect((image.image as AssetImage).assetName,
          'assets/artwork/shadow_cache/card__emphasized_light.png');
    }

    await tester.pumpWidget(MaterialApp(
      themeMode: ThemeMode.dark,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: Scaffold(body: SizedBox(width: 300, height: 170,
        child: NeumorphicSurface(
          radius: 21, emphasized: true,
          child: Text('Выбор'),
        ),
      )),
    ));
    // MaterialApp animates inherited theme changes; wait for the actual
    // dark ThemeData before inspecting the selected shadow asset.
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(
      find.byKey(const ValueKey('matte-3d-surface')),
    )).brightness, Brightness.dark);
    expect(surface(tester).boxShadow, hasLength(cached ? 0 : 1));
    if (cached) {
      final image = tester.widget<Image>(
          find.byKey(const ValueKey('cached-card-shadow')));
      expect((image.image as AssetImage).assetName,
          'assets/artwork/shadow_cache/card__emphasized_dark.png');
    }
  });

  testWidgets('diagnostic shadow OFF removes every shadow but preserves content',
      (tester) async {
    if (!PerformanceProbe.enabled) return;
    PerformanceProbe.setShadowMode(ShadowComparisonMode.noCardShadows);
    addTearDown(() => PerformanceProbe.setShadowMode(ShadowComparisonMode.all));
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: SizedBox(
        width: 330, height: 160,
        child: NeumorphicSurface(child: Text('Сохранить 3D')),
      )),
    ));
    expect(surface(tester).boxShadow, isEmpty);
    expect(find.byKey(const ValueKey('cached-card-shadow')), findsNothing);
    expect(find.text('Сохранить 3D'), findsOneWidget);
    PerformanceProbe.setShadowMode(ShadowComparisonMode.all);
    await tester.pump();
    if (cached) {
      expect(find.byKey(const ValueKey('cached-card-shadow')), findsOneWidget);
    } else {
      expect(surface(tester).boxShadow, hasLength(2));
    }
  });
}
