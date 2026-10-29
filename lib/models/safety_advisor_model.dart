import 'package:flutter/material.dart';

/// Single safety advisor warning or recommendation.
class SafetyWarningModel {
  final String type;
  final String severity;
  final String title;
  final String message;
  final String? reading;
  final DateTime? timestamp;
  final String suggestedAction;
  final String actionType;
  final int? deviceId;
  final String? deviceName;

  const SafetyWarningModel({
    required this.type,
    required this.severity,
    required this.title,
    required this.message,
    this.reading,
    this.timestamp,
    required this.suggestedAction,
    this.actionType = 'None',
    this.deviceId,
    this.deviceName,
  });

  bool get isWarning => severity.toLowerCase() == 'warning';
  bool get isNeedsAttention => severity.toLowerCase() == 'needsattention';
  bool get isInfo => severity.toLowerCase() == 'info';

  bool get isLowBattery => type == 'LowBattery';
  bool get isStaleLocation => type == 'StaleLocation';
  bool get isNoLocation => type == 'NoLocation';
  bool get isMissingBattery => type == 'MissingBattery';
  bool get isNoDevice => type == 'NoDevice';

  bool get canRefreshLocation => actionType == 'RefreshLocation';
  bool get canContactChild => actionType == 'ContactChild';
  bool get canChargeDevice => actionType == 'ChargeDevice';
  bool get canPairDevice => actionType == 'PairDevice';

  Color get severityColor {
    if (isWarning) return const Color(0xFFD32F2F); // Red
    if (isNeedsAttention) return const Color(0xFFF57C00); // Amber/Orange
    return const Color(0xFF1976D2); // Blue
  }

  IconData get icon {
    switch (type) {
      case 'LowBattery':
        return Icons.battery_alert;
      case 'StaleLocation':
        return Icons.location_searching;
      case 'NoLocation':
        return Icons.location_off;
      case 'MissingBattery':
        return Icons.battery_unknown;
      case 'StaleBattery':
        return Icons.battery_saver;
      case 'NoDevice':
        return Icons.phonelink_erase;
      default:
        return Icons.info_outline;
    }
  }

  factory SafetyWarningModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is String && val.isNotEmpty) {
        return DateTime.tryParse(val)?.toLocal();
      }
      return null;
    }

    return SafetyWarningModel(
      type: json['type'] as String? ?? 'Unknown',
      severity: json['severity'] as String? ?? 'NeedsAttention',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      reading: json['reading'] as String?,
      timestamp: parseDate(json['timestamp']),
      suggestedAction: json['suggestedAction'] as String? ?? '',
      actionType: json['actionType'] as String? ?? 'None',
      deviceId: json['deviceId'] as int?,
      deviceName: json['deviceName'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'severity': severity,
    'title': title,
    'message': message,
    'reading': reading,
    'timestamp': timestamp?.toUtc().toIso8601String(),
    'suggestedAction': suggestedAction,
    'actionType': actionType,
    'deviceId': deviceId,
    'deviceName': deviceName,
  };
}

/// Device hardware & battery summary.
class SafetyDeviceSummaryModel {
  final int deviceId;
  final String deviceName;
  final bool isActive;
  final int? batteryPercentage;
  final bool? isCharging;
  final DateTime? batteryUpdatedAt;
  final bool isStaleBattery;

  const SafetyDeviceSummaryModel({
    required this.deviceId,
    required this.deviceName,
    required this.isActive,
    this.batteryPercentage,
    this.isCharging,
    this.batteryUpdatedAt,
    this.isStaleBattery = false,
  });

  bool get hasBatteryData => batteryPercentage != null;
  bool get isLowBattery => batteryPercentage != null && batteryPercentage! < 20;

  factory SafetyDeviceSummaryModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is String && val.isNotEmpty) {
        return DateTime.tryParse(val)?.toLocal();
      }
      return null;
    }

    return SafetyDeviceSummaryModel(
      deviceId: json['deviceId'] as int? ?? 0,
      deviceName: json['deviceName'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
      batteryPercentage: json['batteryPercentage'] as int?,
      isCharging: json['isCharging'] as bool?,
      batteryUpdatedAt: parseDate(json['batteryUpdatedAt']),
      isStaleBattery: json['isStaleBattery'] as bool? ?? false,
    );
  }
}

/// Location recency summary.
class SafetyLocationSummaryModel {
  final int? locationId;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final DateTime? recordedAt;
  final bool isStaleLocation;
  final int? ageMinutes;

