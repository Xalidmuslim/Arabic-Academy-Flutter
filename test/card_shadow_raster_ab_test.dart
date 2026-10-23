import 'package:arabic_academy/ui/neumorphic_components.dart';
import 'package:arabic_academy/core/performance_probe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('disabling card shadows for GPU A/B retains shape, color and text',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: NeumorphicSurface(
        debugShadowsEnabled: false,
        child: Text('Сохранённый арабский урок'),
      )),
    ));
    final surface = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('matte-3d-surface')),
    );
    final box = surface.decoration as BoxDecoration;
    expect(box.boxShadow, isEmpty);
    expect(box.color, const Color(0xFFFBF7EF));
    expect(box.borderRadius, BorderRadius.circular(22));
    expect(box.border, isNotNull);
    expect(find.text('Сохранённый арабский урок'), findsOneWidget);
  });

  testWidgets('default matte design retains both soft relief shadows',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: NeumorphicSurface(child: Text('Матовая карточка'))),
    ));
    final surface = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('matte-3d-surface')),
    );
    expect((surface.decoration as BoxDecoration).boxShadow, hasLength(2));
  });

  test('a diagnostic toggle clears old p95 samples so ON/OFF is not mixed', () {
    final before = PerformanceProbe.silhouetteBlurEnabled.value;
    PerformanceProbe.lastReport.value = FramePerformanceReport.fromMicros(
      [4000], [18000],
    );
    PerformanceProbe.toggleSilhouetteBlur();
    expect(PerformanceProbe.lastReport.value, isNull);
    PerformanceProbe.toggleSilhouetteBlur();
    expect(PerformanceProbe.silhouetteBlurEnabled.value, before);
  });
  testWidgets('in diagnostic builds a single toggle removes and restores '
      'shadow layers on an existing visible card', (tester) async {
    if (!PerformanceProbe.enabled) return;
    if (!PerformanceProbe.silhouetteBlurEnabled.value) {
      PerformanceProbe.toggleSilhouetteBlur();
    }
    addTearDown(() {
      if (!PerformanceProbe.silhouetteBlurEnabled.value) {
        PerformanceProbe.toggleSilhouetteBlur();
      }
    });
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: NeumorphicSurface(child: Text('Учебник'))),
    ));
    BoxDecoration decoration() => tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('matte-3d-surface')),
    ).decoration as BoxDecoration;
    expect(decoration().boxShadow, hasLength(2));
    PerformanceProbe.toggleSilhouetteBlur();
    await tester.pump();
    expect(decoration().boxShadow, isEmpty);
    expect(decoration().color, const Color(0xFFFBF7EF));
    expect(find.text('Учебник'), findsOneWidget);
    PerformanceProbe.toggleSilhouetteBlur();
    await tester.pump();
    expect(decoration().boxShadow, hasLength(2));
  });

}
