import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Versioned local workspace. Demo and each server account use separate keys.
/// One serialized write prevents partially saved answers/settings. Legacy data
/// remains backed up, including fields a newer editor does not understand.
class AcademyState extends ChangeNotifier {
  AcademyState(
    this.prefs,
    this.catalog, {
    this.namespace = 'academy_state_v1',
    this.preferencesSource,
  }) {
    final text = prefs.getString(namespace);
    if (text != null) {
      try {
        final value = jsonDecode(text) as Map<String, dynamic>;
        if (value['version'] != 1) {
          throw const FormatException('Unsupported version');
        }
        _validateSnapshot(value);
        _document = value;
        _legacyCorrupt = value['preserve_legacy_materials'] == true;
        if (_legacyCorrupt) {
          storageWarnings.add(
            'Исходные материалы требуют восстановления. Повреждённый JSON сохранён в резервной копии.',
          );
        }
      } catch (_) {
        storageWarnings.add(
          'Сохранение не удалось прочитать. Исходные данные оставлены для восстановления.',
        );
        _blocked = true;
      }
    } else if (_isDemo) {
      _document['completed'] = prefs.getStringList('completed') ?? <String>[];
      final legacy = prefs.getString('teacher_lessons');
      if (legacy != null) {
        try {
          _document['teacher_lessons'] = (jsonDecode(legacy) as List)
              .map((x) => Map<String, dynamic>.from(x as Map))
              .toList();
        } catch (_) {
          _legacyCorrupt = true;
          _document['preserve_legacy_materials'] = true;
          storageWarnings.add(
            'Материалы учительницы повреждены; оригинальный JSON сохранён. Восстановите его из экспорта.',
          );
        }
      }
    }
    _ensureFields();
  }

  final SharedPreferences prefs;
  final Map<String, dynamic> catalog;
  final String namespace;

  /// Visual preferences are shared on the device; learning data is isolated.
  final AcademyState? preferencesSource;
  final List<String> storageWarnings = [];
  bool _blocked = false;
  bool _disposed = false;
  bool _legacyCorrupt = false;
  Future<void> _writes = Future.value();
  Map<String, dynamic> _document = {'version': 1};
  bool get _isDemo => namespace == 'academy_state_v1';

  static void _validateSnapshot(Map<String, dynamic> value) {
    for (final key in ['completed', 'bookmarks', 'applied_events']) {
      final field = value[key];
      if (field != null && (field is! List || field.any((x) => x is! String))) {
        throw FormatException('Invalid $key');
      }
    }
    for (final key in [
      'teacher_lessons',
      'archived_lessons',
      'attempts',
      'events',
      'submissions',
      'study_sessions',
      'groups',
      'live_sessions',
      'sync_conflicts',
    ]) {
      final field = value[key];
      if (field != null && (field is! List || field.any((x) => x is! Map))) {
        throw FormatException('Invalid $key');
      }
    }
    for (final key in ['settings', 'drafts', 'reviews', 'notes']) {
      if (value[key] != null && value[key] is! Map) {
        throw FormatException('Invalid $key');
      }
    }
  }

  static String newId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  void _ensureFields() {
    for (final key in [
      'completed',
      'teacher_lessons',
      'archived_lessons',
      'bookmarks',
      'attempts',
      'events',
      'submissions',
      'study_sessions',
      'groups',
      'live_sessions',
      'applied_events',
      'sync_conflicts',
    ]) {
      _document.putIfAbsent(key, () => <dynamic>[]);
    }
    for (final key in ['settings', 'drafts', 'reviews', 'notes']) {
      _document.putIfAbsent(key, () => <String, dynamic>{});
    }
  }

