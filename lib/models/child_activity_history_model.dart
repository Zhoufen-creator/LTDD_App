class ActivityLogModel {
  final int id;
  final String clientEventId;
  final int deviceId;
  final String deviceName;
  final int childId;
  final String eventType;
  final String? packageName;
  final String? appName;
  final DateTime startTime;
  final DateTime? endTime;
  final int? durationSeconds;
  final int? ruleId;
  final String? ruleName;
  final String? violationAction;
  final String? violationDetails;
  final DateTime recordedAt;
  final DateTime createdAt;

  const ActivityLogModel({
    required this.id,
    required this.clientEventId,
    required this.deviceId,
    required this.deviceName,
    required this.childId,
    required this.eventType,
    this.packageName,
    this.appName,
    required this.startTime,
    this.endTime,
    this.durationSeconds,
    this.ruleId,
    this.ruleName,
    this.violationAction,
    this.violationDetails,
    required this.recordedAt,
    required this.createdAt,
  });

  factory ActivityLogModel.fromJson(Map<String, dynamic> json) {
    return ActivityLogModel(
      id: json['id'] as int? ?? 0,
      clientEventId: json['clientEventId'] as String? ?? '',
      deviceId: json['deviceId'] as int? ?? 0,
      deviceName: json['deviceName'] as String? ?? '',
      childId: json['childId'] as int? ?? 0,
      eventType: json['eventType'] as String? ?? 'General',
      packageName: json['packageName'] as String?,
      appName: json['appName'] as String?,
      startTime: json['startTime'] != null
          ? DateTime.tryParse(json['startTime'] as String) ?? DateTime.now()
          : DateTime.now(),
      endTime: json['endTime'] != null ? DateTime.tryParse(json['endTime'] as String) : null,
      durationSeconds: json['durationSeconds'] as int?,
      ruleId: json['ruleId'] as int?,
      ruleName: json['ruleName'] as String?,
      violationAction: json['violationAction'] as String?,
      violationDetails: json['violationDetails'] as String?,
      recordedAt: json['recordedAt'] != null
          ? DateTime.tryParse(json['recordedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class AppUsageSummaryItemModel {
  final String packageName;
  final String appName;
  final int totalDurationSeconds;
  final int sessionCount;

  const AppUsageSummaryItemModel({
    required this.packageName,
    required this.appName,
    required this.totalDurationSeconds,
    required this.sessionCount,
  });

  factory AppUsageSummaryItemModel.fromJson(Map<String, dynamic> json) {
    return AppUsageSummaryItemModel(
      packageName: json['packageName'] as String? ?? '',
      appName: json['appName'] as String? ?? '',
      totalDurationSeconds: json['totalDurationSeconds'] as int? ?? 0,
      sessionCount: json['sessionCount'] as int? ?? 0,
    );
  }

  String get formattedDuration {
    final minutes = (totalDurationSeconds / 60).floor();
    if (minutes < 60) {
      return '$minutes phút';
    }
    final hours = (minutes / 60).floor();
    final remMin = minutes % 60;
    return '${hours}h ${remMin}m';
  }
}

class ActivitySummaryModel {
  final int totalScreenTimeSecondsToday;
  final int ruleViolationsToday;
  final int screenUnlockCountToday;
  final List<AppUsageSummaryItemModel> topAppsToday;

  const ActivitySummaryModel({
    required this.totalScreenTimeSecondsToday,
    required this.ruleViolationsToday,
    required this.screenUnlockCountToday,
    required this.topAppsToday,
  });

  factory ActivitySummaryModel.fromJson(Map<String, dynamic> json) {
    final topAppsList = (json['topAppsToday'] as List<dynamic>?)
            ?.map((e) => AppUsageSummaryItemModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return ActivitySummaryModel(
      totalScreenTimeSecondsToday: json['totalScreenTimeSecondsToday'] as int? ?? 0,
      ruleViolationsToday: json['ruleViolationsToday'] as int? ?? 0,
      screenUnlockCountToday: json['screenUnlockCountToday'] as int? ?? 0,
      topAppsToday: topAppsList,
    );
  }

  String get formattedScreenTime {
    final minutes = (totalScreenTimeSecondsToday / 60).floor();
    if (minutes < 60) {
      return '$minutes phút';
    }
    final hours = (minutes / 60).floor();
    final remMin = minutes % 60;
    return '${hours}h ${remMin}m';
  }
}

class ChildActivityHistoryModel {
  final int childId;
  final String childName;
  final int totalEvents;
  final int page;
  final int pageSize;
  final ActivitySummaryModel summary;
  final List<ActivityLogModel> events;

  const ChildActivityHistoryModel({
    required this.childId,
    required this.childName,
    required this.totalEvents,
    required this.page,
    required this.pageSize,
    required this.summary,
    required this.events,
  });

  factory ChildActivityHistoryModel.fromJson(Map<String, dynamic> json) {
    final eventsList = (json['events'] as List<dynamic>?)
            ?.map((e) => ActivityLogModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final summaryObj = json['summary'] != null
        ? ActivitySummaryModel.fromJson(json['summary'] as Map<String, dynamic>)
        : const ActivitySummaryModel(
            totalScreenTimeSecondsToday: 0,
            ruleViolationsToday: 0,
            screenUnlockCountToday: 0,
            topAppsToday: [],
          );

    return ChildActivityHistoryModel(
      childId: json['childId'] as int? ?? 0,
      childName: json['childName'] as String? ?? '',
      totalEvents: json['totalEvents'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['pageSize'] as int? ?? 50,
      summary: summaryObj,
      events: eventsList,
    );
  }
}

