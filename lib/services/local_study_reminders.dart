import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/study_calendar.dart';

/// Offline Android scheduling via our own small native AlarmManager bridge.
/// No new Flutter packages, remote cloud services or exact-alarm privileges.
class LocalStudyReminders {
  static const MethodChannel _channel =
      MethodChannel('bayna.study_reminders');

  Future<bool> schedule(StudyCalendarPlan plan) async {
    if (kIsWeb || !Platform.isAndroid) {
      throw StateError('Локальные уведомления доступны на Android.');
    }
    final permitted =
        await _channel.invokeMethod<bool>('requestPermission') ?? false;
    if (!permitted) return false;
    final when = plan.nextNotifications(count: 14).map(
      (instant) => instant.millisecondsSinceEpoch,
    ).toList();
    await _channel.invokeMethod<void>('schedule', {
      'instants': when,
    });
    return true;
  }

  Future<void> cancel() async {
    if (kIsWeb || !Platform.isAndroid) return;
    await _channel.invokeMethod<void>('cancel');
  }
}
