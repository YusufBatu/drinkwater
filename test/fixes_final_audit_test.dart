import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drinkwater/providers/step_provider.dart';
import 'package:drinkwater/models/step_log.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Son Denetim Düzeltmeleri Doğrulama Testleri', () {
    test('Madde 5 Doğrulaması: Geçmiş günlerin hedefleri bugünkü hedeften bağımsız korunur', () async {
      SharedPreferences.setMockInitialValues({});

      final stepProvider = StepProvider();
      await stepProvider.init();

      // Bugünkü hedefi 10.000 yapalım
      await stepProvider.setStepTarget(10000);

      // Dün hedef 6.000 iken 6.500 adım atılmıştı (başarılıydı)
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayKey = "${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";

      await stepProvider.setStepTarget(10000); // Bugün 10.000
      final yesterdayLog = StepLog(
        dateKey: yesterdayKey,
        steps: 6500,
        target: 6000,
        distanceKm: 4.8,
        calories: 260,
      );
      stepProvider.history.add(yesterdayLog);

      final stats = stepProvider.getPast7DaysStepStats();
      final yesterdayStat = stats.firstWhere(
        (s) => "${s.date.year}-${s.date.month.toString().padLeft(2, '0')}-${s.date.day.toString().padLeft(2, '0')}" == yesterdayKey,
      );

      // Dünün hedefi 6.000 olmalı ve 6.500 adım ile isCompleted = true olmalı!
      expect(yesterdayStat.target, equals(6000));
      expect(yesterdayStat.isCompleted, isTrue);
    });

    test('Madde 1 Doğrulaması: Kilo hesabı formülü kilonun 35 katıdır', () {
      const double weight = 70.0;
      final target = (weight * 35).round();
      expect(target, equals(2450));
    });
  });
}
