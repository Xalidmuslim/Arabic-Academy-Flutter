import 'package:flutter/material.dart';

import 'exercise.dart';

typedef ExerciseInputBuilder = Widget Function(ExerciseInputContext input);

/// A renderer only edits an answer; it never decides correctness or completion.
class ExerciseInputContext {
  const ExerciseInputContext({
    required this.exercise,
    required this.answer,
    required this.enabled,
    required this.optionOrder,
    required this.onChanged,
  });

  final Exercise exercise;
  final dynamic answer;
  final bool enabled;
  final List<int> optionOrder;
  final ValueChanged<dynamic> onChanged;
}

/// Add or override a kind through ExerciseRunner.inputBuilders.
final Map<ExerciseKind, ExerciseInputBuilder> defaultExerciseInputBuilders =
    Map.unmodifiable({
      for (final kind in [
        ExerciseKind.singleChoice,
        ExerciseKind.listeningChoice,
        ExerciseKind.imageChoice,
        ExerciseKind.readingComprehension,
      ])
        kind: _choice,
      ExerciseKind.multipleChoice: _multiple,
      ExerciseKind.trueFalse: _boolean,
      ExerciseKind.quiz: _composite,
      ExerciseKind.exam: _composite,
      for (final kind in [ExerciseKind.wordOrder, ExerciseKind.sentenceOrder])
        kind: (input) => _WordOrderInput(input: input),
      for (final kind in [
        ExerciseKind.matching,
        ExerciseKind.listeningMatching,
        ExerciseKind.imageMatching,
        ExerciseKind.categorization,
      ])
        kind: _matching,
      for (final kind in [
        ExerciseKind.fillBlanks,
        ExerciseKind.table,
        ExerciseKind.conjugation,
      ])
        kind: _structured,
      for (final kind in [
        ExerciseKind.fillBlank,
        ExerciseKind.shortAnswer,
        ExerciseKind.translation,
        ExerciseKind.dictation,
        ExerciseKind.errorCorrection,
        ExerciseKind.diacritics,
      ])
        kind: _text,
      for (final kind in [
        ExerciseKind.dialogue,
        ExerciseKind.writing,
        ExerciseKind.speaking,
        ExerciseKind.pronunciation,
        ExerciseKind.unknown,
      ])
        kind: _manual,
    });

Widget _composite(ExerciseInputContext input) {
  final questions = input.exercise.data['questions'];
  if (questions is! List || questions.isEmpty) return _manual(input);
  final answers = input.answer is Map
      ? Map<String, dynamic>.from(input.answer as Map)
      : <String, dynamic>{};
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final raw in questions)
        if (raw is Map) ...[
          Builder(
            builder: (context) {
              final question = Exercise.fromJson(
                Map<String, dynamic>.from(raw),
              );
              final builder =
                  defaultExerciseInputBuilders[question.kind] ?? _manual;
              final order = List.generate(question.options.length, (i) => i);
              if (question.config.randomizeOptions) {
                order.shuffle(exerciseRandom(question));
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    question.prompt,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  builder(
                    ExerciseInputContext(
                      exercise: question,
                      answer: answers[question.id],
                      enabled: input.enabled,
                      optionOrder: order,
                      onChanged: (value) =>
                          input.onChanged({...answers, question.id: value}),
                    ),
                  ),
                  const Divider(height: 28),
                ],
              );
            },
          ),
        ],
    ],
  );
}

Widget _choice(ExerciseInputContext input) => RadioGroup<int>(
  groupValue: input.answer is int ? input.answer as int : null,
  onChanged: (value) {
    if (input.enabled) input.onChanged(value);
  },
  child: Column(
    children: [
      for (final index in input.optionOrder)
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: RadioListTile<int>(
            value: index,
            enabled: input.enabled,
            title: _optionText(input.exercise.options[index]),
          ),
        ),
    ],
  ),
);