  const SafetyLocationSummaryModel({
    this.locationId,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.recordedAt,
    this.isStaleLocation = false,
    this.ageMinutes,
  });

  bool get hasLocation => recordedAt != null && latitude != null && longitude != null;

  factory SafetyLocationSummaryModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is String && val.isNotEmpty) {
        return DateTime.tryParse(val)?.toLocal();
      }
      return null;
    }

    return SafetyLocationSummaryModel(
      locationId: json['locationId'] as int?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      recordedAt: parseDate(json['recordedAt']),
      isStaleLocation: json['isStaleLocation'] as bool? ?? false,
      ageMinutes: json['ageMinutes'] as int?,
    );
  }
}

/// Complete Smart Safety Advisor payload for a child.
class SafetyAdvisorModel {
  final int childId;
  final String childName;
  final String overallStatus;
  final String statusTitle;
  final String statusMessage;
  final DateTime evaluatedAt;
  final bool hasSufficientData;
  final int totalDevices;
  final int activeDevices;
  final SafetyDeviceSummaryModel? primaryDevice;
  final List<SafetyDeviceSummaryModel> devices;
  final SafetyLocationSummaryModel? latestLocation;
  final List<SafetyWarningModel> warnings;

  const SafetyAdvisorModel({
    required this.childId,
    required this.childName,
    required this.overallStatus,
    required this.statusTitle,
    required this.statusMessage,
    required this.evaluatedAt,
    required this.hasSufficientData,
    this.totalDevices = 0,
    this.activeDevices = 0,
    this.primaryDevice,
    this.devices = const [],
    this.latestLocation,
    this.warnings = const [],
  });

  bool get isSafe => overallStatus.toLowerCase() == 'safe';
  bool get isNeedsAttention => overallStatus.toLowerCase() == 'needsattention';
  bool get isWarning => overallStatus.toLowerCase() == 'warning';
  bool get isInsufficientData => overallStatus.toLowerCase() == 'insufficientdata' || !hasSufficientData;

  Color get statusColor {
    if (isWarning) return const Color(0xFFD32F2F); // Red
    if (isNeedsAttention) return const Color(0xFFF57C00); // Amber
    if (isSafe) return const Color(0xFF2E7D32); // Green
    return const Color(0xFF546E7A); // Slate Grey
  }

  IconData get statusIcon {
    if (isWarning) return Icons.warning_rounded;
    if (isNeedsAttention) return Icons.info_rounded;
    if (isSafe) return Icons.check_circle_rounded;
    return Icons.help_outline_rounded;
  }

  String get statusBadgeLabel {
    if (isWarning) return 'Cảnh báo an toàn';
    if (isNeedsAttention) return 'Cần lưu ý';
    if (isSafe) return 'An toàn (theo dữ liệu)';
    return 'Chưa đủ dữ liệu';
  }

  factory SafetyAdvisorModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val is String && val.isNotEmpty) {
        return DateTime.tryParse(val)?.toLocal() ?? DateTime.now();
      }
      return DateTime.now();
    }

    final rawWarnings = json['warnings'] as List<dynamic>? ?? [];
    final rawDevices = json['devices'] as List<dynamic>? ?? [];

    return SafetyAdvisorModel(
      childId: json['childId'] as int? ?? 0,
      childName: json['childName'] as String? ?? '',
      overallStatus: json['overallStatus'] as String? ?? 'InsufficientData',
      statusTitle: json['statusTitle'] as String? ?? '',
      statusMessage: json['statusMessage'] as String? ?? '',
      evaluatedAt: parseDate(json['evaluatedAt']),
      hasSufficientData: json['hasSufficientData'] as bool? ?? false,
      totalDevices: json['totalDevices'] as int? ?? 0,
      activeDevices: json['activeDevices'] as int? ?? 0,
      primaryDevice: json['primaryDevice'] != null
          ? SafetyDeviceSummaryModel.fromJson(json['primaryDevice'] as Map<String, dynamic>)
          : null,
      devices: rawDevices
          .map((d) => SafetyDeviceSummaryModel.fromJson(d as Map<String, dynamic>))
          .toList(),
      latestLocation: json['latestLocation'] != null
          ? SafetyLocationSummaryModel.fromJson(json['latestLocation'] as Map<String, dynamic>)
          : null,
      warnings: rawWarnings
          .map((w) => SafetyWarningModel.fromJson(w as Map<String, dynamic>))
          .toList(),
    );
  }
}

