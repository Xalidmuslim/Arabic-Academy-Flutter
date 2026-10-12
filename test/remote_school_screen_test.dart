import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:arabic_academy/features/teacher/remote_school_screen.dart';
import 'package:arabic_academy/features/teacher/remote/lesson_editor.dart';
import 'package:arabic_academy/features/teacher/remote/exercises_panel.dart';
import 'package:arabic_academy/services/backend_service.dart';

const user = '11111111-1111-4111-8111-111111111111';
const course = '22222222-2222-4222-8222-222222222222';
const level = '33333333-3333-4333-8333-333333333333';
const book = '44444444-4444-4444-8444-444444444444';
const unit = '55555555-5555-4555-8555-555555555555';
const lesson = '66666666-6666-4666-8666-666666666666';
const question = '77777777-7777-4777-8777-777777777777';
const optionA = '88888888-8888-4888-8888-888888888888';
const optionB = '99999999-9999-4999-8999-999999999999';
Map<String, dynamic> clone(Map source) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(source)) as Map);
Map<String, dynamic> lessonRow() => {
  'id': lesson,
  'unit_id': unit,
  'title': 'Урок школы',
  'title_ar': 'دَرْسٌ',
  'goal': 'Понимать приветствие',
  'version': 3,
  'position': 0,
  'status': 'draft',
  'is_free_sample': false,
  'legacy_id': 'legacy-kept',
};
Map<String, dynamic> body() => {
  'blocks': [
    {
      'id': question,
      'lesson_id': lesson,
      'step': 'dialogue',
      'kind': 'text',
      'body': {
        'text_ar': 'السَّلَامُ عَلَيْكُمْ',
        'text': 'Мир вам',
        'custom_body': {'retained': true},
      },
      'position': 0,
    },
  ],
  'dialogues': [
    {
      'id': optionA,
      'lesson_id': lesson,
      'title': 'Разговор',
      'lines': [
        {
          'id': optionB,
          'dialogue_id': optionA,
          'speaker': 'A',
          'text_ar': 'مَرْحَبًا',
          'translation': 'Здравствуйте',
          'position': 0,
        },
      ],
    },
  ],
  'vocabulary': [
    {
      'id': level,
      'lesson_id': lesson,
      'text_ar': 'كِتَابٌ',
      'translation': 'Книга',
      'transliteration': 'kitab',
      'position': 0,
      'retired_at': null,
    },
  ],
  'grammar': [
    {
      'id': book,
      'lesson_id': lesson,
      'title': 'Правило',
      'explanation': 'Объяснение',
      'examples': [
        {'text_ar': 'كِتَابٌ', 'translation': 'Книга', 'custom': true},
      ],
      'position': 0,
    },
  ],
};
Map<String, dynamic> exerciseRow({
  int version = 2,
  String kind = 'singleChoice',
}) => {
  'id': unit,
  'lesson_id': lesson,
  'title': 'Упражнение школы',
  'kind': kind,
  'grading_mode': kind == 'writing' ? 'manual' : 'automatic',
  'version': version,
  'pass_percent': 100,
  'published': false,
};
List<Map<String, dynamic>> questions() => [
  {
    'id': question,
    'exercise_id': unit,
    'prompt': {
      'text_ar': 'اخْتَرْ',
      'translation': 'Выберите',
      'custom_prompt': 'kept',
    },
    'position': 0,
    'points': 1,
    'options': [
      {'id': optionA, 'question_id': question, 'label': 'أ', 'position': 0},
      {'id': optionB, 'question_id': question, 'label': 'ب', 'position': 1},
    ],
  },
];

