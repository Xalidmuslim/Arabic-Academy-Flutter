import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as timezone_data;
import 'package:timezone/timezone.dart' as tz;

import '../core/study_calendar.dart';

/// Explicitly opt-in, approximate Android OS reminders. All timestamps are
/// stored as absolute instants; this avoids requiring location/contacts or a
/// cloud/FCM account. Android battery management can delay inexact alarms.
class LocalStudyReminders {
  LocalStudyReminders()
      : _plugin = FlutterLocalNotificationsPlugin();
  final FlutterLocalNotificationsPlugin _plugin;

  static const firstId = 42010;
  static const count = 14;
  static const _channel = AndroidNotificationDetails(
    'bayna_study_reminders',
    'Повторение арабского',
    channelDescription: 'Личные напоминания о занятиях на этом телефоне',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  Future<void> _init() async {
    if (kIsWeb || !Platform.isAndroid) {
      throw StateError('Локальные уведомления доступны на Android.');
    }
    timezone_data.initializeTimeZones();
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
  }

  Future<bool> schedule(StudyCalendarPlan plan) async {
    await _init();
    // Permission is requested ONLY after a deliberate button tap.
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    if (granted != true) return false;
    await cancel();
    final dates = plan.nextNotifications(count: count);
    for (var i = 0; i < dates.length; i++) {
      await _plugin.zonedSchedule(
        firstId + i,
        'Байна Ядайк · время повторения',
        'Повторите слова, затем продолжите урок на арабском языке.',
        tz.TZDateTime.from(dates[i].toUtc(), tz.UTC),
        const NotificationDetails(android: _channel),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'personal_study_calendar',
      );
    }
    return true;
  }

  Future<void> cancel() async {
    await _init();
    for (var i = 0; i < count; i++) {
      await _plugin.cancel(firstId + i);
    }
  }
}
