import 'dart:typed_data';

import 'package:arabic_academy/features/learning/textbook_reader_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PDF viewer reserves pinch gestures without horizontal page swipe', (tester) async {
    final data = await rootBundle.load('assets/artwork/lessons.webp');
    final bytes = Uint8List.fromList(data.buffer.asUint8List());
    final controller = TransformationController();
    addTearDown(controller.dispose);
    tester.view.physicalSize = const Size(420, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 390,
            height: 600,
            child: PdfPageImage(
              bytes: bytes,
              controller: controller,
              fitWidth: false,
              viewport: const Size(390, 600),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pdf-interactive-viewer')), findsOneWidget);
    expect(find.byType(PageView), findsNothing);

    final center = tester.getCenter(find.byKey(const ValueKey('pdf-interactive-viewer')));
    final left = await tester.startGesture(center + const Offset(-35, 0), pointer: 1);
    final right = await tester.startGesture(center + const Offset(35, 0), pointer: 2);
    await tester.pump();
    await left.moveBy(const Offset(-35, 0));
    await right.moveBy(const Offset(35, 0));
    await tester.pump();
    expect(controller.value.getMaxScaleOnAxis(), greaterThan(1.05));
    await left.up();
    await right.up();
    await tester.pump();
  });
}
