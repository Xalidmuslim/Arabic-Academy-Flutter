import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/academy_state.dart';
import '../../services/teacher_word_image_store.dart';
import '../../ui/teacher_word_image_picker.dart';
import '../../ui/components.dart';
import '../exercises/exercises.dart';

class LessonContentDraft {
  LessonContentDraft(Map<String, dynamic> old) {
    for (final key in ['dialogue', 'vocabulary', 'exercises']) {
      items[key] = [
        for (final value in old[key] as List? ?? [])
          jsonDecode(jsonEncode(value)) as Map<String, dynamic>,
      ];
    }
    for (final entry in items['vocabulary']!.asMap().entries) {
      entry.value.putIfAbsent('id', () => entry.key.toString());
    }
    grammar = old['grammar'] as String? ?? '';
  }
  final Map<String, List<Map<String, dynamic>>> items = {};
  String grammar = '';
  Map<String, dynamic> toJson() => {...items, 'grammar': grammar};
}

class LessonContentEditor extends StatefulWidget {
  const LessonContentEditor({super.key, required this.draft});
  final LessonContentDraft draft;
  @override
  State<LessonContentEditor> createState() => _LessonContentEditorState();
}

class _LessonContentEditorState extends State<LessonContentEditor> {
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionTitle('Содержание урока'),
      for (final section in [
        ('dialogue', 'Диалог', 'Добавить реплику'),
        ('vocabulary', 'Словарь', 'Добавить слово'),
      ]) ...[
        Text(section.$2, style: Theme.of(context).textTheme.titleMedium),
        ...widget.draft.items[section.$1]!.asMap().entries.map(
          (entry) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: NaskhText(entry.value['ar'] as String? ?? '', size: 24),
            subtitle: Text(entry.value['ru'] as String? ?? ''),
            onTap: () => _pair(section.$1, index: entry.key),
            trailing: IconButton(
              tooltip: 'Удалить строку',
              icon: const Icon(Icons.close),
              onPressed: () => setState(
                () => widget.draft.items[section.$1]!.removeAt(entry.key),
              ),
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => _pair(section.$1),
          icon: const Icon(Icons.add),
          label: Text(section.$3),
        ),
        const SizedBox(height: 12),
      ],
      TextFormField(
        initialValue: widget.draft.grammar,
        minLines: 3,
        maxLines: 10,
        decoration: const InputDecoration(labelText: 'Объяснение грамматики'),
        onChanged: (value) => widget.draft.grammar = value,
      ),
      const SectionTitle('Интерактивные задания'),
      ...widget.draft.items['exercises']!.asMap().entries.map(
        (entry) => ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(entry.value['prompt'] as String? ?? 'Задание'),
          subtitle: Text(entry.value['kind'] as String? ?? ''),
          onTap: () => _exercise(index: entry.key),
          trailing: IconButton(
            tooltip: 'Удалить задание',
            icon: const Icon(Icons.close),
            onPressed: () => setState(
              () => widget.draft.items['exercises']!.removeAt(entry.key),
            ),
          ),
        ),
      ),
      OutlinedButton.icon(
        onPressed: _exercise,
        icon: const Icon(Icons.add),
        label: const Text('Добавить упражнение'),
      ),
    ],
  );

  Future<void> _pair(String section, {int? index}) async {
    final old = index == null
        ? <String, dynamic>{}
        : widget.draft.items[section]![index];
    final arabic = TextEditingController(text: old['ar'] as String? ?? '');
    final russian = TextEditingController(text: old['ru'] as String? ?? '');
    final example = TextEditingController(
      text: old['example_ar'] as String? ?? '',
    );
    final root = TextEditingController(text: old['root'] as String? ?? '');
    final form = GlobalKey<FormState>();
    Uint8List? selectedPicture;
    var pictureCleared = false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          section == 'dialogue' ? 'Реплика диалога' : 'Словарная запись',
        ),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: arabic,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontFamily: 'NotoNaskhArabic',
                    fontSize: 25,
                    height: 1.8,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Арабский текст',
                  ),
                  validator: (value) => value?.trim().isEmpty != false
                      ? 'Введите арабский текст'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: russian,
                  decoration: const InputDecoration(
                    labelText: 'Русский перевод',
                  ),
                  validator: (value) =>
                      value?.trim().isEmpty != false ? 'Введите перевод' : null,
                ),
                if (section == 'vocabulary') ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: root,
                    textDirection: TextDirection.rtl,
                    decoration: const InputDecoration(
                      labelText: 'Корень, если применимо',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: example,
                    textDirection: TextDirection.rtl,
                    decoration: const InputDecoration(
                      labelText: 'Пример употребления',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TeacherWordImagePicker(
                    initialPath: old['image_path'] as String?,
                    onChanged: (bytes, cleared) {
                      selectedPicture = bytes;
                      pictureCleared = cleared;
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
    if (saved == true && mounted) {
      String? picturePath = old['image_path'] as String?;
      if (pictureCleared) picturePath = '';
      var pictureSaved = true;
      if (section == 'vocabulary' && selectedPicture != null) {
        try {
          picturePath = await TeacherWordImageStore.save(selectedPicture!);
        } catch (error) {
          pictureSaved = false;
          if (mounted) notice(context, 'Не удалось сохранить рисунок: $error');
        }
      }
      if (pictureSaved && mounted) {
      final value = {
        ...old,
        if (section == 'vocabulary') 'id': old['id'] ?? AcademyState.newId(),
        'ar': arabic.text.trim(),
        'ru': russian.text.trim(),
        if (section == 'vocabulary') 'root': root.text.trim(),
        if (section == 'vocabulary') 'example_ar': example.text.trim(),
        if (section == 'vocabulary') 'image_path': picturePath ?? '',
      };
      setState(() {
        if (index == null) {
          widget.draft.items[section]!.add(value);
        } else {
          widget.draft.items[section]![index] = value;
        }
      });
      }
    }
    arabic.dispose();
    russian.dispose();
    example.dispose();
    root.dispose();
  }

  Future<void> _exercise({int? index}) async {
    final old = index == null ? null : widget.draft.items['exercises']![index];
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => ExerciseEditor(initial: old)),
    );
    if (result != null && mounted) {
      setState(() {
        if (index == null) {
          widget.draft.items['exercises']!.add(result);
        } else {
          widget.draft.items['exercises']![index] = result;
        }
      });
    }
  }
}

