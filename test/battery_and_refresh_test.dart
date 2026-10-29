import 'dart:async';
import 'dart:convert';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:tran_nguyen_vi_khang_app/constants/api_constants.dart';
import 'package:tran_nguyen_vi_khang_app/models/battery_status_model.dart';
import 'package:tran_nguyen_vi_khang_app/models/child_model.dart';
import 'package:tran_nguyen_vi_khang_app/models/device_model.dart';
import 'package:tran_nguyen_vi_khang_app/models/location_refresh_request_model.dart';
import 'package:tran_nguyen_vi_khang_app/providers/child_mode_provider.dart';
import 'package:tran_nguyen_vi_khang_app/screens/children/child_location_dialog.dart';
import 'package:tran_nguyen_vi_khang_app/services/api_service.dart';
import 'package:tran_nguyen_vi_khang_app/services/battery_service.dart';
import 'package:tran_nguyen_vi_khang_app/services/device_service.dart';
import 'package:tran_nguyen_vi_khang_app/services/gps_service.dart';
import 'package:tran_nguyen_vi_khang_app/services/location_service.dart';

// ==========================================
// MOCKS & TEST DOUBLES
// ==========================================

class MockHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest request) handler;
  final List<http.BaseRequest> recordedRequests = [];

  MockHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    recordedRequests.add(request);
    final response = await handler(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}

class MockBatteryService implements IBatteryService {
  int currentLevel = 85;
  bool currentIsCharging = false;
  final _stateController = StreamController<BatteryState>.broadcast();

