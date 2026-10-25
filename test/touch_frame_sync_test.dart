import 'dart:ui' as ui;

import 'package:arabic_academy/core/touch_input_policy.dart';
import 'package:arabic_academy/features/learning/textbook_reader_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> tick(WidgetTester tester) async {
    tester.binding.scheduleFrame();
    await tester.pump(const Duration(microseconds: 8333));
  }

  ui.PointerData point(WidgetTester tester, Duration epoch, int micros,
      ui.PointerChange change, double x, double y, {int device = 1}) =>
      ui.PointerData(
        viewId: tester.view.viewId, device: device,
        kind: ui.PointerDeviceKind.touch, change: change,
        timeStamp: epoch + Duration(microseconds: micros),
        physicalX: x, physicalY: y,
      );

  void enable(WidgetTester tester) {
    final binding = GestureBinding.instance;
    final previous = binding.resamplingEnabled;
    addTearDown(() => binding.resamplingEnabled = previous);
    TouchInputPolicy.initialize(binding);
    if (!TouchInputPolicy.optedIn) binding.resamplingEnabled = true;
    expect(binding.resamplingEnabled, isTrue);
  }

  testWidgets('60 Hz touch samples interpolate movement on 120 Hz frames',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    final moves = <PointerMoveEvent>[];
    await tester.pumpWidget(Listener(
      behavior: HitTestBehavior.opaque,
      onPointerMove: moves.add,
      child: const SizedBox.expand(),
    ));
    enable(tester);
    final epoch = Duration(
      microseconds: tester.binding.clock.now().microsecondsSinceEpoch,
    );
    GestureBinding.instance.platformDispatcher.onPointerDataPacket!(
      ui.PointerDataPacket(data: [
        point(tester, epoch, 0, ui.PointerChange.add, 100, 100),
        point(tester, epoch, 0, ui.PointerChange.down, 100, 100),
        for (var i = 1; i <= 6; i++)
          point(tester, epoch, i * 16667, ui.PointerChange.move,
            100 + i * 16.667, 100),
        point(tester, epoch, 120000, ui.PointerChange.up, 200, 100),
        point(tester, epoch, 120000, ui.PointerChange.remove, 200, 100),
      ]),
    );
    for (var i = 0; i < 15; i++) {
      await tick(tester);
    }
    expect(moves.length, greaterThanOrEqualTo(8),
        reason: 'movement must be interpolated between the six sensor samples');
    final moving = moves.where((event) => event.delta.distance > .1).toList();
    expect(moving.length, greaterThanOrEqualTo(8));
    expect(moving.map((event) => event.delta.dx.abs()),
        everyElement(lessThanOrEqualTo(9)));
    GestureBinding.instance.resamplingEnabled = false;
    await tester.pump(const Duration(milliseconds: 40));
    expect(tester.takeException(), isNull);
  });

  testWidgets('resampled two-finger input still zooms the actual PDF viewer',
      (tester) async {
    final data = await rootBundle.load('assets/artwork/lessons.webp');
    final controller = TransformationController();
    addTearDown(controller.dispose);
    tester.view.physicalSize = const Size(420, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(
      child: SizedBox(width: 390, height: 600, child: PdfPageImage(
        bytes: data.buffer.asUint8List(), controller: controller,
        fitWidth: false, viewport: const Size(390, 600),
      )),
    ))));
    await tester.pumpAndSettle();
    enable(tester);
    final center = tester.getCenter(
      find.byKey(const ValueKey('pdf-interactive-viewer')),
    );
    final epoch = Duration(
      microseconds: tester.binding.clock.now().microsecondsSinceEpoch,
    );
    GestureBinding.instance.platformDispatcher.onPointerDataPacket!(
      ui.PointerDataPacket(data: [
        for (var device = 1; device <= 2; device++) ...[
          point(tester, epoch, 0, ui.PointerChange.add,
            center.dx + (device == 1 ? -35 : 35), center.dy, device: device),
          point(tester, epoch, 0, ui.PointerChange.down,
            center.dx + (device == 1 ? -35 : 35), center.dy, device: device),
        ],
        for (var step = 1; step <= 4; step++)
          for (var device = 1; device <= 2; device++)
            point(tester, epoch, step * 20000, ui.PointerChange.move,
              center.dx + (device == 1 ? -1 : 1) * (35 + step * 12),
              center.dy, device: device),
        for (var device = 1; device <= 2; device++) ...[
          point(tester, epoch, 120000, ui.PointerChange.up,
            center.dx + (device == 1 ? -83 : 83), center.dy, device: device),
          point(tester, epoch, 120000, ui.PointerChange.remove,
            center.dx + (device == 1 ? -83 : 83), center.dy, device: device),
        ],
      ]),
    );
    for (var i = 0; i < 12; i++) {
      await tick(tester);
    }
    expect(controller.value.getMaxScaleOnAxis(), greaterThan(1.05));
    expect(find.byType(PageView), findsNothing);
    for (var i = 0; i < 5; i++) {
      await tick(tester);
    }
    GestureBinding.instance.resamplingEnabled = false;
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });
}
