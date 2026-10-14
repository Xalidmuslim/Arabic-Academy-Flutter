import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/academy_state.dart';

/// Standalone, persistent simulation. Never grants server permissions and
/// never sends messages or push notifications to external devices.
class DemoSchoolStore extends ChangeNotifier {
  DemoSchoolStore(this.prefs) {
    final saved = prefs.getString(storageKey);
    if (saved != null) {
      try {
        final snapshot = jsonDecode(saved);
        if (snapshot is! Map || snapshot['version'] != 1) {
          throw const FormatException('Unsupported demo workspace');
        }
        for (final key in _collections) {
          if (snapshot[key] is! List ||
              (snapshot[key] as List).any((item) => item is! Map)) {
            throw FormatException('Invalid demo field: $key');
          }
        }
        _data = Map<String, dynamic>.from(snapshot);
      } catch (_) {
        readOnly = true;
        warning = 'Повреждённые демоданные сохранены без изменений. Экспортируйте исходную резервную копию.';
      }
    }
  }

  static const storageKey = 'bayna_demo_school_v1';
  static const _collections = [
    'groups', 'students', 'assignments', 'submissions',
    'sessions', 'announcements', 'lesson_results',
  ];
  final SharedPreferences prefs;
  bool readOnly = false;
  String? warning;
  Future<void> _pending = Future.value();

  Map<String, dynamic> _data = {
    'version': 1,
    'current_student': 's1',
    'groups': [
      {'id': 'g1', 'name': 'Группа А · Начальный', 'level': 'A1'},
      {'id': 'g2', 'name': 'Группа Б · Начальный', 'level': 'A1'},
      {'id': 'g3', 'name': 'Группа В · Продолжение', 'level': 'A2'},
    ],
    'students': [
      {'id': 's1', 'name': 'Амина', 'group_id': 'g1'},
      {'id': 's2', 'name': 'Фатима', 'group_id': 'g1'},
      {'id': 's3', 'name': 'Марьям', 'group_id': 'g1'},
      {'id': 's4', 'name': 'Хадиджа', 'group_id': 'g2'},
      {'id': 's5', 'name': 'Асия', 'group_id': 'g2'},
      {'id': 's6', 'name': 'Зайнаб', 'group_id': 'g2'},
      {'id': 's7', 'name': 'Сафия', 'group_id': 'g3'},
      {'id': 's8', 'name': 'Рукия', 'group_id': 'g3'},
      {'id': 's9', 'name': 'Хафса', 'group_id': 'g3'},
    ],
    'assignments': [
      {
        'id': 'a1', 'title': 'Знакомство на арабском', 'instructions':
            'Напишите 5 предложений о себе по-арабски.',
        'group_id': 'g1', 'student_id': null,
        'created_at': '2026-10-01T09:00:00.000Z', 'due_at': null,
      },
      {
        'id': 'a2', 'title': 'Слова о семье',
        'instructions': 'Составьте короткий рассказ о семье из 6 предложений.',
        'group_id': 'g2', 'student_id': null,
        'created_at': '2026-10-01T09:00:00.000Z', 'due_at': null,
      },
    ],
    'submissions': [
      {
        'id': 'sub1', 'assignment_id': 'a1', 'student_id': 's2',
        'answer': 'اسمي فاطمة. أنا طالبة. أتعلم العربية.',
        'status': 'graded', 'grade': 90,
        'feedback': 'Хорошая работа. Добавьте два предложения.',
        'history': [
          {'status': 'submitted', 'at': '2026-10-02T10:00:00.000Z'},
          {'status': 'graded', 'at': '2026-10-03T12:00:00.000Z'},
        ],
        'updated_at': '2026-10-03T12:00:00.000Z',
      },
    ],
    'sessions': [],
    'announcements': [],
    'lesson_results': [
      {'student_id': 's2', 'lesson_id': 'b1', 'score': 90},
      {'student_id': 's3', 'lesson_id': 'b1', 'score': 75},
      {'student_id': 's4', 'lesson_id': 'b1', 'score': 100},
      {'student_id': 's5', 'lesson_id': 'b1', 'score': 85},
    ],
  };

