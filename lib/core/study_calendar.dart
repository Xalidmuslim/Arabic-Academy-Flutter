import 'academy_state.dart';

/// Time and weekdays are stored in the user's LOCAL learning namespace.
/// This feature does not depend on an online-school account or FCM.
class StudyCalendarPlan {
  const StudyCalendarPlan({
    required this.hour,
    required this.minute,
    required this.weekdays,
    required this.dailyMinutes,
    required this.notifyMinutesBefore,
    required this.notificationsEnabled,
  });

  final int hour;
  final int minute;
  final Set<int> weekdays;
  final int dailyMinutes;
  final int notifyMinutesBefore;
  final bool notificationsEnabled;

  static const defaultPlan = StudyCalendarPlan(
    hour: 18, minute: 0,
    weekdays: {1, 2, 3, 4, 5},
    dailyMinutes: 15,
    notifyMinutesBefore: 15,
    notificationsEnabled: false,
  );

  factory StudyCalendarPlan.fromState(AcademyState state) {
    final value = state.settings['study_calendar_v1'];
    if (value is! Map) return defaultPlan;
    final days = value['weekdays'];
    final parsedDays = days is List
        ? days.whereType<int>().where((d) => d >= 1 && d <= 7).toSet()
        : defaultPlan.weekdays;
    return StudyCalendarPlan(
      hour: (value['hour'] as int? ?? 18).clamp(0, 23),
      minute: (value['minute'] as int? ?? 0).clamp(0, 59),
      weekdays: parsedDays,
      dailyMinutes: (value['daily_minutes'] as int? ?? 15).clamp(5, 120),
      notifyMinutesBefore: (value['notify_before'] as int? ?? 15)
          .clamp(0, 120),
      notificationsEnabled: value['notifications_enabled'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'hour': hour,
    'minute': minute,
    'weekdays': (weekdays.toList()..sort()),
    'daily_minutes': dailyMinutes,
    'notify_before': notifyMinutesBefore,
    'notifications_enabled': notificationsEnabled,
  };

  StudyCalendarPlan copyWith({
    int? hour,
    int? minute,
    Set<int>? weekdays,
    int? dailyMinutes,
    int? notifyMinutesBefore,
    bool? notificationsEnabled,
  }) => StudyCalendarPlan(
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    weekdays: weekdays ?? this.weekdays,
    dailyMinutes: dailyMinutes ?? this.dailyMinutes,
    notifyMinutesBefore: notifyMinutesBefore ?? this.notifyMinutesBefore,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
  );

  /// DateTime(year, month, day + offset, hour, minute) preserves local
  /// calendar time across daylight-saving boundaries; adding 24h does not.
  List<DateTime> nextSessions({
    DateTime? now,
    int count = 14,
  }) {
    final current = now ?? DateTime.now();
    if (weekdays.isEmpty || count <= 0) return [];
    final sessions = <DateTime>[];
    for (var i = 0; i < 180 && sessions.length < count; i++) {
      final day = DateTime(
        current.year, current.month, current.day + i, hour, minute,
      );
      if (!weekdays.contains(day.weekday) || !day.isAfter(current)) continue;
      sessions.add(day);
    }
    return sessions;
  }

  List<DateTime> nextNotifications({DateTime? now, int count = 14}) {
    final current = now ?? DateTime.now();
    // Look farther ahead when the lead time pushes today's notification
    // into the past; never schedule an alarm for a past instant.
    return nextSessions(now: current.subtract(
          Duration(minutes: notifyMinutesBefore + 1)),
          count: count + 1,
        )
        .map((date) => date.subtract(Duration(minutes: notifyMinutesBefore)))
        .where((date) => date.isAfter(current))
        .take(count).toList();
  }
}
