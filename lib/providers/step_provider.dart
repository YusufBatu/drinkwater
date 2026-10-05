import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/step_log.dart';
import '../services/storage_service.dart';
import '../services/health_service.dart';

enum StepSource {
  deviceSensor,
  healthConnect,
  manual,
}

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

  StepSource _currentSource = StepSource.deviceSensor;
  bool _isHealthConnectEnabled = false;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  StreamSubscription<StepCount>? _stepCountSubscription;
  StreamSubscription<PedestrianStatus>? _pedestrianStatusSubscription;

  int get todaySteps => _todaySteps;
  int get stepTarget => _stepTarget;
  String get pedestrianStatus => _pedestrianStatus;
  bool get isSensorAvailable => _isSensorAvailable;
  bool get isLoading => _isLoading;
  List<StepLog> get history => _history;
  StepSource get currentSource => _currentSource;
  bool get isHealthConnectEnabled => _isHealthConnectEnabled;
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;

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
    _isHealthConnectEnabled = await StorageService.loadHealthConnectEnabled();

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
      // Gün değişmiş (gece yarısı 00:00 geçmiş veya ertesi gün açılmış)
      if (savedTodaySteps > 0) {
        _archiveDay(savedDateKey, savedTodaySteps);
      }
      _lastDateKey = todayKey;
      _todaySteps = 0;
      _baselineSensorSteps = -1;
      await StorageService.saveStepBaselineAndDate(_baselineSensorSteps, _lastDateKey);
      await StorageService.saveTodaySteps(0);
    } else {
      // Gün içi yeniden açılış
      _lastDateKey = todayKey;
      _todaySteps = savedTodaySteps;
      _baselineSensorSteps = savedBaseline;
    }

    if (_isHealthConnectEnabled) {
      final hasPerm = await HealthService().hasPermissions();
      if (hasPerm) {
        _currentSource = StepSource.healthConnect;
        _pedestrianStatus = 'Senkronize';
        await syncHealthConnectSteps();
      } else {
        _currentSource = StepSource.deviceSensor;
        await _initPedometer();
      }
    } else {
      _currentSource = StepSource.deviceSensor;
      await _initPedometer();
    }

    // Ana Ekran Widget'ını güncelle
    await StorageService.syncAppWidget();

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
    try {
      final status = await Permission.activityRecognition.request();
      if (status.isDenied || status.isPermanentlyDenied) {
        _isSensorAvailable = false;
        notifyListeners();
        return;
      }
    } catch (e) {
      if (kDebugMode) print("İzin kontrolü hatası: $e");
    }

    try {
      // Eski abonelikler varsa iptal et (çift dinleyici ve sızıntıyı önle)
      await _stepCountSubscription?.cancel();
      _stepCountSubscription = null;
      await _pedestrianStatusSubscription?.cancel();
      _pedestrianStatusSubscription = null;

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
      StorageService.syncAppWidget();
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
    StorageService.syncAppWidget();
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
    StorageService.syncAppWidget();
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
      int targetForDay = _stepTarget;
      if (i == 0) {
        stepsForDay = _todaySteps;
        targetForDay = _stepTarget;
      } else {
        final found = _history.firstWhere(
          (h) => h.dateKey == dateKey,
          orElse: () => StepLog(dateKey: dateKey, steps: 0, target: _stepTarget, distanceKm: 0, calories: 0),
        );
        stepsForDay = found.steps;
        targetForDay = found.target > 0 ? found.target : _stepTarget;
      }

      stats.add(
        StepDayStat(
          date: date,
          steps: stepsForDay,
          target: targetForDay,
          isCompleted: stepsForDay >= targetForDay,
        ),
      );
    }
    return stats;
  }

  // --- Health Connect & Senkronizasyon Metotları ---

  /// Health Connect senkronizasyonunu etkinleştir
  Future<bool> enableHealthConnect() async {
    final status = await HealthService().checkStatus();
    if (status != HealthServiceStatus.available) {
      if (status == HealthServiceStatus.notInstalled) {
        await HealthService().installHealthConnect();
      }
      return false;
    }

    final granted = await HealthService().requestPermissions();
    if (granted) {
      _isHealthConnectEnabled = true;
      _currentSource = StepSource.healthConnect;
      await StorageService.saveHealthConnectEnabled(true);

      // Cihaz sensörü dinleyicilerini durdur (batarya tasarrufu)
      await _stepCountSubscription?.cancel();
      _stepCountSubscription = null;
      await _pedestrianStatusSubscription?.cancel();
      _pedestrianStatusSubscription = null;
      _pedestrianStatus = 'Senkronize';

      await syncHealthConnectSteps();
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Health Connect senkronizasyonunu devre dışı bırak ve cihaz sensörüne dön
  Future<void> disableHealthConnect() async {
    _isHealthConnectEnabled = false;
    _currentSource = StepSource.deviceSensor;
    await StorageService.saveHealthConnectEnabled(false);
    await _initPedometer();
    notifyListeners();
  }

  /// Uygulama arka plandan açıldığında veya yenilendiğinde adımları güncelle
  Future<void> sync() async {
    if (_isHealthConnectEnabled) {
      await syncHealthConnectSteps();
    } else {
      final todayKey = _getTodayKey();
      if (_lastDateKey != todayKey && _lastDateKey.isNotEmpty) {
        if (_todaySteps > 0) {
          _archiveDay(_lastDateKey, _todaySteps);
        }
        _lastDateKey = todayKey;
        _todaySteps = 0;
        _baselineSensorSteps = -1;
        await StorageService.saveStepBaselineAndDate(_baselineSensorSteps, _lastDateKey);
        await StorageService.saveTodaySteps(0);
        notifyListeners();
      }
    }
  }

  /// Health Connect üzerinden bugünün ve geçmiş günlerin adımlarını çek
  Future<void> syncHealthConnectSteps() async {
    if (_isSyncing) return;
    _isSyncing = true;
    notifyListeners();

    try {
      final steps = await HealthService().getTodaySteps();
      final todayKey = _getTodayKey();

      if (_lastDateKey != todayKey && _lastDateKey.isNotEmpty) {
        if (_todaySteps > 0) {
          _archiveDay(_lastDateKey, _todaySteps);
        }
        _lastDateKey = todayKey;
        await StorageService.saveStepBaselineAndDate(-1, _lastDateKey);
      }

      if (steps != null) {
        _todaySteps = steps.clamp(0, 999999);
        await StorageService.saveTodaySteps(_todaySteps);
        StorageService.syncAppWidget();
        _lastSyncTime = DateTime.now();
        _isSensorAvailable = true;
      }

      // Geçmiş 7 günün Health Connect adımlarını da arşivle
      final now = DateTime.now();
      for (int i = 1; i <= 7; i++) {
        final date = DateTime(now.year, now.month, now.day - i);
        final dayStart = DateTime(date.year, date.month, date.day, 0, 0, 0);
        final dayEnd = DateTime(date.year, date.month, date.day, 23, 59, 59);
        final pastSteps = await HealthService().getStepsForInterval(dayStart, dayEnd);
        if (pastSteps != null && pastSteps > 0) {
          final pastDateKey = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
          _archiveDay(pastDateKey, pastSteps);
        }
      }
    } catch (e) {
      if (kDebugMode) print("Health Connect senkronizasyon hatası: $e");
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // Tüm Adım Verilerini Tek Seferde Temizle
  Future<void> resetAllStepData() async {
    _todaySteps = 0;
    _history.clear();
    _baselineSensorSteps = -1;
    _lastSyncTime = null;
    await StorageService.saveTodaySteps(0);
    await StorageService.saveStepHistory([]);
    await StorageService.saveStepBaselineAndDate(-1, _getTodayKey());
    StorageService.syncAppWidget();
    notifyListeners();
  }

  // Sensör veya Health Connect iznini tekrar iste / ayarları aç
  Future<void> retryPermissionAndInit() async {
    if (_isHealthConnectEnabled) {
      await enableHealthConnect();
    } else {
      final status = await Permission.activityRecognition.request();
      if (status.isGranted) {
        _isSensorAvailable = true;
        await _initPedometer();
        notifyListeners();
      } else if (status.isPermanentlyDenied) {
        await openAppSettings();
      }
    }
  }

  @override
  void dispose() {
    _stepCountSubscription?.cancel();
    _pedestrianStatusSubscription?.cancel();
    super.dispose();
  }
}
