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
      final dynamic timezoneInfo = await FlutterTimezone.getLocalTimezone();
      String timeZoneName = timezoneInfo is String ? timezoneInfo : (timezoneInfo.identifier ?? '');
      
      // Geçersiz veya ham GMT formatındaysa fallback yap
      if (timeZoneName.isEmpty || timeZoneName.startsWith('GMT') || timeZoneName.startsWith('UTC')) {
        final offsetHours = DateTime.now().timeZoneOffset.inHours;
        if (offsetHours == 3) {
          timeZoneName = 'Europe/Istanbul';
        } else {
          timeZoneName = 'UTC';
        }
      }

      try {
        tz.setLocalLocation(tz.getLocation(timeZoneName));
      } catch (_) {
        if (DateTime.now().timeZoneOffset.inHours == 3) {
          tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
        }
      }
    } catch (e) {
      try {
        if (DateTime.now().timeZoneOffset.inHours == 3) {
          tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
        }
      } catch (_) {}
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

      // Android 13+ bildirim izni ve exact alarm izni iste
      await requestPermissions();
    } catch (e) {
      if (kDebugMode) {
        print("Bildirim eklentisi başlatılamadı: $e");
      }
    }

    _isInitialized = true;
  }

  // İzinleri İste (Android 13+ POST_NOTIFICATIONS)
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

  // Günlük 12:00 ve 21:00 Hatırlatıcılarını Planla
  static Future<void> scheduleDailyReminders() async {
    await init();
    await cancelAllNotifications();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'drinkwater_scheduled_channel',
      'Su İçme Hatırlatıcıları',
      channelDescription: 'Günlük su içme hatırlatıcı bildirimleri (12:00 ve 21:00)',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    final tzNow = tz.TZDateTime.now(tz.local);

    // 1. Öğle Hatırlatıcısı (12:00)
    tz.TZDateTime scheduled12 = tz.TZDateTime(
      tz.local,
      tzNow.year,
      tzNow.month,
      tzNow.day,
      12,
      0,
    );
    if (scheduled12.isBefore(tzNow)) {
      scheduled12 = scheduled12.add(const Duration(days: 1));
    }

    // 2. Akşam Hatırlatıcısı (21:00)
    tz.TZDateTime scheduled21 = tz.TZDateTime(
      tz.local,
      tzNow.year,
      tzNow.month,
      tzNow.day,
      21,
      0,
    );
    if (scheduled21.isBefore(tzNow)) {
      scheduled21 = scheduled21.add(const Duration(days: 1));
    }

    // 12:00 Bildirimini Planla
    try {
      await _notificationsPlugin.zonedSchedule(
        id: 101,
        title: '💧 Gün Ortası Su Molası!',
        body: 'Günün yarısı geride kaldı! Su hedefine yaklaşmak için bir bardak taze su içmeyi unutma 🌊',
        scheduledDate: scheduled12,
        notificationDetails: platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {
      try {
        await _notificationsPlugin.zonedSchedule(
          id: 101,
          title: '💧 Gün Ortası Su Molası!',
          body: 'Günün yarısı geride kaldı! Su hedefine yaklaşmak için bir bardak taze su içmeyi unutma 🌊',
          scheduledDate: scheduled12,
          notificationDetails: platformDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } catch (e) {
        if (kDebugMode) print("12:00 bildirimi planlanamadı: $e");
      }
    }

    // 21:00 Bildirimini Planla
    try {
      await _notificationsPlugin.zonedSchedule(
        id: 102,
        title: '💧 Akşam Su Hatırlatıcısı!',
        body: 'Günü tamamlamadan önce su hedefini kontrol et! Vücudunu susuz bırakma 🥛',
        scheduledDate: scheduled21,
        notificationDetails: platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {
      try {
        await _notificationsPlugin.zonedSchedule(
          id: 102,
          title: '💧 Akşam Su Hatırlatıcısı!',
          body: 'Günü tamamlamadan önce su hedefini kontrol et! Vücudunu susuz bırakma 🥛',
          scheduledDate: scheduled21,
          notificationDetails: platformDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } catch (e) {
        if (kDebugMode) print("21:00 bildirimi planlanamadı: $e");
      }
    }
  }

  // Geriye dönük uyumluluk için alias (12:00 & 21:00)
  static Future<void> schedulePeriodicReminders({
    int intervalMinutes = 60,
    int wakeUpHour = 8,
    int wakeUpMinute = 0,
    int bedTimeHour = 23,
    int bedTimeMinute = 0,
    DateTime? lastDrinkTime,
    bool smartReminderEnabled = false,
    bool isTargetReached = false,
    int smartDelayMinutes = 45,
  }) async {
    await scheduleDailyReminders();
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
      importance: Importance.max,
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
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      if (kDebugMode) {
        print("1 dakikalık test exact hatası, inexact deneniyor: $e");
      }
      try {
        await _notificationsPlugin.zonedSchedule(
          id: 999,
          title: '💧 1 Dakikalık Hatırlatma Testi!',
          body: 'Harika! Zamanlanmış arka plan hatırlatıcıları telefonunda sorunsuz çalışıyor ⏱️',
          scheduledDate: tzDate,
          notificationDetails: const NotificationDetails(android: androidDetails),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (innerError) {
        if (kDebugMode) {
          print("1 dakikalık test bildirimi hatası: $innerError");
        }
      }
    }
  }
}
