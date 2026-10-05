import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:health/health.dart';

enum HealthServiceStatus {
  available,
  notInstalled,
  updateRequired,
  unsupportedPlatform,
  error,
}

class HealthService {
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  final Health _health = Health();
  bool _isConfigured = false;
  static const MethodChannel _channel = MethodChannel('com.mert.drinkwater/health_connect');

  static const List<HealthDataType> types = [HealthDataType.STEPS];
  static const List<HealthDataAccess> permissions = [HealthDataAccess.READ];

  Future<void> configure() async {
    if (_isConfigured) return;
    try {
      await _health.configure();
      _isConfigured = true;
    } catch (e) {
      if (kDebugMode) print('Health configure error: $e');
    }
  }

  Future<HealthServiceStatus> checkStatus() async {
    if (!kIsWeb && !Platform.isAndroid && !Platform.isIOS) {
      return HealthServiceStatus.unsupportedPlatform;
    }

    try {
      await configure();
      if (!kIsWeb && Platform.isAndroid) {
        final status = await _health.getHealthConnectSdkStatus();
        switch (status) {
          case HealthConnectSdkStatus.sdkAvailable:
            return HealthServiceStatus.available;
          case HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired:
            return HealthServiceStatus.updateRequired;
          case HealthConnectSdkStatus.sdkUnavailable:
          default:
            return HealthServiceStatus.notInstalled;
        }
      }
      return HealthServiceStatus.available;
    } catch (e) {
      if (kDebugMode) print('Health checkStatus error: $e');
      return HealthServiceStatus.error;
    }
  }

  Future<void> installHealthConnect() async {
    try {
      await _health.installHealthConnect();
    } catch (e) {
      if (kDebugMode) print('Health installHealthConnect error: $e');
    }
  }

  Future<void> openHealthConnectSettings() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _channel.invokeMethod('openHealthConnectSettings');
      } catch (e) {
        if (kDebugMode) print('Health openHealthConnectSettings error: $e');
      }
    }
  }

  Future<bool> hasPermissions() async {
    try {
      await configure();
      final hasPerm = await _health.hasPermissions(types, permissions: permissions);
      return hasPerm == true;
    } catch (e) {
      if (kDebugMode) print('Health hasPermissions error: $e');
      return false;
    }
  }

  Future<bool> requestPermissions() async {
    try {
      await configure();
      final granted = await _health.requestAuthorization(types, permissions: permissions);
      return granted;
    } catch (e) {
      if (kDebugMode) print('Health requestPermissions error: $e');
      return false;
    }
  }

  Future<int?> getStepsForInterval(DateTime start, DateTime end) async {
    try {
      await configure();
      final steps = await _health.getTotalStepsInInterval(start, end);
      return steps;
    } catch (e) {
      if (kDebugMode) print('Health getStepsForInterval error: $e');
      return null;
    }
  }

  Future<int?> getTodaySteps() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
    return await getStepsForInterval(startOfDay, now);
  }
}
