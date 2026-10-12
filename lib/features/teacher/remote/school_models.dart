import 'dart:convert';
import '../../../core/academy_state.dart';
import '../../../services/integration_config.dart';

Map<String, dynamic> copySchoolMap(Map source) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(source)) as Map);
List<Map<String, dynamic>> schoolMaps(dynamic source) => (source as List)
    .map((row) => Map<String, dynamic>.from(row as Map))
    .toList();
String requiredSchoolText(String value, String label) {
  if (value.trim().isEmpty) {
    throw IntegrationException('Заполните поле «$label».');
  }
  return value.trim();
}

class SchoolLessonDraft {
  SchoolLessonDraft(Map<String, dynamic> source, Map<String, dynamic> body)
    : lesson = copySchoolMap(source),
      content = copySchoolMap(body),
      _original = copySchoolMap(body),
      _baseline = copySchoolMap(source);
  final Map<String, dynamic> lesson;
  final Map<String, dynamic> content;
  final Map<String, dynamic> _original;
  Map<String, dynamic>? _baseline;
  bool get dirty =>
      contentChanged ||
      (_baseline != null && jsonEncode(lesson) != jsonEncode(_baseline));
  void initializeBaseline() {
    _baseline ??= copySchoolMap(lesson);
  }

  void accept(Map<String, dynamic> saved) {
    lesson.addAll(saved);
    _baseline = copySchoolMap(lesson);
    _original
      ..clear()
      ..addAll(copySchoolMap(content));
  }

  bool get contentChanged => jsonEncode(content) != jsonEncode(_original);
  List<Map<String, dynamic>> rows(String section) =>
      (content[section] as List).cast<Map<String, dynamic>>();
  static const sections = ['blocks', 'dialogues', 'vocabulary', 'grammar'];
  static const _fields = {
    'blocks': {'id', 'lesson_id', 'step', 'kind', 'body', 'position'},
    'dialogues': {'id', 'lesson_id', 'title', 'lines'},
    'vocabulary': {
      'id',
      'lesson_id',
      'text_ar',
      'translation',
      'transliteration',
      'position',
      'retired_at',
      'root',
      'part_of_speech',
      'gender',
      'number',
      'forms',
      'example_ar',
      'example_translation',
      'level',
    },
    'grammar': {
      'id',
      'lesson_id',
      'title',
      'explanation',
      'examples',
      'position',
      'root',
      'part_of_speech',
      'gender',
      'number',
      'forms',
      'example_ar',
      'example_translation',
      'level',
    },
  };
  String? get contentCompatibilityError {
    for (final section in sections) {
      if (content[section] is! List) {
        return 'Не удалось загрузить все разделы урока. Содержимое не будет заменено.';
      }
      for (final row in rows(section)) {
        if (row.keys.any((key) => !_fields[section]!.contains(key))) {
          return 'В уроке есть новые поля, которые этот редактор не поддерживает. Можно менять только сведения об уроке.';
        }
        if (section == 'blocks' &&
            !const {
              'text',
              'heading',
              'image',
              'audio',
              'video',
              'exercise',
            }.contains(row['kind'])) {
          return 'Неизвестный блок сохранён без изменений. Для изменения содержимого нужен совместимый редактор.';
        }
        if (section == 'grammar' && row['examples'] is! List) {
          return 'Примеры имеют неподдерживаемый формат. Сохранение содержимого закрыто.';
        }
        if (section == 'dialogues') {
          if (row['lines'] is! List) {
            return 'Строки диалога не загружены. Сохранение содержимого закрыто.';
          }
          for (final line in schoolMaps(row['lines'])) {
            if (line.keys.any(
              (key) => !const {
                'id',
                'dialogue_id',
                'speaker',
                'text_ar',
                'translation',
                'position',
              }.contains(key),
            )) {
              return 'В диалоге есть неподдерживаемые поля. Исходные данные сохранены.';
            }
          }
        }
      }
    }
    return null;
  }

