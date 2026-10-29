import '../constants/api_constants.dart';
import '../models/device_location_model.dart';
import '../models/location_refresh_request_model.dart';
import 'api_service.dart';

/// Service for synchronizing and querying device GPS locations and refresh requests.
/// Enforces strict token separation:
/// - Child Mode endpoints use `overrideToken: childDeviceToken`.
/// - Parent Mode endpoints use Parent JWT via `ApiService`.
class LocationService {
  final ApiService _apiService;

  LocationService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  /// Records child device GPS coordinates and optional battery reading to `POST /api/locations`.
  /// Strictly requires a valid `childDeviceToken`.
  /// Does NOT send `childId` or `deviceId` in payload (derived securely from JWT on backend).
  Future<DeviceLocationModel> recordLocation({
    required double latitude,
    required double longitude,
    double? accuracy,
    DateTime? recordedAt,
    int? batteryPercentage,
    bool? isCharging,
    String? eventType,
    double? displacementMeters,
    required String childDeviceToken,
  }) async {
    if (childDeviceToken.trim().isEmpty) {
      throw const ApiException(
        statusCode: 401,
        message: 'Thiết bị chưa được cấp mã xác thực hợp lệ hoặc phiên đã hết hạn.',
      );
    }

    final utcRecordedAt = (recordedAt ?? DateTime.now().toUtc()).toUtc();

    final body = <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
      'recordedAt': utcRecordedAt.toIso8601String(),
    };
    if (accuracy != null) {
      body['accuracy'] = accuracy;
    }
    if (batteryPercentage != null) {
      body['batteryPercentage'] = batteryPercentage;
    }
    if (isCharging != null) {
      body['isCharging'] = isCharging;
    }
    if (eventType != null) {
      body['eventType'] = eventType;
    }
    if (displacementMeters != null) {
      body['displacementMeters'] = displacementMeters;
    }

    final response = await _apiService.post(
      ApiConstants.locationsEndpoint,
      body: body,
      overrideToken: childDeviceToken,
    );

    final model = DeviceLocationModel.fromJson(response);
    if (model == null) {
      throw const ApiException(
        statusCode: 0,
        message: 'Phản hồi từ máy chủ không đúng định dạng thông tin vị trí.',
      );
    }

    return model;
  }

  /// Queries the latest recorded location for a specific child via `GET /api/locations/child/{childId}`.
  /// Uses the authenticated Parent JWT.
  /// Returns null if the child has not recorded any locations yet (backend 200 OK with null body).
  Future<DeviceLocationModel?> getLatestChildLocation({
    required int childId,
    String? parentToken,
  }) async {
    final response = await _apiService.get(
      ApiConstants.childLocationEndpoint(childId),
      overrideToken: parentToken,
    );

    if (response == null) {
      return null;
    }

    return DeviceLocationModel.fromJson(response);
  }

  /// Queries location history for a specific child via `GET /api/locations/child/{childId}/history`.
  Future<List<DeviceLocationModel>> getChildLocationHistory({
    required int childId,
    int limit = 50,
    String? parentToken,
  }) async {
    final response = await _apiService.get(
      '${ApiConstants.childLocationEndpoint(childId)}/history?limit=$limit',
      overrideToken: parentToken,
    );

    if (response == null || response is! List) {
      return [];
    }

    return response
        .map((item) => DeviceLocationModel.fromJson(item))
        .whereType<DeviceLocationModel>()
        .toList();
  }

  /// Creates a Parent-Requested location-refresh request via `POST /api/locations/refresh-requests`.
  Future<LocationRefreshRequestModel> createRefreshRequest({
    required int childId,
    int? deviceId,
    String? parentToken,
  }) async {
    final body = <String, dynamic>{
      'childId': childId,
    };
    if (deviceId != null) {
      body['deviceId'] = deviceId;
    }

    final response = await _apiService.post(
      ApiConstants.locationRefreshRequestsEndpoint,
      body: body,
      overrideToken: parentToken,
    );

    return LocationRefreshRequestModel.fromJson(response as Map<String, dynamic>);
  }

  /// Polls the status of a specific location-refresh request via `GET /api/locations/refresh-requests/{id}`.
  Future<LocationRefreshRequestModel> getRefreshRequestStatus({
    required int requestId,
    String? parentToken,
  }) async {
    final response = await _apiService.get(
      ApiConstants.locationRefreshRequestStatusEndpoint(requestId),
      overrideToken: parentToken,
    );

    return LocationRefreshRequestModel.fromJson(response as Map<String, dynamic>);
  }

  /// Checks if there is any pending location-refresh request for this child device.
  /// Restricted to `ChildDevice` tokens. Returns null if no pending request exists.
  Future<LocationRefreshRequestModel?> getPendingRefreshRequest({
    required String childDeviceToken,
  }) async {
    final cleanToken = childDeviceToken.trim();
    if (cleanToken.isEmpty) return null;

    final response = await _apiService.get(
      ApiConstants.pendingRefreshRequestEndpoint,
      overrideToken: cleanToken,
    );

    if (response == null || response is! Map<String, dynamic>) {
      return null;
    }

    return LocationRefreshRequestModel.fromJson(response);
  }

  /// Completes or marks failure for a location-refresh request via `POST /api/locations/refresh-requests/{id}/complete`.
  Future<LocationRefreshRequestModel> completeRefreshRequest({
    required int requestId,
    double? latitude,
    double? longitude,
    double? accuracy,
    DateTime? recordedAt,
    int? batteryPercentage,
    bool? isCharging,
    bool isSuccess = true,
    String? failureReason,
    required String childDeviceToken,
  }) async {
    final cleanToken = childDeviceToken.trim();
    if (cleanToken.isEmpty) {
      throw const ApiException(
        statusCode: 401,
        message: 'Thiếu mã xác thực của thiết bị trẻ.',
      );
    }

    final body = <String, dynamic>{
      'isSuccess': isSuccess,
    };
    if (latitude != null) body['latitude'] = latitude;
    if (longitude != null) body['longitude'] = longitude;
    if (accuracy != null) body['accuracy'] = accuracy;
    if (recordedAt != null) body['recordedAt'] = recordedAt.toUtc().toIso8601String();
    if (batteryPercentage != null) body['batteryPercentage'] = batteryPercentage;
    if (isCharging != null) body['isCharging'] = isCharging;
    if (failureReason != null) body['failureReason'] = failureReason;

    final response = await _apiService.post(
      ApiConstants.completeRefreshRequestEndpoint(requestId),
      body: body,
      overrideToken: cleanToken,
    );

    return LocationRefreshRequestModel.fromJson(response as Map<String, dynamic>);
  }
}
