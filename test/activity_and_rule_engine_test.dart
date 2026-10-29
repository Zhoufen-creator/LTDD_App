import 'package:flutter_test/flutter_test.dart';
import 'package:tran_nguyen_vi_khang_app/models/monitoring_rule_model.dart';
import 'package:tran_nguyen_vi_khang_app/services/app_monitoring_service.dart';
import 'package:tran_nguyen_vi_khang_app/services/rule_execution_engine.dart';

void main() {
  group('RuleExecutionEngine - AppBlock Tests', () {
    final engine = RuleExecutionEngine();

    final blockRule = MonitoringRuleModel(
      id: 1,
      ruleName: 'Khóa TikTok',
      ruleType: 'AppBlock',
      ruleConfig: '{"targetPackage":"com.zhiliaoapp.musically","appName":"TikTok"}',
      isEnabled: true,
      childId: 10,
      createdAt: DateTime.now(),
    );

    test('Blocks foreground app when package matches AppBlock targetPackage', () {
      final result = engine.evaluateForegroundApp(
        packageName: 'com.zhiliaoapp.musically',
        rules: [blockRule],
      );

      expect(result.isBlocked, isTrue);
      expect(result.violationAction, 'Blocked');
      expect(result.violatedRule?.id, 1);
    });

    test('Allows foreground app when package does not match AppBlock targetPackage', () {
      final result = engine.evaluateForegroundApp(
        packageName: 'com.google.android.youtube',
        rules: [blockRule],
      );

      expect(result.isBlocked, isFalse);
    });

    test('Does not block if AppBlock rule is disabled', () {
      final disabledRule = blockRule.copyWith(isEnabled: false);
      final result = engine.evaluateForegroundApp(
        packageName: 'com.zhiliaoapp.musically',
        rules: [disabledRule],
      );

      expect(result.isBlocked, isFalse);
    });
  });

  group('RuleExecutionEngine - TimeLimit Tests', () {
    test('Allows app when cumulative usage is below daily threshold', () {
      final engine = RuleExecutionEngine();
      final timeRule = MonitoringRuleModel(
        id: 2,
        ruleName: 'Giới hạn YouTube',
        ruleType: 'TimeLimit',
        ruleConfig: '{"targetPackage":"com.google.android.youtube","appName":"YouTube","dailyLimitMinutes":30}',
        isEnabled: true,
        childId: 10,
        createdAt: DateTime.now(),
      );

      // Record 15 minutes of usage (900 seconds)
      engine.recordAppUsage('com.google.android.youtube', 900);

      final result = engine.evaluateForegroundApp(
        packageName: 'com.google.android.youtube',
        rules: [timeRule],
      );

      expect(result.isBlocked, isFalse);
    });

    test('Blocks app when cumulative usage reaches or exceeds daily limit', () {
      final engine = RuleExecutionEngine();
      final timeRule = MonitoringRuleModel(
        id: 2,
        ruleName: 'Giới hạn YouTube',
        ruleType: 'TimeLimit',
        ruleConfig: '{"targetPackage":"com.google.android.youtube","appName":"YouTube","dailyLimitMinutes":30}',
        isEnabled: true,
        childId: 10,
        createdAt: DateTime.now(),
      );

      // Record 30 minutes of usage (1800 seconds)
      engine.recordAppUsage('com.google.android.youtube', 1800);

      final result = engine.evaluateForegroundApp(
        packageName: 'com.google.android.youtube',
        rules: [timeRule],
      );

      expect(result.isBlocked, isTrue);
      expect(result.violationAction, 'TimeExceeded');
      expect(result.violationReason, contains('đã đạt giới hạn sử dụng trong ngày'));
    });

    test('Resets daily usage counter on new calendar day', () {
      final engine = RuleExecutionEngine();
      final day1 = DateTime(2026, 10, 28, 15, 0);
      final day2 = DateTime(2026, 10, 29, 9, 0);

      engine.recordAppUsage('com.google.android.youtube', 1800, now: day1);
      expect(engine.dailyAppUsageSeconds['com.google.android.youtube'], 1800);

      // Day changes
      engine.checkAndResetDailyUsage(now: day2);
      expect(engine.dailyAppUsageSeconds['com.google.android.youtube'], isNull);
    });
  });

  group('RuleExecutionEngine - BedTime Tests', () {
    const bedtimeConfig = BedTimeConfig(
      bedtimeStart: '22:00',
      bedtimeEnd: '06:00',
      daysOfWeek: [1, 2, 3, 4, 5, 6, 7], // Every day
    );

    test('Detects time inside cross-midnight window (late evening 23:15)', () {
      // 2026-10-29 is Thursday (weekday = 4)
      final lateEvening = DateTime(2026, 10, 29, 23, 15);
      final isInside = RuleExecutionEngine.isInsideBedtimeWindow(
        now: lateEvening,
        config: bedtimeConfig,
      );

      expect(isInside, isTrue);
    });

    test('Detects time inside cross-midnight window (early morning 03:30)', () {
      final earlyMorning = DateTime(2026, 10, 29, 3, 30);
      final isInside = RuleExecutionEngine.isInsideBedtimeWindow(
        now: earlyMorning,
        config: bedtimeConfig,
      );

      expect(isInside, isTrue);
    });

    test('Detects time outside bedtime window (afternoon 14:00)', () {
      final afternoon = DateTime(2026, 10, 29, 14, 0);
      final isInside = RuleExecutionEngine.isInsideBedtimeWindow(
        now: afternoon,
        config: bedtimeConfig,
      );

      expect(isInside, isFalse);
    });

    test('Respects active days of week filter', () {
      const weekdaysOnly = BedTimeConfig(
        bedtimeStart: '22:00',
        bedtimeEnd: '06:00',
        daysOfWeek: [1, 2, 3, 4, 5], // Mon-Fri
      );

      // Sunday 2026-11-01 (weekday = 7)
      final sundayNight = DateTime(2026, 11, 1, 23, 0);
      final isInside = RuleExecutionEngine.isInsideBedtimeWindow(
        now: sundayNight,
        config: weekdaysOnly,
      );

      expect(isInside, isFalse);
    });
  });

  group('MonitoringRuleModel Serialization Tests', () {
    test('AppMonitoringService checkUsagePermission handles missing channel', () async {
      const service = AppMonitoringService();
      final result = await service.checkUsagePermission();
      expect(result, isFalse);
    });

    test('Correctly serializes and parses AppBlock config', () {
      final rule = MonitoringRuleModel.fromJson({
        'id': 101,
        'ruleName': 'Chặn game',
        'ruleType': 'AppBlock',
        'ruleConfig': '{"targetPackage":"com.roblox.client","appName":"Roblox"}',
        'isEnabled': true,
        'version': 2,
        'syncStatus': 'Active',
        'childId': 5,
        'createdAt': '2026-10-29T10:00:00Z',
      });

      expect(rule.id, 101);
      expect(rule.ruleType, 'AppBlock');
      expect(rule.version, 2);
      expect(rule.syncStatus, 'Active');
      expect(rule.appBlockConfig, isNotNull);
      expect(rule.appBlockConfig!.targetPackage, 'com.roblox.client');
      expect(rule.appBlockConfig!.appName, 'Roblox');
    });

    test('Correctly serializes and parses BedTime config', () {
      final rule = MonitoringRuleModel.fromJson({
        'id': 102,
        'ruleName': 'Giờ đi ngủ',
        'ruleType': 'BedTime',
        'ruleConfig': '{"bedtimeStart":"21:30","bedtimeEnd":"06:30","daysOfWeek":[1,2,3,4,5]}',
        'isEnabled': true,
        'version': 1,
        'syncStatus': 'SyncedToDevice',
        'childId': 5,
        'createdAt': '2026-10-29T10:00:00Z',
      });

      expect(rule.bedTimeConfig, isNotNull);
      expect(rule.bedTimeConfig!.bedtimeStart, '21:30');
      expect(rule.bedTimeConfig!.bedtimeEnd, '06:30');
      expect(rule.bedTimeConfig!.daysOfWeek, [1, 2, 3, 4, 5]);
    });
  });
}