  List<Map<String, dynamic>> _maps(String key) => (_document[key] as List)
      .map((x) => Map<String, dynamic>.from(x as Map))
      .toList();
  Set<String> get completed =>
      (_document['completed'] as List).cast<String>().toSet();
  Set<String> get bookmarks =>
      (_document['bookmarks'] as List).cast<String>().toSet();
  List<Map<String, dynamic>> get teacherLessons => _maps('teacher_lessons');
  List<Map<String, dynamic>> get archivedLessons => _maps('archived_lessons');
  List<Map<String, dynamic>> get attempts => _maps('attempts');
  List<Map<String, dynamic>> get pendingEvents => _maps('events');
  List<Map<String, dynamic>> get submissions => _maps('submissions');
  List<Map<String, dynamic>> get studySessions => _maps('study_sessions');
  List<Map<String, dynamic>> get groups => _maps('groups');
  List<Map<String, dynamic>> get liveSessions => _maps('live_sessions');
  List<Map<String, dynamic>> get syncConflicts => _maps('sync_conflicts');
  int get syncOffset => _document['sync_offset'] as int? ?? 0;
  Map<String, dynamic> get settings => {
    ...Map<String, dynamic>.from(_document['settings'] as Map),
    if (preferencesSource != null)
      for (final entry in preferencesSource!.settings.entries)
        if (_visualKeys.contains(entry.key)) entry.key: entry.value,
  };
  static const _visualKeys = {
    'language',
    'russianScale',
    'arabicSize',
    'arabicHeight',
    'audioSpeed',
    'reduceMotion',
    'dailyGoal',
  };
  Map<String, dynamic> get drafts =>
      Map<String, dynamic>.from(_document['drafts'] as Map);
  Map<String, dynamic> get reviews =>
      Map<String, dynamic>.from(_document['reviews'] as Map);
  List<dynamic> get units => catalog['modules'] as List? ?? [];
  List<dynamic> get lessons => catalog['lessons'] as List? ?? [];
  List<Map<String, dynamic>> get published =>
      teacherLessons.where((x) => x['published'] == true).toList();
  List<Map<String, dynamic>> get allLessons => [
    ...lessons.map((x) => Map<String, dynamic>.from(x as Map)),
    ...published.where((x) => x['free'] != false).map(asLesson),
  ];

  /// Preserve old editor fields while presenting a full lesson contract.
  static Map<String, dynamic> asLesson(Map<String, dynamic> value) => {
    ...value,
    'title_ar': value['title_ar'] ?? value['arabic'] ?? '',
    'goal': value['goal'] ?? value['description'] ?? '',
    'dialogue': value['dialogue'] ?? <dynamic>[],
    'vocabulary': value['vocabulary'] ?? <dynamic>[],
    'grammar': value['grammar'] ?? '',
    'homework': value['homework'] ?? value['assignment'] ?? '',
    'exercises': value['exercises'] ?? <dynamic>[],
  };

  Future<void> initialize() async {
    if (_blocked) return;
    if (_isDemo) {
      if (!prefs.containsKey('legacy_completed_v1')) {
        await prefs.setStringList(
          'legacy_completed_v1',
          prefs.getStringList('completed') ?? [],
        );
      }
      if (!prefs.containsKey('legacy_teacher_lessons_v1') &&
          prefs.containsKey('teacher_lessons')) {
        await prefs.setString(
          'legacy_teacher_lessons_v1',
          prefs.getString('teacher_lessons')!,
        );
      }
    }
    await _change((_) {});
  }

  Future<void> _change(void Function(Map<String, dynamic>) mutation) {
    final operation = _writes.catchError((Object _) {}).then((_) async {
      if (_blocked) {
        throw StateError(
          'Сохранение заблокировано: сначала восстановите повреждённые данные.',
        );
      }
      final next = jsonDecode(jsonEncode(_document)) as Map<String, dynamic>;
      mutation(next);
      if (!await prefs.setString(namespace, jsonEncode(next))) {
        throw StateError('Не удалось сохранить данные. Повторите действие.');
      }
      _document = next;
      if (_isDemo) {
        await prefs.setStringList('completed', completed.toList());
        if (!_legacyCorrupt) {
          await prefs.setString('teacher_lessons', jsonEncode(teacherLessons));
        }
      }
      if (!_disposed) notifyListeners();
    });
    _writes = operation;
    return operation;
  }

  void _event(
    Map<String, dynamic> doc,
    String type,
    Map<String, dynamic> payload,
  ) {
    (doc['events'] as List).add({
      'id': newId(),
      'event_type': type,
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
      'payload': payload,
    });
  }

  Future<void> finish(String id) => _change((doc) {
    if (!(doc['completed'] as List).contains(id)) {
      (doc['completed'] as List).add(id);
      _event(doc, 'lesson_completed', {'lesson_id': id, 'source': 'local'});
    }
    doc['last_lesson'] = id;
  });

