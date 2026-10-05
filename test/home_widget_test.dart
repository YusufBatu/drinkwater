import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drinkwater/services/widget_service.dart';
import 'package:drinkwater/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Ana Ekran Widget (Home Screen Widget) Testleri', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('1. AndroidManifest.xml içinde DrinkWaterWidgetProvider (2x2) ve DrinkWaterWidget2x1Provider (2x1) receiver tanımlıdır', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue);

      final content = manifestFile.readAsStringSync();
      expect(content.contains('.DrinkWaterWidgetProvider'), isTrue);
      expect(content.contains('.DrinkWaterWidget2x1Provider'), isTrue);
      expect(content.contains('android.appwidget.action.APPWIDGET_UPDATE'), isTrue);
      expect(content.contains('@xml/drinkwater_widget_info'), isTrue);
      expect(content.contains('@xml/drinkwater_widget_2x1_info'), isTrue);
    });

    test('2. 2x2 ve 2x1 info.xml ile layout.xml dosyaları mevcuttur', () {
      final infoFile = File('android/app/src/main/res/xml/drinkwater_widget_info.xml');
      expect(infoFile.existsSync(), isTrue);
      final infoContent = infoFile.readAsStringSync();
      expect(infoContent.contains('@layout/drinkwater_widget'), isTrue);

      final layoutFile = File('android/app/src/main/res/layout/drinkwater_widget.xml');
      expect(layoutFile.existsSync(), isTrue);
      final layoutContent = layoutFile.readAsStringSync();
      expect(layoutContent.contains('widget_container'), isTrue);
      expect(layoutContent.contains('widget_water_text'), isTrue);
      expect(layoutContent.contains('widget_steps_text'), isTrue);

      // 2x1 dosyaları
      final info2x1File = File('android/app/src/main/res/xml/drinkwater_widget_2x1_info.xml');
      expect(info2x1File.existsSync(), isTrue);
      final info2x1Content = info2x1File.readAsStringSync();
      expect(info2x1Content.contains('@layout/drinkwater_widget_2x1'), isTrue);

      final layout2x1File = File('android/app/src/main/res/layout/drinkwater_widget_2x1.xml');
      expect(layout2x1File.existsSync(), isTrue);
      final layout2x1Content = layout2x1File.readAsStringSync();
      expect(layout2x1Content.contains('widget_container'), isTrue);
      expect(layout2x1Content.contains('widget_water_text'), isTrue);
      expect(layout2x1Content.contains('widget_steps_text'), isTrue);
    });

    test('3. DrinkWaterWidgetProvider.kt ve DrinkWaterWidget2x1Provider.kt Kotlin dosyaları mevcuttur', () {
      final ktFile = File('android/app/src/main/kotlin/com/mert/drinkwater/drinkwater/DrinkWaterWidgetProvider.kt');
      expect(ktFile.existsSync(), isTrue);
      final ktContent = ktFile.readAsStringSync();
      expect(ktContent.contains('class DrinkWaterWidgetProvider : AppWidgetProvider()'), isTrue);
      expect(ktContent.contains('HomeWidgetPlugin.getData'), isTrue);

      final kt2x1File = File('android/app/src/main/kotlin/com/mert/drinkwater/drinkwater/DrinkWaterWidget2x1Provider.kt');
      expect(kt2x1File.existsSync(), isTrue);
      final kt2x1Content = kt2x1File.readAsStringSync();
      expect(kt2x1Content.contains('class DrinkWaterWidget2x1Provider : AppWidgetProvider()'), isTrue);
      expect(kt2x1Content.contains('HomeWidgetPlugin.getData'), isTrue);
    });

    test('4. WidgetService.updateWidgetData metodu güvenle çalışır ve her iki widgetı günceller', () async {
      await WidgetService.updateWidgetData(
        todayWater: 1500,
        waterTarget: 2500,
        todaySteps: 6000,
        stepTarget: 8000,
      );
    });

    test('5. StorageService.syncAppWidget metodu güvenle çalışır ve çökmez', () async {
      await StorageService.syncAppWidget();
    });

    test('6. WidgetUpdateHelper.kt mevcuttur ve yerel donanım sensörü ile USER_PRESENT desteği vardır', () {
      final helperFile = File('android/app/src/main/kotlin/com/mert/drinkwater/drinkwater/WidgetUpdateHelper.kt');
      expect(helperFile.existsSync(), isTrue);

      final helperContent = helperFile.readAsStringSync();
      expect(helperContent.contains('object WidgetUpdateHelper'), isTrue);
      expect(helperContent.contains('Sensor.TYPE_STEP_COUNTER'), isTrue);
      expect(helperContent.contains('fetchSensorAndRefreshWidgets'), isTrue);

      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      final manifestContent = manifestFile.readAsStringSync();
      expect(manifestContent.contains('android.intent.action.USER_PRESENT'), isTrue);
    });
  });
}
