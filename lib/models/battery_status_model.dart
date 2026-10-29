/// Represents current device battery reading and charging state.
class BatteryStatusModel {
  final int percentage;
  final bool isCharging;
  final DateTime observedAt;

  const BatteryStatusModel({
    required this.percentage,
    required this.isCharging,
    required this.observedAt,
  });

  /// Formatted percentage string (e.g. "85%", "⚡ 85%").
  String get displayString {
    final prefix = isCharging ? '⚡ ' : '';
    return '$prefix$percentage%';
  }

  /// Whether current level is critically low (< 20%).
  bool get isLow => percentage < 20;

  /// Alias for [isLow] for consistency across models.
  bool get isLowBattery => isLow;

  Map<String, dynamic> toJson() {
    return {
      'batteryPercentage': percentage,
      'isCharging': isCharging,
      'observedAt': observedAt.toIso8601String(),
    };
  }

  @override
  String toString() => 'BatteryStatus($percentage%, charging: $isCharging)';
}
