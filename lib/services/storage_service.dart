import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/water_log.dart';
import '../models/step_log.dart';

class StorageService {
  static const String _keyWaterLogs = 'drinkwater_logs';
  static const String _keyDailyTarget = 'drinkwater_daily_target';
  static const String _keyUserWeight = 'drinkwater_user_weight';
  
  // Bildirim anahtarları
  static const String _keyNotifEnabled = 'drinkwater_notif_enabled';
  static const String _keyNotifInterval = 'drinkwater_notif_interval';
  static const String _keyWakeHour = 'drinkwater_wake_hour';
  static const String _keyWakeMinute = 'drinkwater_wake_minute';
  static const String _keyBedHour = 'drinkwater_bed_hour';
  static const String _keyBedMinute = 'drinkwater_bed_minute';

  // Adımsayar anahtarları
  static const String _keyStepTarget = 'drinkwater_step_target';
  static const String _keyStepBaseline = 'drinkwater_step_baseline';
  static const String _keyStepDateKey = 'drinkwater_step_date_key';
  static const String _keyStepHistory = 'drinkwater_step_history';

  // Su kayıtlarını yükle
  static Future<List<WaterLog>> loadLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final String? rawData = prefs.getString(_keyWaterLogs);
    if (rawData == null || rawData.isEmpty) {
      return [];
    }
    try {
      final List<dynamic> decoded = jsonDecode(rawData);
      return decoded.map((item) => WaterLog.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  // Su kayıtlarını kaydet
  static Future<void> saveLogs(List<WaterLog> logs) async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(logs.map((log) => log.toJson()).toList());
    await prefs.setString(_keyWaterLogs, encoded);
  }

  // Günlük hedefi yükle (Varsayılan: 2500 ml)
  static Future<int> loadDailyTarget() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyDailyTarget) ?? 2500;
  }

  // Günlük hedefi kaydet
  static Future<void> saveDailyTarget(int target) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyDailyTarget, target);
  }

  // Kullanıcı kilosunu yükle
  static Future<double?> loadUserWeight() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyUserWeight);
  }

  // Kullanıcı kilosunu kaydet
  static Future<void> saveUserWeight(double weight) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyUserWeight, weight);
  }

  // --- Bildirim Ayarları ---
  static Future<bool> loadNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNotifEnabled) ?? true;
  }

  static Future<void> saveNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotifEnabled, enabled);
  }

  static Future<int> loadReminderInterval() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyNotifInterval) ?? 60;
  }

  static Future<void> saveReminderInterval(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyNotifInterval, minutes);
  }

  static Future<int> loadWakeHour() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyWakeHour) ?? 8;
  }

  static Future<int> loadWakeMinute() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyWakeMinute) ?? 0;
  }

  static Future<void> saveWakeTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyWakeHour, hour);
    await prefs.setInt(_keyWakeMinute, minute);
  }

  static Future<int> loadBedHour() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyBedHour) ?? 23;
  }

  static Future<int> loadBedMinute() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyBedMinute) ?? 0;
  }

  static Future<void> saveBedTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyBedHour, hour);
    await prefs.setInt(_keyBedMinute, minute);
  }

  // --- Adımsayar Depolama Metotları ---
  static Future<int> loadStepTarget() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyStepTarget) ?? 8000; // Varsayılan 8.000 adım
  }

  static Future<void> saveStepTarget(int target) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyStepTarget, target);
  }

  static Future<int> loadStepBaseline() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyStepBaseline) ?? -1;
  }

  static Future<String?> loadStepDateKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyStepDateKey);
  }

  static Future<void> saveStepBaselineAndDate(int baseline, String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyStepBaseline, baseline);
    await prefs.setString(_keyStepDateKey, dateKey);
  }

  static Future<List<StepLog>> loadStepHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? rawData = prefs.getString(_keyStepHistory);
    if (rawData == null || rawData.isEmpty) return [];
    try {
      final List<dynamic> decoded = jsonDecode(rawData);
      return decoded.map((item) => StepLog.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveStepHistory(List<StepLog> history) async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(history.map((log) => log.toJson()).toList());
    await prefs.setString(_keyStepHistory, encoded);
  }
}
