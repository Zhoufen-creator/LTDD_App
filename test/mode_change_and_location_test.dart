import 'package:flutter_test/flutter_test.dart';
import 'package:tran_nguyen_vi_khang_app/constants/api_constants.dart';
import 'package:tran_nguyen_vi_khang_app/models/device_location_model.dart';
import 'package:tran_nguyen_vi_khang_app/models/device_mode_request_model.dart';

void main() {
  group('Part A: DeviceModeRequestModel Unit Tests', () {
    test('Correctly parses pending mode change request JSON', () {
      final json = {
        'id': 101,
        'deviceId': 5,
        'deviceName': 'Samsung A52',
        'childId': 3,
        'childName': 'Bé Nam',
        'targetMode': 'ParentMode',
        'reason': 'Cần mượn máy học bài',
        'status': 'Pending',
        'approvalToken': null,
        'requestedAt': '2026-10-29T10:00:00Z',
        'expiresAt': '2026-10-29T10:15:00Z',
        'reviewedAt': null,
        'reviewedByName': null,
        'executedAt': null,
      };

      final model = DeviceModeRequestModel.fromJson(json);

      expect(model, isNotNull);
      expect(model!.id, 101);
      expect(model.deviceId, 5);
      expect(model.deviceName, 'Samsung A52');
      expect(model.childId, 3);
      expect(model.childName, 'Bé Nam');
      expect(model.targetMode, 'ParentMode');
      expect(model.isPending, isTrue);
      expect(model.isApproved, isFalse);
      expect(model.isUnlink, isFalse);
      expect(model.targetModeLabelVi, 'Chuyển sang Chế độ Phụ huynh');
      expect(model.statusLabelVi, 'Đang chờ phụ huynh duyệt');
    });

    test('Correctly parses approved unlink request with approval token', () {
      final json = {
        'id': 102,
        'deviceId': 6,
        'deviceName': 'Xiaomi Redmi',
        'childId': 4,
        'childName': 'Bé Hoa',
        'targetMode': 'Unlink',
        'reason': 'Đổi điện thoại mới',
        'status': 'Approved',
        'approvalToken': 'token_abc123',
        'requestedAt': '2026-10-29T10:00:00Z',
        'expiresAt': '2026-10-29T10:15:00Z',
        'reviewedAt': '2026-10-29T10:05:00Z',
        'reviewedByName': 'Nguyễn Văn Cha',
        'executedAt': null,
      };

      final model = DeviceModeRequestModel.fromJson(json);

      expect(model, isNotNull);
      expect(model!.isPending, isFalse);
      expect(model.isApproved, isTrue);
      expect(model.isUnlink, isTrue);
      expect(model.approvalToken, 'token_abc123');
      expect(model.reviewedByName, 'Nguyễn Văn Cha');
      expect(model.targetModeLabelVi, 'Hủy liên kết thiết bị');
      expect(model.statusLabelVi, 'Phụ huynh đã phê duyệt');
    });

    test('Correctly identifies Rejected and Expired states', () {
      final rejected = DeviceModeRequestModel(
        id: 1,
        deviceId: 1,
        deviceName: 'Device',
        childId: 1,
        childName: 'Child',
        targetMode: 'ParentMode',
        status: 'Rejected',
        requestedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
      );

      final expired = DeviceModeRequestModel(
        id: 2,
        deviceId: 1,
        deviceName: 'Device',
        childId: 1,
        childName: 'Child',
        targetMode: 'ParentMode',
        status: 'Expired',
        requestedAt: DateTime.now().subtract(const Duration(minutes: 20)),
        expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      expect(rejected.isRejected, isTrue);
      expect(rejected.statusLabelVi, 'Phụ huynh đã từ chối');
      expect(expired.isExpired, isTrue);
      expect(expired.statusLabelVi, 'Yêu cầu đã hết hạn');
    });
  });

  group('Part B: Location Event Types & 20-min Sync Interval Tests', () {
    test('Default sync interval is configured to 20 minutes', () {
      expect(ApiConstants.foregroundSyncInterval, const Duration(minutes: 20));
      expect(ApiConstants.backgroundSyncInterval, const Duration(minutes: 20));
    });

    test('DeviceLocationModel correctly parses EventType and Displacement', () {
      final jsonMovement = {
        'id': 1,
        'deviceId': 5,
        'deviceName': 'Phone',
        'childId': 3,
        'childName': 'Nam',
        'latitude': 10.762622,
        'longitude': 106.660172,
        'accuracy': 12.5,
        'eventType': 'SignificantMovement',
        'displacementMeters': 250.4,
        'recordedAt': '2026-10-29T10:00:00Z',
        'createdAt': '2026-10-29T10:00:00Z',
      };

      final model = DeviceLocationModel.fromJson(jsonMovement);

      expect(model, isNotNull);
      expect(model!.eventType, 'SignificantMovement');
      expect(model.isSignificantMovement, isTrue);
      expect(model.isManualRefresh, isFalse);
      expect(model.eventTypeFormatted, 'Sự kiện di chuyển');
      expect(model.displacementMeters, 250.4);
      expect(model.displacementFormatted, '250 m');
    });

    test('DeviceLocationModel formats kilometer displacement and manual refresh', () {
      final jsonManual = {
        'id': 2,
        'deviceId': 5,
        'deviceName': 'Phone',
        'childId': 3,
        'childName': 'Nam',
        'latitude': 10.762622,
        'longitude': 106.660172,
        'accuracy': 5.0,
        'eventType': 'ManualRefresh',
        'displacementMeters': 1450.8,
        'recordedAt': '2026-10-29T10:00:00Z',
        'createdAt': '2026-10-29T10:00:00Z',
      };

      final model = DeviceLocationModel.fromJson(jsonManual);

      expect(model, isNotNull);
      expect(model!.isManualRefresh, isTrue);
      expect(model.eventTypeFormatted, 'Phụ huynh làm mới');
      expect(model.displacementFormatted, '1.5 km');
    });

    test('DeviceLocationModel fallback values for legacy records without EventType', () {
      final jsonLegacy = {
        'id': 3,
        'deviceId': 5,
        'deviceName': 'Phone',
        'childId': 3,
        'childName': 'Nam',
        'latitude': 10.762622,
        'longitude': 106.660172,
        'accuracy': 10.0,
        'recordedAt': '2026-10-29T10:00:00Z',
        'createdAt': '2026-10-29T10:00:00Z',
      };

      final model = DeviceLocationModel.fromJson(jsonLegacy);

      expect(model, isNotNull);
      expect(model!.eventType, 'Periodic');
      expect(model.eventTypeFormatted, 'Định kỳ');
      expect(model.displacementMeters, isNull);
      expect(model.displacementFormatted, '0 m');
    });
  });
}

