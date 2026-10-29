import 'package:flutter_test/flutter_test.dart';
import 'package:tran_nguyen_vi_khang_app/models/child_model.dart';
import 'package:tran_nguyen_vi_khang_app/models/device_model.dart';
import 'package:tran_nguyen_vi_khang_app/models/monitoring_rule_model.dart';
import 'package:tran_nguyen_vi_khang_app/providers/children_provider.dart';
import 'package:tran_nguyen_vi_khang_app/providers/devices_provider.dart';
import 'package:tran_nguyen_vi_khang_app/providers/monitoring_rules_provider.dart';
import 'package:tran_nguyen_vi_khang_app/services/api_service.dart';
import 'package:tran_nguyen_vi_khang_app/services/child_service.dart';
import 'package:tran_nguyen_vi_khang_app/services/device_service.dart';
import 'package:tran_nguyen_vi_khang_app/services/monitoring_rule_service.dart';

// =============================================================================
// FAKE SERVICES (In-memory mock services for isolated unit testing)
// Note: These unit tests use mock services and do NOT hit the real SQL Server.
// =============================================================================

class FakeChildService extends Fake implements ChildService {
  final List<ChildModel> inMemoryChildren = [];
  bool shouldThrow = false;
  String throwMessage = 'Lỗi kết nối máy chủ';

  @override
  Future<List<ChildModel>> getChildren({int? parentId}) async {
    if (shouldThrow) throw ApiException(statusCode: 500, message: throwMessage);
    return List.from(inMemoryChildren);
  }

  @override
  Future<ChildModel> createChild({
    required String fullName,
    DateTime? dateOfBirth,
    required int parentId,
  }) async {
    if (shouldThrow) throw ApiException(statusCode: 400, message: throwMessage);
    final newChild = ChildModel(
      id: inMemoryChildren.length + 1,
      fullName: fullName,
      dateOfBirth: dateOfBirth,
      parentId: parentId,
      createdAt: DateTime.now(),
      deviceCount: 0,
      monitoringRuleCount: 0,
    );
    inMemoryChildren.add(newChild);
    return newChild;
  }

