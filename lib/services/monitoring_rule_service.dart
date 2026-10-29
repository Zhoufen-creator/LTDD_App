import '../constants/api_constants.dart';
import '../models/monitoring_rule_model.dart';
import 'api_service.dart';

/// Service for managing Monitoring Rules via `/api/monitoringrules`.
class MonitoringRuleService {
  final ApiService _apiService;

  MonitoringRuleService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  /// Retrieves monitoring rules for children belonging to the authenticated parent.
  Future<List<MonitoringRuleModel>> getRules({int? childId}) async {
    final endpoint = childId != null
        ? '${ApiConstants.monitoringRulesEndpoint}?childId=$childId'
        : ApiConstants.monitoringRulesEndpoint;

    final response = await _apiService.get(endpoint, requiresAuth: true);

    if (response is List) {
      return response
          .map((item) => MonitoringRuleModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Retrieves a specific monitoring rule by ID.
  Future<MonitoringRuleModel?> getRuleById(int id) async {
    final response = await _apiService.get(
      '${ApiConstants.monitoringRulesEndpoint}/$id',
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) {
      return MonitoringRuleModel.fromJson(response);
    }
    return null;
  }

  /// Creates a new monitoring rule for a child.
  Future<MonitoringRuleModel> createRule({
    required String ruleName,
    required String ruleType,
    String? description,
    String? ruleConfig,
    bool isEnabled = true,
    required int childId,
  }) async {
    final payload = MonitoringRuleModel.createPayload(
      ruleName: ruleName,
      ruleType: ruleType,
      description: description,
      ruleConfig: ruleConfig,
      isEnabled: isEnabled,
      childId: childId,
    );

    final response = await _apiService.post(
      ApiConstants.monitoringRulesEndpoint,
      body: payload,
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) {
      return MonitoringRuleModel.fromJson(response);
    }
    throw const ApiException(
      statusCode: 500,
      message: 'Không thể xử lý phản hồi khi tạo quy tắc giám sát.',
    );
  }

  /// Updates an existing monitoring rule.
  Future<MonitoringRuleModel> updateRule({
    required int id,
    required String ruleName,
    required String ruleType,
    String? description,
    String? ruleConfig,
    required bool isEnabled,
    int? childId,
  }) async {
    final payload = MonitoringRuleModel.updatePayload(
      ruleName: ruleName,
      ruleType: ruleType,
      description: description,
      ruleConfig: ruleConfig,
      isEnabled: isEnabled,
      childId: childId,
    );

    final response = await _apiService.put(
      '${ApiConstants.monitoringRulesEndpoint}/$id',
      body: payload,
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) {
      return MonitoringRuleModel.fromJson(response);
    }
    throw const ApiException(
      statusCode: 500,
      message: 'Không thể xử lý phản hồi khi cập nhật quy tắc giám sát.',
    );
  }

  /// Deletes a monitoring rule by ID.
  Future<void> deleteRule(int id) async {
    await _apiService.delete(
      '${ApiConstants.monitoringRulesEndpoint}/$id',
      requiresAuth: true,
    );
  }
}