Widget _multiple(ExerciseInputContext input) {
  final selected = input.answer is List
      ? (input.answer as List).whereType<int>().toSet()
      : <int>{};
  return Column(
    children: [
      for (final index in input.optionOrder)
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: CheckboxListTile(
            value: selected.contains(index),
            title: _optionText(input.exercise.options[index]),
            onChanged: !input.enabled
                ? null
                : (checked) {
                    final next = {...selected};
                    if (checked == true) {
                      next.add(index);
                    } else {
                      next.remove(index);
                    }
                    input.onChanged(next.toList()..sort());
                  },
          ),
        ),
    ],
  );
}

Widget _optionText(String text) {
  final arabic = RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  return Text(
    text,
    textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
    style: TextStyle(
      fontFamily: arabic ? 'NotoNaskhArabic' : 'Manrope',
      fontFamilyFallback: const ['Manrope', 'NotoNaskhArabic'],
      fontSize: arabic ? 24 : 16,
      height: 1.7,
    ),
  );
}

Widget _boolean(ExerciseInputContext input) => RadioGroup<bool>(
  groupValue: input.answer is bool ? input.answer as bool : null,
  onChanged: (value) {
    if (input.enabled) input.onChanged(value);
  },
  child: Column(
    children: [
      for (final value in [true, false])
        RadioListTile<bool>(
          value: value,
          enabled: input.enabled,
          title: Text(value ? 'صحيح' : 'خطأ'),
        ),
    ],
  ),
);

Widget _text(ExerciseInputContext input) => TextFormField(
  key: const ValueKey('exercise-text-answer'),
  initialValue: input.answer is String ? input.answer as String : '',
  enabled: input.enabled,
  textDirection: TextDirection.rtl,
  minLines: 2,
  maxLines: 6,
  decoration: const InputDecoration(
    labelText: 'الإجابة',
    border: OutlineInputBorder(),
  ),
  onChanged: input.onChanged,
);

Widget _manual(ExerciseInputContext input) {
  final voice =
      input.exercise.kind == ExerciseKind.speaking ||
      input.exercise.kind == ExerciseKind.pronunciation;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        voice
            ? 'إجابة صوتية تحتاج إلى مراجعة المعلمة. أرفق مرجع التسجيل أو اكتب ملاحظة.'
            : 'هذه الإجابة تحتاج إلى مراجعة المعلمة؛ لا تُمنح نقاط تلقائياً.',
      ),
      const SizedBox(height: 12),
      if (input.answer is Map && (input.answer as Map)['audioPath'] is String)
        Text('التسجيل المرفق: ${(input.answer as Map)['audioPath']}'),
      _text(
        ExerciseInputContext(
          exercise: input.exercise,
          answer: input.answer is Map
              ? (input.answer as Map)['note']
              : input.answer,
          enabled: input.enabled,
          optionOrder: input.optionOrder,
          onChanged: (note) {
            if (input.answer is Map) {
              input.onChanged(<String, dynamic>{
                for (final entry in (input.answer as Map).entries)
                  if (entry.key is String) entry.key as String: entry.value,
                'note': note,
              });
            } else {
              input.onChanged(note);
            }
          },
        ),
      ),
    ],
  );
}

Widget _matching(ExerciseInputContext input) {
  final key = input.exercise.correct;
  if (key is! Map ||
      key.isEmpty ||
      key.keys.any((item) => item is! String) ||
      key.values.any((item) => item is! String)) {
    return _manual(input);
  }
  final sources = key.keys.cast<String>().toList();
  final targets = key.values.cast<String>().toSet().toList()..sort();
  if (input.exercise.config.randomizeOptions) {
    targets.shuffle(exerciseRandom(input.exercise));
  }
  final answer = input.answer is Map ? input.answer as Map : const {};
  return Column(
    children: [
      for (final source in sources)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            key: ValueKey('match-$source'),
            isExpanded: true,
            initialValue: targets.contains(answer[source])
                ? answer[source] as String
                : null,
            decoration: InputDecoration(
              labelText: source,
              border: const OutlineInputBorder(),
            ),
            hint: const Text('اختر المطابقة'),
            items: [
              for (final target in targets)
                DropdownMenuItem(value: target, child: Text(target)),
            ],
            onChanged: !input.enabled
                ? null
                : (value) {
                    input.onChanged(<String, dynamic>{
                      for (final entry in answer.entries)
                        if (entry.key is String)
                          entry.key as String: entry.value,
                      source: value,
                    });
                  },
          ),
        ),
    ],
  );
}

