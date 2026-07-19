import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'alarm_service_contract.dart';

AlarmScheduler createAlarmScheduler() => MobileAlarmScheduler();

class MobileAlarmScheduler implements AlarmScheduler {
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _ready = false;

  @override
  Future<AlarmResult> initializeAndRequestPermissions() async {
    if (!Platform.isAndroid) {
      return const AlarmResult(
        isSupported: false,
        isReady: false,
        message: 'Exact alarms are enabled only in the Android build.',
      );
    }

    try {
      if (!_initialized) {
        tz_data.initializeTimeZones();
        final deviceZone = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(deviceZone.identifier));
        const settings = InitializationSettings(
          android: AndroidInitializationSettings('ic_launcher'),
        );
        await _notifications.initialize(settings: settings);
        _initialized = true;
      }

      final android = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final notificationsAllowed = await android
          ?.requestNotificationsPermission();
      final exactAlarmsAllowed = await android?.requestExactAlarmsPermission();
      _ready = notificationsAllowed != false && exactAlarmsAllowed != false;
      return AlarmResult(
        isSupported: true,
        isReady: _ready,
        message: _ready
            ? null
            : 'Alarm permission is not fully enabled. Tasks are saved, but exact reminders cannot be guaranteed.',
      );
    } catch (error) {
      _ready = false;
      return AlarmResult(
        isSupported: true,
        isReady: false,
        message: 'Could not initialize Android alarms: $error',
      );
    }
  }

  @override
  Future<AlarmResult> replaceAll(List<AlarmEntry> entries) async {
    if (!_initialized || !_ready) {
      return const AlarmResult(
        isSupported: true,
        isReady: false,
        message:
            'Tasks were saved, but alarms were not refreshed because exact-alarm permission is disabled.',
      );
    }

    try {
      await _notifications.cancelAll();
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'pert_task_alarms',
          'PERT task alarms',
          channelDescription: 'Exact reminders at task start and expected end',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          playSound: true,
          enableVibration: true,
          visibility: NotificationVisibility.public,
        ),
      );
      for (final entry in entries) {
        await _notifications.zonedSchedule(
          id: entry.id,
          title: entry.title,
          body: entry.body,
          scheduledDate: tz.TZDateTime.from(entry.at, tz.local),
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: entry.payload,
        );
      }
      return const AlarmResult(isSupported: true, isReady: true);
    } catch (error) {
      return AlarmResult(
        isSupported: true,
        isReady: false,
        message:
            'Tasks were saved, but Android could not refresh their alarms: $error',
      );
    }
  }
}
