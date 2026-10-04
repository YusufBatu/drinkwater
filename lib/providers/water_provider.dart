import 'package:flutter/foundation.dart';
import '../models/water_log.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';

class DayStat {
  final DateTime date;
  final int totalAmount;
  final int target;
  final bool isCompleted;

  DayStat({
    required this.date,
    required this.totalAmount,
    required this.target,
    required this.isCompleted,
  });
}

class WaterProvider extends ChangeNotifier {
  List<WaterLog> _logs = [];
  int _dailyTarget = 2500;
  double? _userWeight;
  bool _isLoading = true;

  // Bildirim Alanları
  bool _notificationsEnabled = true;
  int _reminderIntervalMinutes = 60;
  int _wakeUpHour = 8;
  int _wakeUpMinute = 0;
  int _bedTimeHour = 23;
  int _bedTimeMinute = 0;

  List<WaterLog> get logs => _logs;
  int get dailyTarget => _dailyTarget;
  double? get userWeight => _userWeight;
  bool get isLoading => _isLoading;

  bool get notificationsEnabled => _notificationsEnabled;
  int get reminderIntervalMinutes => _reminderIntervalMinutes;
  int get wakeUpHour => _wakeUpHour;
  int get wakeUpMinute => _wakeUpMinute;
  int get bedTimeHour => _bedTimeHour;
  int get bedTimeMinute => _bedTimeMinute;

  // Başlangıçta verileri yükle ve bildirimleri kur
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    _logs = await StorageService.loadLogs();
    _dailyTarget = await StorageService.loadDailyTarget();
    _userWeight = await StorageService.loadUserWeight();

    // Bildirim ayarlarını yükle
    _notificationsEnabled = await StorageService.loadNotificationsEnabled();
    _reminderIntervalMinutes = await StorageService.loadReminderInterval();
    _wakeUpHour = await StorageService.loadWakeHour();
    _wakeUpMinute = await StorageService.loadWakeMinute();
    _bedTimeHour = await StorageService.loadBedHour();
    _bedTimeMinute = await StorageService.loadBedMinute();

    // Bildirim servisini başlat ve zamanla
    await NotificationService.init();
    if (_notificationsEnabled) {
      await rescheduleNotifications();
    }

