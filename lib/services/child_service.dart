import '../constants/api_constants.dart';
import '../models/child_model.dart';
import '../models/safety_advisor_model.dart';
import 'api_service.dart';

/// Service for managing Child profiles via `/api/children`.
class ChildService {
  final ApiService _apiService;

  ChildService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  /// Retrieves all child profiles belonging to the authenticated parent.
  Future<List<ChildModel>> getChildren({int? parentId}) async {
    final endpoint = parentId != null
        ? '${ApiConstants.childrenEndpoint}?parentId=$parentId'
        : ApiConstants.childrenEndpoint;

    final response = await _apiService.get(endpoint, requiresAuth: true);

    if (response is List) {
      return response
          .map((item) => ChildModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Retrieves a specific child profile by ID.
  Future<ChildModel?> getChildById(int id) async {
    final response = await _apiService.get(
      '${ApiConstants.childrenEndpoint}/$id',
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) {
      return ChildModel.fromJson(response);
    }
    return null;
  }

  /// Creates a new child profile under the authenticated parent account.
  Future<ChildModel> createChild({
    required String fullName,
    DateTime? dateOfBirth,
    required int parentId,
  }) async {
    final payload = ChildModel.createPayload(
      fullName: fullName,
      dateOfBirth: dateOfBirth,
      parentId: parentId,
    );

    final response = await _apiService.post(
      ApiConstants.childrenEndpoint,
      body: payload,
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) {
      return ChildModel.fromJson(response);
    }
    throw const ApiException(
      statusCode: 500,
      message: 'Không thể xử lý phản hồi khi tạo hồ sơ trẻ em.',
    );
  }

  /// Updates an existing child profile.
  Future<ChildModel> updateChild({
    required int id,
    required String fullName,
    DateTime? dateOfBirth,
  }) async {
    final payload = ChildModel.updatePayload(
      fullName: fullName,
      dateOfBirth: dateOfBirth,
    );

    final response = await _apiService.put(
      '${ApiConstants.childrenEndpoint}/$id',
      body: payload,
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) {
      return ChildModel.fromJson(response);
    }
    throw const ApiException(
      statusCode: 500,
      message: 'Không thể xử lý phản hồi khi cập nhật hồ sơ trẻ em.',
    );
  }

  /// Deletes a child profile by ID (cascades to devices and rules).
  Future<void> deleteChild(int id) async {
    await _apiService.delete(
      '${ApiConstants.childrenEndpoint}/$id',
      requiresAuth: true,
    );
  }

  /// Retrieves Smart Safety Advisor evaluations and recommendations for a child.
  Future<SafetyAdvisorModel> getSafetyAdvisor(int childId) async {
    final endpoint = ApiConstants.childSafetyAdvisorEndpoint(childId);
    final response = await _apiService.get(endpoint, requiresAuth: true);

    if (response is Map<String, dynamic>) {
      return SafetyAdvisorModel.fromJson(response);
    }
    throw const ApiException(
      statusCode: 500,
      message: 'Không thể xử lý phản hồi đánh giá an toàn.',
    );
  }
}

