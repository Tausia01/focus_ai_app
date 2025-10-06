import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/cache_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CacheService _cache = CacheService();

  Future<void> initialize() async {
    const AndroidInitializationSettings initAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: initAndroid);
    await _flutterLocalNotificationsPlugin.initialize(initSettings);
    tz.initializeTimeZones();
  }

  Future<bool> _ensureAndroidPermissions() async {
    final androidPlugin = _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return true;
    // Request POST_NOTIFICATIONS on Android 13+
    await androidPlugin.requestPermission();
    // Attempt to request exact alarm permission where applicable (no-op on many devices)
    await androidPlugin.requestExactAlarmsPermission();
    return true;
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

    await _ensureAndroidPermissions();
    await _flutterLocalNotificationsPlugin.zonedSchedule(
      1001,
      "It's studytime!",
      'You have $remainingTasks tasks remaining',
      tz.TZDateTime.from(firstTrigger, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> saveStudyTime(TimeOfDay time) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).set({
      'studytime': {'hour': time.hour, 'minute': time.minute}
    }, SetOptions(merge: true));

    await _cache.updateGamificationOptimistic('studytime', {'hour': time.hour, 'minute': time.minute});
  }

  Future<TimeOfDay?> loadStudyTime() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc = await _firestore.collection('users').doc(user.uid).get();
    final data = doc.data() ?? {};
    final study = data['studytime'];
    if (study is Map) {
      final hour = study['hour'];
      final minute = study['minute'];
      if (hour is int && minute is int) {
        return TimeOfDay(hour: hour, minute: minute);
      }
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
