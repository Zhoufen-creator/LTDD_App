import 'dart:convert';

/// Configuration for AppBlock rule.
class AppBlockConfig {
  final String targetPackage;
  final String appName;

  const AppBlockConfig({
    required this.targetPackage,
    required this.appName,
  });

  factory AppBlockConfig.fromJson(Map<String, dynamic> json) {
    return AppBlockConfig(
      targetPackage: json['targetPackage'] as String? ?? '',
      appName: json['appName'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'targetPackage': targetPackage,
    'appName': appName,
  };
}

/// Configuration for TimeLimit rule.
class TimeLimitConfig {
  final String targetPackage;
  final String appName;
  final int dailyLimitMinutes;

  const TimeLimitConfig({
    required this.targetPackage,
    required this.appName,
    required this.dailyLimitMinutes,
  });

  factory TimeLimitConfig.fromJson(Map<String, dynamic> json) {
    return TimeLimitConfig(
      targetPackage: json['targetPackage'] as String? ?? '',
      appName: json['appName'] as String? ?? '',
      dailyLimitMinutes: json['dailyLimitMinutes'] as int? ?? 60,
    );
  }

  Map<String, dynamic> toJson() => {
    'targetPackage': targetPackage,
    'appName': appName,
    'dailyLimitMinutes': dailyLimitMinutes,
  };
}

/// Configuration for BedTime rule.
class BedTimeConfig {
  final String bedtimeStart; // "HH:mm" (e.g. "22:00")
  final String bedtimeEnd;   // "HH:mm" (e.g. "06:00")
  final List<int> daysOfWeek; // 1 = Monday .. 7 = Sunday
  final String timezone;

  const BedTimeConfig({
    required this.bedtimeStart,
    required this.bedtimeEnd,
    required this.daysOfWeek,
    this.timezone = 'Asia/Ho_Chi_Minh',
  });

  factory BedTimeConfig.fromJson(Map<String, dynamic> json) {
    final days = (json['daysOfWeek'] as List<dynamic>?)
            ?.map((e) => e as int)
            .toList() ??
        [1, 2, 3, 4, 5, 6, 7];
    return BedTimeConfig(
      bedtimeStart: json['bedtimeStart'] as String? ?? '22:00',
      bedtimeEnd: json['bedtimeEnd'] as String? ?? '06:00',
      daysOfWeek: days,
      timezone: json['timezone'] as String? ?? 'Asia/Ho_Chi_Minh',
    );
  }

  Map<String, dynamic> toJson() => {
    'bedtimeStart': bedtimeStart,
    'bedtimeEnd': bedtimeEnd,
    'daysOfWeek': daysOfWeek,
    'timezone': timezone,
  };
}

/// Model representing a monitoring rule retrieved from `/api/monitoringrules`.
/// Exactly mirrors `MonitoringRuleResponseDto` from ASP.NET Core backend.
class MonitoringRuleModel {
  final int id;
  final String ruleName;
  final String ruleType;
  final String? description;
  final String? ruleConfig;
  final bool isEnabled;
  final int version;
  final String syncStatus;
  final DateTime? lastModifiedAt;
  final int childId;
  final DateTime createdAt;

  const MonitoringRuleModel({
    required this.id,
    required this.ruleName,
    required this.ruleType,
    this.description,
    this.ruleConfig,
    required this.isEnabled,
    this.version = 1,
    this.syncStatus = 'ServerSaved',
    this.lastModifiedAt,
    required this.childId,
    required this.createdAt,
  });

  factory MonitoringRuleModel.fromJson(Map<String, dynamic> json) {
    return MonitoringRuleModel(
      id: json['id'] as int? ?? 0,
      ruleName: json['ruleName'] as String? ?? '',
      ruleType: json['ruleType'] as String? ?? 'General',
      description: json['description'] as String?,
      ruleConfig: json['ruleConfig'] as String?,
      isEnabled: json['isEnabled'] as bool? ?? true,
      version: json['version'] as int? ?? 1,
      syncStatus: json['syncStatus'] as String? ?? 'ServerSaved',
      lastModifiedAt: json['lastModifiedAt'] != null
          ? DateTime.tryParse(json['lastModifiedAt'] as String)
          : null,
      childId: json['childId'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ruleName': ruleName,
      'ruleType': ruleType,
      'description': description,
      'ruleConfig': ruleConfig,
      'isEnabled': isEnabled,
      'version': version,
      'syncStatus': syncStatus,
      'lastModifiedAt': lastModifiedAt?.toIso8601String(),
      'childId': childId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Request payload for creating a new monitoring rule (CreateMonitoringRuleDto).
  static Map<String, dynamic> createPayload({
    required String ruleName,
    required String ruleType,
    String? description,
    String? ruleConfig,
    bool isEnabled = true,
    required int childId,
  }) {
    return {
      'ruleName': ruleName.trim(),
      'ruleType': ruleType.trim(),
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      if (ruleConfig != null && ruleConfig.trim().isNotEmpty)
        'ruleConfig': ruleConfig.trim(),
      'isEnabled': isEnabled,
      'childId': childId,
    };
  }

  /// Request payload for updating an existing monitoring rule (UpdateMonitoringRuleDto).
  static Map<String, dynamic> updatePayload({
    required String ruleName,
    required String ruleType,
    String? description,
    String? ruleConfig,
    required bool isEnabled,
    String? syncStatus,
    int? childId,
  }) {
    final payload = <String, dynamic>{
      'ruleName': ruleName.trim(),
      'ruleType': ruleType.trim(),
      'description': (description != null && description.trim().isNotEmpty)
          ? description.trim()
          : null,
      'ruleConfig': (ruleConfig != null && ruleConfig.trim().isNotEmpty)
          ? ruleConfig.trim()
          : null,
      'isEnabled': isEnabled,
      if (syncStatus != null && syncStatus.trim().isNotEmpty)
        'syncStatus': syncStatus.trim(),
    };
    if (childId != null) {
      payload['childId'] = childId;
    }
    return payload;
  }

  MonitoringRuleModel copyWith({
    int? id,
    String? ruleName,
    String? ruleType,
    String? description,
    String? ruleConfig,
    bool? isEnabled,
    int? version,
    String? syncStatus,
    DateTime? lastModifiedAt,
    int? childId,
    DateTime? createdAt,
  }) {
    return MonitoringRuleModel(
      id: id ?? this.id,
      ruleName: ruleName ?? this.ruleName,
      ruleType: ruleType ?? this.ruleType,
      description: description ?? this.description,
      ruleConfig: ruleConfig ?? this.ruleConfig,
      isEnabled: isEnabled ?? this.isEnabled,
      version: version ?? this.version,
      syncStatus: syncStatus ?? this.syncStatus,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      childId: childId ?? this.childId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  AppBlockConfig? get appBlockConfig {
    if (ruleType != 'AppBlock' || ruleConfig == null || ruleConfig!.isEmpty) return null;
    try {
      final map = jsonDecode(ruleConfig!) as Map<String, dynamic>;
      return AppBlockConfig.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  TimeLimitConfig? get timeLimitConfig {
    if (ruleType != 'TimeLimit' || ruleConfig == null || ruleConfig!.isEmpty) return null;
    try {
      final map = jsonDecode(ruleConfig!) as Map<String, dynamic>;
      return TimeLimitConfig.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  BedTimeConfig? get bedTimeConfig {
    if (ruleType != 'BedTime' || ruleConfig == null || ruleConfig!.isEmpty) return null;
    try {
      final map = jsonDecode(ruleConfig!) as Map<String, dynamic>;
      return BedTimeConfig.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() =>
      'MonitoringRuleModel(id: $id, name: $ruleName, type: $ruleType, isEnabled: $isEnabled, status: $syncStatus)';
}
