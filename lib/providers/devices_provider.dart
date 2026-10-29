import 'package:flutter/foundation.dart';
import '../models/device_model.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';

/// State management for Child Devices using Provider.
class DevicesProvider extends ChangeNotifier {
  final DeviceService _deviceService;

  List<DeviceModel> _devices = [];
  bool _isLoading = false;
  String? _errorMessage;
  int? _filterChildId;

  DevicesProvider({DeviceService? deviceService})
      : _deviceService = deviceService ?? DeviceService();

  List<DeviceModel> get devices => List.unmodifiable(_devices);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int? get filterChildId => _filterChildId;
  bool get isEmpty => !_isLoading && _devices.isEmpty;

  /// Fetches devices from backend with optional childId filter.
  Future<void> fetchDevices({int? childId, bool showLoading = true}) async {
    if (childId != null) {
      _filterChildId = childId;
    }

    if (showLoading) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final result = await _deviceService.getDevices(childId: _filterChildId);
      _devices = result;
      _errorMessage = null;
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Không thể tải danh sách thiết bị: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Creates and enrolls a new device for a child.
  Future<bool> addDevice({
    required String deviceName,
    String? deviceIdentifier,
    String? platform,
    required int childId,
    bool isActive = true,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _deviceService.createDevice(
        deviceName: deviceName,
        deviceIdentifier: deviceIdentifier,
        platform: platform,
        childId: childId,
        isActive: isActive,
      );
      await fetchDevices(showLoading: false);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Tạo thiết bị thất bại: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Updates an existing device.
  Future<bool> updateDevice({
    required int id,
    required String deviceName,
    String? deviceIdentifier,
    String? platform,
    required bool isActive,
    int? childId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _deviceService.updateDevice(
        id: id,
        deviceName: deviceName,
        deviceIdentifier: deviceIdentifier,
        platform: platform,
        isActive: isActive,
        childId: childId,
      );
      await fetchDevices(showLoading: false);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Cập nhật thiết bị thất bại: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Toggles the active/inactive state of a device.
  Future<bool> toggleDeviceStatus(DeviceModel device) async {
    return await updateDevice(
      id: device.id,
      deviceName: device.deviceName,
      deviceIdentifier: device.deviceIdentifier,
      platform: device.platform,
      isActive: !device.isActive,
      childId: device.childId,
    );
  }

  /// Deletes a device by ID.
  Future<bool> deleteDevice(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _deviceService.deleteDevice(id);
      await fetchDevices(showLoading: false);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Xóa thiết bị thất bại: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setFilterChildId(int? childId) {
    _filterChildId = childId;
    fetchDevices(childId: childId);
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }
}

