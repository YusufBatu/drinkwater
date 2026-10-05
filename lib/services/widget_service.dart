import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

class WidgetService {
  static const String _widget2x2Name = 'DrinkWaterWidgetProvider';
  static const String _widget2x1Name = 'DrinkWaterWidget2x1Provider';

  static Future<void> updateWidgetData({
    required int todayWater,
    required int waterTarget,
    required int todaySteps,
    required int stepTarget,
    int? stepBaseline,
    String? stepDateKey,
  }) async {
    if (!kIsWeb && !Platform.isAndroid && !Platform.isIOS) return;

    try {
      final int safeWaterTarget = waterTarget > 0 ? waterTarget : 2500;
      final int waterPercent = ((todayWater / safeWaterTarget) * 100).toInt().clamp(0, 999);
      final String waterText = '$todayWater / $safeWaterTarget ml';
      final String waterPercentText = '%$waterPercent';

      final int safeStepTarget = stepTarget > 0 ? stepTarget : 8000;
      final int stepPercent = ((todaySteps / safeStepTarget) * 100).toInt().clamp(0, 999);
      final String stepText = '$todaySteps / $safeStepTarget';
      final String stepPercentText = '%$stepPercent';

      await HomeWidget.saveWidgetData<String>('water_text', waterText);
      await HomeWidget.saveWidgetData<String>('water_percent', waterPercentText);
      await HomeWidget.saveWidgetData<int>('water_progress', waterPercent.clamp(0, 100));

      await HomeWidget.saveWidgetData<String>('step_text', stepText);
      await HomeWidget.saveWidgetData<String>('step_percent', stepPercentText);
      await HomeWidget.saveWidgetData<int>('step_progress', stepPercent.clamp(0, 100));

      // Native Kotlin sensör hesaplaması için gerekli meta veriler
      await HomeWidget.saveWidgetData<int>('step_target_raw', safeStepTarget);
      if (stepBaseline != null) {
        await HomeWidget.saveWidgetData<int>('step_baseline', stepBaseline);
      }
      if (stepDateKey != null && stepDateKey.isNotEmpty) {
        await HomeWidget.saveWidgetData<String>('step_date_key', stepDateKey);
      }

      // 2x2 Widget Güncellemesi
      await HomeWidget.updateWidget(
        name: _widget2x2Name,
        androidName: _widget2x2Name,
        qualifiedAndroidName: 'com.mert.drinkwater.drinkwater.DrinkWaterWidgetProvider',
      );

      // 2x1 Widget Güncellemesi
      await HomeWidget.updateWidget(
        name: _widget2x1Name,
        androidName: _widget2x1Name,
        qualifiedAndroidName: 'com.mert.drinkwater.drinkwater.DrinkWaterWidget2x1Provider',
      );
    } catch (e) {
      if (kDebugMode) {
        print('Widget güncelleme hatası: $e');
      }
    }
  }
}