void main() {
  group('lossless optimistic lesson payload', () {
    test(
      'metadata edits omit content entirely and retain expected version',
      () {
        final draft = SchoolLessonDraft(lessonRow(), body());
        draft.lesson['title'] = 'Новое название';
        final params = draft.saveParams();
        expect(params['p_expected_version'], 3);
        expect(params.containsKey('p_content'), isFalse);
        expect((params['p_patch'] as Map)['title'], 'Новое название');
        expect((params['p_patch'] as Map).containsKey('legacy_id'), isFalse);
        expect(draft.lesson['legacy_id'], 'legacy-kept');
        expect(draft.dirty, isTrue);
      },
    );
    test(
      'editing one section sends complete arrays with stable IDs and unknown nested JSON',
      () {
        final draft = SchoolLessonDraft(lessonRow(), body());
        draft.rows('vocabulary').single['translation'] = 'Учебная книга';
        final content = draft.saveParams()['p_content'] as Map;
        expect(content.keys.toSet(), SchoolLessonDraft.sections.toSet());
        expect(
          (content['dialogues'] as List).single['lines'].single['id'],
          optionB,
        );
        expect((content['vocabulary'] as List).single['id'], level);
        expect((content['blocks'] as List).single['body']['custom_body'], {
          'retained': true,
        });
        expect(
          (content['grammar'] as List).single['examples'].single['custom'],
          isTrue,
        );
        expect(
          (content['vocabulary'] as List).single.containsKey('retired_at'),
          isFalse,
        );
      },
    );
    test(
      'unknown row fields block destructive replacement but permit metadata-only save',
      () {
        final data = body();
        (data['vocabulary'] as List).single['future_column'] = 'keep';
        final draft = SchoolLessonDraft(lessonRow(), data);
        expect(draft.contentCompatibilityError, isNotNull);
        expect(draft.saveParams().containsKey('p_content'), isFalse);
        draft.rows('grammar').single['explanation'] = 'Changed';
        expect(draft.saveParams, throwsA(isA<IntegrationException>()));
        expect(draft.rows('vocabulary').single['future_column'], 'keep');
      },
    );
    test(
      'provenance and optional linguistic metadata survive a complete save',
      () {
        final row = lessonRow()
          ..['source_locator'] = {
            'edition': 'Verified edition',
            'page_start': 12,
            'manifest_key': 'kept',
          };
        final data = clone(body());
        (data['vocabulary'] as List).single.addAll({
          'root': 'ك ت ب',
          'part_of_speech': 'noun',
          'gender': 'masculine',
          'number': 'singular',
          'forms': {'plural': 'كُتُبٌ'},
          'example_ar': 'هٰذَا كِتَابٌ',
          'example_translation': 'Это книга',
          'level': 'A1',
        });
        (data['grammar'] as List).single.addAll({
          'root': null,
          'forms': [
            {'text_ar': 'كِتَابٌ', 'custom': 'kept'},
          ],
          'level': null,
        });
        final draft = SchoolLessonDraft(row, data);
        expect(draft.contentCompatibilityError, isNull);
        draft.rows('vocabulary').single['translation'] = 'Учебная книга';
        final params = draft.saveParams(), content = params['p_content'] as Map;
        expect(
          (params['p_patch'] as Map)['source_locator'],
          row['source_locator'],
        );
        expect((content['vocabulary'] as List).single['root'], 'ك ت ب');
        expect((content['vocabulary'] as List).single['forms'], {
          'plural': 'كُتُبٌ',
        });
        expect((content['grammar'] as List).single['forms'], [
          {'text_ar': 'كِتَابٌ', 'custom': 'kept'},
        ]);
        expect((data['vocabulary'] as List).single['translation'], 'Книга');
      },
    );
    test(
      'block positions are scoped to step; save acknowledgement resets dirty flag',
      () {
        final draft = SchoolLessonDraft(lessonRow(), body());
        (draft.content['blocks'] as List).add({
          'id': optionA,
          'step': 'grammar',
          'kind': 'text',
          'body': {'text': 'Grammar'},
          'position': 5,
        });
        (draft.content['blocks'] as List).add({
          'id': optionB,
          'step': 'dialogue',
          'kind': 'text',
          'body': {'text': 'Second'},
          'position': 9,
        });
        final blocks =
            (draft.saveParams()['p_content'] as Map)['blocks'] as List;
        expect(blocks.map((row) => row['position']).toList(), [0, 0, 1]);
        draft.accept({...draft.lesson, 'version': 4});
        expect(draft.dirty, isFalse);
      },
    );
    test(
      'source objects are not mutated and unsupported examples are preserved',
      () {
        final source = body(), row = lessonRow();
        final draft = SchoolLessonDraft(row, source);
        draft.lesson['title'] = 'Changed';
        draft.rows('vocabulary').single['text_ar'] = 'جَدِيدٌ';
        expect(row['title'], 'Урок школы');
        expect((source['vocabulary'] as List).single['text_ar'], 'كِتَابٌ');
        final other = body();
        (other['grammar'] as List).single['examples'] = {
          'future_format': 'kept',
        };
        expect(
          SchoolLessonDraft(lessonRow(), other).contentCompatibilityError,
          isNotNull,
        );
      },
    );
  });
  group('private exercise keys and exact wire answers', () {
    test(
      'existing automatic exercises cannot save without explicit key replacement',
      () {
        final draft = SchoolExerciseDraft(exerciseRow(), questions());
        draft.questions.single['accepted_answers'] = [optionA];
        expect(draft.saveParams, throwsA(isA<IntegrationException>()));
        draft.replaceKeys = true;
        expect(
          (draft.saveParams()['p_questions'] as List)
              .single['accepted_answers'],
          [optionA],
        );
      },
    );
    test(
      'multiple choice stores a complete array of UUID option IDs, not indexes',
      () {
        final draft = SchoolExerciseDraft(
          exerciseRow(kind: 'multipleChoice'),
          questions(),
        )..replaceKeys = true;
        draft.questions.single['accepted_answers'] = [
          [optionA, optionB],
        ];
        final params = draft.saveParams();
        expect((params['p_questions'] as List).single['accepted_answers'], [
          [optionA, optionB],
        ]);
        expect(
          (params['p_questions'] as List).single['prompt']['custom_prompt'],
          'kept',
        );
        expect(
          (params['p_questions'] as List).single['options']
              .singleWhere((row) => row['id'] == optionA)
              .containsKey('question_id'),
          isFalse,
        );
        for (final bad in [
          [],
          [0],
          ['foreign-id'],
          [optionA, optionA],
        ]) {
          draft.questions.single['accepted_answers'] = [bad];
          expect(draft.saveParams, throwsA(isA<IntegrationException>()));
        }
      },
    );
    test(
      'missing answers, removed options and invalid finite scores fail validation',
      () {
        final draft = SchoolExerciseDraft(exerciseRow(), questions())
          ..replaceKeys = true;
        expect(draft.saveParams, throwsA(isA<IntegrationException>()));
        draft.questions.single['accepted_answers'] = ['foreign-id'];
        expect(draft.saveParams, throwsA(isA<IntegrationException>()));
        draft.questions.single['accepted_answers'] = [optionA];
        draft.exercise['pass_percent'] = 'NaN';
        expect(draft.saveParams, throwsA(isA<IntegrationException>()));
        draft.exercise['pass_percent'] = 100;
        draft.questions.single['points'] = double.infinity;
        expect(draft.saveParams, throwsA(isA<IntegrationException>()));
      },
    );
    test('text answers preserve Arabic diacritics and explicit comparison', () {
      final draft = SchoolExerciseDraft(
        exerciseRow(kind: 'shortAnswer'),
        questions(),
      )..replaceKeys = true;
      draft.questions.single['accepted_answers'] = ['كِتَابٌ'];
      draft.questions.single['comparison'] = 'exact';
      final row = (draft.saveParams()['p_questions'] as List).single;
      expect(row['accepted_answers'], ['كِتَابٌ']);
      expect(row['comparison'], 'exact');
    });
    test(
      'manual questions never send keys; unknown schemas are not overwritten',
      () {
        final draft = SchoolExerciseDraft(
          exerciseRow(kind: 'writing'),
          questions(),
        );
        draft.questions.single['accepted_answers'] = ['private'];
        final wire = (draft.saveParams()['p_questions'] as List).single;
        expect(wire.containsKey('accepted_answers'), isFalse);
        draft.questions.single['unsupported_field'] = true;
        expect(draft.compatibilityError, isNotNull);
        expect(draft.saveParams, throwsA(isA<IntegrationException>()));
      },
    );
    test(
      'new exercise UUID is stable across retries and expected version is zero',
      () {
        final draft = SchoolExerciseDraft.create(lesson);
        final id = draft.exercise['id'];
        expect(id, matches(RegExp(r'^[a-f0-9-]{36}$')));
        draft.exercise['title'] = 'New';
        draft.questions.add({
          ...questions().single,
          'accepted_answers': [optionA],
        });
        final first = draft.saveParams(), second = draft.saveParams();
        expect(first, second);
        expect(first['p_expected_version'], 0);
        expect(first['p_exercise_id'], id);
      },
    );
  });

  testWidgets(
    'unconfigured, student, and failed roles never read school tables',
    (tester) async {
      for (final role in [ServerRole.student, ServerRole.teacher]) {
        final backend = _Backend(role: role)
          ..failRole = role == ServerRole.teacher;
        final api = _Api(backend);
        await tester.pumpWidget(
          MaterialApp(
            home: RemoteSchoolScreen(backend: backend, api: api),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Серверный доступ к управлению школой не подтверждён.'),
          findsOneWidget,
        );
        expect(api.reads, isEmpty);
        expect(find.byTooltip('Добавить'), findsNothing);
        await tester.pumpWidget(const SizedBox());
        backend.dispose();
      }
      final backend = BackendService(
        config: const IntegrationConfig(supabaseUrl: '', supabaseAnonKey: ''),
      );
      await tester.pumpWidget(
        MaterialApp(home: RemoteSchoolScreen(backend: backend)),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Серверный доступ к управлению школой не подтверждён.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      backend.dispose();
    },
  );
  testWidgets(
    'embedded teacher panel browses hierarchy and rechecks revoked role',
    (tester) async {
      final backend = _Backend(), api = _Api(backend);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RemoteSchoolScreen(
              backend: backend,
              embedded: true,
              api: api,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Scaffold), findsOneWidget);
      await tester.tap(find.text('Курс школы'));
      await tester.pumpAndSettle();
      expect(find.text('Уровень школы'), findsOneWidget);
      expect(api.reads.last['filters'], {'course_id': course});
      backend.changeRole(ServerRole.student);
      await tester.pumpAndSettle();
      expect(find.text('Уровень школы'), findsNothing);
      expect(find.byTooltip('Добавить'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      backend.dispose();
    },
  );
  testWidgets('native creation sends only server course/position contract', (
    tester,
  ) async {
    final backend = _Backend(), api = _Api(backend);
    await tester.pumpWidget(
      MaterialApp(
        home: RemoteSchoolScreen(backend: backend, api: api),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Курс школы'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Добавить'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Новый уровень');
    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();
    expect(api.writes.single['name'], 'create_level');
    expect(api.writes.single['params'], {
      'p_title': 'Новый уровень',
      'p_course_id': course,
      'p_position': 1,
    });
    expect(
      (api.writes.single['params'] as Map).containsKey('teacher_id'),
      isFalse,
    );
    await tester.pumpWidget(const SizedBox());
    backend.dispose();
  });
  testWidgets(
    'lesson save uses expected version; conflict keeps visible draft',
    (tester) async {
      final backend = _Backend(), api = _Api(backend);
      await tester.pumpWidget(
        MaterialApp(
          home: RemoteSchoolScreen(backend: backend, api: api),
        ),
      );
      await tester.pumpAndSettle();
      for (final title in [
        'Курс школы',
        'Уровень школы',
        'Книга школы',
        'Раздел школы',
        'Урок школы',
      ]) {
        await tester.tap(find.text(title).last);
        await tester.pumpAndSettle();
      }
      await tester.enterText(
        find.byType(TextFormField).first,
        'Мой новый черновик',
      );
      api.writeError = const PostgrestException(
        message: 'version_conflict',
        code: '40001',
      );
      await tester.ensureVisible(find.text('Сохранить урок'));
      await tester.tap(find.text('Сохранить урок'));
      await tester.pumpAndSettle();
      expect(api.writes.single['params']['p_expected_version'], 3);
      expect(api.writes.single['params'].containsKey('p_content'), isFalse);
      expect(
        find.textContaining('Ваш черновик сохранён на экране'),
        findsOneWidget,
      );
      await tester.drag(find.byType(Scrollable).last, const Offset(0, 600));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).first)
            .controller
            .text,
        'Мой новый черновик',
      );
      await tester.pumpWidget(const SizedBox());
      backend.dispose();
    },
  );
  testWidgets(
    'teacher groups cannot self-assign students; reports use actual rows',
    (tester) async {
      final backend = _Backend(), api = _Api(backend);
      await tester.pumpWidget(
        MaterialApp(
          home: RemoteSchoolScreen(backend: backend, api: api),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Группы'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Группа школы'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Изменение состава группы выполняет серверный администратор.',
        ),
        findsOneWidget,
      );
      expect(find.text('Добавить по UUID'), findsNothing);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Отчёты'));
      await tester.pumpAndSettle();
      expect(find.text('На ручной проверке'), findsOneWidget);
      expect(api.reads.any((row) => row['table'] == 'attempts'), isTrue);
      expect(
        api.reads.any((row) => row['table'] == 'private.answer_keys'),
        isFalse,
      );
      await tester.pumpWidget(const SizedBox());
      backend.dispose();
    },
  );
  testWidgets(
    'failed catalog load offers retry; account changes hide cached school data',
    (tester) async {
      final backend = _Backend(), api = _Api(backend)..readError = true;
      await tester.pumpWidget(
        MaterialApp(
          home: RemoteSchoolScreen(backend: backend, api: api),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Повторить загрузку'), findsOneWidget);
      api.readError = false;
      await tester.tap(find.text('Повторить загрузку'));
      await tester.pumpAndSettle();
      expect(find.text('Курс школы'), findsOneWidget);
      backend.changeUser('other-account');
      await tester.pumpAndSettle();
      expect(find.text('Курс школы'), findsNothing);
      expect(
        find.text('Аккаунт изменился. Закройте панель и откройте заново.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      backend.dispose();
    },
  );
  testWidgets('320px phone at text scale 2 keeps hierarchy actions tappable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final backend = _Backend(), api = _Api(backend);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: RemoteSchoolScreen(backend: backend, api: api),
      ),
    );
    await tester.pumpAndSettle();
    for (final title in [
      'Курс школы',
      'Уровень школы',
      'Книга школы',
      'Раздел школы',
    ]) {
      await tester.scrollUntilVisible(
        find.text(title),
        120,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(find.text(title).hitTestable(), findsOneWidget);
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
    }
    expect(find.text('Урок школы'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    backend.dispose();
  });
  testWidgets(
    'Arabic native editor remains RTL and preserves harakat through save',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final backend = _Backend(), api = _Api(backend);
      await tester.pumpWidget(
        MaterialApp(
          home: SchoolLessonEditor(api: api, id: lesson),
        ),
      );
      await tester.pumpAndSettle();
      final arabic = find.byWidgetPredicate(
        (widget) =>
            widget is EditableText && widget.controller.text == 'دَرْسٌ',
      );
      expect(
        tester.widget<EditableText>(arabic).textDirection,
        TextDirection.rtl,
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'كِتَابٌ جَدِيدٌ',
      );
      final save = find.widgetWithText(FilledButton, 'Сохранить урок');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      expect(save.hitTestable(), findsOneWidget);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(
        api.writes.single['params']['p_patch']['title_ar'],
        'كِتَابٌ جَدِيدٌ',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      backend.dispose();
    },
  );
  testWidgets(
    'native grading binds the displayed submission revision and feedback',
    (tester) async {
      final backend = _Backend(), api = _Api(backend);
      api.extra['assignments'] = [
        {
          'id': book,
          'group_id': question,
          'title': 'Задание школы',
          'exercise_id': unit,
          'due_at': null,
        },
      ];
      api.extra['submissions'] = [
        {
          'id': level,
          'assignment_id': book,
          'student_id': optionA,
          'revision': 7,
          'status': 'submitted',
          'body': {'text_ar': 'إِجَابَةٌ'},
          'updated_at': '2026-10-12T00:00:00Z',
        },
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: RemoteSchoolScreen(backend: backend, api: api),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Группы'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Группа школы'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Задание школы'));
      await tester.tap(find.text('Задание школы'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Оценить работу'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '87');
      await tester.enterText(
        find.byType(TextField).last,
        'Исправьте окончание.',
      );
      await tester.tap(find.text('Готово'));
      await tester.pumpAndSettle();
      expect(api.writes.last['name'], 'grade_submission');
      expect(api.writes.last['params'], {
        'p_submission_id': level,
        'p_revision': 7,
        'p_score': 87,
        'p_feedback': 'Исправьте окончание.',
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      backend.dispose();
    },
  );
  testWidgets(
    'composer targets a scoped member and checks real server dispatch state',
    (tester) async {
      final backend = _Backend(), api = _Api(backend);
      api.extra['group_members'] = [
        {'group_id': question, 'student_id': optionA, 'left_at': null},
      ];
      api.extra['profiles'] = [
        {'id': optionA, 'display_name': 'Ученица группы'},
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: RemoteSchoolScreen(backend: backend, api: api),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Группы'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Группа школы'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Написать ученице группы'));
      await tester.tap(find.text('Написать ученице группы'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ученица группы').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Проверка');
      await tester.enterText(find.byType(TextField).last, 'Работа принята.');
      await tester.tap(find.text('Готово'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Подтвердить'));
      await tester.pumpAndSettle();
      final create = api.writes.firstWhere(
        (row) => row['name'] == 'create_notification',
      );
      expect(create['params']['p_student_id'], optionA);
      expect(create['params']['p_group_id'], question);
      expect(
        create['params']['p_idempotency_key'],
        matches(RegExp(r'^[a-f0-9-]{36}$')),
      );
      expect(api.writes.last['name'], 'notification_dispatch_status');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      backend.dispose();
    },
  );

  testWidgets(
    'native dialogue creation preserves every content array without unsupported position',
    (tester) async {
      final backend = _Backend(), api = _Api(backend);
      await tester.pumpWidget(
        MaterialApp(
          home: SchoolLessonEditor(api: api, id: lesson),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Диалоги'),
        400,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      final section = find
          .ancestor(of: find.text('Диалоги'), matching: find.byType(Column))
          .first;
      final add = find.descendant(
        of: section,
        matching: find.widgetWithText(OutlinedButton, 'Добавить материал'),
      );
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Новый диалог');
      await tester.tap(find.text('Готово'));
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, 'Сохранить урок');
      await tester.scrollUntilVisible(
        save,
        -400,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(save);
      await tester.pumpAndSettle();
      final content = api.writes.single['params']['p_content'] as Map;
      expect(content.keys.toSet(), SchoolLessonDraft.sections.toSet());
      expect((content['dialogues'] as List).last['title'], 'Новый диалог');
      expect(
        (content['dialogues'] as List).last.containsKey('position'),
        isFalse,
      );
      expect(
        (content['dialogues'] as List).first['lines'].single['text_ar'],
        'مَرْحَبًا',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      backend.dispose();
    },
  );
  testWidgets(
    'administrator adds only a server-enrolled profile with exact membership RPC',
    (tester) async {
      final backend = _Backend(role: ServerRole.admin), api = _Api(backend);
      api.extra['enrollments'] = [
        {'course_id': course, 'student_id': optionA},
      ];
      api.extra['profiles'] = [
        {'id': optionA, 'display_name': 'Зарегистрированная ученица'},
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: RemoteSchoolScreen(backend: backend, api: api),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Группы'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Группа школы'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Добавить из записанных на курс'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Зарегистрированная ученица'));
      await tester.pumpAndSettle();
      expect(api.writes.single['name'], 'set_group_member');
      expect(api.writes.single['params'], {
        'p_group_id': question,
        'p_student_id': optionA,
        'p_active': true,
      });
      expect(
        api.reads.where((r) => r['table'] == 'enrollments').last['filters'],
        {'course_id': course, 'student_id': optionA},
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      backend.dispose();
    },
  );
  testWidgets(
    'native exercise builder uses generated question and option UUIDs as exact answers',
    (tester) async {
      final backend = _Backend(),
          api = _Api(backend),
          draft = SchoolExerciseDraft.create(lesson);
      await tester.pumpWidget(
        MaterialApp(
          home: SchoolExerciseEditor(api: api, draft: draft),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Выберите слово',
      );
      await tester.ensureVisible(find.text('Добавить вопрос'));
      await tester.tap(find.text('Добавить вопрос'));
      await tester.pumpAndSettle();
      final fields = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.at(0), 'اخْتَرْ');
      await tester.enterText(fields.at(1), 'Выберите книгу');
      await tester.tap(find.text('Готово'));
      await tester.pumpAndSettle();
      for (final label in ['كِتَابٌ', 'قَلَمٌ']) {
        await tester.scrollUntilVisible(
          find.text('Добавить вариант'),
          250,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.text('Добавить вариант'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          ),
          label,
        );
        expect(
          tester
              .widget<EditableText>(
                find.descendant(
                  of: find.byType(AlertDialog),
                  matching: find.byType(EditableText),
                ),
              )
              .textDirection,
          TextDirection.rtl,
        );
        await tester.tap(find.text('Готово'));
        await tester.pumpAndSettle();
      }
      final correct = find.widgetWithText(CheckboxListTile, 'كِتَابٌ');
      await tester.ensureVisible(correct);
      expect(
        Directionality.of(tester.element(find.text('كِتَابٌ'))),
        TextDirection.rtl,
      );
      await tester.tap(correct);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Сохранить упражнение'),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Сохранить упражнение'));
      await tester.pumpAndSettle();
      final params = api.writes.single['params'];
      final row = (params['p_questions'] as List).single;
      expect(params['p_exercise_id'], draft.exercise['id']);
      expect(params['p_expected_version'], 0);
      expect(row['id'], matches(RegExp(r'^[a-f0-9-]{36}$')));
      expect(row['accepted_answers'], [(row['options'] as List).first['id']]);
      expect(
        (row['options'] as List).last['id'],
        isNot((row['options'] as List).first['id']),
      );
      expect(row['prompt']['text_ar'], 'اخْتَرْ');
      expect(draft.exercise['version'], 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      backend.dispose();
    },
  );
  testWidgets(
    'teacher invitation displays only a validated server-issued expiring code',
    (tester) async {
      final backend = _Backend(), api = _Api(backend);
      api.replies['create_group_invite'] = {
        'code': '0123456789abcdef0123456789abcdef',
        'expires_at': '2026-10-13T10:00:00Z',
      };
      await tester.pumpWidget(
        MaterialApp(
          home: RemoteSchoolScreen(backend: backend, api: api),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Группы'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Группа школы'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Создать приглашение группы'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Подтвердить'));
      await tester.pumpAndSettle();
      expect(api.writes.single['params'], {'p_group_id': question});
      expect(
        find.textContaining('0123456789abcdef0123456789abcdef'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      backend.dispose();
    },
  );
  testWidgets(
    'missing invitation endpoint shows activation error and never fabricates a code',
    (tester) async {
      final backend = _Backend(),
          api = _Api(backend)
            ..writeError = const PostgrestException(
              message: 'Missing create_group_invite',
              code: 'PGRST202',
            );
      await tester.pumpWidget(
        MaterialApp(
          home: RemoteSchoolScreen(backend: backend, api: api),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Группы'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Группа школы'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Создать приглашение группы'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Подтвердить'));
      await tester.pumpAndSettle();
      expect(api.writes.single['name'], 'create_group_invite');
      expect(api.writes.single['params'], {'p_group_id': question});
      expect(
        find.textContaining('Функция школы ещё не активирована'),
        findsWidgets,
      );
      expect(find.byType(SelectableText), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      backend.dispose();
    },
  );
}

class _Backend extends BackendService {
  _Backend({this.role = ServerRole.teacher});
  ServerRole role;
  String uid = user;
  bool failRole = false;
  @override
  bool get isAuthenticated => true;
  @override
  String? get userId => uid;
  @override
  Future<ServerRole> loadRole() async {
    if (failRole) throw const IntegrationException('role unavailable');
    return role;
  }

  void changeRole(ServerRole value) {
    role = value;
    notifyListeners();
  }

  void changeUser(String value) {
    uid = value;
    notifyListeners();
  }
}

class _Api extends RemoteSchoolApi {
  _Api(super.backend);
  final reads = <Map<String, dynamic>>[], writes = <Map<String, dynamic>>[];
  bool readError = false;
  final extra = <String, List<Map<String, dynamic>>>{};
  Object? writeError;
  final replies = <String, Map<String, dynamic>>{};
  @override
  Future<List<Map<String, dynamic>>> courses() =>
      query('courses', order: 'title');
  @override
  Future<List<Map<String, dynamic>>> query(
    String table, {
    Map<String, dynamic> filters = const {},
    Map<String, List<dynamic>> within = const {},
    String order = 'id',
    String columns = '*',
  }) async {
    await guard();
    reads.add({
      'table': table,
      'filters': filters,
      'within': within,
      'columns': columns,
    });
    if (readError) throw const IntegrationException('offline');
    final data = <String, List<Map<String, dynamic>>>{
      'courses': [
        {'id': course, 'title': 'Курс школы', 'status': 'draft'},
      ],
      'levels': [
        {
          'id': level,
          'course_id': course,
          'title': 'Уровень школы',
          'position': 0,
        },
      ],
      'books': [
        {'id': book, 'level_id': level, 'title': 'Книга школы', 'position': 0},
      ],
      'units': [
        {'id': unit, 'book_id': book, 'title': 'Раздел школы', 'position': 0},
      ],
      'lessons': [lessonRow()],
      'lesson_blocks': List<Map<String, dynamic>>.from(body()['blocks']),
      'dialogues': List<Map<String, dynamic>>.from(
        body()['dialogues'],
      ).map((row) => clone(row)..remove('lines')).toList(),
      'dialogue_lines': List<Map<String, dynamic>>.from(
        (body()['dialogues'] as List).single['lines'],
      ),
      'vocabulary': List<Map<String, dynamic>>.from(body()['vocabulary']),
      'grammar': List<Map<String, dynamic>>.from(body()['grammar']),
      'groups': [
        {
          'id': question,
          'title': 'Группа школы',
          'course_id': course,
          'teacher_id': user,
          'archived_at': null,
        },
      ],
      'attempts': [
        {
          'id': optionA,
          'student_id': user,
          'status': 'pending_review',
          'score': null,
          'max_score': 2,
          'answers': {'text': 'Submitted'},
          'created_at': '2026-10-12T00:00:00Z',
        },
      ],
    };
    return (extra[table] ?? data[table] ?? []).map(clone).toList();
  }

  @override
  Future<dynamic> rpc(String name, Map<String, dynamic> params) async {
    await guard();
    writes.add({'name': name, 'params': clone(params)});
    if (writeError != null) throw writeError!;
    if (replies.containsKey(name)) return clone(replies[name]!);
    if (name == 'create_notification') {
      return {
        'id': optionB,
        'body': params['p_body'],
        'user_id': params['p_student_id'],
      };
    }
    if (name == 'notification_dispatch_status') {
      return {
        'notification_id': params['p_notification_id'],
        'state': 'not_dispatched',
        'accepted_count': 0,
        'failed_count': 0,
      };
    }
    if (name == 'save_exercise') {
      return {
        'id': params['p_exercise_id'],
        'lesson_id': params['p_lesson_id'],
        ...params['p_definition'] as Map,
        'version': (params['p_expected_version'] as int) + 1,
      };
    }
    if (name == 'save_lesson') {
      return {...lessonRow(), ...params['p_patch'] as Map, 'version': 4};
    }
    return {
      'id': optionB,
      'title': params['p_title'],
      'position': params['p_position'],
    };
  }
}
