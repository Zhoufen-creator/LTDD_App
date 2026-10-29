import '../models/device_activity_event_model.dart';
import '../models/monitoring_rule_model.dart';

class RuleEvaluationResult {
  final bool isBlocked;
  final String? violationAction;
  final String? violationReason;
  final MonitoringRuleModel? violatedRule;

  const RuleEvaluationResult({
    required this.isBlocked,
    this.violationAction,
    this.violationReason,
    this.violatedRule,
  });

  static const RuleEvaluationResult allowed = RuleEvaluationResult(isBlocked: false);
}

class RuleExecutionEngine {
  // In-memory daily usage tracking per package (in seconds)
  final Map<String, int> _dailyAppUsageSeconds = {};
  int _lastTrackingDay = -1;

  Map<String, int> get dailyAppUsageSeconds => Map.unmodifiable(_dailyAppUsageSeconds);

  /// Resets app usage counters if the calendar day has changed.
  void checkAndResetDailyUsage({DateTime? now}) {
    final current = now ?? DateTime.now();
    final currentDay = current.day;
    if (_lastTrackingDay != currentDay) {
      _dailyAppUsageSeconds.clear();
      _lastTrackingDay = currentDay;
    }
  }

  /// Records usage duration for a package in today's counter.
  void recordAppUsage(String packageName, int durationSeconds, {DateTime? now}) {
    if (packageName.isEmpty || durationSeconds <= 0) return;
    checkAndResetDailyUsage(now: now);
    _dailyAppUsageSeconds[packageName] =
        (_dailyAppUsageSeconds[packageName] ?? 0) + durationSeconds;
  }

  /// Sets accumulated usage directly (e.g. restored from previous sessions).
  void setAccumulatedUsage(String packageName, int totalSeconds) {
    _dailyAppUsageSeconds[packageName] = totalSeconds;
  }

  /// Evaluates an active foreground app package against all enabled rules.
  RuleEvaluationResult evaluateForegroundApp({
    required String packageName,
    required List<MonitoringRuleModel> rules,
    DateTime? currentTime,
  }) {
    if (packageName.isEmpty) return RuleEvaluationResult.allowed;

    final now = currentTime ?? DateTime.now();
    checkAndResetDailyUsage(now: now);

    final enabledRules = rules.where((r) => r.isEnabled).toList();

    // 1. Evaluate BedTime Rules first (highest priority restriction)
    for (final rule in enabledRules.where((r) => r.ruleType == 'BedTime')) {
      final config = rule.bedTimeConfig;
      if (config != null) {
        if (isInsideBedtimeWindow(now: now, config: config)) {
          return RuleEvaluationResult(
            isBlocked: true,
            violationAction: 'BedTimeLock',
            violationReason:
                'Thiết bị đang trong Giờ đi ngủ (${config.bedtimeStart} - ${config.bedtimeEnd}) được cấu hình bởi cha mẹ.',
            violatedRule: rule,
          );
        }
      }
    }

    // 2. Evaluate AppBlock Rules
    for (final rule in enabledRules.where((r) => r.ruleType == 'AppBlock')) {
      final config = rule.appBlockConfig;
      if (config != null && config.targetPackage.trim() == packageName.trim()) {
        return RuleEvaluationResult(
          isBlocked: true,
          violationAction: 'Blocked',
          violationReason: 'Ứng dụng "${config.appName}" đã bị chặn theo quy tắc của cha mẹ.',
          violatedRule: rule,
        );
      }
    }

    // 3. Evaluate TimeLimit Rules
    for (final rule in enabledRules.where((r) => r.ruleType == 'TimeLimit')) {
      final config = rule.timeLimitConfig;
      if (config != null && config.targetPackage.trim() == packageName.trim()) {
        final usedSeconds = _dailyAppUsageSeconds[packageName] ?? 0;
        final maxSeconds = config.dailyLimitMinutes * 60;
        if (usedSeconds >= maxSeconds) {
          final usedMinutes = (usedSeconds / 60).floor();
          return RuleEvaluationResult(
            isBlocked: true,
            violationAction: 'TimeExceeded',
            violationReason:
                'Ứng dụng "${config.appName}" đã đạt giới hạn sử dụng trong ngày ($usedMinutes/${config.dailyLimitMinutes} phút).',
            violatedRule: rule,
          );
        }
      }
    }

    return RuleEvaluationResult.allowed;
  }

  /// Calculates whether a given time is inside the bedtime window, correctly supporting midnight crossing.
  static bool isInsideBedtimeWindow({
    required DateTime now,
    required BedTimeConfig config,
  }) {
    // Check day of week (1 = Monday, 7 = Sunday)
    if (!config.daysOfWeek.contains(now.weekday)) {
      return false;
    }

    final startParts = config.bedtimeStart.split(':');
    final endParts = config.bedtimeEnd.split(':');
    if (startParts.length < 2 || endParts.length < 2) return false;

    final startHour = int.tryParse(startParts[0]) ?? 22;
    final startMin = int.tryParse(startParts[1]) ?? 0;
    final endHour = int.tryParse(endParts[0]) ?? 6;
    final endMin = int.tryParse(endParts[1]) ?? 0;

    final startMinutes = startHour * 60 + startMin;
    final endMinutes = endHour * 60 + endMin;
    final currentMinutes = now.hour * 60 + now.minute;

    if (startMinutes > endMinutes) {
      // Crosses midnight (e.g. 22:00 to 06:00)
      return currentMinutes >= startMinutes || currentMinutes < endMinutes;
    } else {
      // Same-day window (e.g. 13:00 to 15:00)
      return currentMinutes >= startMinutes && currentMinutes < endMinutes;
    }
  }

  /// Creates a DeviceActivityEventModel for a detected rule violation.
  DeviceActivityEventModel createViolationEvent({
    required RuleEvaluationResult result,
    required String packageName,
    String? appName,
  }) {
    return DeviceActivityEventModel.create(
      eventType: 'RuleViolation',
      packageName: packageName,
      appName: appName,
      ruleId: result.violatedRule?.id,
      violationAction: result.violationAction ?? 'Blocked',
      violationDetails: result.violationReason,
    );
  }
}
