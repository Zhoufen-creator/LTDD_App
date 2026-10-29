import 'package:flutter/foundation.dart';
import '../models/monitoring_rule_model.dart';
import '../services/api_service.dart';
import '../services/monitoring_rule_service.dart';

/// State management for Monitoring Rules using Provider.
class MonitoringRulesProvider extends ChangeNotifier {
  final MonitoringRuleService _ruleService;

  List<MonitoringRuleModel> _rules = [];
  bool _isLoading = false;
  String? _errorMessage;
  int? _filterChildId;

  MonitoringRulesProvider({MonitoringRuleService? ruleService})
      : _ruleService = ruleService ?? MonitoringRuleService();

  List<MonitoringRuleModel> get rules => List.unmodifiable(_rules);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int? get filterChildId => _filterChildId;
  bool get isEmpty => !_isLoading && _rules.isEmpty;

  /// Fetches monitoring rules from backend with optional childId filter.
  Future<void> fetchRules({int? childId, bool showLoading = true}) async {
    if (childId != null) {
      _filterChildId = childId;
    }

    if (showLoading) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final result = await _ruleService.getRules(childId: _filterChildId);
      _rules = result;
      _errorMessage = null;
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Không thể tải danh sách quy tắc giám sát: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Creates a new monitoring rule for a child.
  Future<bool> addRule({
    required String ruleName,
    required String ruleType,
    String? description,
    String? ruleConfig,
    bool isEnabled = true,
    required int childId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _ruleService.createRule(
        ruleName: ruleName,
        ruleType: ruleType,
        description: description,
        ruleConfig: ruleConfig,
        isEnabled: isEnabled,
        childId: childId,
      );
      await fetchRules(showLoading: false);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Tạo quy tắc thất bại: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Updates an existing monitoring rule.
  Future<bool> updateRule({
    required int id,
    required String ruleName,
    required String ruleType,
    String? description,
    String? ruleConfig,
    required bool isEnabled,
    int? childId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _ruleService.updateRule(
        id: id,
        ruleName: ruleName,
        ruleType: ruleType,
        description: description,
        ruleConfig: ruleConfig,
        isEnabled: isEnabled,
        childId: childId,
      );
      await fetchRules(showLoading: false);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Cập nhật quy tắc thất bại: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Toggles the enabled/disabled state of a monitoring rule.
  Future<bool> toggleRuleStatus(MonitoringRuleModel rule) async {
    return await updateRule(
      id: rule.id,
      ruleName: rule.ruleName,
      ruleType: rule.ruleType,
      description: rule.description,
      isEnabled: !rule.isEnabled,
      childId: rule.childId,
    );
  }

  /// Deletes a monitoring rule by ID.
  Future<bool> deleteRule(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _ruleService.deleteRule(id);
      await fetchRules(showLoading: false);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Xóa quy tắc thất bại: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setFilterChildId(int? childId) {
    _filterChildId = childId;
    fetchRules(childId: childId);
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }
}