  @override
  Future<BatteryStatusModel> getBatteryStatus() async {
    return BatteryStatusModel(
      percentage: currentLevel,
      isCharging: currentIsCharging,
      observedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Stream<BatteryState> get onBatteryStateChanged => _stateController.stream;

  void emitState(BatteryState state) {
    currentIsCharging = (state == BatteryState.charging || state == BatteryState.full);
    _stateController.add(state);
  }

  void dispose() {
    _stateController.close();
  }
}

class MockGpsService implements IGpsService {
  bool serviceEnabled = true;
  LocationPermission permissionStatus = LocationPermission.always;
  Position currentPosition = Position(
    latitude: 10.762622,
    longitude: 106.660172,
    timestamp: DateTime.now().toUtc(),
    accuracy: 8.5,
    altitude: 10.0,
    altitudeAccuracy: 1.0,
    heading: 0.0,
    headingAccuracy: 1.0,
    speed: 0.0,
    speedAccuracy: 1.0,
  );

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permissionStatus;

  @override
  Future<LocationPermission> requestPermission() async => permissionStatus;

  @override
  Future<Position> getCurrentPosition() async => currentPosition;

  @override
  Future<bool> openAppSettings() async => true;
}

class MockSecureStorage extends FlutterSecureStorage {
  final Map<String, String> _storage = {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _storage[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _storage[key] = value;
    } else {
      _storage.remove(key);
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _storage.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ==========================================
  // 1. MODEL SERIALIZATION & HELPER TESTS
  // ==========================================
  group('1. Models & Helper Tests (Battery & Location Refresh)', () {
    test('BatteryStatusModel detects low battery (< 20%) and formats display', () {
      final normal = BatteryStatusModel(
        percentage: 85,
        isCharging: false,
        observedAt: DateTime.now().toUtc(),
      );
      expect(normal.percentage, 85);
      expect(normal.isCharging, isFalse);
      expect(normal.isLow, isFalse);
      expect(normal.isLowBattery, isFalse);
      expect(normal.displayString, '85%');

      final lowCharging = BatteryStatusModel(
        percentage: 15,
        isCharging: true,
        observedAt: DateTime.now().toUtc(),
      );
      expect(lowCharging.percentage, 15);
      expect(lowCharging.isCharging, isTrue);
      expect(lowCharging.isLow, isTrue);
      expect(lowCharging.isLowBattery, isTrue);
      expect(lowCharging.displayString, '⚡ 15%');
    });

    test('LocationRefreshRequestModel correctly parses all states and Vietnamese labels', () {
      final json = {
        'id': 101,
        'childId': 5,
        'childName': 'Bé Minh',
        'deviceId': 42,
        'deviceName': 'Samsung Galaxy',
        'status': 'Pending',
        'requestedAt': '2026-10-29T10:00:00Z',
        'expiresAt': '2026-10-29T10:05:00Z',
      };

      final pendingReq = LocationRefreshRequestModel.fromJson(json);
      expect(pendingReq.id, 101);
      expect(pendingReq.childName, 'Bé Minh');
      expect(pendingReq.isPending, isTrue);
      expect(pendingReq.isCompleted, isFalse);
      expect(pendingReq.statusLabelVi, 'Đang chờ thiết bị phản hồi');

      final completedReq = LocationRefreshRequestModel.fromJson({
        ...json,
        'status': 'Completed',
        'completedAt': '2026-10-29T10:01:30Z',
      });
      expect(completedReq.isCompleted, isTrue);
      expect(completedReq.statusLabelVi, 'Đã cập nhật vị trí mới');

      final failedReq = LocationRefreshRequestModel.fromJson({
        ...json,
        'status': 'Failed',
        'failureReason': 'GPS bị tắt',
      });
      expect(failedReq.isFailed, isTrue);
      expect(failedReq.statusLabelVi, contains('GPS bị tắt'));

      final expiredReq = LocationRefreshRequestModel.fromJson({
        ...json,
        'status': 'Expired',
      });
      expect(expiredReq.isExpired, isTrue);
      expect(expiredReq.statusLabelVi, contains('Yêu cầu đã hết hạn'));
    });

    test('DeviceModel parses battery fields and helper getters', () {
      final now = DateTime.now().toUtc();
      final device = DeviceModel(
        id: 7,
        deviceName: 'iPad Của Bé',
        childId: 3,
        isActive: true,
        batteryPercentage: 18,
        isCharging: false,
        batteryUpdatedAt: now.subtract(const Duration(minutes: 5)),
        createdAt: now,
      );

      expect(device.isLowBattery, isTrue);
      expect(device.batteryFormatted, '18%');
      expect(device.isBatteryStale, isFalse);
      expect(device.batteryTimeAgo, '5 phút trước');

      final chargingDevice = device.copyWith(
        batteryPercentage: 90,
        isCharging: true,
      );
      expect(chargingDevice.isLowBattery, isFalse);
      expect(chargingDevice.batteryFormatted, '90% ⚡');
    });
  });

  // ==========================================
  // 2. HTTP SERVICE API & TOKEN ISOLATION TESTS
  // ==========================================
  group('2. Service HTTP & Token Isolation Tests', () {
    test('LocationService.createRefreshRequest sends POST with Parent JWT', () async {
      late http.Request sentRequest;
      final mockClient = MockHttpClient((req) async {
        sentRequest = req as http.Request;
        return http.Response(
          jsonEncode({
            'id': 55,
            'childId': 10,
            'childName': 'Bé Nam',
            'deviceId': 20,
            'deviceName': 'Xiaomi',
            'status': 'Pending',
            'requestedAt': DateTime.now().toUtc().toIso8601String(),
            'expiresAt': DateTime.now().toUtc().add(const Duration(minutes: 5)).toIso8601String(),
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final locationService = LocationService(apiService: ApiService(client: mockClient));
      final result = await locationService.createRefreshRequest(
        childId: 10,
        deviceId: 20,
        parentToken: 'parent.jwt.token',
      );

      expect(sentRequest.url.path, ApiConstants.locationRefreshRequestsEndpoint);
      expect(sentRequest.headers['authorization'], 'Bearer parent.jwt.token');
      final body = jsonDecode(sentRequest.body);
      expect(body['childId'], 10);
      expect(body['deviceId'], 20);
      expect(result.id, 55);
      expect(result.status, 'Pending');
    });

    test('LocationService.completeRefreshRequest sends POST with Child Device JWT and coordinates', () async {
      late http.Request sentRequest;
      final mockClient = MockHttpClient((req) async {
        sentRequest = req as http.Request;
        return http.Response(
          jsonEncode({
            'id': 55,
            'childId': 10,
            'childName': 'Bé Nam',
            'deviceId': 20,
            'deviceName': 'Xiaomi',
            'status': 'Completed',
            'requestedAt': DateTime.now().toUtc().toIso8601String(),
            'expiresAt': DateTime.now().toUtc().add(const Duration(minutes: 5)).toIso8601String(),
            'completedAt': DateTime.now().toUtc().toIso8601String(),
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final locationService = LocationService(apiService: ApiService(client: mockClient));
      final result = await locationService.completeRefreshRequest(
        requestId: 55,
        latitude: 10.762622,
        longitude: 106.660172,
        accuracy: 5.0,
        batteryPercentage: 75,
        isCharging: false,
        isSuccess: true,
        childDeviceToken: 'child.device.jwt',
      );

      expect(sentRequest.headers['authorization'], 'Bearer child.device.jwt');
      expect(sentRequest.url.path, '/api/locations/refresh-requests/55/complete');
      final body = jsonDecode(sentRequest.body);
      expect(body['isSuccess'], isTrue);
      expect(body['latitude'], 10.762622);
      expect(body['longitude'], 106.660172);
      expect(body['batteryPercentage'], 75);
      expect(result.isCompleted, isTrue);
    });

    test('DeviceService.updateBatteryStatus sends POST /api/devices/battery with Child Device JWT', () async {
      late http.Request sentRequest;
      final mockClient = MockHttpClient((req) async {
        sentRequest = req as http.Request;
        return http.Response(
          jsonEncode({
            'deviceId': 42,
            'batteryPercentage': 82,
            'isCharging': true,
            'batteryUpdatedAt': DateTime.now().toUtc().toIso8601String(),
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final deviceService = DeviceService(apiService: ApiService(client: mockClient));
      final result = await deviceService.updateBatteryStatus(
        percentage: 82,
        isCharging: true,
        childDeviceToken: 'child.device.token.xyz',
      );

      expect(sentRequest.url.path, ApiConstants.deviceBatteryEndpoint);
      expect(sentRequest.headers['authorization'], 'Bearer child.device.token.xyz');
      final body = jsonDecode(sentRequest.body);
      expect(body['batteryPercentage'], 82);
      expect(body['isCharging'], isTrue);
      expect(result.batteryPercentage, 82);
    });
  });

  // ==========================================
  // 3. CHILD MODE PROVIDER BATTERY & SYNC LOGIC
  // ==========================================
  group('3. ChildModeProvider Battery Sync & Request Handling', () {
    late MockBatteryService mockBattery;
    late MockGpsService mockGps;
    late MockSecureStorage mockStorage;
    late DeviceService mockDeviceService;
    late LocationService mockLocationService;
    int batteryUpdateCount = 0;
    int completeRequestCount = 0;
    LocationRefreshRequestModel? mockPendingRequest;

    setUp(() {
      batteryUpdateCount = 0;
      completeRequestCount = 0;
      mockPendingRequest = null;
      mockBattery = MockBatteryService();
      mockGps = MockGpsService();
      mockStorage = MockSecureStorage();

      final mockClient = MockHttpClient((req) async {
        final path = req.url.path;
        if (path == ApiConstants.deviceBatteryEndpoint) {
          batteryUpdateCount++;
          return http.Response('{"success":true}', 200, headers: {'content-type': 'application/json'});
        }
        if (path == ApiConstants.pendingRefreshRequestEndpoint) {
          if (mockPendingRequest != null) {
            return http.Response(
              jsonEncode({
                'id': mockPendingRequest!.id,
                'childId': mockPendingRequest!.childId,
                'childName': mockPendingRequest!.childName,
                'deviceId': mockPendingRequest!.deviceId,
                'deviceName': mockPendingRequest!.deviceName,
                'status': mockPendingRequest!.status,
                'requestedAt': mockPendingRequest!.requestedAt.toIso8601String(),
                'expiresAt': mockPendingRequest!.expiresAt.toIso8601String(),
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('null', 200, headers: {'content-type': 'application/json'});
        }
        if (path.contains('/complete')) {
          completeRequestCount++;
          return http.Response(
            jsonEncode({
              'id': 1,
              'childId': 5,
              'childName': 'Bé Test',
              'deviceId': 42,
              'deviceName': 'Dev',
              'status': 'Completed',
              'requestedAt': DateTime.now().toUtc().toIso8601String(),
              'expiresAt': DateTime.now().toUtc().toIso8601String(),
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('[]', 200, headers: {'content-type': 'application/json'});
      });

      final apiService = ApiService(client: mockClient);
      mockDeviceService = DeviceService(apiService: apiService);
      mockLocationService = LocationService(apiService: apiService);
    });

    test('syncBatteryStatus uploads only when level changes >= 5% or charging state changes', () async {
      await mockStorage.write(key: ApiConstants.childDeviceTokenStorageKey, value: 'child-jwt');
      await mockStorage.write(key: ApiConstants.childDeviceIdStorageKey, value: '42');

      final provider = ChildModeProvider(
        deviceService: mockDeviceService,
        locationService: mockLocationService,
        batteryService: mockBattery,
        gpsService: mockGps,
        secureStorage: mockStorage,
      );

      await provider.checkChildSession();

      // First initial battery sync: triggers upload
      mockBattery.currentLevel = 80;
      mockBattery.currentIsCharging = false;
      await provider.syncBatteryStatus();
      expect(batteryUpdateCount, 1);

      // Minor change of 2% (80 -> 78): should NOT trigger upload
      mockBattery.currentLevel = 78;
      await provider.syncBatteryStatus();
      expect(batteryUpdateCount, 1);

      // Major change of 5% (80 -> 75): triggers upload!
      mockBattery.currentLevel = 75;
      await provider.syncBatteryStatus();
      expect(batteryUpdateCount, 2);

      // Charging state change (false -> true) even with same level: triggers upload!
      mockBattery.currentIsCharging = true;
      await provider.syncBatteryStatus();
      expect(batteryUpdateCount, 3);

      provider.dispose();
    });

    test('checkAndHandlePendingRefreshRequests fulfills pending request with GPS coordinates', () async {
      await mockStorage.write(key: ApiConstants.childDeviceTokenStorageKey, value: 'child-jwt');
      await mockStorage.write(key: ApiConstants.childDeviceIdStorageKey, value: '42');

      final provider = ChildModeProvider(
        deviceService: mockDeviceService,
        locationService: mockLocationService,
        batteryService: mockBattery,
        gpsService: mockGps,
        secureStorage: mockStorage,
      );

      await provider.checkChildSession();

      mockPendingRequest = LocationRefreshRequestModel(
        id: 77,
        childId: 5,
        childName: 'Bé Linh',
        deviceId: 42,
        deviceName: 'Device',
        status: 'Pending',
        requestedAt: DateTime.now().toUtc(),
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
      );

      await provider.checkAndHandlePendingRefreshRequests();

      expect(completeRequestCount, 1);
      expect(provider.lastLocation?.latitude, 10.762622);
      expect(provider.lastLocation?.longitude, 106.660172);

      provider.dispose();
    });

    test('startAutoSync activates sync loop and stopAutoSync cancels timers cleanly', () async {
      await mockStorage.write(key: ApiConstants.childDeviceTokenStorageKey, value: 'child-jwt');
      await mockStorage.write(key: ApiConstants.childDeviceIdStorageKey, value: '42');

      final provider = ChildModeProvider(
        deviceService: mockDeviceService,
        locationService: mockLocationService,
        batteryService: mockBattery,
        gpsService: mockGps,
        secureStorage: mockStorage,
      );

      await provider.checkChildSession();

      expect(provider.isAutoSyncRunning, isFalse);

      provider.startAutoSync();
      expect(provider.isAutoSyncRunning, isTrue);

      provider.stopAutoSync();
      expect(provider.isAutoSyncRunning, isFalse);

      provider.dispose();
    });
  });

  // ==========================================
  // 4. CHILD LOCATION DIALOG WIDGET TESTS
  // ==========================================
  group('4. ChildLocationDialog Monitoring Dashboard Widget Tests', () {
    final testChild = ChildModel(
      id: 5,
      fullName: 'Bé Mai Chi',
      parentId: 1,
      createdAt: DateTime.now(),
      deviceCount: 1,
    );

    testWidgets('Displays battery percentage, charging indicator, and location coordinates', (tester) async {
      final mockClient = MockHttpClient((req) async {
        final path = req.url.path;
        if (path == '/api/locations/child/5') {
          return http.Response(
            jsonEncode({
              'id': 1,
              'deviceId': 42,
              'deviceName': 'iPhone 15',
              'childId': 5,
              'childName': 'Bé Mai Chi',
              'latitude': 10.776889,
              'longitude': 106.700806,
              'accuracy': 7.5,
              'recordedAt': DateTime.now().toUtc().toIso8601String(),
              'createdAt': DateTime.now().toUtc().toIso8601String(),
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (path == ApiConstants.devicesEndpoint) {
          return http.Response(
            jsonEncode([
              {
                'id': 42,
                'deviceName': 'iPhone 15',
                'childId': 5,
                'isActive': true,
                'batteryPercentage': 88,
                'isCharging': true,
                'batteryUpdatedAt': DateTime.now().toUtc().toIso8601String(),
                'createdAt': DateTime.now().toUtc().toIso8601String(),
              }
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('[]', 200, headers: {'content-type': 'application/json'});
      });

      final apiService = ApiService(client: mockClient);
      final locationService = LocationService(apiService: apiService);
      final deviceService = DeviceService(apiService: apiService);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChildLocationDialog(
              child: testChild,
              locationServiceOverride: locationService,
              deviceServiceOverride: deviceService,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Battery assertions
      expect(find.textContaining('Pin thiết bị: 88% ⚡'), findsOneWidget);
      expect(find.text('Đang sạc'), findsOneWidget);

      // Location coordinates assertions
      expect(find.text('10.776889, 106.700806'), findsOneWidget);
      expect(find.text('±7.5 m'), findsOneWidget);
      expect(find.text('Mở bản đồ ngoài'), findsOneWidget);
      expect(find.text('Yêu cầu vị trí mới'), findsOneWidget);
    });

    testWidgets('Displays low-battery warning banner when battery level is under 20%', (tester) async {
      final mockClient = MockHttpClient((req) async {
        final path = req.url.path;
        if (path == '/api/locations/child/5') {
          return http.Response('null', 200, headers: {'content-type': 'application/json'});
        }
        if (path == ApiConstants.devicesEndpoint) {
          return http.Response(
            jsonEncode([
              {
                'id': 42,
                'deviceName': 'iPad Air',
                'childId': 5,
                'isActive': true,
                'batteryPercentage': 12,
                'isCharging': false,
                'batteryUpdatedAt': DateTime.now().toUtc().toIso8601String(),
                'createdAt': DateTime.now().toUtc().toIso8601String(),
              }
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('[]', 200, headers: {'content-type': 'application/json'});
      });

      final apiService = ApiService(client: mockClient);
      final locationService = LocationService(apiService: apiService);
      final deviceService = DeviceService(apiService: apiService);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChildLocationDialog(
              child: testChild,
              locationServiceOverride: locationService,
              deviceServiceOverride: deviceService,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Low battery warning banner must be visible!
      expect(find.textContaining('Pin thiết bị: 12%'), findsOneWidget);
      expect(find.textContaining('Cảnh báo: Pin thiết bị dưới 20% (12%)'), findsOneWidget);
    });
  });
}
