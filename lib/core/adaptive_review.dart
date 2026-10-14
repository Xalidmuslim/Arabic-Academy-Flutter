import 'dart:math' as math;

/// Adaptive, conservative spaced repetition, compatible with stored stage
/// metadata from Bayna v8. Days are scheduled from actual review time, not
/// guessed across devices.  A lapse is immediately due again.
abstract final class AdaptiveReview {
  static const _baseDays = [0, 1, 3, 7, 14, 30];

  static Map<String, dynamic> update(
    Map<dynamic, dynamic> previous,
    bool remembered,
    DateTime now, {
    int responseMillis = 0,
    int? confidence,
  }) {
    final priorStage = (previous['stage'] as int? ?? 0).clamp(0, 5);
    final stage = remembered ? math.min(priorStage + 1, 5) : 0;
    final oldEase = (previous['ease'] as num? ?? 2.3).toDouble();
    // A recalled word is less stable when it took a long time or
    // the student explicitly marked the answer as a guess.
    final slow = responseMillis > 15000;
    final uncertain = confidence != null && confidence <= 2;
    final strong = remembered && !slow && !uncertain &&
        (confidence == null || confidence >= 4);
    final ease = (oldEase + (remembered
        ? strong ? 0.08 : -0.04
        : -0.22)).clamp(1.3, 2.8);
    final lapses = (previous['lapses'] as int? ?? 0) +
        (remembered ? 0 : 1);
    final successes = (previous['successes'] as int? ?? 0) +
        (remembered ? 1 : 0);
    final base = _baseDays[stage];
    final slowdown = remembered && (slow || uncertain) ? 0.65 : 1.0;
    final adjusted = stage <= 1
        ? base
        : math.max(1, (base * ease / 2.3 * slowdown).round());
    final due = remembered
        ? now.add(Duration(days: adjusted))
        : now; // The failed word is due now, not mastered.
    return {
      ...previous,
      'stage': stage,
      'difficult': !remembered || (remembered && lapses > successes),
      'last_review': now.toUtc().toIso8601String(),
      'due_at': due.toUtc().toIso8601String(),
      'reviews': (previous['reviews'] as int? ?? 0) + 1,
      'successes': successes,
      'lapses': lapses,
      'ease': ease,
      'interval_days': adjusted,
      'response_millis': responseMillis.clamp(0, 600000),
      if (confidence != null) 'confidence': confidence.clamp(0, 5),
      'retrieval_quality': remembered ? (strong ? 'strong' : 'hesitant')
          : 'forgotten',
    };
  }

  /// Approximate memory availability from the learned interval and time
  /// since last recall; not a psychometric diagnosis.
  static double predictedRecall(Map<dynamic, dynamic>? review,
      DateTime at) {
    if (review == null) return 0;
    final last = DateTime.tryParse(review['last_review']?.toString() ?? '');
    if (last == null) return 0;
    final days = at.difference(last).inSeconds / 86400;
    final interval = (review['interval_days'] as num? ?? 1)
        .toDouble().clamp(0.2, 365);
    if (review['stage'] == 0) return 0;
    final elapsed = math.max(0.0, days);
    return math.exp(-elapsed / interval).clamp(0, 1);
  }

  static double mastery(Map<dynamic, dynamic>? review) {
    if (review == null) return 0;
    final stage = (review['stage'] as int? ?? 0).clamp(0, 5);
    final successes = review['successes'] as int? ?? stage;
    final lapses = review['lapses'] as int? ?? 0;
    final reliability = successes + lapses == 0
        ? 0.5
        : successes / (successes + lapses);
    return (stage / 5 * 0.75 + reliability * 0.25).clamp(0, 1);
  }
}