  Map<String, dynamic> saveParams({String? status}) {
    final title = requiredSchoolText(
      lesson['title']?.toString() ?? '',
      'Название урока',
    );
    if (contentChanged && contentCompatibilityError != null) {
      throw IntegrationException(contentCompatibilityError!);
    }
    if (utf8.encode(jsonEncode(content)).length > 1024 * 1024) {
      throw const IntegrationException('Содержимое урока превышает 1 МБ.');
    }
    return {
      'p_lesson_id': lesson['id'],
      'p_expected_version': lesson['version'],
      'p_patch': {
        'title': title,
        'title_ar': lesson['title_ar'] ?? '',
        'goal': lesson['goal'] ?? '',
        'status': status ?? lesson['status'],
        'is_free_sample': lesson['is_free_sample'] == true,
        'position': lesson['position'],
        if (lesson.containsKey('source_locator'))
          'source_locator': lesson['source_locator'],
      },
      if (contentChanged)
        'p_content': {
          for (final section in sections) section: _wireRows(section),
        },
    };
  }

  List<Map<String, dynamic>> _wireRows(String section) =>
      rows(section).map((source) {
        final row = copySchoolMap(source)
          ..remove('lesson_id')
          ..remove('retired_at');
        if (row.containsKey('position')) {
          row['position'] = rows(section).indexOf(source);
        }
        if (section == 'blocks') {
          // Positions are unique per step, not across unrelated lesson steps.
          row['position'] = rows(section)
              .take(rows(section).indexOf(source))
              .where((item) => item['step'] == source['step'])
              .length;
        }
        if (section == 'dialogues') {
          row['lines'] = schoolMaps(row['lines'])
              .asMap()
              .entries
              .map(
                (entry) => copySchoolMap(entry.value)
                  ..remove('dialogue_id')
                  ..['position'] = entry.key,
              )
              .toList();
        }
        return row;
      }).toList();
}

class SchoolExerciseDraft {
  SchoolExerciseDraft(
    Map<String, dynamic> source,
    List<Map<String, dynamic>> rows,
  ) : exercise = copySchoolMap(source),
      questions = rows.map(copySchoolMap).toList(),
      existing = (source['version'] as int? ?? 0) > 0;
  factory SchoolExerciseDraft.create(String lessonId) => SchoolExerciseDraft({
    'id': AcademyState.newId(),
    'lesson_id': lessonId,
    'version': 0,
    'kind': 'singleChoice',
    'title': '',
    'grading_mode': 'automatic',
    'pass_percent': 100,
    'published': false,
  }, []);
  final Map<String, dynamic> exercise;
  final List<Map<String, dynamic>> questions;
  final bool existing;
  bool replaceKeys = false;
  static const kinds = {
    'singleChoice': 'Один вариант',
    'multipleChoice': 'Несколько вариантов',
    'shortAnswer': 'Текстовый ответ',
    'writing': 'Ручная проверка',
  };
  String? get compatibilityError {
    if (!kinds.containsKey(exercise['kind'])) {
      return 'Тип упражнения не поддерживается редактором. Исходное упражнение не будет заменено.';
    }
    if (exercise.keys.any(
      (key) => !const {
        'id',
        'lesson_id',
        'version',
        'kind',
        'title',
        'grading_mode',
        'pass_percent',
        'published',
      }.contains(key),
    )) {
      return 'Упражнение содержит новые поля. Нужен совместимый редактор.';
    }
    for (final question in questions) {
      if (question.keys.any(
        (key) => !const {
          'id',
          'exercise_id',
          'prompt',
          'position',
          'points',
          'options',
          'accepted_answers',
          'comparison',
        }.contains(key),
      )) {
        return 'В вопросе есть неподдерживаемые поля. Сохранение закрыто.';
      }
      for (final option in schoolMaps(question['options'] ?? [])) {
        if (option.keys.any(
          (key) =>
              !const {'id', 'question_id', 'label', 'position'}.contains(key),
        )) {
          return 'В варианте ответа есть неподдерживаемые поля. Сохранение закрыто.';
        }
      }
    }
    return null;
  }

