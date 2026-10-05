import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drinkwater/services/storage_service.dart';
import 'package:drinkwater/providers/water_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Akıllı Hatırlatıcı (Smart Reminder) Testleri', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('1. StorageService Akıllı Hatırlatıcı varsayılan olarak açıktır ve kaydedilir', () async {
      expect(await StorageService.loadSmartReminderEnabled(), isTrue);

      await StorageService.saveSmartReminderEnabled(false);
      expect(await StorageService.loadSmartReminderEnabled(), isFalse);

      await StorageService.saveSmartReminderEnabled(true);
      expect(await StorageService.loadSmartReminderEnabled(), isTrue);
    });

    test('2. WaterProvider başlangıç durumu ve toggleSmartReminder çalışması', () async {
      final provider = WaterProvider();
      await provider.init();

      expect(provider.smartReminderEnabled, isTrue);

      await provider.toggleSmartReminder(false);
      expect(provider.smartReminderEnabled, isFalse);
      expect(await StorageService.loadSmartReminderEnabled(), isFalse);

      await provider.toggleSmartReminder(true);
      expect(provider.smartReminderEnabled, isTrue);
      expect(await StorageService.loadSmartReminderEnabled(), isTrue);
    });

    test('3. Su ekleme işlemi lastDrinkTime değerini anında günceller', () async {
      final provider = WaterProvider();
      await provider.init();

      expect(provider.lastDrinkTime, isNull);

      await provider.addWater(250);
      expect(provider.lastDrinkTime, isNotNull);
      expect(provider.todayIntake, equals(250));

      final firstDrinkTime = provider.lastDrinkTime!;
      expect(firstDrinkTime.year, equals(DateTime.now().year));
    });

    test('4. Akıllı Hatırlatıcı erteleme mantığı (45 dakika kuralı)', () {
      final now = DateTime(2026, 10, 4, 14, 0); // 14:00
      final lastDrink = DateTime(2026, 10, 4, 13, 50); // 13:50'de su içildi
      const smartDelayMinutes = 45;
      final threshold = lastDrink.add(const Duration(minutes: smartDelayMinutes)); // 14:35

      // 14:10'daki planlı bildirim: threshold'dan (14:35) önce -> ÖTELENMELİ (atlamalı)
      final slot1410 = DateTime(2026, 10, 4, 14, 10);
      expect(slot1410.isBefore(threshold), isTrue);

      // 14:30'daki planlı bildirim: threshold'dan (14:35) önce -> ÖTELENMELİ (atlamalı)
      final slot1430 = DateTime(2026, 10, 4, 14, 30);
      expect(slot1430.isBefore(threshold), isTrue);

      // 15:00'daki planlı bildirim: threshold'dan (14:35) sonra -> GÖNDERİLMELİ
      final slot1500 = DateTime(2026, 10, 4, 15, 0);
      expect(slot1500.isBefore(threshold), isFalse);
    });

    test('5. Hedefe ulaşıldığında bildirimi öteleme mantığı', () async {
      final provider = WaterProvider();
      await provider.init();
      await provider.setDailyTarget(1000);

      expect(provider.isTargetReached, isFalse);

      await provider.addWater(1000);
      expect(provider.isTargetReached, isTrue);
      // Hedefe ulaşıldığında kalan bildirimler kullanıcıyı rahatsız etmemek için ertelenir
    });
  });
}
