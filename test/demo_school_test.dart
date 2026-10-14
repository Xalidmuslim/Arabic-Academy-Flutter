import 'dart:convert';

import 'package:arabic_academy/features/teacher/demo_school_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('demo school ships separate groups and real assignment visibility', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = DemoSchoolStore(prefs);
    expect(store.groups, hasLength(3));
    expect(store.students, hasLength(9));
    expect(store.members('g1'), hasLength(3));
    expect(store.homeworkFor('s1').map((x) => x['id']), contains('a1'));
    expect(store.homeworkFor('s4').map((x) => x['id']), isNot(contains('a1')));
    expect(store.submissionFor('a1', 's2')?['grade'], 90);
    expect(store.submissionFor('a1', 's1'), isNull);
    store.dispose();
  });

  test('teacher assigns to one pupil and group; responses, grades and revisions persist', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = DemoSchoolStore(prefs);
    await store.createGroup('Арабский для начинающих');
    final newGroup = store.groups.last['id'] as String;
    await store.addStudent(newGroup, 'Лейла');
    final newPupil = store.students.last['id'] as String;
    await store.createAssignment(
      title: 'Персональное задание',
      instructions: 'Написать семь предложений.',
      groupId: newGroup,
      studentId: newPupil,
    );
    final id = store.assignments.last['id'] as String;
    expect(store.homeworkFor(newPupil).map((x) => x['id']), contains(id));
    expect(store.homeworkFor('s1').map((x) => x['id']), isNot(contains(id)));

    await expectLater(store.submit(
      assignmentId: id, studentId: 's1', answer: 'Нельзя'),
      throwsStateError);
    await store.submit(assignmentId: id, studentId: newPupil, answer: 'أَنَا لَيْلَى');
    final submissionId = store.submissionFor(id, newPupil)!['id'] as String;
    await store.grade(submissionId: submissionId, score: 70,
        feedback: 'Повторите', revision: true);
    expect(store.submissionFor(id, newPupil)!['status'], 'revision_requested');
    await store.submit(assignmentId: id, studentId: newPupil,
        answer: 'أَنَا لَيْلَى، أَنَا طَالِبَةٌ');
    expect(store.submissionFor(id, newPupil)!['status'], 'submitted');
    expect((store.submissionFor(id, newPupil)!['history'] as List), hasLength(4));
    await store.grade(submissionId: submissionId, score: 97,
        feedback: 'Принято');
    expect(store.submissionFor(id, newPupil)!['grade'], 97);

    await store.createAssignment(title: 'Всем', instructions: 'Перевести текст',
      groupId: newGroup);
    expect(store.homeworkFor(newPupil), hasLength(2));
    expect(store.homeworkFor('s1'), hasLength(1));
    final restored = DemoSchoolStore(prefs);
    expect(restored.students.last['name'], 'Лейла');
    expect(restored.submissionFor(id, newPupil)!['grade'], 97);
    expect(restored.submissionFor(id, newPupil)!['feedback'], 'Принято');
    store.dispose();
    restored.dispose();
  });

  test('live reminders and notices observe the correct group and remain on-device', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = DemoSchoolStore(prefs);
    final now = DateTime.now();
    final start = now.add(const Duration(hours: 3));
    await store.scheduleLive(title: 'Читаем по-арабски',
      groupId: 'g1', startsAt: start,
      durationMinutes: 60, remindMinutes: 120);
    expect(store.sessionsFor('s1'), hasLength(1));
    expect(store.sessionsFor('s4'), isEmpty);
    expect(store.dueReminders('s1', now), isEmpty);
    expect(store.dueReminders('s1', now.add(const Duration(hours: 2))),
        hasLength(1));
    expect(store.dueReminders('s4', now.add(const Duration(hours: 2))), isEmpty);

    final sessionId = store.sessions.single['id'] as String;
    await store.setLiveStatus(sessionId, 'live');
    expect(store.sessions.single['status'], 'live');
    await store.postLiveMessage(
      sessionId: sessionId, authorId: 's1', text: 'السلام عليكم');
    await store.toggleLiveHand(sessionId: sessionId, studentId: 's1');
    expect((store.sessions.single['messages'] as List).single['text'],
        'السلام عليكم');
    expect(store.sessions.single['raised_hands'], contains('s1'));
    await expectLater(store.postLiveMessage(
      sessionId: sessionId, authorId: 's4', text: 'Wrong group'),
        throwsStateError);
    await store.setLiveStatus(sessionId, 'ended');
    await expectLater(store.postLiveMessage(
      sessionId: sessionId, authorId: 's1', text: 'After ending'),
        throwsStateError);
    await store.announce(title: 'Всем', text: 'Учебное сообщение', groupId: 'all');
    await store.announce(title: 'Только группа А', text: 'Не забудьте тетрадь',
        groupId: 'g1');
    expect(store.announcementsFor('s1'), hasLength(2));
    expect(store.announcementsFor('s4'), hasLength(1));
    await store.selectStudent('s3');
    expect(DemoSchoolStore(prefs).currentStudentId, 's3');
    store.dispose();
  });

  test('corrupted demo data is not overwritten or mixed into account workspace', () async {
    const invalid = '{"version":1,"groups":"broken"}';
    SharedPreferences.setMockInitialValues({DemoSchoolStore.storageKey: invalid});
    final prefs = await SharedPreferences.getInstance();
    final store = DemoSchoolStore(prefs);
    expect(store.readOnly, isTrue);
    await expectLater(store.createGroup('Нельзя записывать'), throwsStateError);
    expect(prefs.getString(DemoSchoolStore.storageKey), invalid);
    final snapshot = jsonDecode(invalid);
    expect(snapshot['groups'], 'broken');
    store.dispose();
  });
}
