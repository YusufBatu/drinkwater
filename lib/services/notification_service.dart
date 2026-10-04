import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  // Bildirim servisini başlat ve Android kanalını kaydet
  static Future<void> init() async {
    if (_isInitialized) return;

    // Saat dilimlerini ve yerel cihaz saat dilimini başlat
    tz.initializeTimeZones();
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = timezoneInfo.identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      if (kDebugMode) {
        print("Yerel saat dilimi tespit edilemedi, varsayılan kullanılıyor: $e");
      }
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    try {
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
    } catch (e) {
      if (kDebugMode) {
        print("Bildirim eklentisi başlatılamadı: $e");
      }
    }

    _isInitialized = true;
  }

  // İzinleri İste (Android 13+ POST_NOTIFICATIONS & EXACT_ALARM)
  static Future<bool> requestPermissions() async {
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      final bool? granted = await androidPlugin.requestNotificationsPermission();
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

    // Sonsuz döngü önlemi: aralık en az 15 dakika olmalı
    final int safeInterval = intervalMinutes <= 0 ? 60 : intervalMinutes;

    final int startTotalMinutes = wakeUpHour * 60 + wakeUpMinute;
    int endTotalMinutes = bedTimeHour * 60 + bedTimeMinute;

    // Gece yarısını geçen uyku saatleri desteği (Örn: Uyanma 08:00, Uyku 01:00)
    if (endTotalMinutes <= startTotalMinutes) {
      endTotalMinutes += 24 * 60;
    }

    int currentMinute = startTotalMinutes;
    int messageIndex = 0;



    while (currentMinute <= endTotalMinutes) {
      final int normalizedMinute = currentMinute % (24 * 60);
      final int hour = normalizedMinute ~/ 60;
      final int minute = normalizedMinute % 60;

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
        // Tam alarm izni yoksa inexact ile garanti planla
        try {
          await _notificationsPlugin.zonedSchedule(
            id: notificationId++,
            title: '💧 Su İçme Zamanı!',
            body: msg,
            scheduledDate: tzScheduledDate,
            notificationDetails: platformDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.time,
          );
        } catch (innerError) {
          if (kDebugMode) {
            print("Bildirim planlanamadı: $innerError");
          }
        }
      }

      currentMinute += safeInterval;
      messageIndex++;
    }
  }

  // Tüm Bildirimleri İptal Et
  static Future<void> cancelAllNotifications() async {
    try {
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      if (kDebugMode) {
        print("Bildirimler iptal edilemedi: $e");
      }
    }
  }

  // 1 Dakika Sonra Zamanlanmış Test Bildirimi Gönder
  static Future<void> scheduleOneMinuteTestReminder() async {
    await init();
    final now = DateTime.now().add(const Duration(minutes: 1));
    final tz.TZDateTime tzDate = tz.TZDateTime.from(now, tz.local);

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

    try {
      await _notificationsPlugin.zonedSchedule(
        id: 999,
        title: '💧 1 Dakikalık Hatırlatma Testi!',
        body: 'Harika! Zamanlanmış arka plan hatırlatıcıları telefonunda sorunsuz çalışıyor ⏱️',
        scheduledDate: tzDate,
        notificationDetails: const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      if (kDebugMode) {
        print("1 dakikalık test bildirimi hatası: $e");
      }
    }
  }
}