    _isLoading = false;
    notifyListeners();
  }

  // Sadece bugünün kayıtlarını getir
  List<WaterLog> get todayLogs {
    final now = DateTime.now();
    return _logs.where((log) {
      return log.timestamp.year == now.year &&
          log.timestamp.month == now.month &&
          log.timestamp.day == now.day;
    }).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  // Bugün toplam içilen su (ml)
  int get todayIntake {
    return todayLogs.fold(0, (sum, item) => sum + item.amount);
  }

  // Günlük hedefe kalan su (ml)
  int get remainingIntake {
    final remaining = _dailyTarget - todayIntake;
    return remaining > 0 ? remaining : 0;
  }

  // İlerleme oranı (0.0 ile 1.0 arası veya üzeri)
  double get progressRatio {
    if (_dailyTarget <= 0) return 0.0;
    return todayIntake / _dailyTarget;
  }

  // Hedef tamamlandı mı?
  bool get isTargetReached => todayIntake >= _dailyTarget;

  // Su ekle
  Future<void> addWater(int amount) async {
    if (amount <= 0) return;

    final now = DateTime.now();
    final newLog = WaterLog(
      id: '${now.microsecondsSinceEpoch}_${_logs.length}',
      amount: amount,
      timestamp: now,
    );

    _logs.add(newLog);
    await StorageService.saveLogs(_logs);
    notifyListeners();
  }

  // Belirli bir kaydı sil
  Future<void> removeLog(String id) async {
    _logs.removeWhere((log) => log.id == id);
    await StorageService.saveLogs(_logs);
    notifyListeners();
  }

  // Son eklenen suyu geri al (Undo)
  Future<WaterLog?> undoLastLog() async {
    final todayList = todayLogs;
    if (todayList.isEmpty) return null;

    final lastLog = todayList.first;
    await removeLog(lastLog.id);
    return lastLog;
  }

  // Günlük hedefi güncelle
  Future<void> setDailyTarget(int target) async {
    if (target < 500) target = 500;
    _dailyTarget = target;
    await StorageService.saveDailyTarget(target);
    notifyListeners();
  }

  // Kilo bazlı otomatik hedef hesapla ve ayarla (Kilo * 35 ml)
  Future<void> calculateAndSetTargetFromWeight(double weight) async {
    _userWeight = weight;
    await StorageService.saveUserWeight(weight);

    final calculatedTarget = (weight * 35).round();
    await setDailyTarget(calculatedTarget);
  }

  // Son 7 günün günlük istatistiklerini getir
  List<DayStat> getPast7DaysStats() {
    final List<DayStat> stats = [];
    final now = DateTime.now();

    for (int i = 6; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day - i);
      final totalForDay = _logs.where((log) {
        return log.timestamp.year == date.year &&
            log.timestamp.month == date.month &&
            log.timestamp.day == date.day;
      }).fold(0, (sum, item) => sum + item.amount);

      stats.add(
        DayStat(
          date: date,
          totalAmount: totalForDay,
          target: _dailyTarget,
          isCompleted: totalForDay >= _dailyTarget,
        ),
      );
    }
    return stats;
  }

  // Son 30 günün geçmiş listesini getir
  List<DayStat> getPast30DaysHistory() {
    final List<DayStat> history = [];
    final now = DateTime.now();

    for (int i = 0; i < 30; i++) {
      final date = DateTime(now.year, now.month, now.day - i);
      final totalForDay = _logs.where((log) {
        return log.timestamp.year == date.year &&
            log.timestamp.month == date.month &&
            log.timestamp.day == date.day;
      }).fold(0, (sum, item) => sum + item.amount);

      if (totalForDay > 0 || i == 0) {
        history.add(
          DayStat(
            date: date,
            totalAmount: totalForDay,
            target: _dailyTarget,
            isCompleted: totalForDay >= _dailyTarget,
          ),
        );
      }
    }
    return history;
  }

  // Haftalık Ortalama Su Tüketimi (ml)
  int get weeklyAverage {
    final stats = getPast7DaysStats();
    if (stats.isEmpty) return 0;
    final total = stats.fold(0, (sum, s) => sum + s.totalAmount);
    return (total / stats.length).round();
  }

  // Haftalık Hedefe Ulaşılan Gün Sayısı
  int get weeklyCompletedDaysCount {
    final stats = getPast7DaysStats();
    return stats.where((s) => s.isCompleted).length;
  }

  // Başarı Serisi (Streak)
  int get streakCount {
    int streak = 0;
    final now = DateTime.now();

    int startIndex = isTargetReached ? 0 : 1;

    for (int i = startIndex; i < 365; i++) {
      final date = DateTime(now.year, now.month, now.day - i);
      final total = _logs.where((log) {
        return log.timestamp.year == date.year &&
            log.timestamp.month == date.month &&
            log.timestamp.day == date.day;
      }).fold(0, (sum, item) => sum + item.amount);

      if (total >= _dailyTarget) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  // --- Bildirim Yönetimi Metotları ---

  // Bildirimleri Aç / Kapat
  Future<void> toggleNotifications(bool enabled) async {
    _notificationsEnabled = enabled;
    await StorageService.saveNotificationsEnabled(enabled);

    if (enabled) {
      await rescheduleNotifications();
    } else {
      await NotificationService.cancelAllNotifications();
    }
    notifyListeners();
  }

  // Hatırlatma Sıklığını Değiştir
  Future<void> setReminderInterval(int minutes) async {
    _reminderIntervalMinutes = minutes;
    await StorageService.saveReminderInterval(minutes);
    if (_notificationsEnabled) {
      await rescheduleNotifications();
    }
    notifyListeners();
  }

  // Uyanma Saatini Değiştir
  Future<void> setWakeTime(int hour, int minute) async {
    _wakeUpHour = hour;
    _wakeUpMinute = minute;
    await StorageService.saveWakeTime(hour, minute);
    if (_notificationsEnabled) {
      await rescheduleNotifications();
    }
    notifyListeners();
  }

  // Uyku Saatini Değiştir
  Future<void> setBedTime(int hour, int minute) async {
    _bedTimeHour = hour;
    _bedTimeMinute = minute;
    await StorageService.saveBedTime(hour, minute);
    if (_notificationsEnabled) {
      await rescheduleNotifications();
    }
    notifyListeners();
  }

  // Bildirimleri Yeniden Planla
  Future<void> rescheduleNotifications() async {
    await NotificationService.schedulePeriodicReminders(
      intervalMinutes: _reminderIntervalMinutes,
      wakeUpHour: _wakeUpHour,
      wakeUpMinute: _wakeUpMinute,
      bedTimeHour: _bedTimeHour,
      bedTimeMinute: _bedTimeMinute,
    );
  }

  // Anında Test Bildirimi Gönder
  Future<void> sendTestNotification() async {
    await NotificationService.showInstantNotification(
      title: '💧 Test Hatırlatıcısı',
      body: 'Harika! DrinkWater bildirim sistemi telefonunuzda sorunsuz çalışıyor.',
    );
  }

  // 1 Dakika Sonra Zamanlanmış Test Bildirimi Kur
  Future<void> sendOneMinuteReminderTest() async {
    await NotificationService.scheduleOneMinuteTestReminder();
  }

  // Tüm Su Kayıtlarını Tek Seferde Temizle
  Future<void> clearAllLogs() async {
    _logs.clear();
    await StorageService.saveLogs([]);
    notifyListeners();
  }
}
