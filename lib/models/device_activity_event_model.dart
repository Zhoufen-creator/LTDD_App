import 'dart:math';

/// Generates a cryptographically random UUID v4 for activity events.
String generateActivityEventUuid() {
  final rng = Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // Version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // Variant 10
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// Model representing a single device activity or rule violation event recorded on the child device.
/// Queued locally for offline resilience and synced in batch to backend.
class DeviceActivityEventModel {
  final String clientEventId;
  final String eventType;
  final String? packageName;
  final String? appName;
  final DateTime startTime;
  final DateTime? endTime;
  final int? durationSeconds;
  final int? ruleId;
  final String? violationAction;
  final String? violationDetails;
  final DateTime recordedAt;
  final bool isSynced;

  const DeviceActivityEventModel({
    required this.clientEventId,
    required this.eventType,
    this.packageName,
    this.appName,
    required this.startTime,
    this.endTime,
    this.durationSeconds,
    this.ruleId,
    this.violationAction,
    this.violationDetails,
    required this.recordedAt,
    this.isSynced = false,
  });

  factory DeviceActivityEventModel.create({
    required String eventType,
    String? packageName,
    String? appName,
    DateTime? startTime,
    DateTime? endTime,
    int? durationSeconds,
    int? ruleId,
    String? violationAction,
    String? violationDetails,
    DateTime? recordedAt,
  }) {
    final now = DateTime.now().toUtc();
    return DeviceActivityEventModel(
      clientEventId: generateActivityEventUuid(),
      eventType: eventType,
      packageName: packageName,
      appName: appName,
      startTime: startTime ?? now,
      endTime: endTime,
      durationSeconds: durationSeconds,
      ruleId: ruleId,
      violationAction: violationAction,
      violationDetails: violationDetails,
      recordedAt: recordedAt ?? now,
      isSynced: false,
    );
  }

  factory DeviceActivityEventModel.fromJson(Map<String, dynamic> json) {
    return DeviceActivityEventModel(
      clientEventId: json['clientEventId'] as String? ?? generateActivityEventUuid(),
      eventType: json['eventType'] as String? ?? 'General',
      packageName: json['packageName'] as String?,
      appName: json['appName'] as String?,
      startTime: json['startTime'] != null
          ? DateTime.tryParse(json['startTime'] as String) ?? DateTime.now().toUtc()
          : DateTime.now().toUtc(),
      endTime: json['endTime'] != null ? DateTime.tryParse(json['endTime'] as String) : null,
      durationSeconds: json['durationSeconds'] as int?,
      ruleId: json['ruleId'] as int?,
      violationAction: json['violationAction'] as String?,
      violationDetails: json['violationDetails'] as String?,
      recordedAt: json['recordedAt'] != null
          ? DateTime.tryParse(json['recordedAt'] as String) ?? DateTime.now().toUtc()
          : DateTime.now().toUtc(),
      isSynced: json['isSynced'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'clientEventId': clientEventId,
      'eventType': eventType,
      'packageName': packageName,
      'appName': appName,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'durationSeconds': durationSeconds,
      'ruleId': ruleId,
      'violationAction': violationAction,
      'violationDetails': violationDetails,
      'recordedAt': recordedAt.toIso8601String(),
      'isSynced': isSynced,
    };
  }

  /// Converts to payload expected by POST /api/activities/batch (CreateActivityLogDto).
  Map<String, dynamic> toBatchApiPayload() {
    return {
      'clientEventId': clientEventId,
      'eventType': eventType,
      'packageName': packageName,
      'appName': appName,
      'startTime': startTime.toUtc().toIso8601String(),
      'endTime': endTime?.toUtc().toIso8601String(),
      'durationSeconds': durationSeconds,
      'ruleId': ruleId,
      'violationAction': violationAction,
      'violationDetails': violationDetails,
      'recordedAt': recordedAt.toUtc().toIso8601String(),
    };
  }

  DeviceActivityEventModel copyWith({
    String? clientEventId,
    String? eventType,
    String? packageName,
    String? appName,
    DateTime? startTime,
    DateTime? endTime,
    int? durationSeconds,
    int? ruleId,
    String? violationAction,
    String? violationDetails,
    DateTime? recordedAt,
    bool? isSynced,
  }) {
    return DeviceActivityEventModel(
      clientEventId: clientEventId ?? this.clientEventId,
      eventType: eventType ?? this.eventType,
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      ruleId: ruleId ?? this.ruleId,
      violationAction: violationAction ?? this.violationAction,
      violationDetails: violationDetails ?? this.violationDetails,
      recordedAt: recordedAt ?? this.recordedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}

