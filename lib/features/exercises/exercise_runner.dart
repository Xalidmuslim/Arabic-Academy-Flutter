import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import 'exercise.dart';
import 'exercise_evaluator.dart';
import 'exercise_inputs.dart';
import 'exercise_result.dart';

class ExerciseRunner extends StatefulWidget {
  const ExerciseRunner({
    super.key,
    required this.exercise,
    required this.onCompleted,
    this.initialAnswer,
    this.onDraft,
    this.onAttempt,
    this.evaluator,
    this.inputBuilders = const {},
  });

  final Exercise exercise;

  /// Called once, on success, review submission, exhaustion, or timeout.
  final void Function(ExerciseResult result, dynamic answer) onCompleted;
  final dynamic initialAnswer;

  /// Called for each edit and for the explicit save-draft action.
  final ValueChanged<dynamic>? onDraft;

  /// Every checked answer, including a wrong answer before attempt exhaustion.
  final void Function(ExerciseResult result, dynamic answer)? onAttempt;
  final ExerciseEvaluator? evaluator;
  final Map<ExerciseKind, ExerciseInputBuilder> inputBuilders;

  @override
  State<ExerciseRunner> createState() => _ExerciseRunnerState();
}

class _ExerciseRunnerState extends State<ExerciseRunner> {
  dynamic _answer;
  ExerciseResult? _result;
  late List<int> _optionOrder;
  late String _identity;
  int _attempts = 0;
  int? _remainingSeconds;
  bool _finished = false;
  Timer? _expiry;
  Timer? _ticker;
  DateTime? _deadline;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    _expiry?.cancel();
    _ticker?.cancel();
    _identity = jsonEncode(widget.exercise.toJson());
    _answer = copyExerciseValue(widget.initialAnswer);
    _result = null;
    _attempts = 0;
    _finished = false;
    _optionOrder = List<int>.generate(widget.exercise.options.length, (i) => i);
    if (widget.exercise.config.randomizeOptions) {
      _optionOrder.shuffle(exerciseRandom(widget.exercise));
    }
    _remainingSeconds = widget.exercise.config.timeLimitSeconds;
    _deadline = _remainingSeconds == null
        ? null
        : DateTime.now().add(Duration(seconds: _remainingSeconds!));
    if (_remainingSeconds != null) {
      _expiry = Timer(Duration(seconds: _remainingSeconds!), _expire);
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || _finished) return;
        setState(() {
          _remainingSeconds = max(
            0,
            (_deadline!.difference(DateTime.now()).inMilliseconds / 1000)
                .ceil(),
          );
        });
      });
    }
  }

  @override
  void didUpdateWidget(covariant ExerciseRunner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (jsonEncode(widget.exercise.toJson()) != _identity) _reset();
  }

  @override
  void dispose() {
    _expiry?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  bool _active() {
    if (_finished) return false;
    if (_deadline != null && !DateTime.now().isBefore(_deadline!)) {
      _expire();
      return false;
    }
    return true;
  }

  void _edit(dynamic answer) {
    if (!_active()) return;
    setState(() => _answer = copyExerciseValue(answer));
    widget.onDraft?.call(copyExerciseValue(_answer));
  }

  void _saveDraft() {
    if (_active()) widget.onDraft?.call(copyExerciseValue(_answer));
  }

  bool _hasAnswer(dynamic value) {
    if (value is String) return value.trim().isNotEmpty;
    if (value is List) return value.isNotEmpty && value.every(_hasAnswer);
    if (value is Map) return value.isNotEmpty && value.values.every(_hasAnswer);
    return value is int || value is bool;
  }

  bool get _hasSubmission {
    final answer = _answer;
    if (answer is Map &&
        (widget.exercise.kind == ExerciseKind.speaking ||
            widget.exercise.kind == ExerciseKind.pronunciation)) {
      final path = answer['audioPath'];
      final note = answer['note'];
      return (path is String && path.trim().isNotEmpty) ||
          (note is String && note.trim().isNotEmpty);
    }
    return _hasAnswer(answer);
  }

  void _submit() {
    if (!_active() || !_hasSubmission) return;
    final evaluator = widget.evaluator ?? ExerciseEvaluator();
    final result = evaluator.grade(widget.exercise, copyExerciseValue(_answer));
    widget.onAttempt?.call(result, copyExerciseValue(_answer));
    setState(() {
      _attempts++;
      _result = result;
      _finished =
          result.passed ||
          result.status == ExerciseStatus.needsReview ||
          _attempts >= widget.exercise.config.maxAttempts;
    });
    if (_finished) _complete(result);
  }

  void _complete(ExerciseResult result) {
    _expiry?.cancel();
    _ticker?.cancel();
    widget.onCompleted(result, copyExerciseValue(_answer));
  }

  void _expire() {
    if (!mounted || _finished) return;
    final result = ExerciseResult(
      status: ExerciseStatus.incorrect,
      points: 0,
      explanation: 'انتهى الوقت.',
      passThreshold: widget.exercise.config.passThreshold,
    );
    setState(() {
      _finished = true;
      _remainingSeconds = 0;
      _result = result;
    });
    widget.onDraft?.call(copyExerciseValue(_answer));
    _complete(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final hasArabic =
        RegExp(r'[\u0600-\u06FF]').hasMatch(widget.exercise.prompt) ||
        widget.exercise.options.any(
          (option) => RegExp(r'[\u0600-\u06FF]').hasMatch(option),
        );
    final arabicTheme = theme.textTheme
        .apply(
          fontFamily: 'NotoNaskhArabic',
          fontFamilyFallback: const ['Manrope'],
        )
        .merge(
          const TextTheme(
            bodyLarge: TextStyle(height: 1.7),
            bodyMedium: TextStyle(height: 1.7),
            bodySmall: TextStyle(height: 1.7),
            labelLarge: TextStyle(height: 1.7),
            labelMedium: TextStyle(height: 1.7),
            titleMedium: TextStyle(height: 1.7),
          ),
        );
    final builder =
        widget.inputBuilders[widget.exercise.kind] ??
        defaultExerciseInputBuilders[widget.exercise.kind]!;
    final result = _result;
    final status = result == null
        ? null
        : switch (result.status) {
            ExerciseStatus.correct => arabic ? 'إجابة صحيحة' : 'Правильно!',
            ExerciseStatus.incorrect =>
              arabic
                  ? 'إجابة غير صحيحة'
                  : 'Неверно. Разберите объяснение и попробуйте снова.',
            ExerciseStatus.needsReview =>
              arabic
                  ? 'بانتظار مراجعة المعلمة — لا توجد نقاط تلقائية'
                  : 'Ответ сохранён для ручной проверки. Автоматические баллы не начисляются.',
          };
    return Theme(
      data: theme.copyWith(
        textTheme: hasArabic ? arabicTheme : theme.textTheme,
      ),
      child: Directionality(
        textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
        child: DefaultTextStyle.merge(
          style: TextStyle(
            fontFamily: hasArabic ? 'NotoNaskhArabic' : 'Manrope',
            fontFamilyFallback: const ['Manrope', 'NotoNaskhArabic'],
            height: 1.7,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.exercise.prompt,
                  textDirection:
                      RegExp(
                        r'[\u0600-\u06FF]',
                      ).hasMatch(widget.exercise.prompt)
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontFamily:
                        RegExp(
                          r'[\u0600-\u06FF]',
                        ).hasMatch(widget.exercise.prompt)
                        ? 'NotoNaskhArabic'
                        : 'Manrope',
                    height: 1.7,
                    fontFamilyFallback: const ['Manrope', 'NotoNaskhArabic'],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  arabic
                      ? 'المحاولات: $_attempts / ${widget.exercise.config.maxAttempts}'
                      : 'Попытки: $_attempts / ${widget.exercise.config.maxAttempts}',
                  style: TextStyle(
                    fontFamily: arabic ? 'NotoNaskhArabic' : 'Manrope',
                    fontFamilyFallback: const ['Manrope', 'NotoNaskhArabic'],
                  ),
                ),
                if (_remainingSeconds != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      arabic
                          ? 'الوقت المتبقي: $_remainingSeconds ث'
                          : 'Осталось: $_remainingSeconds с',
                    ),
                  ),
                const SizedBox(height: 16),
                KeyedSubtree(
                  key: ValueKey(_identity),
                  child: builder(
                    ExerciseInputContext(
                      exercise: widget.exercise,
                      answer: copyExerciseValue(_answer),
                      enabled: !_finished,
                      optionOrder: List.unmodifiable(_optionOrder),
                      onChanged: _edit,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (status != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      status,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFamily: arabic ? 'NotoNaskhArabic' : 'Manrope',
                        fontFamilyFallback: const [
                          'Manrope',
                          'NotoNaskhArabic',
                        ],
                        height: 1.7,
                        color: result!.status == ExerciseStatus.incorrect
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                if (result?.explanation != null) Text(result!.explanation!),
                const SizedBox(height: 12),
                FilledButton(
                  key: const ValueKey('exercise-submit'),
                  onPressed: !_finished && _hasSubmission ? _submit : null,
                  child: Text(
                    Localizations.localeOf(context).languageCode == 'ar'
                        ? 'إرسال الإجابة'
                        : 'Проверить',
                    style: arabic
                        ? const TextStyle(
                            fontFamily: 'NotoNaskhArabic',
                            fontFamilyFallback: ['Manrope'],
                            height: 1.7,
                          )
                        : null,
                  ),
                ),
                if (widget.onDraft != null)
                  TextButton(
                    key: const ValueKey('exercise-save-draft'),
                    onPressed: _finished ? null : _saveDraft,
                    child: Text(
                      Localizations.localeOf(context).languageCode == 'ar'
                          ? 'حفظ المسودة'
                          : 'Сохранить черновик',
                      style: arabic
                          ? const TextStyle(
                              fontFamily: 'NotoNaskhArabic',
                              fontFamilyFallback: ['Manrope'],
                              height: 1.7,
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
