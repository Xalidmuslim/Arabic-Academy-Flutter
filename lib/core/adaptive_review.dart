import 'dart:math' as math;

/// Adaptive, conservative spaced repetition, compatible with stored stage
/// metadata from Bayna v8. Days are scheduled from actual review time, not
/// guessed across devices.  A lapse is immediately due again.
abstract final class AdaptiveReview {
  static const _baseDays = [0, 1, 3, 7, 14, 30];

  static Map<String, dynamic> update(
    Map<dynamic, dynamic> previous,
    bool remembered,
    DateTime now,
  ) {
    final priorStage = (previous['stage'] as int? ?? 0).clamp(0, 5);
    final stage = remembered ? math.min(priorStage + 1, 5) : 0;
    final oldEase = (previous['ease'] as num? ?? 2.3).toDouble();
    final ease = (oldEase + (remembered ? 0.08 : -0.22))
        .clamp(1.3, 2.8);
    final lapses = (previous['lapses'] as int? ?? 0) +
        (remembered ? 0 : 1);
    final successes = (previous['successes'] as int? ?? 0) +
        (remembered ? 1 : 0);
    final base = _baseDays[stage];
    final adjusted = stage <= 1
        ? base
        : math.max(1, (base * ease / 2.3).round());
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
    };
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