class ExerciseEditor extends StatefulWidget {
  const ExerciseEditor({super.key, this.initial});
  final Map<String, dynamic>? initial;
  @override
  State<ExerciseEditor> createState() => _ExerciseEditorState();
}

class _ExerciseEditorState extends State<ExerciseEditor> {
  final _form = GlobalKey<FormState>();
  late ExerciseKind _kind;
  late final TextEditingController _prompt,
      _options,
      _answer,
      _explanation,
      _time,
      _attempts,
      _points,
      _threshold;
  List<Map<String, dynamic>> _questions = [];
  Set<int> _selected = {0};
  bool _shuffle = true;
  bool _ignoreDiacritics = false;
  String? _error;
  static const labels = <ExerciseKind, String>{
    ExerciseKind.singleChoice: 'Один правильный ответ',
    ExerciseKind.multipleChoice: 'Несколько правильных ответов',
    ExerciseKind.fillBlank: 'Пропущенное слово',
    ExerciseKind.wordOrder: 'Составить предложение',
    ExerciseKind.sentenceOrder: 'Порядок слов',
    ExerciseKind.matching: 'Слово и перевод',
    ExerciseKind.imageMatching: 'Изображение и слово',
    ExerciseKind.translation: 'Перевод предложения',
    ExerciseKind.shortAnswer: 'Написать слово',
    ExerciseKind.dictation: 'Диктант',
    ExerciseKind.listeningChoice: 'Аудирование: выбор',
    ExerciseKind.readingComprehension: 'Вопрос по фрагменту',
    ExerciseKind.conjugation: 'Спряжение глагола',
    ExerciseKind.categorization: 'Род, число и местоимения',
    ExerciseKind.errorCorrection: 'Исправление ошибок',
    ExerciseKind.diacritics: 'Окончания и огласовки',
    ExerciseKind.table: 'Заполнение таблицы',
    ExerciseKind.pronunciation: 'Устное повторение',
    ExerciseKind.speaking: 'Запись ответа',
    ExerciseKind.dialogue: 'Разговорный диалог',
    ExerciseKind.writing: 'Домашняя работа: ручная проверка',
    ExerciseKind.trueFalse: 'Верно или неверно',
    ExerciseKind.fillBlanks: 'Несколько пропусков',
    ExerciseKind.imageChoice: 'Выбор по изображению',
    ExerciseKind.listeningMatching: 'Аудирование: соответствия',
    ExerciseKind.quiz: 'Мини-викторина',
    ExerciseKind.exam: 'Итоговый экзамен',
  };
  bool get _choice => [
    ExerciseKind.singleChoice,
    ExerciseKind.multipleChoice,
    ExerciseKind.listeningChoice,
    ExerciseKind.imageChoice,
    ExerciseKind.readingComprehension,
  ].contains(_kind);
  bool get _composite =>
      _kind == ExerciseKind.quiz || _kind == ExerciseKind.exam;
  bool get _manual => [
    ExerciseKind.writing,
    ExerciseKind.speaking,
    ExerciseKind.pronunciation,
    ExerciseKind.dialogue,
  ].contains(_kind);
  bool get _pairs => [
    ExerciseKind.matching,
    ExerciseKind.imageMatching,
    ExerciseKind.listeningMatching,
    ExerciseKind.categorization,
    ExerciseKind.table,
    ExerciseKind.fillBlanks,
    ExerciseKind.conjugation,
  ].contains(_kind);
  List<String> get _variants => _options.text
      .split('\n')
      .map((x) => x.trim())
      .where((x) => x.isNotEmpty)
      .toList();

