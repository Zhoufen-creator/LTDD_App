import '../constants/api_constants.dart';
import '../models/child_enrollment_model.dart';
import '../models/device_mode_request_model.dart';
import '../models/device_model.dart';
import '../models/monitoring_rule_model.dart';
import '../models/pairing_ticket_model.dart';
import 'api_service.dart';

/// Service for managing Child Devices via `/api/devices`.
class DeviceService {
  final ApiService _apiService;

  DeviceService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  /// Retrieves devices belonging to children of the authenticated parent.
  Future<List<DeviceModel>> getDevices({int? childId}) async {
    final endpoint = childId != null
        ? '${ApiConstants.devicesEndpoint}?childId=$childId'
        : ApiConstants.devicesEndpoint;

    final response = await _apiService.get(endpoint, requiresAuth: true);

    if (response is List) {
      return response
          .map((item) => DeviceModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Retrieves a specific device by ID.
  Future<DeviceModel?> getDeviceById(int id) async {
    final response = await _apiService.get(
      '${ApiConstants.devicesEndpoint}/$id',
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) {
      return DeviceModel.fromJson(response);
    }
    return null;
  }

  /// Creates/enrolls a new device for a child.
  Future<DeviceModel> createDevice({
    required String deviceName,
    String? deviceIdentifier,
    String? platform,
    required int childId,
    bool isActive = true,
  }) async {
    final payload = DeviceModel.createPayload(
      deviceName: deviceName,
      deviceIdentifier: deviceIdentifier,
      platform: platform,
      childId: childId,
      isActive: isActive,
    );

    final response = await _apiService.post(
      ApiConstants.devicesEndpoint,
      body: payload,
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) {
      return DeviceModel.fromJson(response);
    }
    throw const ApiException(
      statusCode: 500,
      message: 'Không thể xử lý phản hồi khi tạo thiết bị mới.',
    );
  }

  /// Updates an existing device's details or active status.
  Future<DeviceModel> updateDevice({
    required int id,
    required String deviceName,
    String? deviceIdentifier,
    String? platform,
    required bool isActive,
    int? childId,
  }) async {
    final payload = DeviceModel.updatePayload(
      deviceName: deviceName,
      deviceIdentifier: deviceIdentifier,
      platform: platform,
      isActive: isActive,
      childId: childId,
    );

    final response = await _apiService.put(
      '${ApiConstants.devicesEndpoint}/$id',
      body: payload,
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) {
      return DeviceModel.fromJson(response);
    }
    throw const ApiException(
      statusCode: 500,
      message: 'Không thể xử lý phản hồi khi cập nhật thiết bị.',
    );
  }

  /// Deletes a device by ID.
  Future<void> deleteDevice(int id) async {
    await _apiService.delete(
      '${ApiConstants.devicesEndpoint}/$id',
      requiresAuth: true,
    );
  }

  /// Generates a single-use pairing ticket for enrolling a child's device via QR.
  Future<PairingTicketModel> createPairingTicket({
    required int childId,
    int? validitySeconds,
  }) async {
    final payload = <String, dynamic>{
      'childId': childId,
    };
    if (validitySeconds != null) {
      payload['validitySeconds'] = validitySeconds;
    }

    final response = await _apiService.post(
      ApiConstants.pairingTicketEndpoint,
      body: payload,
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) {
      return PairingTicketModel.fromJson(response);
    }
    throw const ApiException(
      statusCode: 500,
      message: 'Không thể xử lý phản hồi khi tạo mã ghép nối.',
    );
  }

  /// Enrolls a child device using a pairing code / ticket.
  Future<ChildEnrollmentModel> enrollChildDevice({
    required String pairingCode,
    required String deviceName,
    String? deviceIdentifier,
    String? platform,
  }) async {
    final payload = <String, dynamic>{
      'pairingCode': pairingCode,
      'deviceName': deviceName,
    };
    if (deviceIdentifier != null) {
      payload['deviceIdentifier'] = deviceIdentifier;
    }
    if (platform != null) {
      payload['platform'] = platform;
    }

    final response = await _apiService.post(
      ApiConstants.enrollDeviceEndpoint,
      body: payload,
      requiresAuth: false,
    );

    if (response is Map<String, dynamic>) {
      return ChildEnrollmentModel.fromJson(response);
    }
    throw const ApiException(
      statusCode: 500,
      message: 'Không thể xử lý phản hồi khi kích hoạt thiết bị.',
    );
  }

  /// Retrieves active monitoring rules for this enrolled child device.
  Future<List<MonitoringRuleModel>> getMyRules({required String childDeviceToken}) async {
    final cleanToken = childDeviceToken.trim();
    if (cleanToken.isEmpty) {
      throw const ApiException(
        statusCode: 401,
        message: 'Thiếu mã xác thực của thiết bị trẻ.',
      );
    }

    final response = await _apiService.get(
      ApiConstants.myRulesEndpoint,
      requiresAuth: true,
      overrideToken: cleanToken,
    );

    if (response is List) {
      return response
          .map((item) => MonitoringRuleModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Updates current battery percentage and charging state for this child device.
  Future<DeviceModel> updateBatteryStatus({
    required int percentage,
    required bool isCharging,
    required String childDeviceToken,
  }) async {
    final cleanToken = childDeviceToken.trim();
    if (cleanToken.isEmpty) {
      throw const ApiException(
        statusCode: 401,
        message: 'Thiếu mã xác thực của thiết bị trẻ.',
      );
    }

    final response = await _apiService.post(
      ApiConstants.deviceBatteryEndpoint,
      body: {
        'batteryPercentage': percentage,
        'isCharging': isCharging,
      },
      requiresAuth: true,
      overrideToken: cleanToken,
    );

    return DeviceModel.fromJson(response as Map<String, dynamic>);
  }

  /// Creates a mode change or unlink request from the child device.
  Future<DeviceModeRequestModel> createModeRequest({
    required String targetMode,
    String? reason,
    required String childDeviceToken,
  }) async {
    final response = await _apiService.post(
      ApiConstants.deviceModeRequestsEndpoint,
      body: {
        'targetMode': targetMode,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
      overrideToken: childDeviceToken,
    );

    final model = DeviceModeRequestModel.fromJson(response);
    if (model == null) {
      throw const ApiException(
        statusCode: 0,
        message: 'Phản hồi không hợp lệ khi tạo yêu cầu thay đổi chế độ.',
      );
    }
    return model;
  }

  /// Retrieves pending mode change requests for children belonging to the authenticated parent.
  Future<List<DeviceModeRequestModel>> getPendingModeRequests({String? parentToken}) async {
    final response = await _apiService.get(
      ApiConstants.pendingDeviceModeRequestsEndpoint,
      overrideToken: parentToken,
    );

    if (response is List) {
      return response
          .map((item) => DeviceModeRequestModel.fromJson(item))
          .whereType<DeviceModeRequestModel>()
          .toList();
    }
    return [];
  }

  /// Retrieves active pending mode change request for this child device.
  Future<DeviceModeRequestModel?> getPendingModeRequestForDevice({
    required String childDeviceToken,
  }) async {
    final response = await _apiService.get(
      ApiConstants.pendingDeviceModeRequestsEndpoint,
      overrideToken: childDeviceToken,
    );

    if (response == null) return null;
    return DeviceModeRequestModel.fromJson(response);
  }

  /// Retrieves status and details of a mode change request by ID.
  Future<DeviceModeRequestModel?> getModeRequestById(
    int id, {
    String? token,
  }) async {
    final response = await _apiService.get(
      ApiConstants.deviceModeRequestStatusEndpoint(id),
      overrideToken: token,
    );

    if (response == null) return null;
    return DeviceModeRequestModel.fromJson(response);
  }

  /// Approves a child device mode request (Parent only).
  Future<DeviceModeRequestModel> approveModeRequest(
    int id, {
    String? parentToken,
  }) async {
    final response = await _apiService.post(
      ApiConstants.approveDeviceModeRequestEndpoint(id),
      body: {},
      overrideToken: parentToken,
    );

    final model = DeviceModeRequestModel.fromJson(response);
    if (model == null) {
      throw const ApiException(
        statusCode: 0,
        message: 'Phản hồi không hợp lệ khi phê duyệt yêu cầu.',
      );
    }
    return model;
  }

  /// Rejects a child device mode request (Parent only).
  Future<DeviceModeRequestModel> rejectModeRequest(
    int id, {
    String? parentToken,
  }) async {
    final response = await _apiService.post(
      ApiConstants.rejectDeviceModeRequestEndpoint(id),
      body: {},
      overrideToken: parentToken,
    );

    final model = DeviceModeRequestModel.fromJson(response);
    if (model == null) {
      throw const ApiException(
        statusCode: 0,
        message: 'Phản hồi không hợp lệ khi từ chối yêu cầu.',
      );
    }
    return model;
  }

  /// Executes an approved mode change or unlink using the single-use approval token.
  Future<bool> executeModeChange({
    required int requestId,
    required String approvalToken,
    required String childDeviceToken,
  }) async {
    final response = await _apiService.post(
      ApiConstants.executeDeviceModeRequestEndpoint(requestId),
      body: {'approvalToken': approvalToken.trim()},
      overrideToken: childDeviceToken,
    );

    return response != null;
  }

  /// Direct unlock: parent types credentials directly on child device.
  Future<DeviceModeRequestModel> directParentUnlock({
    required String email,
    required String password,
    String targetMode = 'ParentMode',
    required String childDeviceToken,
  }) async {
    final response = await _apiService.post(
      ApiConstants.directParentUnlockEndpoint,
      body: {
        'email': email.trim(),
        'password': password,
        'targetMode': targetMode,
      },
      overrideToken: childDeviceToken,
    );

    final model = DeviceModeRequestModel.fromJson(response);
    if (model == null) {
      throw const ApiException(
        statusCode: 0,
        message: 'Phản hồi không hợp lệ khi xác thực mật khẩu phụ huynh.',
      );
    }
    return model;
  }

  /// Acknowledges rule sync/execution status from the child device.
  Future<bool> acknowledgeRules({
    required List<Map<String, dynamic>> acks,
    required String childDeviceToken,
  }) async {
    try {
      await _apiService.post(
        ApiConstants.myRulesAckEndpoint,
        body: {'acks': acks},
        overrideToken: childDeviceToken,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}

