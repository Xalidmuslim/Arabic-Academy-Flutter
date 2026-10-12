import 'dart:convert';

import 'package:arabic_academy/core/academy_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Account export excludes device demo teacher backups', () async {
    SharedPreferences.setMockInitialValues({
      'legacy_teacher_lessons_v1': '[{"title":"Private demo material"}]',
    });
    final prefs = await SharedPreferences.getInstance();
    final account = AcademyState(prefs, {
      'modules': [],
      'lessons': [],
    }, namespace: 'academy_account_student');
    await account.initialize();
    expect(jsonDecode(account.exportData())['legacy_teacher_lessons'], isNull);
    expect(prefs.getString('legacy_teacher_lessons_v1'), isNotNull);
  });
  TestWidgetsFlutterBinding.ensureInitialized();
  const catalog = <String, dynamic>{
    'modules': <dynamic>[],
    'lessons': <dynamic>[],
  };

  test(
    'Migration keeps completion IDs, teacher materials and unknown fields',
    () async {
      final legacy = jsonEncode([
        {
          'id': 'owner-lesson',
          'title': 'Материал',
          'arabic': 'كِتَابٌ',
          'description': 'Текст',
          'published': true,
          'custom_field': {'keep': true},
        },
      ]);
      SharedPreferences.setMockInitialValues({
        'completed': ['l1', 'deleted-catalog-id'],
        'teacher_lessons': legacy,
      });
      final prefs = await SharedPreferences.getInstance();
      final state = AcademyState(prefs, catalog);
      await state.initialize();
      await state.save({'id': 'owner-lesson', 'title': 'Изменён'});
      await state.setSetting('arabicSize', 30.0);
      final restored = AcademyState(prefs, catalog);
      expect(restored.completed, containsAll(['l1', 'deleted-catalog-id']));
      expect(restored.teacherLessons.single['custom_field'], {'keep': true});
      expect(restored.teacherLessons.single['arabic'], 'كِتَابٌ');
      expect(restored.settings['arabicSize'], 30.0);
      expect(prefs.getString('legacy_teacher_lessons_v1'), legacy);
    },
  );

  test(
    'Corrupt legacy JSON remains available and produces a recoverable warning',
    () async {
      SharedPreferences.setMockInitialValues({
        'teacher_lessons': '{broken',
        'completed': ['l2'],
      });
      final prefs = await SharedPreferences.getInstance();
      final state = AcademyState(prefs, catalog);
      await state.initialize();
      expect(state.storageWarnings, isNotEmpty);
      expect(prefs.getString('teacher_lessons'), '{broken');
      expect(state.completed, contains('l2'));
      expect(() => state.exportData(), returnsNormally);
      final restored = AcademyState(prefs, catalog);
      await restored.initialize();
      expect(prefs.getString('teacher_lessons'), '{broken');
    },
  );

  test(
    'Attempts keep wrong answers; event IDs are stable until acknowledged',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final state = AcademyState(prefs, catalog);
      await state.initialize();
      await state.recordAttempt(
        lessonId: 'l1',
        exerciseId: 'e1',
        answer: 'wrong',
        status: 'incorrect',
        points: 0,
      );
      expect(state.completed, isEmpty);
      expect(state.attempts.single['answer'], 'wrong');
      final id = state.pendingEvents.single['id'];
      final restored = AcademyState(prefs, catalog);
      expect(restored.pendingEvents.single['id'], id);
      await restored.acknowledgeEvents([id as String]);
      expect(restored.pendingEvents, isEmpty);
      expect(restored.attempts, hasLength(1));
    },
  );

  test('Concurrent updates and bookmarks survive restarting the app', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final state = AcademyState(prefs, catalog);
    await Future.wait([
      state.finish('l1'),
      state.finish('l2'),
      state.toggleBookmark('word:l1:0'),
      state.saveDraft('l1:e1', {'answer': 'كَتَبَ'}),
    ]);
    final restored = AcademyState(prefs, catalog);
    expect(restored.completed, containsAll(['l1', 'l2']));
    expect(restored.bookmarks, contains('word:l1:0'));
    expect(restored.drafts['l1:e1']['answer'], 'كَتَبَ');
  });

  test(
    'Malformed versioned snapshot is preserved and never replaced by defaults',
    () async {
      final corrupt = jsonEncode({
        'version': 1,
        'completed': 'invalid-list',
        'settings': 6,
      });
      SharedPreferences.setMockInitialValues({'academy_state_v1': corrupt});
      final prefs = await SharedPreferences.getInstance();
      final state = AcademyState(prefs, catalog);
      expect(state.storageWarnings, isNotEmpty);
      expect(state.completed, isEmpty);
      await expectLater(state.finish('l1'), throwsStateError);
      expect(prefs.getString('academy_state_v1'), corrupt);
    },
  );

  test(
    'Archived teacher lessons can be restored without losing content',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final state = AcademyState(prefs, catalog);
      await state.save({'id': 'own', 'title': 'Сохрани', 'description': 'всё'});
      await state.remove('own');
      expect(state.teacherLessons, isEmpty);
      await state.restoreLesson('own');
      expect(state.teacherLessons.single['description'], 'всё');
    },
  );
}
