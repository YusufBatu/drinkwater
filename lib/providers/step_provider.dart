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

    _stepTarget = await StorageService.loadStepTarget();
    _baselineSensorSteps = await StorageService.loadStepBaseline();
    _lastDateKey = await StorageService.loadStepDateKey() ?? _getTodayKey();
    _history = await StorageService.loadStepHistory();

    // Gün değişimi kontrolü (Gece 00:00 reset kontrolü)
    _checkDayRollover();

    // Sensör izinlerini iste ve dinlemeyi başlat
    await _initPedometer();

    _isLoading = false;
    notifyListeners();
  }

  String _getTodayKey() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  // Gece 00:00 veya yeni gün kontrolü
  void _checkDayRollover([int currentRawSensorSteps = 0]) {
    final todayKey = _getTodayKey();

    if (_lastDateKey != todayKey && _lastDateKey.isNotEmpty) {
      // Dünün verisini geçmişe arşivle
      if (_todaySteps > 0) {
        final existingIndex = _history.indexWhere((h) => h.dateKey == _lastDateKey);
        final yesterdayLog = StepLog(
          dateKey: _lastDateKey,
          steps: _todaySteps,
          target: _stepTarget,
          distanceKm: distanceKm,
          calories: caloriesBurned,
        );

        if (existingIndex >= 0) {
          _history[existingIndex] = yesterdayLog;
        } else {
          _history.insert(0, yesterdayLog);
        }
        StorageService.saveStepHistory(_history);
      }

      // Bugün için sayacı sıfırla ve yeni gün bazını kaydet
      _todaySteps = 0;
      _baselineSensorSteps = currentRawSensorSteps;
      _lastDateKey = todayKey;
      StorageService.saveStepBaselineAndDate(_baselineSensorSteps, _lastDateKey);
    }
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

    // İlk kez çalışıyorsa veya gün değişmişse
    if (_baselineSensorSteps == -1 || _lastDateKey != todayKey) {
      _checkDayRollover(rawSensorSteps);
      _baselineSensorSteps = rawSensorSteps;
      _lastDateKey = todayKey;
      StorageService.saveStepBaselineAndDate(_baselineSensorSteps, _lastDateKey);
    }

    // Telefon yeniden başlatılmışsa (Sensör değeri baz değerden küçük kalırsa)
    if (rawSensorSteps < _baselineSensorSteps) {
      _baselineSensorSteps = 0;
      StorageService.saveStepBaselineAndDate(_baselineSensorSteps, _lastDateKey);
    }

    _todaySteps = (rawSensorSteps - _baselineSensorSteps).clamp(0, 999999);
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
    _todaySteps += count;
    notifyListeners();
  }

  // Son 7 Günün Adım İstatistikleri (Grafik için)
  List<StepDayStat> getPast7DaysStepStats() {
    final List<StepDayStat> stats = [];
    final now = DateTime.now();

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
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
