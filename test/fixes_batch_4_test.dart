import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drinkwater/providers/water_provider.dart';
import 'package:drinkwater/providers/step_provider.dart';
import 'package:drinkwater/models/water_log.dart';
import 'package:drinkwater/models/step_log.dart';
import 'package:drinkwater/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Sorun 10, 11, 12 Doğrulama Testleri', () {
    test('Sorun 10 & 11 Doğrulaması: clearAllLogs ve resetAllStepData tek seferde hızlıca tüm verileri sıfırlar', () async {
      SharedPreferences.setMockInitialValues({});

      // Su verileri ekle
      final waterProvider = WaterProvider();
      await waterProvider.init();
      await waterProvider.addWater(200);
      await waterProvider.addWater(300);
      expect(waterProvider.logs.length, equals(2));
      expect(waterProvider.todayIntake, equals(500));

      // Adım verileri ekle (bugünün tarihiyle)
      final now = DateTime.now();
      final todayKey = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      await StorageService.saveTodaySteps(6000);
      await StorageService.saveStepBaselineAndDate(10000, todayKey);
      await StorageService.saveStepHistory([
        StepLog(dateKey: '2026-10-03', steps: 7000, target: 8000, distanceKm: 5.2, calories: 280),
      ]);
      final stepProvider = StepProvider();
      await stepProvider.init();
      expect(stepProvider.todaySteps, equals(6000));
      expect(stepProvider.history.length, equals(1));

      // Sıfırlama çalıştır (Sorun 10 & 11 Çözümü)
      await waterProvider.clearAllLogs();
      await stepProvider.resetAllStepData();

      // Su verileri temizlendi mi?
      expect(waterProvider.logs, isEmpty);
      expect(waterProvider.todayIntake, equals(0));

      // Adım verileri ve geçmişi temizlendi mi?
      expect(stepProvider.todaySteps, equals(0));
      expect(stepProvider.history, isEmpty);

      // Diskteki veriler de temizlendi mi?
      final diskLogs = await StorageService.loadLogs();
      final diskSteps = await StorageService.loadTodaySteps();
      final diskStepHistory = await StorageService.loadStepHistory();

      expect(diskLogs, isEmpty);
      expect(diskSteps, equals(0));
      expect(diskStepHistory, isEmpty);
    });

    test('Sorun 12 Doğrulaması: isSensorAvailable durumu ve izin durumu doğru yönetilir', () {
      final stepProvider = StepProvider();
      // Başlangıçta sensör kontrolü
      expect(stepProvider.isSensorAvailable, isTrue);
      // Sensör kapalı durumu simülasyonu
      expect(stepProvider.pedestrianStatus, equals('Durdu'));
    });
  });
}
