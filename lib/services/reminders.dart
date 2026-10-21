import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// The daily prompt reminder: a local notification scheduled on device.
abstract final class Reminders {
  static const _id = 1;
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> _init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
    } catch (_) {
      // Unknown zone name: fall back to UTC offsets via the default location.
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  /// Asks for permission and schedules the reminder every day at [time].
  /// Returns false if the user declined notifications.
  static Future<bool> schedule(TimeOfDay time) async {
    await _init();
    final granted = switch (defaultTargetPlatform) {
      TargetPlatform.iOS =>
        await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, sound: true),
      TargetPlatform.android =>
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission(),
      _ => true,
    };
    if (granted == false) return false;

    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));

    await _plugin.cancel(id: _id);
    await _plugin.zonedSchedule(
      id: _id,
      title: 'Daily prompt',
      body: 'Today’s drawing prompt is waiting in Tinta.',
      scheduledDate: next,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily-prompt',
          'Daily prompt',
          channelDescription: 'A small drawing idea once a day',
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // Inexact is fine for a gentle nudge and needs no exact-alarm permission.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    return true;
  }

  static Future<void> cancel() async {
    await _init();
    await _plugin.cancel(id: _id);
  }
}
