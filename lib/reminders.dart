import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class Reminders {
  static final plugin = FlutterLocalNotificationsPlugin();
  static bool ready = false;

  static Future<void> init() async {
    if (ready) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await plugin.initialize(const InitializationSettings(android: android, iOS: ios));
    await plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    ready = true;
  }

  static int _id(String taskId) => taskId.hashCode & 0x7fffffff;

  static Future<void> schedule(String taskId, String title, DateTime when) async {
    try {
      await init();
      if (!when.isAfter(DateTime.now())) return;
      await plugin.zonedSchedule(
        _id(taskId),
        'Taskio',
        title,
        tz.TZDateTime.from(when, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails('taskio', 'Reminders', importance: Importance.high, priority: Priority.high),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {}
  }

  static Future<void> cancel(String taskId) async {
    try {
      await init();
      await plugin.cancel(_id(taskId));
    } catch (_) {}
  }
}
