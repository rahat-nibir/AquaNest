import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Thin wrapper around flutter_local_notifications. Every call site
/// (AquariumProvider, CameraProvider) goes through `show()` so alert
/// wording, channel choice, and the SettingsProvider on/off check all
/// live in one obvious place instead of being duplicated per feature.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  int _nextId = 0;

  Future<void> init() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings =
        InitializationSettings(android: androidInit, iOS: iosInit);

    try {
      await _plugin.initialize(settings);

      // Android 13+ requires a runtime prompt; iOS needs its own
      // request call. Both are safe no-ops on older platforms/OSes.
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      _initialized = true;
    } catch (e) {
      // Notifications are a "nice to have" proactive layer, not core
      // aquarium functionality — a failure here (e.g. permission
      // denied, unsupported platform) should never block app startup
      // or take down a screen. show() below just becomes a silent
      // no-op if init never succeeded.
      debugPrint('[NotificationService] init failed: $e');
    }
  }

  Future<void> show({
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    Importance importance = Importance.high,
  }) async {
    if (!_initialized) await init();
    if (!_initialized) return;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: importance,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();

    try {
      await _plugin.show(
        _nextId++,
        title,
        body,
        NotificationDetails(android: androidDetails, iOS: iosDetails),
      );
    } catch (e) {
      debugPrint('[NotificationService] show failed: $e');
    }
  }
}
