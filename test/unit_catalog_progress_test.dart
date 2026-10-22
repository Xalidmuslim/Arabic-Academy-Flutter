import 'package:arabic_academy/core/academy_state.dart';
import 'package:arabic_academy/features/learning/course_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CountingAcademyState extends AcademyState {
  _CountingAcademyState(super.prefs, super.catalog);

  int catalogReads = 0;
  int completionReads = 0;

  @override
  List<Map<String, dynamic>> get allLessons {
    catalogReads++;
    return super.allLessons;
  }

  @override
  Set<String> get completed {
    completionReads++;
    return super.completed;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('unit scroll uses one cached catalog progress snapshot', (tester) async {
    SharedPreferences.setMockInitialValues({
      'completed': <String>['l1-0', 'l1-1'],
    });
    final prefs = await SharedPreferences.getInstance();
    final state = _CountingAcademyState(prefs, {
      'modules': <dynamic>[
        for (var i = 1; i <= 8; i++)
          <String, dynamic>{
            'id': 'u$i',
            'title_ru': 'Раздел $i',
            'title_ar': 'الْوَحْدَةُ',
            'access_default': 'free',
          },
      ],
      'lessons': <dynamic>[
        for (var i = 1; i <= 8; i++)
          for (var j = 0; j < 10; j++)
            <String, dynamic>{
              'id': 'l$i-$j',
              'module_id': 'u$i',
              'title': 'Урок $j',
              'vocabulary': <dynamic>[],
              'dialogue': <dynamic>[],
            },
      ],
    });
    addTearDown(state.dispose);

    await tester.pumpWidget(MaterialApp(home: UnitScreen(state: state)));
    await tester.pumpAndSettle();
    expect(find.text('Открыто · 2/10'), findsOneWidget);
    expect(state.catalogReads, lessThanOrEqualTo(2),
      reason: 'each visible tile must not rescan every lesson');
    expect(state.completionReads, lessThanOrEqualTo(2),
      reason: 'completion set should not be rebuilt for every unit');

    await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(state.catalogReads, lessThanOrEqualTo(2),
      reason: 'flinging the lazy course catalog should reuse the index');
  });
}
