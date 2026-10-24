import 'package:arabic_academy/ui/neumorphic_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('large cached card uses one perimeter draw without blur or layers',
      (tester) async {
    const cached = bool.fromEnvironment('BAYNA_CACHED_CARD_SHADOWS');
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: SizedBox(
        width: 330, height: 430,
        child: NeumorphicSurface(child: Text('Диалог 1')),
      )),
    ));
    if (!cached) {
      expect(find.byKey(const ValueKey('cached-card-shadow')), findsNothing);
      expect(find.text('Диалог 1'), findsOneWidget);
      return;
    }
    await tester.runAsync(() => precacheImage(
      const AssetImage('assets/artwork/shadow_cache/card__regular_light.png'),
      tester.element(find.byType(NeumorphicSurface)),
    ));
    await tester.pump();

    final box = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey('cached-card-shadow')),
    );
    final canvas = TestRecordingCanvas();
    box.paint(TestRecordingPaintingContext(canvas), Offset.zero);
    final calls = canvas.invocations.map((call) => call.invocation).toList();
    expect(calls.where((call) => call.memberName == #drawImageNine), isEmpty,
        reason: 'Flutter 3.35.7 Impeller expands ImageNine into nine draws');
    expect(calls.where((call) => call.memberName == #drawVertices), hasLength(1),
        reason: 'all eight visible shadow patches share one textured mesh');
    expect(calls.where((call) => call.memberName == #saveLayer), isEmpty);
    final paint = calls.singleWhere((call) =>
        call.memberName == #drawVertices).positionalArguments.last as Paint;
    expect(paint.maskFilter, isNull);
    expect(paint.imageFilter, isNull);
    expect(paint.shader, isNotNull);
    expect(find.text('Диалог 1'), findsOneWidget);
  });
}
