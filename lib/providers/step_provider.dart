import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/step_log.dart';
import '../services/storage_service.dart';

class StepDayStat {
  final DateTime date;
  final int steps;
  final int target;
  final bool isCompleted;

  StepDayStat({
    required this.date,
    required this.steps,
    required this.target,
    required this.isCompleted,
  });
}

class StepProvider extends ChangeNotifier {
  int _todaySteps = 0;
  int _stepTarget = 8000;
  int _baselineSensorSteps = -1;
  String _lastDateKey = '';
  String _pedestrianStatus = 'Durdu';
  bool _isSensorAvailable = true;
  bool _isLoading = true;
  List<StepLog> _history = [];

  StreamSubscription<StepCount>? _stepCountSubscription;
  StreamSubscription<PedestrianStatus>? _pedestrianStatusSubscription;

  int get todaySteps => _todaySteps;
  int get stepTarget => _stepTarget;
  String get pedestrianStatus => _pedestrianStatus;
  bool get isSensorAvailable => _isSensorAvailable;
  bool get isLoading => _isLoading;
  List<StepLog> get history => _history;

  // Hesaplanan Metrikler
  double get distanceKm => _todaySteps * 0.00075; // Ortalama 75 cm adım boyu
  int get caloriesBurned => (_todaySteps * 0.04).round(); // Ortalama 0.04 kcal/adım
  double get progressRatio => _stepTarget > 0 ? _todaySteps / _stepTarget : 0.0;
  bool get isTargetReached => _todaySteps >= _stepTarget;
  int get remainingSteps => (_stepTarget - _todaySteps) > 0 ? (_stepTarget - _todaySteps) : 0;

  // Başlatma ve İzin Yönetimi
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    final todayKey = _getTodayKey();
    _stepTarget = await StorageService.loadStepTarget();
    _history = await StorageService.loadStepHistory();

    final savedDateKey = await StorageService.loadStepDateKey();
    final savedTodaySteps = await StorageService.loadTodaySteps();
    final savedBaseline = await StorageService.loadStepBaseline();

    if (savedDateKey == null || savedDateKey.isEmpty) {
      // Uygulamanın ilk kez açılışı
      _lastDateKey = todayKey;
      _todaySteps = 0;
      _baselineSensorSteps = -1;
      await StorageService.saveStepBaselineAndDate(_baselineSensorSteps, _lastDateKey);
      await StorageService.saveTodaySteps(0);
    } else if (savedDateKey != todayKey) {
      // 1. SORUNUN ÇÖZÜMÜ: Gün değişmiş (gece yarısı 00:00 geçmiş veya ertesi gün açılmış)
      // Dünün adımları diske kaydedilmişti; şimdi geçmişe güvenle arşivliyoruz.
      if (savedTodaySteps > 0) {
        _archiveDay(savedDateKey, savedTodaySteps);
      }

      // 2. SORUNUN ÇÖZÜMÜ: Yeni gün için sayacı sıfırla, baseline'ı -1 bırak
      // (Böylece 0 kabul edilip hayalet 50.000 adım patlaması yaşanmaz; ilk sensör verisi gelince baz alınır)
      _lastDateKey = todayKey;
      _todaySteps = 0;
      _baselineSensorSteps = -1;
      await StorageService.saveStepBaselineAndDate(_baselineSensorSteps, _lastDateKey);
      await StorageService.saveTodaySteps(0);
    } else {
      // 3. SORUNUN ÇÖZÜMÜ: Gün içi yeniden açılış
      // Önceden diske kaydedilen adımları anında yükle (0 görünmez)
      _lastDateKey = todayKey;
      _todaySteps = savedTodaySteps;
      _baselineSensorSteps = savedBaseline;
    }

    // Sensör izinlerini iste ve dinlemeyi başlat
    await _initPedometer();

