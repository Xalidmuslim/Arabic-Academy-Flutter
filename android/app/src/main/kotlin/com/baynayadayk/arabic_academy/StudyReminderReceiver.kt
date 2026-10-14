package com.example.arabic_academy

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import org.json.JSONArray

/**
 * Uses only Android platform APIs. Local inexact alarms do not request exact
 * alarm privileges or contact a backend. A reboot restores future instants
 * from the app-private preference snapshot.
 */
object StudyReminderScheduler {
    private const val PREFS = "bayna_offline_study_reminders"
    private const val KEY_TIMES = "times"
    private const val CHANNEL = "bayna_study_reminders"
    private const val FIRST_ID = 42010
    private const val MAX_REMINDERS = 14

    private fun alarm(ctx: Context) =
        ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    private fun intent(ctx: Context, index: Int): PendingIntent {
        val target = Intent(ctx, StudyReminderReceiver::class.java)
            .setAction("com.example.arabic_academy.STUDY_ALARM")
            .putExtra("index", index)
        return PendingIntent.getBroadcast(
            ctx, FIRST_ID + index, target,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun cancelAlarms(ctx: Context) {
        for (index in 0 until MAX_REMINDERS) {
            alarm(ctx).cancel(intent(ctx, index))
        }
    }

    fun cancel(ctx: Context) {
        cancelAlarms(ctx)
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().remove(KEY_TIMES).apply()
    }

    fun schedule(ctx: Context, times: List<Long>) {
        require(times.size <= MAX_REMINDERS) { "Too many reminders" }
        val now = System.currentTimeMillis()
        require(times.all { it > now && it < now + 180L * 86400000L }) {
            "Reminder must be a future instant within 180 days"
        }
        cancelAlarms(ctx)
        val stored = JSONArray()
        times.forEachIndexed { index, at ->
            stored.put(at)
            // Inexact alarms have no exact-alarm permission requirement.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarm(ctx).setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP, at, intent(ctx, index)
                )
            } else {
                alarm(ctx).set(
                    AlarmManager.RTC_WAKEUP, at, intent(ctx, index)
                )
            }
        }
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(KEY_TIMES, stored.toString()).apply()
    }

    fun restore(ctx: Context) {
        val value = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_TIMES, null) ?: return
        try {
            val array = JSONArray(value)
            val now = System.currentTimeMillis()
            val times = (0 until array.length())
                .map { array.getLong(it) }
                .filter { it > now + 5000 }
            schedule(ctx, times)
        } catch (_: Exception) {
            // Corrupt notification metadata is discarded, not allowed
            // to crash the OS broadcast receiver after a reboot.
            cancel(ctx)
        }
    }

    fun notify(ctx: Context, index: Int) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ctx.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED) {
            return
        }
        val manager = ctx.getSystemService(Context.NOTIFICATION_SERVICE)
            as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL, "Повторение арабского",
                    NotificationManager.IMPORTANCE_DEFAULT)
            )
        }
        val open = PendingIntent.getActivity(
            ctx, 0, Intent(ctx, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(ctx, CHANNEL)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(ctx)
        }
        val notification = builder
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("Байна Ядайк · время повторения")
            .setContentText("Повторите слова и продолжите арабский урок.")
            .setAutoCancel(true)
            .setContentIntent(open)
            .build()
        manager.notify(FIRST_ID + index, notification)
    }
}

class StudyReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != "com.example.arabic_academy.STUDY_ALARM") return
        val index = intent.getIntExtra("index", -1)
        if (index in 0..13) StudyReminderScheduler.notify(context, index)
    }
}

class StudyReminderBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action in setOf(
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON"
        )) {
            StudyReminderScheduler.restore(context)
        }
    }
}
