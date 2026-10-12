import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:arabic_academy/core/academy_state.dart';
import 'package:arabic_academy/features/learning/online_courses_screen.dart';
import 'package:arabic_academy/features/learning/online_homework_screen.dart';
import 'package:arabic_academy/features/learning/notification_preferences.dart';
import 'package:arabic_academy/features/teacher/remote_school_screen.dart'
    show SchoolExerciseDraft;
import 'package:arabic_academy/services/backend_service.dart';

const owner = '11111111-1111-4111-8111-111111111111',
    lesson = '22222222-2222-4222-8222-222222222222',
    exercise = '33333333-3333-4333-8333-333333333333',
    question = '44444444-4444-4444-8444-444444444444',
    a = '55555555-5555-4555-8555-555555555555',
    b = '66666666-6666-4666-8666-666666666666',
    c = '77777777-7777-4777-8777-777777777777',
    group = '88888888-8888-4888-8888-888888888888',
    assignment = '99999999-9999-4999-8999-999999999999',
    submission = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
Map<String, dynamic> copy(Map source) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(source)) as Map);
Map<String, dynamic> exerciseRow({String kind = 'multipleChoice'}) => {
  'id': exercise,
  'lesson_id': lesson,
  'version': 1,
  'title': 'Выбор слов',
  'kind': kind,
  'grading_mode': kind == 'writing' ? 'manual' : 'automatic',
  'pass_percent': 100,
  'published': true,
};
List<Map<String, dynamic>> questionRows() => [
  {
    'id': question,
    'exercise_id': exercise,
    'prompt': {'text_ar': 'اخْتَرْ', 'translation': 'Выберите два слова'},
    'points': 1,
    'position': 0,
    'options': [
      {'id': a, 'label': 'كِتَابٌ', 'position': 0},
      {'id': b, 'label': 'قَلَمٌ', 'position': 1},
      {'id': c, 'label': 'دَفْتَرٌ', 'position': 2},
    ],
  },
];
Future<AcademyState> workspace({String id = owner}) async {
  final prefs = await SharedPreferences.getInstance();
  final state = AcademyState(prefs, const {
    'modules': [],
    'lessons': [],
  }, namespace: 'academy_account_$id');
  await state.initialize();
  return state;
}

