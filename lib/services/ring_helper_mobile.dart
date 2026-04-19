import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

const AndroidNotificationChannel _ringChannel = AndroidNotificationChannel(
  'ring_channel',
  'Incoming Rings',
  description: 'High-priority wake-up ring alerts',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
);

const AndroidNotificationChannel _msgChannel = AndroidNotificationChannel(
  'message_channel',
  'New Messages',
  description: 'Incoming chat messages',
  importance: Importance.high,
  playSound: true,
);

const AndroidNotificationChannel _taskChannel = AndroidNotificationChannel(
  'task_channel',
  'Personal Tasks',
  description: 'Reminders for your personal tasks',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
);

final _plugin = FlutterLocalNotificationsPlugin();

class RingHelper {
  RingHelper._();
  static final RingHelper instance = RingHelper._();

  Future<void> init() async {
    // Init Timezone
    tz.initializeTimeZones();
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings: initSettings);

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_ringChannel);
    await androidPlugin?.createNotificationChannel(_msgChannel);
    await androidPlugin?.createNotificationChannel(_taskChannel);
    await androidPlugin?.requestNotificationsPermission();
  }

  Future<void> scheduleTaskAlarm(String id, String title, DateTime alarmTime) async {
    final scheduledDate = tz.TZDateTime.from(alarmTime, tz.local);
    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) return;

    const androidDetails = AndroidNotificationDetails(
      'task_channel',
      'Personal Tasks',
      channelDescription: 'Reminders for your personal tasks',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      ticker: 'Task Reminder',
    );
    const details = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      id: id.hashCode,
      title: '⏰ Task Reminder!',
      body: title,
      scheduledDate: scheduledDate,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancelTaskAlarm(String id) async {
    await _plugin.cancel(id: id.hashCode);
  }

  Future<void> showRingNotification(String senderName) async {
    const androidDetails = AndroidNotificationDetails(
      'ring_channel',
      'Incoming Rings',
      channelDescription: 'High-priority wake-up ring alerts',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
      autoCancel: false,
      ongoing: true,
      ticker: 'Incoming ring',
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(
      id: 999,
      title: '📞 $senderName is calling!',
      body: 'Wake Up! Open the app to respond',
      notificationDetails: details,
    );
  }

  Future<void> cancelRingNotification() async {
    await _plugin.cancel(id: 999);
  }

  Future<void> showMessageNotification(
      String senderName, String text) async {
    const androidDetails = AndroidNotificationDetails(
      'message_channel',
      'New Messages',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: senderName,
      body: text,
      notificationDetails: details,
    );
  }
}
