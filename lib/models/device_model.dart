/// Model representing an enrolled child device retrieved from `/api/devices`.
/// Exactly mirrors `DeviceResponseDto` from ASP.NET Core backend.
class DeviceModel {
  final int id;
  final String deviceName;
  final String? deviceIdentifier;
  final String? platform;
  final int childId;
  final bool isActive;
  final int? batteryPercentage;
  final bool? isCharging;
  final DateTime? batteryUpdatedAt;
  final DateTime createdAt;

  const DeviceModel({
    required this.id,
    required this.deviceName,
    this.deviceIdentifier,
    this.platform,
    required this.childId,
    required this.isActive,
    this.batteryPercentage,
    this.isCharging,
    this.batteryUpdatedAt,
    required this.createdAt,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id: json['id'] as int? ?? 0,
      deviceName: json['deviceName'] as String? ?? '',
      deviceIdentifier: json['deviceIdentifier'] as String?,
      platform: json['platform'] as String?,
      childId: json['childId'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      batteryPercentage: json['batteryPercentage'] as int?,
      isCharging: json['isCharging'] as bool?,
      batteryUpdatedAt: json['batteryUpdatedAt'] != null
          ? DateTime.tryParse(json['batteryUpdatedAt'] as String)?.toUtc()
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceName': deviceName,
      'deviceIdentifier': deviceIdentifier,
      'platform': platform,
      'childId': childId,
      'isActive': isActive,
      if (batteryPercentage != null) 'batteryPercentage': batteryPercentage,
      if (isCharging != null) 'isCharging': isCharging,
      if (batteryUpdatedAt != null) 'batteryUpdatedAt': batteryUpdatedAt!.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Request payload for creating/enrolling a new device (CreateDeviceDto).
  static Map<String, dynamic> createPayload({
    required String deviceName,
    String? deviceIdentifier,
    String? platform,
    required int childId,
    bool isActive = true,
  }) {
    return {
      'deviceName': deviceName.trim(),
      if (deviceIdentifier != null && deviceIdentifier.trim().isNotEmpty)
        'deviceIdentifier': deviceIdentifier.trim(),
      if (platform != null && platform.trim().isNotEmpty)
        'platform': platform.trim(),
      'childId': childId,
      'isActive': isActive,
    };
  }

  /// Request payload for updating an existing device (UpdateDeviceDto).
  static Map<String, dynamic> updatePayload({
    required String deviceName,
    String? deviceIdentifier,
    String? platform,
    required bool isActive,
    int? childId,
  }) {
    final payload = <String, dynamic>{
      'deviceName': deviceName.trim(),
      'deviceIdentifier': (deviceIdentifier != null && deviceIdentifier.trim().isNotEmpty)
          ? deviceIdentifier.trim()
          : null,
      'platform': (platform != null && platform.trim().isNotEmpty)
          ? platform.trim()
          : null,
      'isActive': isActive,
    };
    if (childId != null) {
      payload['childId'] = childId;
    }
    return payload;
  }

  /// Formatted battery label (e.g. "85%", "Đang sạc 85%", or "Chưa có dữ liệu").
  String get batteryFormatted {
    if (batteryPercentage == null) return 'Chưa có dữ liệu';
    final charging = isCharging == true ? ' ⚡' : '';
    return '$batteryPercentage%$charging';
  }

  /// Low battery alert condition (< 20%).
  bool get isLowBattery => batteryPercentage != null && batteryPercentage! < 20;

  /// Stale battery reading condition (> 1 hour old).
  bool get isBatteryStale {
    if (batteryUpdatedAt == null) return true;
    final diff = DateTime.now().toUtc().difference(batteryUpdatedAt!.toUtc());
    return diff.inMinutes >= 60;
  }

  /// Formatted battery observation time.
  String get batteryTimeAgo {
    if (batteryUpdatedAt == null) return 'Chưa có';
    final diff = DateTime.now().toUtc().difference(batteryUpdatedAt!.toUtc());
    if (diff.isNegative || diff.inSeconds < 45) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return '${diff.inDays} ngày trước';
  }

  DeviceModel copyWith({
    int? id,
    String? deviceName,
    String? deviceIdentifier,
    String? platform,
    int? childId,
    bool? isActive,
    int? batteryPercentage,
    bool? isCharging,
    DateTime? batteryUpdatedAt,
    DateTime? createdAt,
  }) {
    return DeviceModel(
      id: id ?? this.id,
      deviceName: deviceName ?? this.deviceName,
      deviceIdentifier: deviceIdentifier ?? this.deviceIdentifier,
      platform: platform ?? this.platform,
      childId: childId ?? this.childId,
      isActive: isActive ?? this.isActive,
      batteryPercentage: batteryPercentage ?? this.batteryPercentage,
      isCharging: isCharging ?? this.isCharging,
      batteryUpdatedAt: batteryUpdatedAt ?? this.batteryUpdatedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'DeviceModel(id: $id, name: $deviceName, battery: $batteryPercentage%, isActive: $isActive)';
}