  List<Map<String, dynamic>> _rows(String key) =>
      (_data[key] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  List<Map<String, dynamic>> get groups => _rows('groups');
  List<Map<String, dynamic>> get students => _rows('students');
  List<Map<String, dynamic>> get assignments => _rows('assignments');
  List<Map<String, dynamic>> get submissions => _rows('submissions');
  List<Map<String, dynamic>> get sessions => _rows('sessions');
  List<Map<String, dynamic>> get announcements => _rows('announcements');
  List<Map<String, dynamic>> get lessonResults => _rows('lesson_results');
  String get currentStudentId => _data['current_student'] as String? ?? 's1';

  Map<String, dynamic>? student(String id) {
    for (final row in students) {
      if (row['id'] == id) return row;
    }
    return null;
  }
  Map<String, dynamic>? group(String id) {
    for (final row in groups) {
      if (row['id'] == id) return row;
    }
    return null;
  }
  String groupName(String id) => group(id)?['name'] as String? ?? 'Без группы';
  String studentName(String id) => student(id)?['name'] as String? ?? 'Ученица';
  List<Map<String, dynamic>> members(String groupId) =>
      students.where((row) => row['group_id'] == groupId).toList();

  bool isRecipient(Map<String, dynamic> assignment, String studentId) {
    final pupil = student(studentId);
    if (pupil == null) return false;
    final individual = assignment['student_id'];
    if (individual is String && individual.isNotEmpty) return individual == studentId;
    return assignment['group_id'] == pupil['group_id'];
  }

  List<Map<String, dynamic>> homeworkFor(String studentId) =>
      assignments.where((assignment) => isRecipient(assignment, studentId)).toList()
        ..sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));

  Map<String, dynamic>? submissionFor(String assignmentId, String studentId) {
    for (final row in submissions) {
      if (row['assignment_id'] == assignmentId && row['student_id'] == studentId) {
        return row;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> assignmentsForStudent(String studentId) =>
      homeworkFor(studentId);

  List<Map<String, dynamic>> studentResults(String studentId) =>
      lessonResults.where((x) => x['student_id'] == studentId).toList();

  List<Map<String, dynamic>> sessionsFor(String studentId) {
    final groupId = student(studentId)?['group_id'];
    return sessions.where((x) => x['group_id'] == groupId ||
        x['group_id'] == 'all').toList()
      ..sort((a, b) => (a['starts_at'] as String).compareTo(b['starts_at'] as String));
  }

  List<Map<String, dynamic>> announcementsFor(String studentId) {
    final pupil = student(studentId);
    if (pupil == null) return [];
    return announcements.where((a) => a['group_id'] == 'all' ||
        a['group_id'] == pupil['group_id'] ||
        a['student_id'] == studentId).toList().reversed.toList();
  }

  /// In-app simulation only. Real scheduled push requires a backend scheduler.
  List<Map<String, dynamic>> dueReminders(String studentId, DateTime now) {
    return sessionsFor(studentId).where((row) {
      final starts = DateTime.tryParse(row['starts_at']?.toString() ?? '')?.toLocal();
      final before = row['remind_minutes'];
      if (starts == null || before is! int || before < 0) return false;
      return !now.isBefore(starts.subtract(Duration(minutes: before))) &&
          now.isBefore(starts.add(Duration(minutes: row['duration_minutes'] as int? ?? 60)));
    }).toList();
  }

  Future<void> _change(void Function(Map<String, dynamic>) fn) {
    final task = _pending.catchError((Object _) {}).then((_) async {
      if (readOnly) throw StateError(warning ?? 'Демоархив недоступен.');
      final snapshot = jsonDecode(jsonEncode(_data)) as Map<String, dynamic>;
      fn(snapshot);
      if (!await prefs.setString(storageKey, jsonEncode(snapshot))) {
        throw StateError('Не удалось сохранить демоданные.');
      }
      _data = snapshot;
      notifyListeners();
    });
    _pending = task;
    return task;
  }

  Future<void> selectStudent(String id) => _change((data) {
    if (!students.any((s) => s['id'] == id)) {
      throw StateError('Ученица не найдена.');
    }
    data['current_student'] = id;
  });

  Future<void> createGroup(String name) => _change((data) {
    if (name.trim().isEmpty) throw const FormatException('Укажите название группы.');
    (data['groups'] as List).add({
      'id': AcademyState.newId(), 'name': name.trim(), 'level': 'A1',
    });
  });

  Future<void> addStudent(String groupId, String name) => _change((data) {
    if (name.trim().isEmpty || group(groupId) == null) {
      throw const FormatException('Выберите группу и введите имя.');
    }
    (data['students'] as List).add({
      'id': AcademyState.newId(), 'name': name.trim(), 'group_id': groupId,
    });
  });

  Future<void> createAssignment({
    required String title,
    required String instructions,
    required String groupId,
    String? studentId,
    DateTime? due,
  }) => _change((data) {
    if (title.trim().isEmpty || instructions.trim().isEmpty || group(groupId) == null) {
      throw const FormatException('Заполните название, текст и группу.');
    }
    if (studentId != null && student(studentId)?['group_id'] != groupId) {
      throw StateError('Ученица не входит в выбранную группу.');
    }
    (data['assignments'] as List).add({
      'id': AcademyState.newId(),
      'title': title.trim(), 'instructions': instructions.trim(),
      'group_id': groupId, 'student_id': studentId,
      'due_at': due?.toUtc().toIso8601String(),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  });

  Future<void> submit({
    required String assignmentId,
    required String studentId,
    required String answer,
  }) => _change((data) {
    final matching = assignments.where((a) => a['id'] == assignmentId);
    if (matching.isEmpty || !isRecipient(matching.first, studentId)) {
      throw StateError('Задание не назначено выбранной ученице.');
    }
    if (answer.trim().isEmpty) throw const FormatException('Напишите ответ.');
    final rows = data['submissions'] as List;
    final index = rows.indexWhere((r) => r['assignment_id'] == assignmentId &&
        r['student_id'] == studentId);
    final old = index < 0 ? <String, dynamic>{} : Map<String, dynamic>.from(rows[index] as Map);
    final now = DateTime.now().toUtc().toIso8601String();
    final next = <String, dynamic>{
      ...old,
      'id': old['id'] ?? AcademyState.newId(),
      'assignment_id': assignmentId, 'student_id': studentId,
      'answer': answer.trim(), 'status': 'submitted',
      'grade': null, 'feedback': null, 'updated_at': now,
      'history': [
        ...((old['history'] as List?) ?? []),
        {'status': 'submitted', 'at': now, 'answer': answer.trim()},
      ],
    };
    if (index < 0) { rows.add(next); } else { rows[index] = next; }
  });

  Future<void> grade({
    required String submissionId,
    required int score,
    required String feedback,
    bool revision = false,
  }) => _change((data) {
    if (score < 0 || score > 100) throw const FormatException('Оценка: 0–100.');
    final rows = data['submissions'] as List;
    final index = rows.indexWhere((r) => r['id'] == submissionId);
    if (index < 0) throw StateError('Ответ не найден.');
    final item = rows[index] as Map;
    if (item['status'] != 'submitted' && item['status'] != 'graded' &&
        item['status'] != 'revision_requested') {
      throw StateError('Работа ещё не отправлена.');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    item['status'] = revision ? 'revision_requested' : 'graded';
    item['grade'] = score;
    item['feedback'] = feedback.trim();
    item['updated_at'] = now;
    (item['history'] as List).add({
      'status': item['status'], 'score': score, 'feedback': feedback.trim(), 'at': now,
    });
  });

  Future<void> completeLesson(String studentId, String lessonId, {int score = 100}) =>
      _change((data) {
        if (student(studentId) == null || lessonId.isEmpty) {
          throw StateError('Некорректный урок или ученица.');
        }
        if (score < 0 || score > 100) throw const FormatException('Результат: 0–100.');
        final rows = data['lesson_results'] as List;
        rows.removeWhere((item) => item['student_id'] == studentId &&
            item['lesson_id'] == lessonId);
        rows.add({
          'student_id': studentId, 'lesson_id': lessonId,
          'score': score, 'at': DateTime.now().toUtc().toIso8601String(),
        });
      });

  Future<void> scheduleLive({
    required String title,
    required String groupId,
    required DateTime startsAt,
    required int durationMinutes,
    required int remindMinutes,
  }) => _change((data) {
    if (title.trim().isEmpty || (groupId != 'all' && group(groupId) == null)) {
      throw const FormatException('Укажите название и получателей.');
    }
    if (startsAt.isBefore(DateTime.now())) {
      throw const FormatException('Выберите будущее время начала.');
    }
    if (durationMinutes < 15 || durationMinutes > 240 ||
        remindMinutes < 0 || remindMinutes > 10080) {
      throw const FormatException('Некорректное время занятия или напоминания.');
    }
    (data['sessions'] as List).add({
      'id': AcademyState.newId(), 'title': title.trim(),
      'group_id': groupId, 'starts_at': startsAt.toUtc().toIso8601String(),
      'duration_minutes': durationMinutes, 'remind_minutes': remindMinutes,
      'status': 'scheduled',
    });
  });

  Future<void> setLiveStatus(String sessionId, String status) => _change((data) {
    if (!['live', 'ended'].contains(status)) throw StateError('Некорректный статус.');
    final rows = data['sessions'] as List;
    final i = rows.indexWhere((row) => row['id'] == sessionId);
    if (i < 0) throw StateError('Эфир не найден.');
    (rows[i] as Map)['status'] = status;
  });

  Future<void> announce({
    required String title,
    required String text,
    required String groupId,
  }) => _change((data) {
    if (title.trim().isEmpty || text.trim().isEmpty ||
        (groupId != 'all' && group(groupId) == null)) {
      throw const FormatException('Заполните уведомление и адресатов.');
    }
    (data['announcements'] as List).add({
      'id': AcademyState.newId(), 'title': title.trim(),
      'text': text.trim(), 'group_id': groupId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  });
}
