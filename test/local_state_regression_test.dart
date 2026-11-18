import 'dart:convert';

import 'package:arabic_academy/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-data regression tests: never silently destroy local draft lessons.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AcademyState> openState(Map<String, Object> stored) async {
    SharedPreferences.setMockInitialValues(stored);
    final prefs = await SharedPreferences.getInstance();
    return AcademyState(prefs, <String, dynamic>{
      'modules': <dynamic>[],
      'lessons': <dynamic>[],
    });
  }

  test('valid saved lessons survive a new app state and ordinary edits', () async {
    final original = jsonEncode(<Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'teacher-1',
        'title': 'Первый урок',
        'published': true,
      },
    ]);
    final state = await openState(<String, Object>{
      'teacher_lessons': original,
      'completed': <String>['l1'],
    });

    expect(state.completed, contains('l1'));
    expect(state.published, hasLength(1));
    expect(state.teacherLessons.single['title'], 'Первый урок');
    await state.save(<String, dynamic>{
      'id': 'teacher-1',
      'title': 'Отредактированный урок',
      'published': true,
    });

    expect(state.teacherLessons, hasLength(1));
    expect(state.teacherLessons.single['title'], 'Отредактированный урок');
    expect(state.prefs.getString('teacher_lessons_backup'), isNull);
    final reloaded = AcademyState(state.prefs, state.catalog);
    expect(reloaded.completed, contains('l1'));
    expect(reloaded.teacherLessons.single['title'], 'Отредактированный урок');
  });

  test('malformed JSON does not crash and is backed up before first save', () async {
    const malformed = '[{"id":"broken"';
    final state = await openState(<String, Object>{
      'teacher_lessons': malformed,
      'completed': <String>['l1'],
    });

    expect(state.teacherLessons, isEmpty);
    expect(state.completed, contains('l1'));
    expect(state.prefs.getString('teacher_lessons'), malformed);
    expect(state.prefs.getString('teacher_lessons_backup'), isNull);

    await state.save(<String, dynamic>{
      'id': 'teacher-2',
      'title': 'Новый урок',
      'published': false,
    });

    expect(state.prefs.getString('teacher_lessons_backup'), malformed);
    expect(
      (jsonDecode(state.prefs.getString('teacher_lessons')!) as List).single['id'],
      'teacher-2',
    );
    final restored = AcademyState(state.prefs, state.catalog);
    expect(restored.teacherLessons.single['id'], 'teacher-2');
  });

  test('unexpected JSON structure is preserved rather than discarded', () async {
    const badShape = '{"lessons":"not an array"}';
    final state = await openState(<String, Object>{
      'teacher_lessons': badShape,
      'teacher_lessons_backup': 'previous-backup',
    });

    expect(state.teacherLessons, isEmpty);
    await state.save(<String, dynamic>{
      'id': 'teacher-3',
      'title': 'Черновик',
      'published': false,
    });
    expect(state.prefs.getString('teacher_lessons_backup'), 'previous-backup');
    expect(state.prefs.getString('teacher_lessons'), isNot(badShape));
  });

  test('an invalid lesson element never causes a lazy type crash', () async {
    const brokenList = '[{"id":"teacher-1","title":"Хороший урок"},7]';
    final state = await openState(<String, Object>{
      'teacher_lessons': brokenList,
    });
    expect(state.teacherLessons, isEmpty);
    expect(state.prefs.getString('teacher_lessons'), brokenList);
  });
}
