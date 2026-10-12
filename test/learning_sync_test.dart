import 'package:arabic_academy/core/academy_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<AcademyState> state() async {
    SharedPreferences.setMockInitialValues({});
    return AcademyState(await SharedPreferences.getInstance(), {
      'modules': [],
      'lessons': [],
    }, namespace: 'academy_account_student');
  }

  test(
    'School assignment outboxes persist without author-learning event replay',
    () async {
      final data = await state();
      await data.saveDraft('online_assignment:assignment-id', {
        'text': 'Personal school answer',
        'revision': 2,
      });
      expect(data.drafts['online_assignment:assignment-id']['revision'], 2);
      expect(data.pendingEvents, isEmpty);
    },
  );

  test(
    'Remote local-learning events merge once without granting any role or paid access',
    () async {
      final data = await state();
      final event = {
        'id': 'server-id',
        'idempotency_key': 'remote-id',
        'payload': {
          'origin': 'local_author_learning',
          'workspace_version': 1,
          'local_type': 'exercise_attempt',
          'local_payload': {
            'id': 'attempt-id',
            'lesson_id': 'l1',
            'exercise_id': 'l1-check',
            'answer': 'wrong',
            'status': 'incorrect',
            'points': 0,
            'created_at': '2026-10-12T12:00:00Z',
          },
        },
      };
      await data.mergeLearningEvents([event]);
      await data.mergeLearningEvents([event]);
      expect(data.attempts, hasLength(1));
      expect(data.completed, isEmpty);
      expect(data.pendingEvents, isEmpty);
    },
  );
  test(
    'Concurrent draft conflicts preserve both versions for an explicit choice',
    () async {
      final data = await state();
      await data.saveDraft('l1:e1', {'answer': 'mine'});
      await data.mergeLearningEvents([
        {
          'idempotency_key': 'different-device',
          'payload': {
            'origin': 'local_author_learning',
            'workspace_version': 1,
            'local_type': 'draft_saved',
            'local_payload': {
              'draft_id': 'l1:e1',
              'draft': {'answer': 'other'},
            },
          },
        },
      ]);
      expect(data.drafts['l1:e1']['answer'], 'mine');
      expect(data.syncConflicts, hasLength(1));
      await data.resolveDraftConflict('different-device', useRemote: true);
      expect(data.drafts['l1:e1']['answer'], 'other');
      expect(data.syncConflicts, isEmpty);
    },
  );
  test(
    'Learning synchronization cannot publish demo teacher materials',
    () async {
      final data = await state();
      await data.save({
        'id': 'teacher',
        'title': 'Private teacher material',
        'description': 'Keep local',
      });
      expect(data.pendingEvents, isEmpty);
      await data.finish('l1');
      final events = data.pendingEvents;
      await data.acknowledgeEvents(
        events.map((x) => x['id'] as String).toList(),
      );
      await data.mergeLearningEvents([
        {
          'idempotency_key': events.single['id'],
          'payload': {
            'origin': 'local_author_learning',
            'workspace_version': 1,
            'local_type': events.single['event_type'],
            'local_payload': events.single['payload'],
          },
        },
      ]);
      expect(data.completed, {'l1'});
      expect(data.teacherLessons.single['description'], 'Keep local');
    },
  );
}
