import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Central place to initialize and schedule local phone notifications (reminders).
class LocalNotificationsService {
  static const int _maxAndroidNotificationId = 0x7fffffff; // 2^31 - 1

  static int _toAndroidNotificationId(int id) {
    final mod = id % _maxAndroidNotificationId;
    // Avoid 0 just in case; keeps ids valid and non-zero.
    return mod == 0 ? 1 : mod;
  }
  static final LocalNotificationsService _instance =
      LocalNotificationsService._internal();

  factory LocalNotificationsService() => _instance;

  LocalNotificationsService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    // Initialize timezone database for scheduled notifications.
    // Fallback approach: use device UTC offset as a fixed offset location.
    // (Avoids dependency on flutter_native_timezone which can break Android builds.)
    tzdata.initializeTimeZones();

    // Fallback: use UTC as the local timezone to avoid relying on
    // flutter_native_timezone (which is currently failing to compile).
    tz.setLocalLocation(tz.getLocation('UTC'));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (_) {},
    );

    _initialized = true;
  }

  Future<void> requestPermissions() async {
    // Android 13+ permission is requested in the manifest, but the runtime prompt
    // is still needed.
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  Future<void> scheduleOneShot({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    String? payload,
  }) async {
    await init();

    final safeId = _toAndroidNotificationId(id);

    // Ensure idempotency: cancel any existing notification with the same id.
    await _plugin.cancel(safeId);

    await _plugin.zonedSchedule(
      safeId,
      title,
      body,
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminders',
          'Reminders',
          channelDescription: 'Reminder notifications',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancel(int id) async {
    final safeId = _toAndroidNotificationId(id);
    await _plugin.cancel(safeId);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
