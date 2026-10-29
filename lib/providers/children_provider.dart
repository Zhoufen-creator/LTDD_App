import 'package:flutter/foundation.dart';
import '../models/child_model.dart';
import '../services/api_service.dart';
import '../services/child_service.dart';

/// State management for Children profiles using Provider.
class ChildrenProvider extends ChangeNotifier {
  final ChildService _childService;

  List<ChildModel> _children = [];
  bool _isLoading = false;
  String? _errorMessage;
  ChildModel? _selectedChild;

  ChildrenProvider({ChildService? childService})
      : _childService = childService ?? ChildService();

  List<ChildModel> get children => List.unmodifiable(_children);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  ChildModel? get selectedChild => _selectedChild;
  bool get isEmpty => !_isLoading && _children.isEmpty;

  /// Fetches all children belonging to the authenticated parent from the backend.
  Future<void> fetchChildren({bool showLoading = true}) async {
    if (showLoading) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final result = await _childService.getChildren();
      _children = result;
      _errorMessage = null;

      // Update selectedChild if it still exists in the fetched list
      if (_selectedChild != null) {
        final found = _children.where((c) => c.id == _selectedChild!.id).toList();
        _selectedChild = found.isNotEmpty ? found.first : null;
      }
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Không thể tải danh sách trẻ em: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Creates a new child profile and refreshes data from server.
  Future<bool> addChild({
    required String fullName,
    DateTime? dateOfBirth,
    required int parentId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _childService.createChild(
        fullName: fullName,
        dateOfBirth: dateOfBirth,
        parentId: parentId,
      );
      // Re-fetch from server to ensure accurate state
      await fetchChildren(showLoading: false);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Tạo hồ sơ trẻ em thất bại: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Updates an existing child profile and refreshes data from server.
  Future<bool> updateChild({
    required int id,
    required String fullName,
    DateTime? dateOfBirth,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _childService.updateChild(
        id: id,
        fullName: fullName,
        dateOfBirth: dateOfBirth,
      );
      // Re-fetch from server
      await fetchChildren(showLoading: false);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Cập nhật hồ sơ thất bại: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Deletes a child profile and cascades deletion.
  Future<bool> deleteChild(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _childService.deleteChild(id);
      if (_selectedChild?.id == id) {
        _selectedChild = null;
      }
      await fetchChildren(showLoading: false);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Xóa hồ sơ trẻ thất bại: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectChild(ChildModel? child) {
    _selectedChild = child;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }
}

