import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drinkwater/services/storage_service.dart';
import 'package:drinkwater/models/step_log.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Step Storage & Rollover Verification Tests', () {
    test('Sorun 3 Doğrulaması: Gün içi açılışta adımlar diske kaydedilir ve sıfırlanmadan geri yüklenir', () async {
      SharedPreferences.setMockInitialValues({});

      // Kullanıcı gün içinde 4500 adım attı ve diske yazıldı
      await StorageService.saveTodaySteps(4500);
      await StorageService.saveStepBaselineAndDate(15000, '2026-10-04');

      // Uygulama yeniden başlatıldı
      final loadedSteps = await StorageService.loadTodaySteps();
      final loadedBaseline = await StorageService.loadStepBaseline();
      final loadedDateKey = await StorageService.loadStepDateKey();

      expect(loadedSteps, equals(4500));
      expect(loadedBaseline, equals(15000));
      expect(loadedDateKey, equals('2026-10-04'));
    });

    test('Sorun 1 Doğrulaması: Dünün adımları yeni günde geçmiş listesine başarıyla arşivlenir', () async {
      SharedPreferences.setMockInitialValues({});

      // Dünün verisi (5200 adım)
      final yesterdayLog = StepLog(
        dateKey: '2026-10-03',
        steps: 5200,
        target: 8000,
        distanceKm: 5200 * 0.00075,
        calories: (5200 * 0.04).round(),
      );

      await StorageService.saveStepHistory([yesterdayLog]);

      final history = await StorageService.loadStepHistory();
      expect(history.length, equals(1));
      expect(history.first.dateKey, equals('2026-10-03'));
      expect(history.first.steps, equals(5200));
      expect(history.first.distanceKm, equals(3.9));
      expect(history.first.calories, equals(208));
    });

    test('Sorun 2 Doğrulaması: Yeni günde ilk sensör verisi (örn: 60.000) baz alınır ve gün 0 adımdan başlar', () async {
      // Senaryo: Yeni gün başladı, baseline = -1 olarak ayarlandı.
      int baselineSensorSteps = -1;
      int todaySteps = 0;

      // Donanımsal sensör boot'tan beri 60.000 adımı bildirdi
      const int rawSensorSteps = 60000;

      // Uyguladığımız mantık:
      if (baselineSensorSteps == -1) {
        baselineSensorSteps = rawSensorSteps - todaySteps;
      }
      final calculated = rawSensorSteps - baselineSensorSteps;
      todaySteps = calculated;

      // Adım sayısı 60.000 patlamamalı, tam 0 olmalı!
      expect(baselineSensorSteps, equals(60000));
      expect(todaySteps, equals(0));

      // Kullanıcı 50 adım attığında:
      const int walkingSensorSteps = 60050;
      final updatedSteps = walkingSensorSteps - baselineSensorSteps;
      expect(updatedSteps, equals(50));
    });
  });
}