  @override
  void initState() {
    super.initState();
    final old = widget.initial ?? {};
    _questions = [
      for (final question in old['questions'] as List? ?? [])
        Map<String, dynamic>.from(question as Map),
    ];
    _kind = ExerciseKind.parse(old['kind']);
    if (_kind == ExerciseKind.unknown) _kind = ExerciseKind.singleChoice;
    _prompt = TextEditingController(text: old['prompt'] as String? ?? '');
    _options = TextEditingController(
      text: ((old['options'] ?? old['words']) as List? ?? []).join('\n'),
    );
    final answer = old['correct'];
    _answer = TextEditingController(
      text: answer is Map
          ? answer.entries.map((e) => '${e.key} = ${e.value}').join('\n')
          : answer is List && !_choice
          ? answer.join(' ')
          : answer is String
          ? answer
          : '',
    );
    if (answer is int) _selected = {answer};
    if (answer is List && answer.every((x) => x is int)) {
      _selected = answer.cast<int>().toSet();
    }
    _explanation = TextEditingController(
      text: old['explanation'] as String? ?? '',
    );
    final config = old['config'] as Map? ?? {};
    _time = TextEditingController(text: '${config['timeLimitSeconds'] ?? ''}');
    _attempts = TextEditingController(text: '${config['maxAttempts'] ?? 3}');
    _points = TextEditingController(text: '${config['points'] ?? 1}');
    _threshold = TextEditingController(
      text: '${((config['passThreshold'] as num? ?? 1) * 100).round()}',
    );
    _shuffle = config['randomizeOptions'] != false;
    _ignoreDiacritics = config['ignoreDiacritics'] == true;
  }