/// List/map shape comes from the answer key, while no answer values are shown.
Widget _structured(ExerciseInputContext input) {
  final shape = input.exercise.correct;
  if (shape is! List && shape is! Map) return _text(input);

  Widget fields(
    dynamic node,
    dynamic value,
    String label,
    ValueChanged<dynamic> update,
  ) {
    if (node is List) {
      return Column(
        children: [
          for (var index = 0; index < node.length; index++)
            fields(
              node[index],
              value is List && index < value.length ? value[index] : null,
              '$label ${index + 1}',
              (next) {
                final answer = List<dynamic>.generate(
                  node.length,
                  (i) => value is List && i < value.length
                      ? copyExerciseValue(value[i])
                      : null,
                );
                answer[index] = next;
                update(answer);
              },
            ),
        ],
      );
    }
    if (node is Map) {
      return Column(
        children: [
          for (final key in node.keys.whereType<String>())
            fields(node[key], value is Map ? value[key] : null, key, (next) {
              update(<String, dynamic>{
                for (final key in node.keys.whereType<String>())
                  key: value is Map ? copyExerciseValue(value[key]) : null,
                key: next,
              });
            }),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        key: ValueKey('field-$label'),
        initialValue: value is String ? value : '',
        enabled: input.enabled,
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: update,
      ),
    );
  }

  return fields(shape, input.answer, 'الإجابة', input.onChanged);
}

/// Uses token positions internally so repeated words can be selected separately.
class _WordOrderInput extends StatefulWidget {
  const _WordOrderInput({required this.input});
  final ExerciseInputContext input;

  @override
  State<_WordOrderInput> createState() => _WordOrderInputState();
}

class _WordOrderInputState extends State<_WordOrderInput> {
  late final List<String> _words;
  final List<int> _selected = [];

  @override
  void initState() {
    super.initState();
    final exercise = widget.input.exercise;
    final source =
        exercise.data['words'] ??
        (exercise.options.isNotEmpty ? exercise.options : exercise.correct);
    _words = source is List && source.every((value) => value is String)
        ? source.cast<String>().toList()
        : [];
    final initial = widget.input.answer;
    if (initial is List) {
      for (final word in initial) {
        final index = _words.asMap().entries.where(
          (item) => item.value == word && !_selected.contains(item.key),
        );
        if (index.isNotEmpty) _selected.add(index.first.key);
      }
    }
  }

  void _publish() =>
      widget.input.onChanged([for (final index in _selected) _words[index]]);

  @override
  Widget build(BuildContext context) {
    // This deterministic presentation remains stable across draft rebuilds.
    final order = List<int>.generate(_words.length, (index) => index);
    if (widget.input.exercise.config.randomizeOptions) {
      order.shuffle(exerciseRandom(widget.input.exercise));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('اختر الكلمات بالترتيب، واضغط الكلمة المختارة لإزالتها.'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final index in _selected)
              InputChip(
                label: Text(_words[index]),
                onDeleted: !widget.input.enabled
                    ? null
                    : () {
                        setState(() => _selected.remove(index));
                        _publish();
                      },
              ),
          ],
        ),
        const Divider(),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final index in order)
              OutlinedButton(
                onPressed: !widget.input.enabled || _selected.contains(index)
                    ? null
                    : () {
                        setState(() => _selected.add(index));
                        _publish();
                      },
                child: Text(_words[index]),
              ),
          ],
        ),
      ],
    );
  }
}
