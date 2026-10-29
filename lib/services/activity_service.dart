import '../constants/api_constants.dart';
import '../models/child_activity_history_model.dart';
import '../models/device_activity_event_model.dart';
import 'api_service.dart';

class ActivityService {
  final ApiService _apiService;

  ActivityService({ApiService? apiService}) : _apiService = apiService ?? ApiService();

  /// Synchronizes a batch of child activity events to the backend.
  /// Restricted strictly to the enrolled ChildDevice token.
  Future<Map<String, dynamic>> syncBatchActivities({
    required List<DeviceActivityEventModel> events,
    required String childDeviceToken,
  }) async {
    if (events.isEmpty) {
      return {
        'syncedCount': 0,
        'skippedDuplicatesCount': 0,
        'syncedClientEventIds': <String>[],
      };
    }

    final payload = {
      'events': events.map((e) => e.toBatchApiPayload()).toList(),
    };

    final response = await _apiService.post(
      ApiConstants.activitiesBatchEndpoint,
      body: payload,
      overrideToken: childDeviceToken,
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    throw const ApiException(
      statusCode: 0,
      message: 'Phản hồi không hợp lệ từ máy chủ khi đồng bộ hoạt động thiết bị.',
    );
  }

  /// Retrieves paginated activity history and daily usage summary for a child.
  /// Restricted to authenticated Parents (verifying ownership) or Admins.
  Future<ChildActivityHistoryModel> getChildActivityHistory(
    int childId, {
    DateTime? fromDate,
    DateTime? toDate,
    String? eventType,
    String? packageName,
    int page = 1,
    int pageSize = 50,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    };

    if (fromDate != null) {
      queryParams['fromDate'] = fromDate.toUtc().toIso8601String();
    }
    if (toDate != null) {
      queryParams['toDate'] = toDate.toUtc().toIso8601String();
    }
    if (eventType != null && eventType.isNotEmpty) {
      queryParams['eventType'] = eventType;
    }
    if (packageName != null && packageName.isNotEmpty) {
      queryParams['packageName'] = packageName;
    }

    final uri = Uri.parse(ApiConstants.childActivitiesEndpoint(childId))
        .replace(queryParameters: queryParams);

    final response = await _apiService.get(
      uri.toString(),
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) {
      return ChildActivityHistoryModel.fromJson(response);
    }

    throw const ApiException(
      statusCode: 0,
      message: 'Phản hồi không hợp lệ từ máy chủ khi tải lịch sử hoạt động.',
    );
  }
}

