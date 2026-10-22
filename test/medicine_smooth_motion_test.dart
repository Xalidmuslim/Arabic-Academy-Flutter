import 'package:arabic_academy/ui/medicine_smooth_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Medicine smooth page route uses exact fast transition windows', () {
    final route = MedicineSmoothPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('Урок')),
    );
    expect(route.transitionDuration, const Duration(milliseconds: 225));
    expect(route.reverseTransitionDuration, const Duration(milliseconds: 175));
    expect(MedicineSmoothMotion.tabEnter,
        const Duration(milliseconds: 205));
    expect(MedicineSmoothMotion.tabExit,
        const Duration(milliseconds: 155));
    final reduced = MedicineSmoothPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('Урок')),
      reduceMotion: true,
    );
    expect(reduced.transitionDuration, Duration.zero);
    expect(reduced.reverseTransitionDuration, Duration.zero);
  });

  testWidgets('Reader route opens and closes without moving the outgoing page',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
        pageTransitionsTheme: const PageTransitionsTheme(builders: {
          TargetPlatform.android: MedicineFadePageTransitionsBuilder(),
        }),
      ),
      home: Builder(builder: (context) => Scaffold(
        body: Center(child: TextButton(
          onPressed: () => Navigator.of(context).push(
            MedicineSmoothMotion.route<void>(
              context,
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('Урок')),
                body: const Text('Текст урока'),
              ),
            ),
          ),
          child: const Text('Открыть'),
        )),
      )),
    ));
    await tester.tap(find.text('Открыть'));
    await tester.pump();
    expect(find.byType(SlideTransition), findsNothing,
        reason: 'reader transitions should not slide patterned backgrounds');
    await tester.pumpAndSettle();
    expect(find.text('Текст урока'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Открыть'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Root tab fade removes outgoing screen immediately',
      (tester) async {
    final current = ValueNotifier<int>(0);
    addTearDown(current.dispose);
    await tester.pumpWidget(MaterialApp(
      home: ValueListenableBuilder<int>(
        valueListenable: current,
        builder: (context, selected, _) => Scaffold(
          body: MedicineTabSwitcher(
            tabKey: selected,
            child: Center(child: Text(selected == 0 ? 'Сегодня' : 'Учебник')),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => current.value = 1,
            child: const Icon(Icons.navigate_next),
          ),
        ),
      ),
    ));
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    expect(find.text('Учебник'), findsOneWidget);
    expect(find.text('Сегодня'), findsNothing,
        reason: 'no two background surfaces should be painted in a tab swap');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reduced system motion disables tab transitions',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: const MedicineTabSwitcher(
        tabKey: 0,
        child: Text('Контент'),
      ),
    ));
    final transition = tester.widget<AnimatedSwitcher>(
      find.byType(AnimatedSwitcher).first);
    expect(transition.duration, Duration.zero);
    expect(transition.reverseDuration, Duration.zero);
  });
}
