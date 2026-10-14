import 'package:arabic_academy/app.dart';
import 'package:arabic_academy/core/academy_state.dart';
import 'package:arabic_academy/ui/floating_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('root tab back gesture returns home, then requests confirmation', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'welcome_seen': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final state = AcademyState(prefs, <String, dynamic>{
      'modules': <dynamic>[],
      'lessons': <dynamic>[],
    });
    await tester.pumpWidget(AcademyApp(state: state));
    await tester.pump();
    expect(find.byType(FloatingStudyNavigation), findsOneWidget);
    // The navigation is now a real overlay, not an opaque Scaffold slot.
    final overlay = tester.widget<Positioned>(
      find.ancestor(
        of: find.byType(FloatingStudyNavigation),
        matching: find.byType(Positioned),
      ).first,
    );
    expect(overlay.bottom, 0);
    expect(overlay.left, 0);
    expect(overlay.right, 0);

    await tester.tap(find.byKey(const ValueKey('study-tab-3')));
    await tester.pump();
    expect(find.text('Ученица · локальное обучение'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Арабский каждый день'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Выйти из приложения?'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(find.text('Выйти из приложения?'), findsNothing);
  });
}
