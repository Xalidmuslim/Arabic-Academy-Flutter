import 'package:arabic_academy/core/academy_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('lesson cache reuses unchanged catalog but invalidates after writes',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final state = AcademyState(
      prefs,
      <String, dynamic>{
        'modules': <dynamic>[],
        'lessons': [
          {'id': 'base', 'title': 'النَّصُّ الأَصْلِيُّ', 'dialogue': []},
        ],
      },
    );
    addTearDown(state.dispose);
    await state.initialize();

    final first = state.allLessons;
    expect(identical(first, state.allLessons), isTrue);
    expect(first.first['title'], 'النَّصُّ الأَصْلِيُّ');

    await state.save({
      'id': 'teacher-1',
      'title': 'Урок учителя',
      'published': true,
    });
    final second = state.allLessons;
    expect(identical(second, first), isFalse);
    expect(second.any((x) => x['id'] == 'teacher-1'), isTrue);
    expect(identical(second, state.allLessons), isTrue);

    await state.remove('teacher-1');
    expect(state.allLessons.any((x) => x['id'] == 'teacher-1'), isFalse);
    expect(state.allLessons.first['title'], 'النَّصُّ الأَصْلِيُّ');
    final restored = AcademyState(prefs, state.catalog);
    addTearDown(restored.dispose);
    expect(restored.allLessons.any((x) => x['id'] == 'teacher-1'), isFalse);
  });
}
