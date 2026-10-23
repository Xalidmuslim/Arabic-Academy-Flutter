import 'package:arabic_academy/core/academy_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('progress, audio settings and bookmarks reuse expanded lesson catalog',
      () async {
    SharedPreferences.setMockInitialValues({});
    final state = AcademyState(
      await SharedPreferences.getInstance(),
      {
        'modules': <dynamic>[
          {'id': 'u1', 'title_ru': 'Раздел 1', 'access_default': 'free'},
        ],
        'lessons': <dynamic>[
          for (var i = 0; i < 100; i++)
            {
              'id': 'l$i',
              'module_id': 'u1',
              'title': 'Урок $i',
              'dialogue': <dynamic>[],
            },
        ],
      },
    );
    addTearDown(state.dispose);
    await state.initialize();
    final catalog = state.allLessons;
    expect(catalog.length, 100);

    await state.visitLesson('l0');
    expect(identical(catalog, state.allLessons), isTrue,
        reason: 'opening a lesson must not re-expand the immutable catalog');
    await state.finish('l0');
    expect(identical(catalog, state.allLessons), isTrue,
        reason: 'completing a lesson only changes progress');
    await state.toggleBookmark('lesson:l0');
    expect(identical(catalog, state.allLessons), isTrue,
        reason: 'bookmarks do not change course source material');
    await state.setSetting('audioSpeed', 0.8);
    expect(identical(catalog, state.allLessons), isTrue,
        reason: 'audio preferences must not regenerate all lesson vocabulary');
    expect(state.completed.contains('l0'), isTrue);
    expect(state.bookmarks.contains('lesson:l0'), isTrue);

    await state.save({
      'id': 'teacher-1', 'title': 'Новый авторский урок', 'published': true,
    });
    final updated = state.allLessons;
    expect(identical(updated, catalog), isFalse,
        reason: 'published teacher edits must still invalidate catalog');
    expect(updated.any((l) => l['id'] == 'teacher-1'), isTrue);
    await state.remove('teacher-1');
    expect(state.allLessons.any((l) => l['id'] == 'teacher-1'), isFalse);
    await state.restoreLesson('teacher-1');
    expect(state.allLessons.any((l) => l['id'] == 'teacher-1'), isTrue);
  });
}
