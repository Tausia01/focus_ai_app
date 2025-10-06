import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  static const String _prefsStudyHour = 'studytime_hour';
  static const String _prefsStudyMinute = 'studytime_minute';

  Future<void> initialize() async {
    const AndroidInitializationSettings initAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: initAndroid);
    await _flutterLocalNotificationsPlugin.initialize(initSettings);
    tz.initializeTimeZones();
  }

  Future<void> scheduleDailyStudyReminder(TimeOfDay time, {required int remainingTasks}) async {
    final androidDetails = const AndroidNotificationDetails(
      'studytime_channel',
      'Study Time Reminders',
      channelDescription: 'Daily reminder to study with remaining tasks count',
      importance: Importance.max,
      priority: Priority.high,
    );
    final details = NotificationDetails(android: androidDetails);

    final now = DateTime.now();
    final scheduledDate = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    final firstTrigger = scheduledDate.isAfter(now)
        ? scheduledDate
        : scheduledDate.add(const Duration(days: 1));

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      1001,
      "It's studytime!",
      'You have $remainingTasks tasks remaining',
      tz.TZDateTime.from(firstTrigger, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      androidAllowWhileIdle: true,
    );
  }

  Future<void> saveStudyTimeLocal(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsStudyHour, time.hour);
    await prefs.setInt(_prefsStudyMinute, time.minute);
  }

  Future<TimeOfDay?> loadStudyTimeLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt(_prefsStudyHour);
    final minute = prefs.getInt(_prefsStudyMinute);
    if (hour != null && minute != null) {
      return TimeOfDay(hour: hour, minute: minute);
    }
    return null;
  }

  Future<void> showDistractionNotification(String appName, BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Stay Focused! 🎯 You opened $appName during your focus session.'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  Future<void> showSessionCompleteNotification(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Focus Session Complete! 🎉 Great job! Your focus session has ended.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 5),
      ),
    );
  }

  Future<void> showSessionStartNotification(Duration duration, BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Focus Session Started! 🚀 Your ${duration.inMinutes}-minute focus session has begun.'),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
