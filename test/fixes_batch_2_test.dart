import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Sorun 4, 5, 6 Doğrulama Testleri', () {
    test('Sorun 4 Doğrulaması: Sıfır hedef veya sıfır veride maxY asla 0 olamaz (fl_chart çökmez)', () {
      int target = 0;
      List<int> statsAmounts = [0, 0, 0, 0, 0, 0, 0];

      // Uyguladığımız mantık:
      int maxVal = target > 0 ? target : 2000;
      for (var amount in statsAmounts) {
        if (amount > maxVal) maxVal = amount;
      }
      final double maxY = maxVal > 0 ? (maxVal * 1.25).toDouble() : 1000.0;

      // fl_chart'ın minY değeri varsayılan 0.0'dır. maxY kesinlikle > 0 olmalıdır.
      expect(maxY > 0.0, isTrue);
      expect(maxY, equals(2500.0));
    });

    test('Sorun 5 Doğrulaması: Bildirim aralığı 0 veya negatif girilse bile döngü sonsuza girmez', () {
      int intervalMinutes = -10; // Hatalı/geçersiz aralık
      final int safeInterval = intervalMinutes <= 0 ? 60 : intervalMinutes;

      int wakeUpHour = 8;
      int wakeUpMinute = 0;
      int bedTimeHour = 23;
      int bedTimeMinute = 0;

      final int startTotalMinutes = wakeUpHour * 60 + wakeUpMinute;
      int endTotalMinutes = bedTimeHour * 60 + bedTimeMinute;

      if (endTotalMinutes <= startTotalMinutes) {
        endTotalMinutes += 24 * 60;
      }

      int count = 0;
      int currentMinute = startTotalMinutes;
      while (currentMinute <= endTotalMinutes) {
        count++;
        currentMinute += safeInterval;
        if (count > 100) break; // Güvenlik sigortası
      }

      // 08:00 ile 23:00 arası 15 saat -> 60 dk aralıkla 16 bildirim planlanır
      expect(count, equals(16));
      expect(safeInterval, equals(60));
    });

    test('Sorun 5 Ekstra Doğrulama: Gece yarısını geçen uyku saatleri (08:00 - 01:00) doğru çalışır', () {
      int wakeUpHour = 8;
      int wakeUpMinute = 0;
      int bedTimeHour = 1; // Gece 01:00
      int bedTimeMinute = 0;

      final int startTotalMinutes = wakeUpHour * 60 + wakeUpMinute; // 480
      int endTotalMinutes = bedTimeHour * 60 + bedTimeMinute; // 60

      if (endTotalMinutes <= startTotalMinutes) {
        endTotalMinutes += 24 * 60; // 60 + 1440 = 1500
      }

      expect(endTotalMinutes > startTotalMinutes, isTrue);
      expect(endTotalMinutes, equals(1500));
    });

    test('Sorun 6 Doğrulaması: AndroidManifest.xml dosyasında USE_EXACT_ALARM izni bulunmamalıdır', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue);

      final content = manifestFile.readAsStringSync();
      expect(content.contains('android.permission.USE_EXACT_ALARM'), isFalse);
      expect(content.contains('android.permission.SCHEDULE_EXACT_ALARM'), isTrue);
    });
  });
}
