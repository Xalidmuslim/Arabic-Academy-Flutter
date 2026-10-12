# Exercise engine contract

Import `package:arabic_academy/features/exercises/exercises.dart`. This module has
no dependency on main, core, storage, recording, or a network service.

```dart
final exercise = Exercise.fromJson(json); // Map<String, dynamic>
final jsonCopy = exercise.toJson();       // Map<String, dynamic>
final result = ExerciseEvaluator.evaluate(exercise, answer); // ExerciseResult

ExerciseRunner(
  exercise: exercise,
  initialAnswer: savedAnswer,
  onDraft: (dynamic answer) => saveDraft(answer),
  onCompleted: (ExerciseResult result, dynamic answer) {
    // Only result.passed permits automatic learning progress.
    // Incorrect exhaustion/timeout and needsReview also call this callback.
  },
);
```

`Exercise` deeply copies/freezes JSON, including unknown fields. Its getters are
`id`, `kind`, `prompt`, `options`, `correct`, `config`, `explanation`, and `data`.
`toJson()` returns a detached, mutable copy without rewriting legacy content.
`kind` also accepts the JSON field `type`; camelCase, snake_case, and kebab-case
spellings are accepted. Legacy objects with no kind/type and with `options` and
integer `correct` become single choices; `question` supplies the prompt.

The architecture specifies a count of 25 but does not list the original names.
These are the explicit local kinds; unknown wire names survive serialization and
receive `needsReview`. Any upstream taxonomy should be mapped explicitly.

| Kinds | `correct` and submitted answer |
| --- | --- |
| singleChoice, listeningChoice, imageChoice, readingComprehension | Integer index into the original `options: List<String>`; never a shuffled display index |
| multipleChoice | Nonempty list of unique original integer indexes; exact set equality |
| trueFalse | Boolean |
| matching, listeningMatching, imageMatching, categorization | Nonempty `Map<String, String>` from source identities/labels to target identities/labels; every pair required, no extra keys |
| wordOrder, sentenceOrder | Nonempty ordered `List<String>`; `words` or `options` optionally supplies the displayed token pool |
| fillBlanks, table, conjugation | Nonempty string/list/map structure with nonempty strings at every leaf; identical shape required |
| fillBlank, shortAnswer, translation, dictation, errorCorrection, diacritics | Nonempty string; explicit `acceptedAnswers: List<String>` can replace `correct` with an exhaustive list of alternatives |
| dialogue, writing, speaking, pronunciation | Teacher review, even when an answer key exists |

The runner uses native radio groups, checkboxes, dropdowns, editable fields, and
word chips/buttons. Tables use labeled cell fields in a vertical layout that fits
small screens. The image/listening kinds supply choice/matching input; a caller
can render its stimulus above the runner or provide a kind-specific input builder.
Voice answers can be a note string or a JSON object such as
`{'audioPath': 'recording.m4a', 'note': 'optional'}`. An existing attachment survives
note edits. Recording and playback belong to the integration module; this runner
does not claim to record audio or assess pronunciation.

Configuration names may be inside `config` (taking precedence) or at the top
level. Invalid types/ranges throw `FormatException` during parsing.

| Field | Default | Meaning |
| --- | --- | --- |
| timeLimitSeconds | null | Positive integer, or no time limit |
| maxAttempts | 3 | Positive integer |
| randomizeOptions | false | Stable seeded shuffle without modifying original indexes or keys |
| points | 1 | Nonnegative integer, awarded only for a correct answer |
| passThreshold | 1.0 | Fraction in [0, 1]; incorrect/review never pass even with threshold zero |
| ignoreDiacritics | false | Ignore vowel/shadda and annotation marks while preserving hamza and ta marbuta |
| explanation | null | String shown after evaluation; may also be on the exercise |

Built-in grading is all-or-nothing. `ExerciseResult` exposes `status` (enum
`ExerciseStatus.correct/incorrect/needsReview`), `points`, `explanation`, `score`
(0 or 1), `passThreshold`, and `passed`. Missing/malformed/empty keys return
`needsReview` with zero points; a wrong answer to a valid key returns `incorrect`.
Text grading trims and collapses whitespace, preserves case and Arabic letter
distinctions, and composes common decomposed hamza/madda spellings. Matching
identities are compared literally. `ArabicNormalization.forSearch` is deliberately
more permissive and is never called by a grader.

The runner calls `onDraft(dynamic answer)` for each edit, explicit save, and
timeout. Callback answers are detached copies. `initialAnswer` is applied when
mounting or switching exercise content. Equivalent parent rebuilds retain edits,
attempts and the deadline. A wrong attempt below the limit displays feedback and
allows retry; completion fires once on pass, review submission, exhaustion, or
timeout. Timeout is always incorrect with zero points, even for a correct draft.
Attempts/deadlines are enforced for the mounted runner session; persisting them
across disposal/reopening is the host's responsibility. Draft callbacks contain
answers, not a persisted attempt/session envelope.

Extension APIs are `ExerciseEvaluator(registry: Map<ExerciseKind, ExerciseGrader>)`
and its `grade(exercise, answer)` instance method, and runner parameters
`evaluator: ExerciseEvaluator?` and
`inputBuilders: Map<ExerciseKind, ExerciseInputBuilder>`. Overrides merge into
private built-in registries. `ExerciseGrader` is
`ExerciseResult Function(Exercise exercise, dynamic answer)`.
`ExerciseInputBuilder` is `Widget Function(ExerciseInputContext input)`; its
context provides `exercise`, `answer`, `enabled`, `optionOrder`, and `onChanged`.
Extensions must respect `enabled`, return explicit review outcomes when uncertain,
and compute their result's score/threshold consistently.

The runner reads the inherited Material theme, sets RTL and NotoNaskhArabic with
line height 1.7, and supports scrolling/text scaling. The host must register the
local font family in its asset configuration.

Validation: `flutter test --no-pub test/exercise_engine_test.dart` and
`dart analyze lib/features/exercises test/exercise_engine_test.dart` after the
coordinator has installed dependencies.
