import 'package:arabic_academy/ui/floating_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('floating bar width is capped on tablets with usable targets', (tester) async {
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        bottomNavigationBar: FloatingStudyNavigation(
          selectedIndex: 0, onSelected: (_) {},
        ),
      ),
    ));
    expect(tester.getSize(find.byKey(const ValueKey('floating-study-navigation'))).width,
        lessThanOrEqualTo(440));
    for (var index = 0; index < 4; index++) {
      expect(tester.getSize(find.byKey(ValueKey('study-tab-$index'))).height,
          greaterThanOrEqualTo(48));
    }
  });

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
    expect(paint.border, isNotNull);
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