  Map<String, dynamic> saveParams() {
    if (compatibilityError != null) {
      throw IntegrationException(compatibilityError!);
    }
    requiredSchoolText(
      exercise['title']?.toString() ?? '',
      'Название упражнения',
    );
    if (questions.isEmpty) {
      throw const IntegrationException('Добавьте хотя бы один вопрос.');
    }
    final automatic = exercise['grading_mode'] == 'automatic';
    if (automatic && existing && !replaceKeys) {
      throw const IntegrationException(
        'Закрытые ответы нельзя читать с сервера. Явно подтвердите их замену и задайте ответы для каждого вопроса.',
      );
    }
    final pass = num.tryParse(exercise['pass_percent'].toString());
    if (pass == null || !pass.isFinite || pass <= 0 || pass > 100) {
      throw const IntegrationException(
        'Проходной процент должен быть от 1 до 100.',
      );
    }
    final wire = questions.asMap().entries.map((entry) {
      final checkedPoints = num.tryParse(entry.value['points'].toString());
      if (checkedPoints == null ||
          !checkedPoints.isFinite ||
          checkedPoints <= 0) {
        throw const IntegrationException(
          'Баллы вопроса должны быть больше нуля.',
        );
      }
      final row = copySchoolMap(entry.value)..remove('exercise_id');
      row['position'] = entry.key;
      if (row['prompt'] is! Map || (row['prompt'] as Map).isEmpty) {
        throw const IntegrationException('Добавьте текст каждого вопроса.');
      }
      row['points'] = checkedPoints;
      row['options'] = schoolMaps(row['options'] ?? [])
          .asMap()
          .entries
          .map(
            (option) => copySchoolMap(option.value)
              ..remove('question_id')
              ..['position'] = option.key,
          )
          .toList();
      if (automatic &&
          (row['accepted_answers'] is! List ||
              (row['accepted_answers'] as List).isEmpty)) {
        throw const IntegrationException(
          'Укажите правильный ответ для каждого вопроса.',
        );
      }
      if (automatic) {
        final accepted = row['accepted_answers'] as List;
        final kind = exercise['kind'];
        final options = schoolMaps(row['options']);
        final ids = options.map((option) => option['id']).toSet();
        if (kind == 'singleChoice' || kind == 'multipleChoice') {
          if (options.length < 2 || ids.length != options.length) {
            throw const IntegrationException(
              'Добавьте два или больше разных вариантов ответа.',
            );
          }
          for (final answer in accepted) {
            final chosen = kind == 'singleChoice'
                ? [answer]
                : answer is List
                ? answer
                : <dynamic>[];
            if (chosen.isEmpty ||
                chosen.any((id) => !ids.contains(id)) ||
                chosen.toSet().length != chosen.length) {
              throw const IntegrationException(
                'Правильный ответ должен состоять из ID существующих вариантов, без повторов.',
              );
            }
          }
        } else if (kind == 'shortAnswer' &&
            accepted.any(
              (answer) => answer is! String || answer.trim().isEmpty,
            )) {
          throw const IntegrationException(
            'Текстовые ответы должны быть непустыми строками.',
          );
        }
      }
      if (!automatic) {
        row.remove('accepted_answers');
        row.remove('comparison');
      }
      return row;
    }).toList();
    return {
      'p_exercise_id': exercise['id'],
      'p_lesson_id': exercise['lesson_id'],
      'p_expected_version': exercise['version'],
      'p_definition': {
        for (final key in ['kind', 'title', 'grading_mode', 'published'])
          key: exercise[key],
        'pass_percent': pass,
      },
      'p_questions': wire,
    };
  }
}
