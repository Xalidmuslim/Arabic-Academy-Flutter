import 'package:arabic_academy/core/academy_state.dart';
import 'package:arabic_academy/features/learning/course_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('nonfree local unit opens even if lesson files are not imported', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final state = AcademyState(prefs, <String, dynamic>{
      'modules': <dynamic>[
        <String, dynamic>{
          'id': 'u2', 'title_ru': 'Открытый раздел',
          'title_ar': 'الدَّرْسُ', 'access_default': 'purchase_or_subscription',
        },
      ],
      'lessons': <dynamic>[],
    });
    expect(AcademyState.temporaryLocalLessonAccess, isTrue);
    await tester.pumpWidget(MaterialApp(home: UnitScreen(state: state)));
    await tester.ensureVisible(find.text('Открытый раздел'));
    await tester.tap(find.text('Открытый раздел'));
    await tester.pumpAndSettle();
    expect(find.text('Материалы пока не загружены'), findsOneWidget);
    expect(find.textContaining('Учебные тексты появятся'), findsOneWidget);
  });
}
