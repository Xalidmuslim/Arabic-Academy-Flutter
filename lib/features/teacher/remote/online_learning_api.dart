import '../../../services/backend_service.dart';

/// Authenticated learner reads. RLS remains authoritative; this adapter also
/// prevents an in-flight response being reused after switching accounts.
class OnlineLearningApi {
  OnlineLearningApi(this.backend) : owner = backend.userId;
  final BackendService backend;
  final String? owner;
  void requireOwner() {
    if (!backend.isAuthenticated || owner == null || owner != backend.userId) {
      throw const IntegrationException(
        'Войдите в свой аккаунт и откройте экран заново.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    Map<String, dynamic> filters = const {},
    Map<String, List<dynamic>> within = const {},
    String order = 'id',
    String columns = '*',
  }) async {
    requireOwner();
    final rows = <Map<String, dynamic>>[];
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
      if (order != 'id' && table != 'group_members') {
        sorted = sorted.order('id');
      }
      final page = await sorted.range(offset, offset + 199);
      requireOwner();
      rows.addAll(page);
      if (page.length < 200) return rows;
    }
  }

  Future<dynamic> rpc(String name, Map<String, dynamic> params) async {
    requireOwner();
    final result = await backend.client.rpc(name, params: params);
    requireOwner();
    return result;
  }

  Future<Map<String, dynamic>> lessonContent(String id) async {
    requireOwner();
    final data = await backend.lessonContent(id);
    requireOwner();
    final dialogues = await query('dialogues', filters: {'lesson_id': id});
    final lines = await query(
      'dialogue_lines',
      within: {'dialogue_id': dialogues.map((d) => d['id']).toList()},
      order: 'position',
    );
    for (final dialogue in dialogues) {
      dialogue['lines'] = lines
          .where((l) => l['dialogue_id'] == dialogue['id'])
          .toList();
    }
    final media = await query(
      'media',
      filters: {'lesson_id': id, 'upload_state': 'ready'},
    );
    return {
      ...data,
      'dialogues': dialogues,
      'media': media,
      'vocabulary': (data['vocabulary'] as List)
          .where((v) => v['retired_at'] == null)
          .toList(),
    };
  }

  Future<List<Map<String, dynamic>>> exercises(String lessonId) async {
    final rows = await query(
      'exercises',
      filters: {'lesson_id': lessonId, 'published': true},
    );
    for (final row in rows) {
      row['questions'] = await questions(row['id'] as String);
    }
    return rows;
  }

  Future<List<Map<String, dynamic>>> questions(String exerciseId) async {
    final rows = await query(
      'questions',
      filters: {'exercise_id': exerciseId},
      order: 'position',
    );
    final options = await query(
      'question_options',
      within: {'question_id': rows.map((q) => q['id']).toList()},
      order: 'position',
    );
    for (final row in rows) {
      row['options'] = options
          .where((o) => o['question_id'] == row['id'])
          .toList();
    }
    return rows;
  }

  Future<void> completeLesson(String id) async {
    await rpc('complete_lesson', {'p_lesson_id': id});
  }

  Future<Map<String, dynamic>> claimInvite(String code) async {
    final trimmed = code.trim();
    if (!RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(trimmed)) {
      throw const IntegrationException('Введите код приглашения группы.');
    }
    final row = await rpc('claim_group_invite', {'p_code': trimmed});
    if (row is! Map ||
        row['group_id'] is! String ||
        row['course_id'] is! String ||
        row['title'] is! String) {
      throw const IntegrationException(
        'Сервер не подтвердил участие в группе.',
      );
    }
    IntegrationValidation.uuid(row['group_id'] as String);
    IntegrationValidation.uuid(row['course_id'] as String);
    return Map<String, dynamic>.from(row);
  }

  Future<List<Map<String, dynamic>>> assignments() async {
    final memberships = await query(
      'group_members',
      filters: {'student_id': owner, 'left_at': null},
      order: 'group_id',
    );
    final groups = await query(
      'groups',
      within: {'id': memberships.map((m) => m['group_id']).toList()},
      filters: {'archived_at': null},
    );
    final assignments = await query(
      'assignments',
      within: {'group_id': groups.map((g) => g['id']).toList()},
      order: 'created_at',
    );
    final submissions = await query(
      'submissions',
      filters: {'student_id': owner},
      within: {'assignment_id': assignments.map((a) => a['id']).toList()},
    );
    return assignments
        .map(
          (a) => {
            ...a,
            'group_title': groups
                .where((g) => g['id'] == a['group_id'])
                .firstOrNull?['title'],
            'submission': submissions
                .where((s) => s['assignment_id'] == a['id'])
                .firstOrNull,
          },
        )
        .toList();
  }

  Future<Map<String, dynamic>> homeworkDetails(String assignmentId) async {
    final assignments = await query(
      'assignments',
      filters: {'id': assignmentId},
    );
    if (assignments.length != 1) {
      throw const IntegrationException('Задание недоступно вашему аккаунту.');
    }
    final rows = await query(
      'submissions',
      filters: {'assignment_id': assignmentId, 'student_id': owner},
    );
    final submission = rows.firstOrNull;
    final id = submission?['id'];
    final grades = id == null
        ? <Map<String, dynamic>>[]
        : await query(
            'grades',
            filters: {'submission_id': id},
            order: 'revision',
          );
    final feedback = await query(
      'feedback',
      within: {'grade_id': grades.map((g) => g['id']).toList()},
    );
    final history = id == null
        ? <Map<String, dynamic>>[]
        : await query(
            'submission_history',
            filters: {'submission_id': id},
            order: 'revision',
          );
    final requests = id == null
        ? <Map<String, dynamic>>[]
        : await query(
            'revision_requests',
            filters: {'submission_id': id},
            order: 'revision',
          );
    final exercises = await query(
      'exercises',
      filters: {'id': assignments.single['exercise_id'], 'published': true},
    );
    return {
      'assignment': assignments.single,
      'submission': submission,
      'grades': grades,
      'feedback': feedback,
      'history': history,
      'requests': requests,
      'exercise': exercises.firstOrNull,
      'questions': exercises.isEmpty
          ? <Map<String, dynamic>>[]
          : await questions(exercises.single['id'] as String),
    };
  }

  Future<String> mediaUrl(String id) async {
    requireOwner();
    final url = await backend.signedMediaUrl(id);
    requireOwner();
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const IntegrationException(
        'Сервис не подтвердил защищённый адрес материала.',
      );
    }
    return url;
  }
}
