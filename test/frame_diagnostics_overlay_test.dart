import 'package:arabic_academy/core/performance_probe.dart';
import 'package:arabic_academy/ui/frame_diagnostics_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('diagnostic panel is noninteractive and shows UI/GPU p95',
      (tester) async {
    PerformanceProbe.lastReport.value = FramePerformanceReport.fromMicros(
      [for (var i = 0; i < 120; i++) 4500],
      [for (var i = 0; i < 120; i++) 11700],
    );
    addTearDown(() => PerformanceProbe.lastReport.value = null);
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(child: Center(
              child: TextButton(
                onPressed: () => tapped = true,
                child: const Text('Tap target'),
              ),
            )),
            const FrameDiagnosticsOverlay(),
          ],
        ),
      ),
    ));
    expect(find.textContaining('UI p95'), findsOneWidget);
    expect(find.textContaining('GPU p95'), findsOneWidget);
    expect(find.textContaining('120 Гц'), findsOneWidget);
    expect(find.byType(IgnorePointer), findsWidgets);
    await tester.tap(find.text('Tap target'));
    expect(tapped, isTrue);
  });
}
