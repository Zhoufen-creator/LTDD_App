import '../constants/api_constants.dart';
import '../models/safety_advisor_model.dart';
import 'api_service.dart';

/// Contract for fetching Smart Safety Advisor evaluations.
abstract class ISafetyAdvisorService {
  Future<SafetyAdvisorModel> getSafetyAdvisor({required int childId});
}

/// Service implementing Smart Safety Advisor queries via `/api/children/{id}/safety-advisor`.
class SafetyAdvisorService implements ISafetyAdvisorService {
  final ApiService _apiService;

  SafetyAdvisorService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  @override
  Future<SafetyAdvisorModel> getSafetyAdvisor({required int childId}) async {
    final endpoint = ApiConstants.childSafetyAdvisorEndpoint(childId);
    final response = await _apiService.get(endpoint, requiresAuth: true);

    if (response is Map<String, dynamic>) {
      return SafetyAdvisorModel.fromJson(response);
    }

    throw const ApiException(
      statusCode: 500,
      message: 'Không thể đọc phản hồi đánh giá an toàn từ máy chủ.',
    );
  }
}

