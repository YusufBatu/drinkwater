import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  // Bildirim servisini başlat ve Android kanalını kaydet
  static Future<void> init() async {
    if (_isInitialized) return;

    // Saat dilimlerini başlat
    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _notificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (kDebugMode) {
          print("Bildirime tıklandı: ${response.payload}");
        }
      },
    );

    // Android 13+ bildirim izni iste
    await requestPermissions();

    _isInitialized = true;
  }

  // İzinleri İste (Android 13+ POST_NOTIFICATIONS & EXACT_ALARM)
  static Future<bool> requestPermissions() async {
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      final bool? granted = await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();
      return granted ?? false;
    }
    return false;
  }

  // Anında Test Bildirimi Gönder
  static Future<void> showInstantNotification({
    required String title,
    required String body,
  }) async {
    await init();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'drinkwater_instant_channel',
      'Anlık Hatırlatıcılar',
      channelDescription: 'Su içme hatırlatma test bildirimleri',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.show(
      id: 0,
      title: title,
      body: body,
      notificationDetails: platformDetails,
    );
  }

  // Uyanma ve Yatma Saatleri Arasında Periyodik Bildirimleri Planla
  static Future<void> schedulePeriodicReminders({
    required int intervalMinutes,
    required int wakeUpHour,
    required int wakeUpMinute,
    required int bedTimeHour,
    required int bedTimeMinute,
  }) async {
    await init();
    // Önceki planlanmış tüm bildirimleri temizle
    await cancelAllNotifications();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'drinkwater_scheduled_channel',
      'Su İçme Hatırlatıcıları',
      channelDescription: 'Periyodik su içme hatırlatıcı bildirimleri',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    final List<String> reminderMessages = [
      "Vücudunu susuz bırakma! Bir bardak su içme zamanı 💧",
      "Küçük bir mola verip bir bardak su içmeye ne dersin? 🥛",
      "Enerjini yüksek tut! Su içmeyi unutma ⚡",
      "Bugünkü hedefine yaklaşmak için harika bir an! 🎯",
      "Cildin ve sağlığın için bir bardak taze su iç 🌊",
    ];

    int notificationId = 100;
    final now = DateTime.now();

    final int startTotalMinutes = wakeUpHour * 60 + wakeUpMinute;
    final int endTotalMinutes = bedTimeHour * 60 + bedTimeMinute;

    if (startTotalMinutes >= endTotalMinutes) return;

    int currentMinute = startTotalMinutes;
    int messageIndex = 0;

    while (currentMinute <= endTotalMinutes) {
      final int hour = currentMinute ~/ 60;
      final int minute = currentMinute % 60;

      DateTime scheduledDate = DateTime(
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      // Eğer saat bugünün vaktini geçtiyse yarına planla
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      final tz.TZDateTime tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);
      final String msg = reminderMessages[messageIndex % reminderMessages.length];

      try {
        await _notificationsPlugin.zonedSchedule(
          id: notificationId++,
          title: '💧 Su İçme Zamanı!',
          body: msg,
          scheduledDate: tzScheduledDate,
          notificationDetails: platformDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } catch (e) {
        if (kDebugMode) {
          print("Bildirim planlanırken hata: $e");
        }
      }

      currentMinute += intervalMinutes;
      messageIndex++;
    }
  }

  // Tüm Bildirimleri İptal Et
  static Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }
}