  String? get lastLessonId => _document['last_lesson'] as String?;
  Future<void> visitLesson(String id) =>
      _change((doc) => doc['last_lesson'] = id);

  Future<void> save(Map<String, dynamic> data) => _change((doc) {
    if ((data['id'] as String?)?.isEmpty != false ||
        (data['title'] as String?)?.trim().isEmpty != false) {
      throw const FormatException('Нужны идентификатор и название урока.');
    }
    final list = doc['teacher_lessons'] as List;
    final index = list.indexWhere((x) => x['id'] == data['id']);
    final updated = <String, dynamic>{
      if (index >= 0) ...Map<String, dynamic>.from(list[index] as Map),
      ...data,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (index < 0) {
      list.add(updated);
    } else {
      list[index] = updated;
    }
  });

  Future<void> remove(String id) => _change((doc) {
    final lessons = doc['teacher_lessons'] as List;
    final found = lessons.where((x) => x['id'] == id).toList();
    if (found.isNotEmpty) {
      (doc['archived_lessons'] as List).removeWhere((x) => x['id'] == id);
      (doc['archived_lessons'] as List).add({
        ...found.first as Map,
        'archived_at': DateTime.now().toUtc().toIso8601String(),
      });
      lessons.removeWhere((x) => x['id'] == id);
    }
  });

  Future<void> restoreLesson(String id) => _change((doc) {
    final archived = doc['archived_lessons'] as List;
    final found = archived.where((x) => x['id'] == id).toList();
    if (found.isEmpty) return;
    if ((doc['teacher_lessons'] as List).any((x) => x['id'] == id)) {
      throw StateError('Урок с таким ID уже существует.');
    }
    (doc['teacher_lessons'] as List).add(found.first);
    archived.removeWhere((x) => x['id'] == id);
  });

  Future<void> copyLesson(Map<String, dynamic> source) => save({
    ...source,
    'id': newId(),
    'title': '${source['title']} — копия',
    'published': false,
  });

  Future<void> reorderLessons(List<String> ids) => _change((doc) {
    final materials = doc['teacher_lessons'] as List;
    if (ids.length != materials.length ||
        ids.toSet().length != ids.length ||
        materials.any((x) => !ids.contains(x['id']))) {
      throw const FormatException('Неверный список уроков.');
    }
    materials.sort(
      (a, b) => ids
          .indexOf(a['id'] as String)
          .compareTo(ids.indexOf(b['id'] as String)),
    );
  });

  Future<void> setSetting(String key, dynamic value) async {
    await _change((doc) => (doc['settings'] as Map)[key] = value);
    if (_visualKeys.contains(key) && preferencesSource != null) {
      await preferencesSource!.setSetting(key, value);
    }
  }

  Future<void> toggleBookmark(String id) => _change((doc) {
    final values = doc['bookmarks'] as List;
    if (values.contains(id)) {
      values.remove(id);
    } else {
      values.add(id);
    }
    _event(doc, 'bookmark_changed', {
      'bookmark_id': id,
      'enabled': values.contains(id),
    });
  });
  Future<void> saveDraft(String id, Map<String, dynamic> draft) =>
      _change((doc) {
        (doc['drafts'] as Map)[id] = draft;
        if (!id.startsWith('online_assignment:')) {
          _event(doc, 'draft_saved', {'draft_id': id, 'draft': draft});
        }
      });
  Future<void> saveNote(String id, String text) => _change((doc) {
    (doc['notes'] as Map)[id] = text;
    _event(doc, 'note_saved', {'lesson_id': id, 'text': text});
  });
  String note(String id) => (_document['notes'] as Map)[id] as String? ?? '';

  Future<void> recordAttempt({
    required String lessonId,
    required String exerciseId,
    required dynamic answer,
    required String status,
    required num points,
  }) => _change((doc) {
    if (!['correct', 'incorrect', 'needsReview', 'timedOut'].contains(status)) {
      throw const FormatException('Неизвестный статус ответа.');
    }
    final attempt = {
      'id': newId(),
      'lesson_id': lessonId,
      'exercise_id': exerciseId,
      'answer': answer,
      'status': status,
      'points': points,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    (doc['attempts'] as List).add(attempt);
    _event(doc, 'exercise_attempt', attempt);
    doc['last_lesson'] = lessonId;
  });

  Future<void> acknowledgeEvents(List<String> ids) => _change((doc) {
    (doc['events'] as List).removeWhere((x) => ids.contains(x['id']));
    final applied = doc['applied_events'] as List;
    for (final id in ids) {
      if (!applied.contains(id)) applied.add(id);
    }
  });
  Future<void> advanceSyncOffset(int offset) => _change((doc) {
    doc['sync_offset'] = max(doc['sync_offset'] as int? ?? 0, offset);
  });

  /// Imported local study events are personal self-study history, never server
  /// grades, role assignments, enrollments or paid access entitlements.
  Future<void> mergeLearningEvents(List<Map<String, dynamic>> rows) => _change((
    doc,
  ) {
    final applied = doc['applied_events'] as List;
    for (final row in rows) {
      final key = row['idempotency_key'];
      final envelope = row['payload'];
      if (key is! String ||
          applied.contains(key) ||
          envelope is! Map ||
          envelope['origin'] != 'local_author_learning' ||
          envelope['workspace_version'] != 1 ||
          envelope['local_payload'] is! Map) {
        continue;
      }
      final payload = envelope['local_payload'] as Map;
      final type = envelope['local_type'];
      if (type == 'lesson_completed' && payload['lesson_id'] is String) {
        if (!(doc['completed'] as List).contains(payload['lesson_id'])) {
          (doc['completed'] as List).add(payload['lesson_id']);
        }
      } else if (type == 'exercise_attempt' || type == 'study_session') {
        final bucket = type == 'exercise_attempt'
            ? 'attempts'
            : 'study_sessions';
        if (payload['id'] is! String || payload['lesson_id'] is! String) {
          continue;
        }
        if (type == 'exercise_attempt' &&
            (![
                  'correct',
                  'incorrect',
                  'needsReview',
                  'timedOut',
                ].contains(payload['status']) ||
                payload['points'] is! num ||
                (payload['points'] as num) < 0)) {
          continue;
        }
        if (type == 'study_session' &&
            (payload['seconds'] is! int || (payload['seconds'] as int) <= 0)) {
          continue;
        }
        if (!(doc[bucket] as List).any((x) => x['id'] == payload['id'])) {
          (doc[bucket] as List).add(Map<String, dynamic>.from(payload));
        }
      } else if (type == 'draft_saved' &&
          payload['draft_id'] is String &&
          payload['draft'] is Map) {
        final id = payload['draft_id'] as String;
        final remote = Map<String, dynamic>.from(payload['draft'] as Map);
        final local = (doc['drafts'] as Map)[id];
        if (local == null || jsonEncode(local) == jsonEncode(remote)) {
          (doc['drafts'] as Map)[id] = remote;
        } else {
          (doc['sync_conflicts'] as List).add({
            'id': key,
            'draft_id': id,
            'local': local,
            'remote': remote,
          });
        }
      } else if (type == 'bookmark_changed' &&
          payload['bookmark_id'] is String &&
          payload['enabled'] is bool) {
        final values = doc['bookmarks'] as List;
        values.remove(payload['bookmark_id']);
        if (payload['enabled'] == true) values.add(payload['bookmark_id']);
      } else if (type == 'word_review' &&
          payload['word_id'] is String &&
          payload['review'] is Map) {
        final review = payload['review'] as Map;
        final local = (doc['reviews'] as Map)[payload['word_id']] as Map?;
        final time = DateTime.tryParse(review['last_review'] as String? ?? '');
        final oldTime = DateTime.tryParse(
          local?['last_review'] as String? ?? '',
        );
        if (time != null && (oldTime == null || time.isAfter(oldTime))) {
          (doc['reviews'] as Map)[payload['word_id']] =
              Map<String, dynamic>.from(review);
        }
      } else if (type == 'note_saved' &&
          payload['lesson_id'] is String &&
          payload['text'] is String) {
        final id = payload['lesson_id'] as String;
        final local = (doc['notes'] as Map)[id];
        if (local == null || local == payload['text']) {
          (doc['notes'] as Map)[id] = payload['text'];
        } else {
          // Reuse the explicit conflict chooser; notes are never silently lost.
          (doc['sync_conflicts'] as List).add({
            'id': key,
            'draft_id': 'note:$id',
            'local': {'answer': local},
            'remote': {'answer': payload['text']},
            'note_id': id,
          });
        }
      }
      applied.add(key);
    }
  });

  Future<void> resolveDraftConflict(String id, {required bool useRemote}) =>
      _change((doc) {
        final conflicts = doc['sync_conflicts'] as List;
        final match = conflicts.where((x) => x['id'] == id).toList();
        if (match.isEmpty) return;
        final conflict = match.first as Map;
        if (useRemote) {
          if (conflict['note_id'] != null) {
            (doc['notes'] as Map)[conflict['note_id']] =
                conflict['remote']['answer'];
          } else {
            (doc['drafts'] as Map)[conflict['draft_id']] = conflict['remote'];
          }
        }
        if (conflict['note_id'] != null) {
          _event(doc, 'note_saved', {
            'lesson_id': conflict['note_id'],
            'text': (doc['notes'] as Map)[conflict['note_id']],
          });
        } else {
          _event(doc, 'draft_saved', {
            'draft_id': conflict['draft_id'],
            'draft': (doc['drafts'] as Map)[conflict['draft_id']],
          });
        }
        conflicts.removeWhere((x) => x['id'] == id);
      });

  Future<void> recordStudy(String lessonId, int seconds) => _change((doc) {
    if (seconds <= 0) return;
    final record = {
      'id': newId(),
      'lesson_id': lessonId,
      'seconds': seconds,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    (doc['study_sessions'] as List).add(record);
    _event(doc, 'study_session', record);
  });

  Future<void> reviewWord(String id, bool remembered, {DateTime? now}) =>
      _change((doc) {
        final time = now ?? DateTime.now();
        final old = (doc['reviews'] as Map)[id] as Map? ?? {};
        final stage = remembered ? min((old['stage'] as int? ?? 0) + 1, 5) : 0;
        const intervals = [0, 1, 3, 7, 14, 30];
        (doc['reviews'] as Map)[id] = {
          'stage': stage,
          'difficult': !remembered,
          'last_review': time.toUtc().toIso8601String(),
          'due_at': time
              .add(Duration(days: intervals[stage]))
              .toUtc()
              .toIso8601String(),
          'reviews': (old['reviews'] as int? ?? 0) + 1,
        };
        _event(doc, 'word_review', {
          'word_id': id,
          'remembered': remembered,
          'review': (doc['reviews'] as Map)[id],
        });
      });

  Future<void> submitHomework(
    String lessonId,
    String text, {
    String? audioPath,
  }) => _change((doc) {
    if (text.trim().isEmpty && audioPath == null) {
      throw const FormatException('Добавьте ответ.');
    }
    final list = doc['submissions'] as List;
    final oldIndex = list.indexWhere((x) => x['lesson_id'] == lessonId);
    final old = oldIndex < 0
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(list[oldIndex] as Map);
    final record = {
      ...old,
      'id': old['id'] ?? newId(),
      'lesson_id': lessonId,
      'text': text,
      'audio_path': audioPath,
      'status': 'submitted',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'history': [
        ...old['history'] as List? ?? [],
        {
          'status': 'submitted',
          'text': text,
          'at': DateTime.now().toUtc().toIso8601String(),
        },
      ],
    };
    if (oldIndex < 0) {
      list.add(record);
    } else {
      list[oldIndex] = record;
    }
  });

  Future<void> gradeHomework(
    String id,
    int grade,
    String comment, {
    bool returnForRevision = false,
  }) => _change((doc) {
    if (grade < 0 || grade > 100) {
      throw const FormatException('Оценка должна быть от 0 до 100.');
    }
    final list = doc['submissions'] as List;
    final index = list.indexWhere((x) => x['id'] == id);
    if (index < 0) throw StateError('Работа не найдена.');
    final item = list[index] as Map;
    item['status'] = returnForRevision ? 'revision_requested' : 'graded';
    item['grade'] = grade;
    item['feedback'] = comment;
    (item['history'] as List).add({
      'status': item['status'],
      'grade': grade,
      'feedback': comment,
      'at': DateTime.now().toUtc().toIso8601String(),
    });
  });

  String exportData() => const JsonEncoder.withIndent('  ').convert({
    ..._document,
    'workspace': _isDemo ? 'demo' : 'account',
    'legacy_teacher_lessons': prefs.getString('legacy_teacher_lessons_v1'),
    'unreadable_snapshot': _blocked ? prefs.getString(namespace) : null,
    'warnings': storageWarnings,
  });

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
