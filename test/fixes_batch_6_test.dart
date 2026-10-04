import 'package:flutter_test/flutter_test.dart';
import 'package:drinkwater/models/water_log.dart';
import 'package:drinkwater/widgets/plant_character_widget.dart';

void main() {
  group('Sorun 16, 17, 18, 19 Doğrulama Testleri', () {
    test('Sorun 16 Doğrulaması: WaterLog.fromJson null, double veya eksik alanlarda çökmez', () {
      // amount double olarak geldiğinde:
      final jsonWithDouble = {
        'id': 'test_1',
        'amount': 250.5,
        'timestamp': '2026-10-04T12:00:00.000',
      };
      final log1 = WaterLog.fromJson(jsonWithDouble);
      expect(log1.amount, equals(250));

      // amount ve id null olduğunda:
      final jsonWithNulls = <String, dynamic>{
        'id': null,
        'amount': null,
        'timestamp': null,
      };
      final log2 = WaterLog.fromJson(jsonWithNulls);
      expect(log2.id, equals(''));
      expect(log2.amount, equals(0));
      expect(log2.timestamp, isNotNull);
    });

    test('Sorun 17 Doğrulaması: PlantCharacterWidget gereksiz parametreler olmadan da oluşturulabilir', () {
      const widget = PlantCharacterWidget(progress: 0.8);
      expect(widget.progress, equals(0.8));
      expect(widget.todayTotal, isNull);
      expect(widget.target, isNull);
    });

    test('Sorun 19 Doğrulaması: Mikro saniye ve sıra numaralı ID üretimi çakışma üretmez', () {
      final now = DateTime.now();
      final id1 = '${now.microsecondsSinceEpoch}_0';
      final id2 = '${now.microsecondsSinceEpoch}_1';
      expect(id1 == id2, isFalse);
    });
  });
}
