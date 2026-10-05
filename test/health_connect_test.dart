import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drinkwater/services/storage_service.dart';
import 'package:drinkwater/services/health_service.dart';
import 'package:drinkwater/providers/step_provider.dart';
import 'package:health/health.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Health Connect & Arka Plan Adım Takibi Testleri', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('1. AndroidManifest.xml içinde Health Connect konfigürasyonu eksiksizdir', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue);

      final content = manifestFile.readAsStringSync();
      // READ_STEPS izni
      expect(content.contains('android.permission.health.READ_STEPS'), isTrue);
      // Health Connect sorgu paketi
      expect(content.contains('com.google.android.apps.healthdata'), isTrue);
      // Android 13 ve altı intent filter
      expect(content.contains('androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE'), isTrue);
      // Android 14+ activity alias
      expect(content.contains('ViewPermissionUsageActivity'), isTrue);
      expect(content.contains('android.permission.START_VIEW_PERMISSION_USAGE'), isTrue);
      expect(content.contains('android.intent.category.HEALTH_PERMISSIONS'), isTrue);
    });

    test('2. StorageService Health Connect tercihini doğru kaydeder ve yükler', () async {
      expect(await StorageService.loadHealthConnectEnabled(), isFalse);

      await StorageService.saveHealthConnectEnabled(true);
      expect(await StorageService.loadHealthConnectEnabled(), isTrue);

      await StorageService.saveHealthConnectEnabled(false);
      expect(await StorageService.loadHealthConnectEnabled(), isFalse);
    });

    test('3. HealthService singleton ve yapılandırma türleri doğrudur', () {
      final s1 = HealthService();
      final s2 = HealthService();
      expect(identical(s1, s2), isTrue);

      expect(HealthService.types.contains(HealthDataType.STEPS), isTrue);
      expect(HealthService.permissions.contains(HealthDataAccess.READ), isTrue);
    });

    test('4. StepProvider Health Connect başlangıç durumu ve reset yönetimi', () async {
      final provider = StepProvider();
      expect(provider.isHealthConnectEnabled, isFalse);
      expect(provider.currentSource, equals(StepSource.deviceSensor));
      expect(provider.isSyncing, isFalse);
      expect(provider.lastSyncTime, isNull);

      // Manuel adım ekleme
      provider.manualAddSteps(1250);
      expect(provider.todaySteps, equals(1250));

      // Veri sıfırlama
      await provider.resetAllStepData();
      expect(provider.todaySteps, equals(0));
      expect(provider.history, isEmpty);
      expect(provider.lastSyncTime, isNull);
    });

    test('5. StepProvider sync() çağrısı güvenle çalışır ve çökmez', () async {
      final provider = StepProvider();
      await provider.sync();
      expect(provider.isSyncing, isFalse);
    });
  });
}
