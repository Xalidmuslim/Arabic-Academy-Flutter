import 'dart:async';
import 'dart:convert';

import 'package:arabic_academy/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

/// A controlled backing store exercises actual SharedPreferences failures.
class ControlledStore extends SharedPreferencesStorePlatform {
  ControlledStore(this.delegate);

  final SharedPreferencesStorePlatform delegate;
  int failTeacherWrites = 0;
  int failBackupWrites = 0;
  int failProgressWrites = 0;
  int teacherWriteCalls = 0;
  Completer<void>? holdFirstTeacherWrite;

  @override
  Future<Map<String, Object>> getAll() => delegate.getAll();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == 'flutter.teacher_lessons') {
      teacherWriteCalls++;
      if (failTeacherWrites > 0) {
        failTeacherWrites--;
        return false;
      }
      if (teacherWriteCalls == 1 && holdFirstTeacherWrite != null) {
        await holdFirstTeacherWrite!.future;
      }
    } else if (key.startsWith('flutter.teacher_lessons_backup') &&
        failBackupWrites > 0) {
      failBackupWrites--;
      return false;
    } else if (key == 'flutter.completed' && failProgressWrites > 0) {
      failProgressWrites--;
      return false;
    }
    return delegate.setValue(valueType, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(AcademyState, ControlledStore)> openState(
    Map<String, Object> initial,
  ) async {
    SharedPreferences.setMockInitialValues(initial);
    final prefs = await SharedPreferences.getInstance();
    final store = ControlledStore(SharedPreferencesStorePlatform.instance);
    SharedPreferencesStorePlatform.instance = store;
    return (AcademyState(prefs, <String, dynamic>{
      'modules': <dynamic>[],
      'lessons': <dynamic>[],
    }), store);
  }

  Map<String, dynamic> lesson(String id) => <String, dynamic>{
    'id': id,
    'title': 'Урок $id',
    'published': false,
  };

  test('failed backup must not alter in-memory lessons or original data',
      () async {
    const damaged = 'not valid JSON';
    final (state, store) = await openState(
      <String, Object>{'teacher_lessons': damaged},
    );
    store.failBackupWrites = 1;

    await expectLater(state.save(lesson('one')), throwsStateError);
    expect(state.teacherLessons, isEmpty);
    await state.prefs.reload();
    expect(state.prefs.getString('teacher_lessons'), damaged);
    expect(state.prefs.getString('teacher_lessons_backup'), isNull);

    await state.save(lesson('one'));
    await state.prefs.reload();
    expect(state.prefs.getString('teacher_lessons_backup'), damaged);
    expect(state.teacherLessons.single['id'], 'one');
  });

  test('failed primary write keeps original draft and permits retry',
      () async {
    final previous = jsonEncode(<Map<String, dynamic>>[lesson('old')]);
    final (state, store) = await openState(
      <String, Object>{'teacher_lessons': previous},
    );
    store.failTeacherWrites = 1;

    await expectLater(state.save(lesson('new')), throwsStateError);
    expect(state.teacherLessons.map((item) => item['id']), <String>['old']);
    await state.prefs.reload();
    expect(state.prefs.getString('teacher_lessons'), previous);

    await state.save(lesson('new'));
    expect(state.teacherLessons.map((item) => item['id']),
        <String>['old', 'new']);
    expect(state.prefs.getString('teacher_lessons_backup'), isNull);
  });

  test('failed primary write after backup keeps exactly one recovery copy',
      () async {
    const damaged = '{broken-json';
    final (state, store) = await openState(
      <String, Object>{'teacher_lessons': damaged},
    );
    store.failTeacherWrites = 1;

    await expectLater(state.save(lesson('first')), throwsStateError);
    expect(state.teacherLessons, isEmpty);
    await state.prefs.reload();
    expect(state.prefs.getString('teacher_lessons'), damaged);
    expect(state.prefs.getString('teacher_lessons_backup'), damaged);

    await state.save(lesson('second'));
    expect(state.prefs.containsKey('teacher_lessons_backup_1'), false);
    expect(state.teacherLessons.single['id'], 'second');
  });

  test('simultaneous saves are serialized without losing an update',
      () async {
    final (state, store) = await openState(<String, Object>{});
    store.holdFirstTeacherWrite = Completer<void>();

    final first = state.save(lesson('first'));
    await Future<void>.delayed(Duration.zero);
    final second = state.save(lesson('second'));
    await Future<void>.delayed(Duration.zero);

    expect(store.teacherWriteCalls, 1);
    store.holdFirstTeacherWrite!.complete();
    await Future.wait(<Future<void>>[first, second]);
    await state.prefs.reload();
    final saved = jsonDecode(state.prefs.getString('teacher_lessons')!) as List;
    expect(saved.map((entry) => entry['id']), <String>['first', 'second']);
  });

  test('failed removal does not erase lesson in running state', () async {
    final before = jsonEncode(<Map<String, dynamic>>[lesson('keep')]);
    final (state, store) = await openState(
      <String, Object>{'teacher_lessons': before},
    );
    store.failTeacherWrites = 1;

    await expectLater(state.remove('keep'), throwsStateError);
    expect(state.teacherLessons.single['id'], 'keep');
    await state.prefs.reload();
    expect(state.prefs.getString('teacher_lessons'), before);
  });

  test('progress storage failure does not mark a lesson completed', () async {
    final (state, store) = await openState(<String, Object>{});
    store.failProgressWrites = 1;

    await expectLater(state.finish('l1'), throwsStateError);
    expect(state.completed, isEmpty);
    await state.prefs.reload();
    expect(state.prefs.getStringList('completed'), isNull);
    await state.finish('l1');
    expect(state.completed, contains('l1'));
  });
}
