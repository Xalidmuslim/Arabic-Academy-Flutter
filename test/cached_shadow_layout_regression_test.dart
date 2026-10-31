import 'package:arabic_academy/ui/neumorphic_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cached = bool.fromEnvironment(
    'BAYNA_CACHED_CARD_SHADOWS', defaultValue: false,
  );

  testWidgets('cached matte card surface fills its fixed two-column grid tile',
      (tester) async {
    if (!cached) return;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SizedBox(
        width: 320,
        height: 430,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, childAspectRatio: 0.8,
          ),
          itemCount: 2,
          itemBuilder: (_, index) => NeumorphicSurface(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('كِتَابٌ $index'),
              const Text('книга'),
            ]),
          ),
        ),
      )),
    ));
    await tester.pumpAndSettle();
    final surface = find.byKey(const ValueKey('matte-3d-surface')).first;
    expect(tester.getSize(surface), const Size(160, 200),
      reason: 'An opaque rounded card must cover the full cached shadow centre');
    expect(tester.takeException(), isNull);
  });

  testWidgets('fixed width progress metric does not shrink to short text',
      (tester) async {
    if (!cached) return;
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: SizedBox(
        width: 180,
        child: NeumorphicSurface(
          child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Icon(Icons.book_outlined), Text('0'), Text('Уроки')],
          ),
        ),
      ))),
    ));
    await tester.pumpAndSettle();
    final surface = find.byKey(const ValueKey('matte-3d-surface'));
    expect(tester.getSize(surface).width, 180,
      reason: 'The background and shadow need the same width on progress stats');
    expect(tester.takeException(), isNull);
  });
}