    _isLoading = false;
    notifyListeners();
  }

  String _getTodayKey() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  // Geçmiş güne ait adımları arşive ekler
  void _archiveDay(String dateKey, int steps) {
    final existingIndex = _history.indexWhere((h) => h.dateKey == dateKey);
    final log = StepLog(
      dateKey: dateKey,
      steps: steps,
      target: _stepTarget,
      distanceKm: steps * 0.00075,
      calories: (steps * 0.04).round(),
    );

    if (existingIndex >= 0) {
      _history[existingIndex] = log;
    } else {
      _history.insert(0, log);
    }
    StorageService.saveStepHistory(_history);
  }

  // Sensörü başlat
  Future<void> _initPedometer() async {
    // Android Aktivite Tanıma İzni
    final status = await Permission.activityRecognition.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      _isSensorAvailable = false;
      notifyListeners();
      return;
    }

    try {
      // Adım sayar akışını dinle
      _stepCountSubscription = Pedometer.stepCountStream.listen(
        _onStepCount,
        onError: (error) {
          if (kDebugMode) print("Pedometer StepCount Error: $error");
          _isSensorAvailable = false;
          notifyListeners();
        },
      );

      // Yürüme durumu akışını dinle (Yürüyor / Durdu)
      _pedestrianStatusSubscription = Pedometer.pedestrianStatusStream.listen(
        _onPedestrianStatusChanged,
        onError: (error) {
          if (kDebugMode) print("Pedometer Status Error: $error");
        },
      );
    } catch (e) {
      _isSensorAvailable = false;
      notifyListeners();
    }
  }

  void _onStepCount(StepCount event) {
    final int rawSensorSteps = event.steps;
    final todayKey = _getTodayKey();

    // 1. Uygulama açıkken gün değişimi olduysa (Gece 00:00 rollover)
    if (_lastDateKey != todayKey && _lastDateKey.isNotEmpty) {
      if (_todaySteps > 0) {
        _archiveDay(_lastDateKey, _todaySteps);
      }
      _lastDateKey = todayKey;
      _baselineSensorSteps = rawSensorSteps;
      _todaySteps = 0;
      StorageService.saveStepBaselineAndDate(_baselineSensorSteps, _lastDateKey);
      StorageService.saveTodaySteps(0);
    }

    // 2. Bugünün baseline'ı henüz belirlenmemişse (yeni günün ilk sensör verisi)
    // Böylece rawSensorSteps ne kadar büyük olursa olsun (örn: 60.000), baz olarak alınır ve gün 0'dan başlar.
    if (_baselineSensorSteps == -1) {
      _baselineSensorSteps = rawSensorSteps - _todaySteps;
      if (_baselineSensorSteps < 0) _baselineSensorSteps = rawSensorSteps;
      StorageService.saveStepBaselineAndDate(_baselineSensorSteps, _lastDateKey);
    }

    // 3. Telefon yeniden başlatılmışsa (rawSensorSteps baz değerden küçük olursa)
    if (rawSensorSteps < _baselineSensorSteps) {
      // Yeniden başlatma öncesi atılan adımlar _todaySteps içinde korunur
      _baselineSensorSteps = rawSensorSteps - _todaySteps;
      StorageService.saveStepBaselineAndDate(_baselineSensorSteps, _lastDateKey);
    }

    // 4. Günlük adım hesabını yap ve diske kaydet
    final calculated = rawSensorSteps - _baselineSensorSteps;
    if (calculated >= _todaySteps) {
      _todaySteps = calculated.clamp(0, 999999);
      StorageService.saveTodaySteps(_todaySteps);
    }

    _isSensorAvailable = true;
    notifyListeners();
  }

  void _onPedestrianStatusChanged(PedestrianStatus event) {
    if (event.status == 'walking') {
      _pedestrianStatus = 'Yürüyor 🚶';
    } else if (event.status == 'stopped') {
      _pedestrianStatus = 'Durdu 🛑';
    } else {
      _pedestrianStatus = 'Bilinmiyor';
    }
    notifyListeners();
  }

  // Manuel Adım Hedefi Değiştir
  Future<void> setStepTarget(int target) async {
    if (target < 1000) target = 1000;
    _stepTarget = target;
    await StorageService.saveStepTarget(target);
    notifyListeners();
  }

  // Test veya Manuel Adım Ekleme (Emülatör/Sensörsüz durumlar için)
  void manualAddSteps(int count) {
    if (count <= 0) return;
    _todaySteps += count;
    if (_baselineSensorSteps != -1) {
      _baselineSensorSteps -= count;
      StorageService.saveStepBaselineAndDate(_baselineSensorSteps, _lastDateKey);
    }
    StorageService.saveTodaySteps(_todaySteps);
    notifyListeners();
  }

  // Son 7 Günün Adım İstatistikleri (Grafik için - DST güvenli)
  List<StepDayStat> getPast7DaysStepStats() {
    final List<StepDayStat> stats = [];
    final now = DateTime.now();

    for (int i = 6; i >= 0; i--) {
      // Duration(days: i) yerine DST ve saat kayması güvenli DateTime hesabı
      final date = DateTime(now.year, now.month, now.day - i);
      final dateKey = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

      int stepsForDay = 0;
      if (i == 0) {
        stepsForDay = _todaySteps;
      } else {
        final found = _history.firstWhere(
          (h) => h.dateKey == dateKey,
          orElse: () => StepLog(dateKey: dateKey, steps: 0, target: _stepTarget, distanceKm: 0, calories: 0),
        );
        stepsForDay = found.steps;
      }

      stats.add(
        StepDayStat(
          date: date,
          steps: stepsForDay,
          target: _stepTarget,
          isCompleted: stepsForDay >= _stepTarget,
        ),
      );
    }
    return stats;
  }

  @override
  void dispose() {
    _stepCountSubscription?.cancel();
    _pedestrianStatusSubscription?.cancel();
    super.dispose();
  }
}