  @override
  void dispose() {
    for (final control in [
      _prompt,
      _options,
      _answer,
      _explanation,
      _time,
      _attempts,
      _points,
      _threshold,
    ]) {
      control.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    try {
      dynamic correct;
      if (_composite) {
        if (_questions.isEmpty) {
          throw const FormatException(
            'Добавьте вопросы викторины или экзамена.',
          );
        }
      } else if (_choice) {
        if (_variants.length < 2 ||
            _selected.isEmpty ||
            _selected.any((x) => x >= _variants.length)) {
          throw const FormatException(
            'Добавьте минимум два варианта и укажите правильный ответ.',
          );
        }
        correct = _kind == ExerciseKind.multipleChoice
            ? (_selected.toList()..sort())
            : _selected.first;
      } else if (_pairs) {
        final values = <String, String>{};
        for (final row
            in _answer.text.split('\n').where((x) => x.trim().isNotEmpty)) {
          final parts = row.split('=');
          if (parts.length != 2 ||
              parts.any((x) => x.trim().isEmpty) ||
              values.containsKey(parts[0].trim())) {
            throw const FormatException(
              'Каждая строка: уникальный элемент = правильный ответ.',
            );
          }
          values[parts[0].trim()] = parts[1].trim();
        }
        if (values.isEmpty) {
          throw const FormatException('Добавьте правильные пары/ячейки.');
        }
        correct = values;
      } else if (_kind == ExerciseKind.wordOrder ||
          _kind == ExerciseKind.sentenceOrder) {
        correct = _answer.text.trim().split(RegExp(r'\s+'));
        if (_answer.text.trim().isEmpty) {
          throw const FormatException('Введите правильное предложение.');
        }
      } else if (_kind == ExerciseKind.trueFalse) {
        correct = _selected.contains(0);
      } else if (!_manual) {
        correct = _answer.text.trim();
        if (correct.isEmpty) {
          throw const FormatException('Укажите правильный ответ.');
        }
      }
      final result = <String, dynamic>{
        ...widget.initial ?? {},
        'id': widget.initial?['id'] ?? AcademyState.newId(),
        'kind': _kind.name,
        'prompt': _prompt.text.trim(),
        'explanation': _explanation.text.trim(),
        if (_choice) 'options': _variants,
        if (_kind == ExerciseKind.wordOrder ||
            _kind == ExerciseKind.sentenceOrder)
          'words': correct,
        'correct': correct,
        if (_composite) 'questions': _questions,
        'config': {
          'maxAttempts': int.tryParse(_attempts.text) ?? 0,
          'points': _manual ? 0 : int.tryParse(_points.text) ?? -1,
          'randomizeOptions': _shuffle,
          'ignoreDiacritics': _ignoreDiacritics,
          'passThreshold': (double.tryParse(_threshold.text) ?? -1) / 100,
          if (_time.text.trim().isNotEmpty)
            'timeLimitSeconds': int.tryParse(_time.text) ?? 0,
        },
      };
      Exercise.fromJson(result); // Same validation used by the learner runtime.
      Navigator.pop(context, result);
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Конструктор задания')),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 150),
        children: [
          DropdownButtonFormField<ExerciseKind>(
            initialValue: _kind,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Тип задания'),
            items: labels.entries
                .map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
            onChanged: (kind) => setState(() {
              _kind = kind!;
              _selected = {0};
            }),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _prompt,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Вопрос или инструкция',
            ),
            validator: (value) =>
                value?.trim().isEmpty != false ? 'Введите вопрос' : null,
          ),
          const SizedBox(height: 12),
          if (_choice) ...[
            TextFormField(
              controller: _options,
              minLines: 3,
              maxLines: 10,
              decoration: const InputDecoration(
                labelText: 'Варианты: один на строку',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            const Text('Отметьте правильный ответ:'),
            ..._variants.asMap().entries.map(
              (entry) => CheckboxListTile(
                title: Text(entry.value),
                value: _selected.contains(entry.key),
                onChanged: (selected) => setState(() {
                  if (_kind != ExerciseKind.multipleChoice) _selected.clear();
                  if (selected == true) {
                    _selected.add(entry.key);
                  } else {
                    _selected.remove(entry.key);
                  }
                }),
              ),
            ),
          ],
          if (!_choice &&
              !_manual &&
              !_composite &&
              _kind != ExerciseKind.trueFalse)
            TextFormField(
              controller: _answer,
              minLines: _pairs ? 3 : 1,
              maxLines: 10,
              decoration: InputDecoration(
                labelText: _pairs
                    ? 'Пары или ячейки: элемент = ответ, по одной на строку'
                    : 'Правильный ответ',
              ),
            ),
          if (_composite) ...[
            ..._questions.asMap().entries.map(
              (entry) => ListTile(
                title: Text(entry.value['prompt'] as String? ?? 'Вопрос'),
                trailing: IconButton(
                  tooltip: 'Удалить вопрос',
                  icon: const Icon(Icons.close),
                  onPressed: () =>
                      setState(() => _questions.removeAt(entry.key)),
                ),
              ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Добавить вопрос'),
              onPressed: () async {
                final question = await Navigator.push<Map<String, dynamic>>(
                  context,
                  MaterialPageRoute(builder: (_) => const ExerciseEditor()),
                );
                if (question != null && mounted) {
                  setState(() => _questions.add(question));
                }
              },
            ),
          ],
          if (_kind == ExerciseKind.trueFalse)
            SwitchListTile(
              title: const Text('Правильный ответ — верно'),
              value: _selected.contains(0),
              onChanged: (value) =>
                  setState(() => _selected = value ? {0} : {1}),
            ),
          if (_manual)
            const Panel(
              child: Text(
                'Ответ сохраняется для ручной проверки. Автоматические баллы не начисляются. Голос записывается в разделе устной практики.',
              ),
            ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _explanation,
            minLines: 2,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Объяснение правильного ответа',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _attempts,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Количество попыток'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _threshold,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Порог прохождения, %',
            ),
            validator: (value) {
              final number = double.tryParse(value ?? '');
              return number == null || number <= 0 || number > 100
                  ? 'Укажите число от 1 до 100'
                  : null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _time,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Ограничение времени, секунды (необязательно)',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _points,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Баллы'),
          ),
          SwitchListTile(
            title: const Text('Случайный порядок вариантов'),
            value: _shuffle,
            onChanged: (value) => setState(() => _shuffle = value),
          ),
          SwitchListTile(
            title: const Text('Принимать ответы без огласовок'),
            value: _ignoreDiacritics,
            onChanged: (value) => setState(() => _ignoreDiacritics = value),
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Сохранить задание'),
          ),
        ],
      ),
    ),
  );
}
