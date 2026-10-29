import 'package:battery_plus/battery_plus.dart';
import '../models/battery_status_model.dart';

/// Abstract contract for device battery observation.
/// Enables mock substitution during unit and widget testing.
abstract class IBatteryService {
  Future<BatteryStatusModel> getBatteryStatus();
  Stream<BatteryState> get onBatteryStateChanged;
}

/// Concrete implementation utilizing the official `battery_plus` plugin.
class BatteryService implements IBatteryService {
  final Battery _battery;

  BatteryService({Battery? battery}) : _battery = battery ?? Battery();

  @override
  Future<BatteryStatusModel> getBatteryStatus() async {
    try {
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      final isCharging = state == BatteryState.charging || state == BatteryState.full;

      return BatteryStatusModel(
        percentage: level,
        isCharging: isCharging,
        observedAt: DateTime.now().toUtc(),
      );
    } catch (_) {
      // Fallback for unsupported emulators/platforms
      return BatteryStatusModel(
        percentage: 100,
        isCharging: false,
        observedAt: DateTime.now().toUtc(),
      );
    }
  }

  @override
  Stream<BatteryState> get onBatteryStateChanged => _battery.onBatteryStateChanged;
}

