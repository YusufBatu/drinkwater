import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() {
  group('Sorun 7, 8, 9 Doğrulama Testleri', () {
    test('Sorun 7 Doğrulaması: Gece yarısını geçen saatlerde (08:00 - 01:30) tüm aralıklar hesaplanır', () {
      int wakeUpHour = 8;
      int wakeUpMinute = 0;
      int bedTimeHour = 1;
      int bedTimeMinute = 30;
      int intervalMinutes = 60;

      final int startTotalMinutes = wakeUpHour * 60 + wakeUpMinute; // 480
      int endTotalMinutes = bedTimeHour * 60 + bedTimeMinute; // 90

      if (endTotalMinutes <= startTotalMinutes) {
        endTotalMinutes += 24 * 60; // 90 + 1440 = 1530
      }

      final List<String> scheduledTimes = [];
      int currentMinute = startTotalMinutes;
      while (currentMinute <= endTotalMinutes) {
        final int normalized = currentMinute % (24 * 60);
        final int hour = normalized ~/ 60;
        final int minute = normalized % 60;
        scheduledTimes.add('${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}');
        currentMinute += intervalMinutes;
      }

      // 08:00'dan başlayıp gece 01:00'e kadar her saat başı eklenmeli
      expect(scheduledTimes.first, equals('08:00'));
      expect(scheduledTimes.contains('23:00'), isTrue);
      expect(scheduledTimes.contains('00:00'), isTrue);
      expect(scheduledTimes.contains('01:00'), isTrue);
      expect(scheduledTimes.length, equals(18)); // 08:00..01:00 (18 zaman noktası)
    });

    test('Sorun 8 Doğrulaması: Timezone kütüphanesinde yerel saat dilimi (Europe/Istanbul) atanabilmektedir', () {
      tz.initializeTimeZones();
      final location = tz.getLocation('Europe/Istanbul');
      tz.setLocalLocation(location);

      expect(tz.local.name, equals('Europe/Istanbul'));
      final now = tz.TZDateTime.now(tz.local);
      expect(now.timeZoneOffset.inHours, equals(3)); // UTC+3
    });

    test('Sorun 9 Doğrulaması: DateTime(year, month, day - i) ay ve gün sınırlarında Duration(days) kayması yaşatmaz', () {
      // Örnek: 1 Mart 2024 (Artık yıl)
      final marchFirst = DateTime(2024, 3, 1, 0, 30); // 00:30

      // Eski yöntem Duration(days: 1) saat kayması olan geçişlerde veya saat farklarında risklidir.
      // Yeni yöntem:
      final previousDaySafe = DateTime(marchFirst.year, marchFirst.month, marchFirst.day - 1);
      
      expect(previousDaySafe.year, equals(2024));
      expect(previousDaySafe.month, equals(2));
      expect(previousDaySafe.day, equals(29)); // 29 Şubat olarak kesin ve doğru hesaplanır
    });
  });
}
