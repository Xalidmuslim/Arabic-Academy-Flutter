import '../../../services/backend_service.dart';
import 'school_models.dart';

class RemoteSchoolApi {
  RemoteSchoolApi(this.backend);
  final BackendService backend;
  Future<ServerRole> guard() async {
    final owner = backend.userId;
    if (!backend.isAuthenticated || owner == null) {
      throw const IntegrationException(
        'Войдите в серверный аккаунт преподавателя или администратора.',
      );
    }
    final role = await backend.loadRole();
    if (role == ServerRole.student || owner != backend.userId) {
      throw const IntegrationException(
        'Сервер не подтвердил роль преподавателя или администратора.',
      );
    }
    return role;
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    Map<String, dynamic> filters = const {},
    Map<String, List<dynamic>> within = const {},
    String order = 'id',
    String columns = '*',
  }) async {
    await guard();
    final owner = backend.userId;
    final result = <Map<String, dynamic>>[];
    for (var offset = 0; ; offset += 200) {
      var request = backend.client.from(table).select(columns);
      for (final entry in filters.entries) {
        request = entry.value == null
            ? request.isFilter(entry.key, null)
            : request.eq(entry.key, entry.value);
      }
      for (final entry in within.entries) {
        if (entry.value.isEmpty) return [];
        request = request.inFilter(entry.key, entry.value);
      }
      var sorted = request.order(order);
      if (order != 'id' &&
          !const {
            'group_members',
            'course_teachers',
            'enrollments',
          }.contains(table)) {
        sorted = sorted.order('id');
      }
      final page = await sorted.range(offset, offset + 199);
      if (owner != backend.userId) {
        throw const IntegrationException(
          'Аккаунт изменился. Откройте панель заново.',
        );
      }
      result.addAll(page);
      if (page.length < 200) return result;
    }
  }

  Future<dynamic> rpc(String name, Map<String, dynamic> params) async {
    await guard();
    final owner = backend.userId;
    final response = await backend.client.rpc(name, params: params);
    if (owner != backend.userId) {
      throw const IntegrationException('Аккаунт изменился. Обновите данные.');
    }
    return response;
  }

  Future<List<Map<String, dynamic>>> courses() async {
    final role = await guard();
    if (role == ServerRole.admin) return query('courses', order: 'title');
    final assigned = await query(
      'course_teachers',
      filters: {'teacher_id': backend.userId},
      order: 'course_id',
    );
    return query(
      'courses',
      within: {'id': assigned.map((row) => row['course_id']).toList()},
      order: 'title',
    );
  }

  Future<List<Map<String, dynamic>>> groups() async {
    final role = await guard();
    return query(
      'groups',
      filters: {
        'archived_at': null,
        if (role != ServerRole.admin) 'teacher_id': backend.userId,
      },
      order: 'title',
    );
  }

  Future<SchoolLessonDraft> lesson(String id) async {
    final rows = await query('lessons', filters: {'id': id});
    if (rows.length != 1) {
      throw const IntegrationException('Урок недоступен для редактирования.');
    }
    final results = await Future.wait([
      query('lesson_blocks', filters: {'lesson_id': id}, order: 'position'),
      query('dialogues', filters: {'lesson_id': id}),
      query(
        'vocabulary',
        filters: {'lesson_id': id, 'retired_at': null},
        order: 'position',
      ),
      query('grammar', filters: {'lesson_id': id}, order: 'position'),
    ]);
    final dialogues = results[1];
    final lines = await query(
      'dialogue_lines',
      within: {'dialogue_id': dialogues.map((row) => row['id']).toList()},
      order: 'position',
    );
    for (final dialogue in dialogues) {
      dialogue['lines'] = lines
          .where((line) => line['dialogue_id'] == dialogue['id'])
          .toList();
    }
    final latest = await query('lessons', filters: {'id': id});
    if (latest.isEmpty || latest.single['version'] != rows.single['version']) {
      throw const IntegrationException(
        'Урок изменился во время загрузки. Повторите загрузку.',
      );
    }
    return SchoolLessonDraft(rows.single, {
      'blocks': results[0],
      'dialogues': dialogues,
      'vocabulary': results[2],
      'grammar': results[3],
    });
  }

  Future<List<Map<String, dynamic>>> exercises(String lessonId) =>
      query('exercises', filters: {'lesson_id': lessonId});
  Future<SchoolExerciseDraft> exercise(Map<String, dynamic> row) async {
    final questions = await query(
      'questions',
      filters: {'exercise_id': row['id']},
      order: 'position',
    );
    final options = await query(
      'question_options',
      within: {'question_id': questions.map((q) => q['id']).toList()},
      order: 'position',
    );
    for (final question in questions) {
      question['options'] = options
          .where((option) => option['question_id'] == question['id'])
          .toList();
    }
    return SchoolExerciseDraft(row, questions);
  }

  Future<List<Map<String, dynamic>>> enrolledProfiles(String courseId) async {
    final enrolled = await query(
      'enrollments',
      filters: {'course_id': courseId},
      order: 'student_id',
    );
    return query(
      'profiles',
      within: {'id': enrolled.map((row) => row['student_id']).toList()},
      order: 'display_name',
      columns: 'id,display_name',
    );
  }
}
