import 'package:arabic_academy/ui/floating_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('floating bar remains above nested pushed screens', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        builder: (context, child) => Scaffold(
          extendBody: true,
          backgroundColor: Colors.transparent,
          body: child!,
          bottomNavigationBar: FloatingStudyNavigation(
            selectedIndex: selected,
            onSelected: (tab) => selected = tab,
          ),
        ),
        home: const Scaffold(body: Text('Главная страница')),
      ),
    );

    expect(find.byKey(const ValueKey('floating-study-navigation')), findsOneWidget);
    final nav = find.byKey(const ValueKey('floating-study-navigation'));
    final paint = tester.widget<DecoratedBox>(nav).decoration as BoxDecoration;
    expect(paint.border, isNull);
    expect(tester.widget<Scaffold>(find.byType(Scaffold).first).extendBody, isTrue);
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Вложенный урок')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Вложенный урок'), findsOneWidget);
    expect(find.byKey(const ValueKey('floating-study-navigation')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('study-tab-1')));
    await tester.pump();
    expect(selected, 1);
  });
}
