import 'package:arabic_academy/ui/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('voice error is visible above persistent floating navigation',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) => Center(
          child: TextButton(
            onPressed: () => guardedAction(context,
              () async => throw StateError('Арабский голос недоступен')),
            child: const Text('Тест голоса'),
          ),
        )),
      ),
    ));
    await tester.tap(find.text('Тест голоса'));
    await tester.pump();
    final banner = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(banner.behavior, SnackBarBehavior.floating,
      reason: 'A fixed black bar is covered by the root floating pill');
    expect(banner.margin!.bottom, greaterThanOrEqualTo(110),
      reason: 'Message must clear the persistent floating bottom nav');
    expect(find.textContaining('Арабский голос недоступен'), findsOneWidget);
  });
}
