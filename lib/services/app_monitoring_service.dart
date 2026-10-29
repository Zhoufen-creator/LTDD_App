import 'package:flutter/services.dart';

abstract class IAppMonitoringService {
  Future<bool> checkUsagePermission();
  Future<bool> openUsageSettings();
  Future<bool> checkOverlayPermission();
  Future<bool> openOverlaySettings();
  Future<List<Map<String, dynamic>>> queryUsageEvents({
    required DateTime startTime,
    required DateTime endTime,
  });
  Future<List<Map<String, String>>> getInstalledApps();
  Future<bool> goToHomeScreen();
  Future<bool> bringAppToFront();
}

class AppMonitoringService implements IAppMonitoringService {
  static const MethodChannel _channel = MethodChannel('vn.edu.parentalcontrol/monitoring');

  const AppMonitoringService();

  @override
  Future<bool> checkUsagePermission() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('checkUsageAccessPermission');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> openUsageSettings() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('openUsageAccessSettings');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> checkOverlayPermission() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('checkOverlayPermission');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> openOverlaySettings() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('openOverlaySettings');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> queryUsageEvents({
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    try {
      final List<dynamic>? raw = await _channel.invokeMethod<List<dynamic>>(
        'queryUsageEvents',
        {
          'startTime': startTime.millisecondsSinceEpoch,
          'endTime': endTime.millisecondsSinceEpoch,
        },
      );
      if (raw == null) return [];
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Map<String, String>>> getInstalledApps() async {
    try {
      final List<dynamic>? raw = await _channel.invokeMethod<List<dynamic>>('getInstalledApps');
      if (raw == null) return [];
      return raw.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return {
          'packageName': m['packageName']?.toString() ?? '',
          'appName': m['appName']?.toString() ?? '',
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<bool> goToHomeScreen() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('goToHomeScreen');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> bringAppToFront() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('bringAppToFront');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}