Future<void> reveal(
  WidgetTester tester,
  Finder finder, {
  double delta = 300,
}) async {
  await tester.scrollUntilVisible(
    finder,
    delta,
    scrollable: find
        .descendant(
          of: find.byType(ListView).last,
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'preference patch changes only one stable category and preserves global/consent/unknown fields',
    () async {
      final backend = _Backend();
      final result = await saveNotificationPreference(
        backend,
        'assignment',
        false,
        {'unrelated': 'stale'},
      );
      expect(backend.rpcClient.calls.single, {
        'name': 'update_user_preferences',
        'params': {
          'p_patch': {
            'preferences': {
              'notification_categories': {'assignment': false},
            },
          },
        },
      });
      expect((result['preferences'] as Map)['unrelated'], 'kept');
      expect((result['preferences'] as Map)['notification_categories'], {
        'lesson': false,
        'assignment': false,
      });
      expect(result['notifications_enabled'], false);
      expect(result['stt_consent'], true);
      backend.dispose();
    },
  );
  test(
    'unknown category, anonymous account and switched-account reply fail closed',
    () async {
      final backend = _Backend();
      await expectLater(
        saveNotificationPreference(backend, 'fake', true),
        throwsA(isA<IntegrationException>()),
      );
      expect(backend.rpcClient.calls, isEmpty);
      backend.authenticated = false;
      await expectLater(
        saveNotificationPreference(backend, 'lesson', true),
        throwsA(isA<IntegrationException>()),
      );
      expect(backend.rpcClient.calls, isEmpty);
      backend.authenticated = true;
      backend.rpcClient.onCall = () => backend.uid = b;
      await expectLater(
        saveNotificationPreference(backend, 'lesson', true),
        throwsA(isA<IntegrationException>()),
      );
      backend.dispose();
    },
  );
  test(
    'homework draft freezes a durable revision/key/body and rejects demo and cross-account snapshots',
    () async {
      final state = await workspace();
      final draft = OnlineHomeworkDraft(
        owner: owner,
        assignmentId: assignment,
        revision: 3,
      )..edit(arabic: 'إِجَابَةٌ', russian: 'Ответ');
      draft.queue();
      await draft.persist(state);
      final key = draft.requestId, params = draft.submitParams();
      expect(
        () => draft.edit(russian: 'Changed'),
        throwsA(isA<IntegrationException>()),
      );
      final snapshot = copy(state.drafts[draft.storageKey] as Map)
        ..['unknown_future'] = {'kept': true};
      final restored = OnlineHomeworkDraft(
        owner: owner,
        assignmentId: assignment,
        revision: 99,
        saved: snapshot,
      );
      expect(restored.requestId, key);
      expect(restored.submitParams(), params);
      expect(restored.expectedRevision, 3);
      expect(restored.snapshot()['unknown_future'], {'kept': true});
      final demo = AcademyState(state.prefs, const {'lessons': []});
      expect(
        () => restored.persist(demo),
        throwsA(isA<IntegrationException>()),
      );
      expect(
        () => OnlineHomeworkDraft(
          owner: b,
          assignmentId: assignment,
          revision: 0,
          saved: restored.snapshot(),
        ),
        throwsA(isA<IntegrationException>()),
      );
      state.dispose();
      demo.dispose();
    },
  );
  test(
    'homework validates nonempty/size and only acknowledges its own newer server revision',
    () async {
      final draft = OnlineHomeworkDraft(
        owner: owner,
        assignmentId: assignment,
        revision: 0,
      );
      expect(draft.queue, throwsA(isA<IntegrationException>()));
      draft.edit(arabic: 'كِتَابٌ');
      draft.queue();
      expect(
        () => draft.accept({
          'assignment_id': assignment,
          'student_id': b,
          'revision': 1,
        }),
        throwsA(isA<IntegrationException>()),
      );
      expect(
        () => draft.accept({
          'assignment_id': assignment,
          'student_id': owner,
          'revision': 0,
        }),
        throwsA(isA<IntegrationException>()),
      );
      draft.accept({
        'assignment_id': assignment,
        'student_id': owner,
        'revision': 1,
      });
      expect(draft.pending, isFalse);
      expect(draft.expectedRevision, 1);
      draft.edit(russian: List.filled(65000, 'x').join());
      expect(draft.queue, throwsA(isA<IntegrationException>()));
    },
  );
  test(
    'learner assignments are scoped to own active memberships and own submissions',
    () async {
      final backend = _Backend(), api = _Api(backend);
      final rows = await api.assignments();
      expect(rows.single['id'], assignment);
      expect(api.reads.first['filters'], {
        'student_id': owner,
        'left_at': null,
      });
      expect(
        api.reads.firstWhere((r) => r['table'] == 'submissions')['filters'],
        {'student_id': owner},
      );
      expect(
        api.reads.firstWhere((r) => r['table'] == 'assignments')['within'],
        {
          'group_id': [group],
        },
      );
      backend.uid = b;
      await expectLater(
        api.assignments(),
        throwsA(isA<IntegrationException>()),
      );
      backend.dispose();
    },
  );
  testWidgets(
    'teacher multiple-choice wire draft round trips through learner API and server lesson completion',
    (tester) async {
      final teacher = SchoolExerciseDraft(exerciseRow(), questionRows())
        ..replaceKeys = true;
      teacher.questions.single['accepted_answers'] = [
        [a, c],
      ];
      teacher.questions.single['comparison'] = 'exact';
      final wire = teacher.saveParams();
      final backend = _Backend(),
          api = _Api(backend)
            ..accepted =
                (wire['p_questions'] as List).single['accepted_answers'].single;
      await tester.pumpWidget(
        MaterialApp(
          home: OnlineLessonScreen(
            backend: backend,
            api: api,
            lessonId: lesson,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Проверка'));
      await tester.pumpAndSettle();
      expect(find.text('Выберите два слова'), findsOneWidget);
      expect(find.text('اخْتَرْ'), findsOneWidget);
      await reveal(tester, find.widgetWithText(CheckboxListTile, 'دَفْتَرٌ'));
      await tester.tap(find.widgetWithText(CheckboxListTile, 'دَفْتَرٌ'));
      await tester.pumpAndSettle();
      await reveal(
        tester,
        find.widgetWithText(CheckboxListTile, 'كِتَابٌ'),
        delta: -200,
      );
      await tester.tap(find.widgetWithText(CheckboxListTile, 'كِتَابٌ'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Проверить на сервере'));
      await tester.tap(find.text('Проверить на сервере'));
      await tester.pumpAndSettle();
      final attempt = api.calls.single;
      expect(attempt['params']['p_answers'], {
        question: [a, c],
      });
      expect(api.passed, isTrue);
      await reveal(tester, find.text('Завершить урок на сервере'));
      await tester.tap(find.text('Завершить урок на сервере'));
      await tester.pumpAndSettle();
      expect(api.calls.last, {
        'name': 'complete_lesson',
        'params': {'p_lesson_id': lesson},
      });
      expect(api.completed, isTrue);
      expect(
        api.reads.any((r) => r['table'].toString().contains('answer_keys')),
        isFalse,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      backend.dispose();
    },
  );
  testWidgets(
    'single-choice remains scalar and text prompt uses legacy fallback',
    (tester) async {
      final backend = _Backend(), api = _Api(backend)..accepted = a;
      final row = exerciseRow(kind: 'singleChoice')
        ..['questions'] = questionRows();
      (row['questions'] as List).single['prompt'] = {
        'text': 'Старый текст',
        'text_ar': 'كِتَابٌ',
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [ServerExerciseForm(api: api, exercise: row)],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Старый текст'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNothing);
      await reveal(
        tester,
        find.widgetWithText(RadioListTile<String>, 'كِتَابٌ'),
      );
      await tester.tap(find.widgetWithText(RadioListTile<String>, 'كِتَابٌ'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Проверить на сервере'));
      await tester.tap(find.text('Проверить на сервере'));
      await tester.pumpAndSettle();
      expect(api.calls.single['params']['p_answers'], {question: a});
      await tester.pumpWidget(const SizedBox());
      backend.dispose();
    },
  );
  testWidgets(
    'dialogue lines render RTL; unavailable private media never requests a URL',
    (tester) async {
      final backend = _Backend(), api = _Api(backend);
      api.tables['dialogues'] = [
        {'id': group, 'lesson_id': lesson, 'title': 'Разговор'},
      ];
      api.tables['dialogue_lines'] = [
        {
          'id': question,
          'dialogue_id': group,
          'speaker': 'A',
          'text_ar': 'السَّلَامُ عَلَيْكُمْ',
          'translation': 'Мир вам',
          'position': 0,
        },
      ];
      backend.blocks = [
        {
          'id': a,
          'step': 'dialogue',
          'kind': 'image',
          'body': {'media_id': b, 'text': 'Иллюстрация'},
        },
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: OnlineLessonScreen(
            backend: backend,
            api: api,
            lessonId: lesson,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Диалог'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('السَّلَامُ عَلَيْكُمْ'));
      expect(
        Directionality.of(tester.element(find.text('السَّلَامُ عَلَيْكُمْ'))),
        TextDirection.rtl,
      );
      expect(find.text('Мир вам'), findsOneWidget);
      expect(
        find.text('Прикреплённый материал недоступен вашему аккаунту.'),
        findsOneWidget,
      );
      expect(api.mediaCalls, isEmpty);
      backend.changeUser(b);
      await tester.pumpAndSettle();
      expect(find.text('السَّلَامُ عَلَيْكُمْ'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      backend.dispose();
    },
  );
  testWidgets(
    'private audio signing is explicit and a denied URL displays a real error',
    (tester) async {
      final backend = _Backend(), api = _Api(backend);
      backend.blocks = [
        {
          'id': a,
          'step': 'introduction',
          'kind': 'audio',
          'body': {'media_id': b},
        },
      ];
      api.tables['media'] = [
        {
          'id': b,
          'lesson_id': lesson,
          'kind': 'audio',
          'upload_state': 'ready',
        },
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: OnlineLessonScreen(
            backend: backend,
            api: api,
            lessonId: lesson,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(api.mediaCalls, isEmpty);
      await reveal(tester, find.text('Открыть защищённый материал'));
      await tester.tap(find.text('Открыть защищённый материал'));
      await tester.pumpAndSettle();
      expect(api.mediaCalls, [b]);
      expect(find.text('private media denied'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      backend.dispose();
    },
  );
  testWidgets(
    'homework persists before RPC and keeps identical payload/key after an uncertain failure',
    (tester) async {
      final state = await workspace(),
          backend = _Backend(),
          api = _Api(backend)..failBeforeStore = true;
      await tester.pumpWidget(
        MaterialApp(
          home: OnlineHomeworkEditor(
            api: api,
            assignmentId: assignment,
            state: state,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byWidgetPredicate(
          (w) =>
              w is TextField && w.decoration?.labelText == 'Ответ на арабском',
        ),
        'كِتَابٌ جَدِيدٌ',
      );
      await tester.pumpAndSettle();
      api.beforeSubmit = (params) {
        final saved = state.drafts['online_assignment:$assignment'] as Map;
        expect(saved['pending_body'], params['p_body']);
        expect(saved['idempotency_key'], params['p_idempotency_key']);
      };
      await reveal(tester, find.text('Отправить работу'));
      await tester.tap(find.text('Отправить работу'));
      await tester.pumpAndSettle();
      final first = copy(api.calls.single['params'] as Map);
      expect(
        (state.drafts['online_assignment:$assignment'] as Map)['pending_body'],
        isNotNull,
      );
      expect(find.text('Повторить отправку'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      final restored = AcademyState(state.prefs, const {
        'lessons': [],
      }, namespace: state.namespace);
      await tester.pumpWidget(
        MaterialApp(
          home: OnlineHomeworkEditor(
            api: api,
            assignmentId: assignment,
            state: restored,
          ),
        ),
      );
      await tester.pumpAndSettle();
      api.failBeforeStore = false;
      await reveal(tester, find.text('Повторить отправку'));
      await tester.tap(find.text('Повторить отправку'));
      await tester.pumpAndSettle();
      expect(api.calls.last['params'], first);
      expect(api.tables['submissions']!.single['revision'], 1);
      expect(
        (restored.drafts['online_assignment:$assignment']
            as Map)['pending_body'],
        isNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
      restored.dispose();
      backend.dispose();
    },
  );
  testWidgets(
    'lost acknowledgement reconciles server history without creating another revision',
    (tester) async {
      final state = await workspace(),
          backend = _Backend(),
          api = _Api(backend)..failAfterStore = true;
      await tester.pumpWidget(
        MaterialApp(
          home: OnlineHomeworkEditor(
            api: api,
            assignmentId: assignment,
            state: state,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.labelText == 'Ответ / комментарий на русском',
        ),
        'Ответ по заданию',
      );
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Отправить работу'));
      await tester.tap(find.text('Отправить работу'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Обновить работу и историю'));
      await tester.tap(find.text('Обновить работу и историю'));
      await tester.pumpAndSettle();
      expect(api.calls.length, 1);
      expect(api.tables['submissions']!.single['revision'], 1);
      expect(
        (state.drafts['online_assignment:$assignment'] as Map)['pending_body'],
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
      state.dispose();
      backend.dispose();
    },
  );
  testWidgets(
    'requested revision shows teacher feedback/history and sends expected revision with text',
    (tester) async {
      final state = await workspace(),
          backend = _Backend(),
          api = _Api(backend);
      api.tables['submissions'] = [
        {
          'id': submission,
          'assignment_id': assignment,
          'student_id': owner,
          'revision': 3,
          'status': 'revision_requested',
          'body': {'text_ar': 'قَدِيمٌ', 'text': ''},
        },
      ];
      api.tables['grades'] = [
        {'id': c, 'submission_id': submission, 'revision': 2, 'score': 70},
      ];
      api.tables['feedback'] = [
        {'id': b, 'grade_id': c, 'body': 'Проверьте окончание.'},
      ];
      api.tables['revision_requests'] = [
        {
          'id': a,
          'submission_id': submission,
          'revision': 3,
          'reason': 'Добавьте пример.',
          'resolved_at': null,
        },
      ];
      api.tables['submission_history'] = [
        {
          'id': b,
          'submission_id': submission,
          'revision': 2,
          'idempotency_key': c,
          'body': {'text_ar': 'كِتَابٌ', 'text': 'Старый ответ'},
        },
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: OnlineHomeworkEditor(
            api: api,
            assignmentId: assignment,
            state: state,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Преподаватель просит исправить: Добавьте пример.'),
        findsOneWidget,
      );
      expect(find.text('Проверьте окончание.'), findsOneWidget);
      await reveal(
        tester,
        find.byWidgetPredicate(
          (w) =>
              w is TextField && w.decoration?.labelText == 'Ответ на арабском',
        ),
      );
      await tester.enterText(
        find.byWidgetPredicate(
          (w) =>
              w is TextField && w.decoration?.labelText == 'Ответ на арабском',
        ),
        'جَدِيدٌ',
      );
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Отправить новую ревизию'));
      await tester.tap(find.text('Отправить новую ревизию'));
      await tester.pumpAndSettle();
      expect(api.calls.single['params']['p_expected_revision'], 3);
      expect(api.calls.single['params']['p_body'], {
        'text_ar': 'جَدِيدٌ',
        'text': '',
      });
      expect(api.tables['submissions']!.single['revision'], 4);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
      backend.dispose();
    },
  );

  testWidgets(
    'revision conflict keeps local text until explicit comparison then submits the new expected revision',
    (tester) async {
      final state = await workspace(),
          backend = _Backend(),
          api = _Api(backend);
      final draft = OnlineHomeworkDraft(
        owner: owner,
        assignmentId: assignment,
        revision: 2,
      )..edit(russian: 'Мой сохранённый ответ');
      await draft.persist(state);
      api.tables['submissions'] = [
        {
          'id': submission,
          'assignment_id': assignment,
          'student_id': owner,
          'revision': 3,
          'status': 'submitted',
          'body': {'text': 'Ответ другого устройства', 'text_ar': ''},
        },
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: OnlineHomeworkEditor(
            api: api,
            assignmentId: assignment,
            state: state,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Отправить новую ревизию'));
      await tester.tap(find.text('Отправить новую ревизию'));
      await tester.pumpAndSettle();
      expect(api.calls.single['params']['p_expected_revision'], 2);
      expect(
        (state.drafts[draft.storageKey] as Map)['text'],
        'Мой сохранённый ответ',
      );
      await reveal(tester, find.text('Сверить ревизию, сохранив текст'));
      await tester.tap(find.text('Сверить ревизию, сохранив текст'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Сверить'));
      await tester.pumpAndSettle();
      expect((state.drafts[draft.storageKey] as Map)['expected_revision'], 3);
      expect(
        (state.drafts[draft.storageKey] as Map)['text'],
        'Мой сохранённый ответ',
      );
      await reveal(tester, find.text('Отправить новую ревизию'));
      await tester.tap(find.text('Отправить новую ревизию'));
      await tester.pumpAndSettle();
      expect(api.calls.last['params']['p_expected_revision'], 3);
      expect(api.tables['submissions']!.single['revision'], 4);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
      backend.dispose();
    },
  );
  testWidgets(
    'anonymous and mismatched draft workspaces make no assignment reads',
    (tester) async {
      final backend = _Backend()..authenticated = false,
          api = _Api(backend),
          state = await workspace(id: b);
      await tester.pumpWidget(
        MaterialApp(
          home: OnlineHomeworkScreen(backend: backend, api: api, state: state),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Войти по телефону'), findsOneWidget);
      expect(api.reads, isEmpty);
      backend.authenticated = true;
      backend.changeUser(owner);
      await tester.pumpAndSettle();
      expect(api.reads, isEmpty);
      expect(
        find.textContaining('школьные черновики не сохраняются'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      state.dispose();
      backend.dispose();
    },
  );
  testWidgets(
    'native join dialog sends only the real server code and confirms returned membership',
    (tester) async {
      final backend = _Backend(), api = _Api(backend);
      await tester.pumpWidget(
        MaterialApp(
          home: OnlineCoursesScreen(backend: backend, api: api),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Присоединиться к группе'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        '0123456789abcdef0123456789abcdef',
      );
      await tester.tap(find.text('Присоединиться'));
      await tester.pumpAndSettle();
      expect(api.calls.single, {
        'name': 'claim_group_invite',
        'params': {'p_code': '0123456789abcdef0123456789abcdef'},
      });
      expect(find.text('Сервер подтвердил участие в группе.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      backend.dispose();
    },
  );
}

class _Backend extends BackendService {
  bool authenticated = true;
  String uid = owner;
  final rpcClient = _RpcClient();
  List<Map<String, dynamic>> blocks = [];
  @override
  bool get isAuthenticated => authenticated;
  @override
  String? get userId => uid;
  @override
  SupabaseClient get client => rpcClient;
  @override
  Future<List<Map<String, dynamic>>> courses() async => [
    {'id': group, 'title': 'Курс'},
  ];
  @override
  Future<Map<String, dynamic>> lessonContent(String id) async => {
    'lesson': {'id': id, 'title': 'Урок', 'title_ar': 'دَرْسٌ'},
    'blocks': blocks,
    'vocabulary': [],
    'grammar': [],
  };
  void changeUser(String id) {
    uid = id;
    notifyListeners();
  }
}

class _RpcClient implements SupabaseClient {
  final calls = <Map<String, dynamic>>[];
  void Function()? onCall;
  @override
  PostgrestFilterBuilder<T> rpc<T>(
    String fn, {
    Map<String, dynamic>? params,
    dynamic get = false,
  }) {
    calls.add({'name': fn, 'params': copy(params!)});
    onCall?.call();
    return _Reply<T>({
      'user_id': owner,
      'notifications_enabled': false,
      'stt_consent': true,
      'preferences': {
        'unrelated': 'kept',
        'notification_categories': {
          'lesson': false,
          ...params['p_patch']['preferences']['notification_categories'] as Map,
        },
      },
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Reply<T> implements PostgrestFilterBuilder<T> {
  _Reply(this.value);
  final dynamic value;
  @override
  Future<U> then<U>(
    FutureOr<U> Function(T value) onValue, {
    Function? onError,
  }) => Future<T>.value(value as T).then(onValue, onError: onError);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Api extends OnlineLearningApi {
  _Api(super.backend);
  final reads = <Map<String, dynamic>>[],
      calls = <Map<String, dynamic>>[],
      mediaCalls = <String>[];
  final tables = <String, List<Map<String, dynamic>>>{
    'group_members': [
      {'group_id': group, 'student_id': owner, 'left_at': null},
    ],
    'groups': [
      {'id': group, 'title': 'Учебная группа', 'archived_at': null},
    ],
    'assignments': [
      {
        'id': assignment,
        'group_id': group,
        'exercise_id': exercise,
        'title': 'Домашняя работа',
        'due_at': null,
      },
    ],
    'exercises': [exerciseRow()],
    'questions': questionRows().map((q) => copy(q)..remove('options')).toList(),
    'question_options': questionRows().single['options']
        .map<Map<String, dynamic>>(
          (o) => {
            ...Map<String, dynamic>.from(o as Map),
            'question_id': question,
          },
        )
        .toList(),
  };
  dynamic accepted = [a, c];
  bool passed = false,
      completed = false,
      failBeforeStore = false,
      failAfterStore = false;
  void Function(Map<String, dynamic>)? beforeSubmit;
  final receipts = <String, Map<String, dynamic>>{};
  @override
  Future<List<Map<String, dynamic>>> query(
    String table, {
    Map<String, dynamic> filters = const {},
    Map<String, List<dynamic>> within = const {},
    String order = 'id',
    String columns = '*',
  }) async {
    requireOwner();
    reads.add({
      'table': table,
      'filters': filters,
      'within': within,
      'columns': columns,
    });
    return (tables[table] ?? [])
        .where(
          (r) =>
              filters.entries.every((e) => r[e.key] == e.value) &&
              within.entries.every((e) => e.value.contains(r[e.key])),
        )
        .map(copy)
        .toList();
  }

  @override
  Future<dynamic> rpc(String name, Map<String, dynamic> params) async {
    requireOwner();
    calls.add({'name': name, 'params': copy(params)});
    if (name == 'submit_attempt') {
      passed =
          jsonEncode(params['p_answers'][question]) == jsonEncode(accepted);
      return {
        'id': submission,
        'exercise_id': exercise,
        'student_id': owner,
        'status': 'graded',
        'score': passed ? 1 : 0,
        'max_score': 1,
        'passed': passed,
      };
    }
    if (name == 'complete_lesson') {
      if (!passed) {
        throw const IntegrationException('current version not passed');
      }
      completed = true;
      return null;
    }
    if (name == 'claim_group_invite') {
      return {
        'group_id': group,
        'course_id': lesson,
        'title': 'Учебная группа',
      };
    }
    if (name == 'submit_assignment') {
      beforeSubmit?.call(params);
      if (failBeforeStore) throw const IntegrationException('connection lost');
      final key = params['p_idempotency_key'] as String;
      if (receipts.containsKey(key)) {
        if (jsonEncode(receipts[key]!['body']) !=
            jsonEncode(params['p_body'])) {
          throw const IntegrationException('idempotency conflict');
        }
        return copy(receipts[key]!);
      }
      final old = (tables['submissions'] ?? []).firstOrNull;
      final revision = old?['revision'] as int? ?? 0;
      if (revision != params['p_expected_revision']) {
        throw const PostgrestException(
          message: 'revision_conflict',
          code: '40001',
        );
      }
      final row = {
        'id': submission,
        'assignment_id': assignment,
        'student_id': owner,
        'status': 'submitted',
        'revision': revision + 1,
        'body': copy(params['p_body'] as Map),
      };
      tables['submissions'] = [row];
      receipts[key] = row;
      (tables['submission_history'] ??= <Map<String, dynamic>>[]).add({
        'id': a,
        'submission_id': submission,
        'revision': revision + 1,
        'body': row['body'],
        'idempotency_key': key,
      });
      if (failAfterStore) {
        throw const IntegrationException('acknowledgement lost');
      }
      return copy(row);
    }
    throw UnimplementedError(name);
  }

  @override
  Future<String> mediaUrl(String id) async {
    requireOwner();
    mediaCalls.add(id);
    throw const IntegrationException('private media denied');
  }
}