  @override
  Future<ChildModel> updateChild({
    required int id,
    required String fullName,
    DateTime? dateOfBirth,
  }) async {
    if (shouldThrow) throw ApiException(statusCode: 400, message: throwMessage);
    final index = inMemoryChildren.indexWhere((c) => c.id == id);
    if (index == -1) throw const ApiException(statusCode: 404, message: 'Child not found');
    final updated = ChildModel(
      id: id,
      fullName: fullName,
      dateOfBirth: dateOfBirth,
      parentId: inMemoryChildren[index].parentId,
      createdAt: inMemoryChildren[index].createdAt,
      deviceCount: inMemoryChildren[index].deviceCount,
      monitoringRuleCount: inMemoryChildren[index].monitoringRuleCount,
    );
    inMemoryChildren[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteChild(int id) async {
    if (shouldThrow) throw ApiException(statusCode: 400, message: throwMessage);
    inMemoryChildren.removeWhere((c) => c.id == id);
  }
}

class FakeDeviceService extends Fake implements DeviceService {
  final List<DeviceModel> inMemoryDevices = [];
  bool shouldThrow = false;
  String throwMessage = 'Lỗi thiết bị';

  @override
  Future<List<DeviceModel>> getDevices({int? childId}) async {
    if (shouldThrow) throw ApiException(statusCode: 500, message: throwMessage);
    if (childId != null) {
      return inMemoryDevices.where((d) => d.childId == childId).toList();
    }
    return List.from(inMemoryDevices);
  }

  @override
  Future<DeviceModel> createDevice({
    required String deviceName,
    String? deviceIdentifier,
    String? platform,
    required int childId,
    bool isActive = true,
  }) async {
    if (shouldThrow) throw ApiException(statusCode: 400, message: throwMessage);
    final device = DeviceModel(
      id: inMemoryDevices.length + 1,
      deviceName: deviceName,
      deviceIdentifier: deviceIdentifier,
      platform: platform,
      childId: childId,
      isActive: isActive,
      createdAt: DateTime.now(),
    );
    inMemoryDevices.add(device);
    return device;
  }

  @override
  Future<DeviceModel> updateDevice({
    required int id,
    required String deviceName,
    String? deviceIdentifier,
    String? platform,
    required bool isActive,
    int? childId,
  }) async {
    if (shouldThrow) throw ApiException(statusCode: 400, message: throwMessage);
    final index = inMemoryDevices.indexWhere((d) => d.id == id);
    if (index == -1) throw const ApiException(statusCode: 404, message: 'Device not found');
    final updated = DeviceModel(
      id: id,
      deviceName: deviceName,
      deviceIdentifier: deviceIdentifier,
      platform: platform,
      childId: childId ?? inMemoryDevices[index].childId,
      isActive: isActive,
      createdAt: inMemoryDevices[index].createdAt,
    );
    inMemoryDevices[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteDevice(int id) async {
    if (shouldThrow) throw ApiException(statusCode: 400, message: throwMessage);
    inMemoryDevices.removeWhere((d) => d.id == id);
  }
}

class FakeMonitoringRuleService extends Fake implements MonitoringRuleService {
  final List<MonitoringRuleModel> inMemoryRules = [];
  bool shouldThrow = false;
  String throwMessage = 'Lỗi quy tắc';

  @override
  Future<List<MonitoringRuleModel>> getRules({int? childId}) async {
    if (shouldThrow) throw ApiException(statusCode: 500, message: throwMessage);
    if (childId != null) {
      return inMemoryRules.where((r) => r.childId == childId).toList();
    }
    return List.from(inMemoryRules);
  }

  @override
  Future<MonitoringRuleModel> createRule({
    required String ruleName,
    required String ruleType,
    String? description,
    String? ruleConfig,
    bool isEnabled = true,
    required int childId,
  }) async {
    if (shouldThrow) throw ApiException(statusCode: 400, message: throwMessage);
    final rule = MonitoringRuleModel(
      id: inMemoryRules.length + 1,
      ruleName: ruleName,
      ruleType: ruleType,
      description: description,
      ruleConfig: ruleConfig,
      isEnabled: isEnabled,
      childId: childId,
      createdAt: DateTime.now(),
    );
    inMemoryRules.add(rule);
    return rule;
  }

  @override
  Future<MonitoringRuleModel> updateRule({
    required int id,
    required String ruleName,
    required String ruleType,
    String? description,
    String? ruleConfig,
    required bool isEnabled,
    int? childId,
  }) async {
    if (shouldThrow) throw ApiException(statusCode: 400, message: throwMessage);
    final index = inMemoryRules.indexWhere((r) => r.id == id);
    if (index == -1) throw const ApiException(statusCode: 404, message: 'Rule not found');
    final updated = MonitoringRuleModel(
      id: id,
      ruleName: ruleName,
      ruleType: ruleType,
      description: description,
      ruleConfig: ruleConfig,
      isEnabled: isEnabled,
      childId: childId ?? inMemoryRules[index].childId,
      createdAt: inMemoryRules[index].createdAt,
    );
    inMemoryRules[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteRule(int id) async {
    if (shouldThrow) throw ApiException(statusCode: 400, message: throwMessage);
    inMemoryRules.removeWhere((r) => r.id == id);
  }
}

// =============================================================================
// TEST SUITE
// =============================================================================

void main() {
  group('1. Models JSON Serialization & Deserialization Tests', () {
    test('ChildModel correctly parses JSON matching backend ChildResponseDto', () {
      final json = {
        'id': 101,
        'fullName': 'Nguyễn Văn Bé',
        'dateOfBirth': '2016-04-15T00:00:00Z',
        'parentId': 5,
        'createdAt': '2026-01-01T10:00:00Z',
        'deviceCount': 2,
        'monitoringRuleCount': 3,
      };

      final child = ChildModel.fromJson(json);

      expect(child.id, 101);
      expect(child.fullName, 'Nguyễn Văn Bé');
      expect(child.dateOfBirth, isNotNull);
      expect(child.dateOfBirth!.year, 2016);
      expect(child.parentId, 5);
      expect(child.deviceCount, 2);
      expect(child.monitoringRuleCount, 3);
      expect(child.age, isNotNull);
      expect(child.age! >= 0, isTrue);

      final outJson = child.toJson();
      expect(outJson['fullName'], 'Nguyễn Văn Bé');
      expect(outJson['deviceCount'], 2);
    });

    test('ChildModel handles null dateOfBirth gracefully without throwing', () {
      final json = {
        'id': 102,
        'fullName': 'Trẻ sơ sinh',
        'dateOfBirth': null,
        'parentId': 5,
        'createdAt': '2026-01-01T10:00:00Z',
        'deviceCount': 0,
        'monitoringRuleCount': 0,
      };

      final child = ChildModel.fromJson(json);

      expect(child.dateOfBirth, isNull);
      expect(child.age, isNull);
    });

    test('DeviceModel correctly parses JSON matching DeviceResponseDto and generates payloads', () {
      final json = {
        'id': 201,
        'deviceName': 'iPad Học Tập',
        'deviceIdentifier': 'APPLE-SN-998877',
        'platform': 'iPadOS',
        'childId': 101,
        'isActive': true,
        'createdAt': '2026-01-01T10:00:00Z',
      };

      final device = DeviceModel.fromJson(json);

      expect(device.id, 201);
      expect(device.deviceName, 'iPad Học Tập');
      expect(device.platform, 'iPadOS');
      expect(device.isActive, isTrue);
      expect(device.childId, 101);

      final createPayload = DeviceModel.createPayload(
        deviceName: 'iPad Học Tập',
        platform: 'iPadOS',
        childId: 101,
      );
      expect(createPayload['deviceName'], 'iPad Học Tập');
      expect(createPayload['childId'], 101);
      expect(createPayload['isActive'], isTrue);

      final updatePayload = DeviceModel.updatePayload(
        deviceName: 'iPad Học Tập (Mới)',
        platform: 'iPadOS',
        isActive: false,
      );
      expect(updatePayload['deviceName'], 'iPad Học Tập (Mới)');
      expect(updatePayload['isActive'], isFalse);
    });

    test('MonitoringRuleModel parses JSON matching MonitoringRuleResponseDto', () {
      final json = {
        'id': 301,
        'ruleName': 'Giới hạn dùng YouTube',
        'ruleType': 'TimeLimit',
        'description': 'Tối đa 1 tiếng mỗi ngày',
        'isEnabled': true,
        'childId': 101,
        'createdAt': '2026-01-01T10:00:00Z',
      };

      final rule = MonitoringRuleModel.fromJson(json);

      expect(rule.id, 301);
      expect(rule.ruleName, 'Giới hạn dùng YouTube');
      expect(rule.ruleType, 'TimeLimit');
      expect(rule.isEnabled, isTrue);
      expect(rule.childId, 101);

      final copy = rule.copyWith(isEnabled: false);
      expect(copy.isEnabled, isFalse);
      expect(copy.ruleName, 'Giới hạn dùng YouTube');
    });
  });

  group('2. ChildrenProvider State Management Unit Tests', () {
    late FakeChildService fakeService;
    late ChildrenProvider provider;

    setUp(() {
      fakeService = FakeChildService();
      provider = ChildrenProvider(childService: fakeService);
    });

    test('fetchChildren populates list and sets isEmpty correctly', () async {
      fakeService.inMemoryChildren.add(
        ChildModel(
          id: 1,
          fullName: 'Bé An',
          parentId: 10,
          createdAt: DateTime.now(),
        ),
      );

      expect(provider.isEmpty, isTrue); // Initially empty
      await provider.fetchChildren();

      expect(provider.children.length, 1);
      expect(provider.isEmpty, isFalse); // Now has 1 child
      expect(provider.children.first.fullName, 'Bé An');
      expect(provider.isLoading, isFalse);
      expect(provider.errorMessage, isNull);
    });

    test('fetchChildren captures ApiException and sets errorMessage', () async {
      fakeService.shouldThrow = true;
      fakeService.throwMessage = '401 Unauthorized: Phiên làm việc hết hạn';

      await provider.fetchChildren();

      expect(provider.children, isEmpty);
      expect(provider.errorMessage, contains('401 Unauthorized'));
      expect(provider.isLoading, isFalse);
    });

    test('addChild creates child, calls fetch, and updates provider state', () async {
      final success = await provider.addChild(
        fullName: 'Bé Bình',
        parentId: 10,
      );

      expect(success, isTrue);
      expect(provider.children.length, 1);
      expect(provider.children.first.fullName, 'Bé Bình');
      expect(provider.errorMessage, isNull);
    });

    test('updateChild updates child details and preserves id', () async {
      await provider.addChild(fullName: 'Tên Ban Đầu', parentId: 10);
      final id = provider.children.first.id;

      final success = await provider.updateChild(
        id: id,
        fullName: 'Tên Đã Chỉnh Sửa',
      );

      expect(success, isTrue);
      expect(provider.children.first.fullName, 'Tên Đã Chỉnh Sửa');
    });

    test('deleteChild removes child and updates children list', () async {
      await provider.addChild(fullName: 'Trẻ Sắp Bị Xóa', parentId: 10);
      final id = provider.children.first.id;

      final success = await provider.deleteChild(id);

      expect(success, isTrue);
      expect(provider.children, isEmpty);
    });
  });

  group('3. DevicesProvider State Management Unit Tests', () {
    late FakeDeviceService fakeService;
    late DevicesProvider provider;

    setUp(() {
      fakeService = FakeDeviceService();
      provider = DevicesProvider(deviceService: fakeService);
    });

    test('addDevice and toggleDeviceStatus work correctly', () async {
      final success = await provider.addDevice(
        deviceName: 'Điện thoại Samsung',
        platform: 'Android',
        childId: 1,
        isActive: true,
      );

      expect(success, isTrue);
      expect(provider.devices.length, 1);
      expect(provider.devices.first.isActive, isTrue);

      final toggleSuccess = await provider.toggleDeviceStatus(provider.devices.first);
      expect(toggleSuccess, isTrue);
      expect(provider.devices.first.isActive, isFalse);
    });

    test('deleteDevice removes device from state', () async {
      await provider.addDevice(
        deviceName: 'Thiết bị phụ',
        childId: 1,
      );
      final id = provider.devices.first.id;

      final success = await provider.deleteDevice(id);

      expect(success, isTrue);
      expect(provider.devices, isEmpty);
    });

    test('fetchDevices handles API errors properly', () async {
      fakeService.shouldThrow = true;
      fakeService.throwMessage = 'Máy chủ nội bộ gặp sự cố (500)';

      await provider.fetchDevices();

      expect(provider.errorMessage, contains('Máy chủ nội bộ'));
    });
  });

  group('4. MonitoringRulesProvider State Management Unit Tests', () {
    late FakeMonitoringRuleService fakeService;
    late MonitoringRulesProvider provider;

    setUp(() {
      fakeService = FakeMonitoringRuleService();
      provider = MonitoringRulesProvider(ruleService: fakeService);
    });

    test('addRule and toggleRuleStatus work correctly', () async {
      final success = await provider.addRule(
        ruleName: 'Chặn game sau 20h',
        ruleType: 'AppBlock',
        childId: 1,
        isEnabled: true,
      );

      expect(success, isTrue);
      expect(provider.rules.length, 1);
      expect(provider.rules.first.isEnabled, isTrue);

      final toggleSuccess = await provider.toggleRuleStatus(provider.rules.first);
      expect(toggleSuccess, isTrue);
      expect(provider.rules.first.isEnabled, isFalse);
    });

    test('deleteRule removes rule from state', () async {
      await provider.addRule(
        ruleName: 'Quy tắc thử nghiệm',
        ruleType: 'Custom',
        childId: 1,
      );
      final id = provider.rules.first.id;

      final success = await provider.deleteRule(id);

      expect(success, isTrue);
      expect(provider.rules, isEmpty);
    });
  });
}
