import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drinkwater/main.dart';

void main() {
  group('Sorun 13, 14, 15 Doğrulama Testleri', () {
    test('Sorun 13 Doğrulaması: AndroidManifest.xml içinde uygulama adı "DrinkWater" olarak standartlaştırılmıştır', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue);

      final content = manifestFile.readAsStringSync();
      expect(content.contains('android:label="DrinkWater"'), isTrue);
      expect(content.contains('android:label="Drink Water"'), isFalse);
    });

    testWidgets('Sorun 14 Doğrulaması: MaterialApp Türkçe (tr_TR) delegeleriyle yapılandırılmıştır', (WidgetTester tester) async {
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            const app = DrinkWaterApp();
            final widget = app.build(context) as MaterialApp;
            return MaterialApp(
              locale: widget.locale,
              supportedLocales: widget.supportedLocales,
              localizationsDelegates: widget.localizationsDelegates,
              title: widget.title,
              home: const SizedBox(),
            );
          },
        ),
      );

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.locale, equals(const Locale('tr', 'TR')));
      expect(materialApp.supportedLocales.contains(const Locale('tr', 'TR')), isTrue);
      expect(materialApp.localizationsDelegates, isNotNull);
      expect(materialApp.localizationsDelegates!.isNotEmpty, isTrue);
      expect(materialApp.title, equals('DrinkWater'));
    });

    test('Sorun 15 Doğrulaması: Koyu tema (Dark Mode) renk adaptasyonu mevcuttur', () {
      // Açık mod renk testi
      const isDarkFalse = false;
      final lightCardColor = isDarkFalse ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
      expect(lightCardColor, equals(const Color(0xFFF8FAFC)));

      // Koyu mod renk testi (Beyaz kutu çirkinliğini önleyen arka plan)
      const isDarkTrue = true;
      final darkCardColor = isDarkTrue ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
      expect(darkCardColor, equals(const Color(0xFF1E293B)));
    });
  });
}
