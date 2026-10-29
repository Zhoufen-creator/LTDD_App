import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:tran_nguyen_vi_khang_app/constants/api_constants.dart';
import 'package:tran_nguyen_vi_khang_app/models/child_model.dart';
import 'package:tran_nguyen_vi_khang_app/models/device_location_model.dart';
import 'package:tran_nguyen_vi_khang_app/providers/child_mode_provider.dart';
import 'package:tran_nguyen_vi_khang_app/screens/children/child_location_dialog.dart';
import 'package:tran_nguyen_vi_khang_app/services/api_service.dart';
import 'package:tran_nguyen_vi_khang_app/services/gps_service.dart';
import 'package:tran_nguyen_vi_khang_app/services/location_service.dart';

/// Test double for Mocking HTTP requests and verifying token isolation & body payloads.
class MockLocationHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest request) handler;
  final List<http.BaseRequest> interceptedRequests = [];

  MockLocationHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    interceptedRequests.add(request);
    final response = await handler(request);
    return http.StreamedResponse(
      Stream.value(utf8.encode(response.body)),
      response.statusCode,
      headers: response.headers,
    );
  }
}

/// Test double for GPS and Location Services.
class MockGpsService implements IGpsService {
  bool serviceEnabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  Position? customPosition;
  Exception? positionError;
  bool openAppSettingsCalled = false;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => permission;

  @override
  Future<bool> openAppSettings() async {
    openAppSettingsCalled = true;
    return true;
  }

  @override
  Future<Position> getCurrentPosition() async {
    if (positionError != null) throw positionError!;
    return customPosition ??
        Position(
          latitude: 10.762622,
          longitude: 106.660172,
          timestamp: DateTime.utc(2026, 10, 29, 8, 30),
          accuracy: 12.5,
          altitude: 10.0,
          altitudeAccuracy: 1.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );
  }
}

/// In-Memory Mock of FlutterSecureStorage.
class MockSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _data = {};

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
      _data[key] = value;
    } else {
      _data.remove(key);
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _data[key];
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
    _data.remove(key);
  }
}

void main() {
  group('1. DeviceLocationModel Serialization & Deserialization Tests', () {
    test('Correctly parses valid JSON matching backend DeviceLocationResponseDto', () {
      final json = {
        'id': 101,
        'deviceId': 42,
        'deviceName': "An's Samsung",
        'childId': 7,
        'childName': 'Bé An',
        'latitude': 10.762622,
        'longitude': 106.660172,
        'accuracy': 15.2,
        'recordedAt': '2026-10-29T08:30:00Z',
        'createdAt': '2026-10-29T08:30:02Z',
      };

      final model = DeviceLocationModel.fromJson(json);

      expect(model, isNotNull);
      expect(model!.id, 101);
      expect(model.deviceId, 42);
      expect(model.deviceName, "An's Samsung");
      expect(model.childId, 7);
      expect(model.childName, 'Bé An');
      expect(model.latitude, 10.762622);
      expect(model.longitude, 106.660172);
      expect(model.accuracy, 15.2);
      expect(model.accuracyFormatted, '±15.2 m');
      expect(model.coordinatesFormatted, '10.762622, 106.660172');
      expect(model.googleMapsUrl, 'https://maps.google.com/?q=10.762622,106.660172');
    });

    test('Safely handles null JSON without throwing', () {
      final model = DeviceLocationModel.fromJson(null);
      expect(model, isNull);

      final invalidModel = DeviceLocationModel.fromJson('not-a-map');
      expect(invalidModel, isNull);
    });

    test('Handles missing accuracy and defaults gracefully', () {
      final json = {
        'id': 5,
        'deviceId': 2,
        'deviceName': '',
        'childId': 3,
        'childName': '',
        'latitude': 21.028511,
        'longitude': 105.854444,
        'accuracy': null,
        'recordedAt': '2026-10-29T08:00:00Z',
        'createdAt': '2026-10-29T08:00:01Z',
      };

      final model = DeviceLocationModel.fromJson(json);

      expect(model, isNotNull);
      expect(model!.accuracy, isNull);
      expect(model.accuracyFormatted, 'Không xác định');
      expect(model.coordinatesFormatted, '21.028511, 105.854444');
    });
  });

  group('2. LocationService HTTP & Token Isolation Tests', () {
    test('Child sends location with Child Device JWT and without childId/deviceId in body', () async {
      String? sentAuthHeader;
      Map<String, dynamic>? sentBody;

      final mockClient = MockLocationHttpClient((req) async {
        sentAuthHeader = req.headers['Authorization'];
        if (req is http.Request) {
          sentBody = jsonDecode(req.body) as Map<String, dynamic>;
        }
        return http.Response(
          jsonEncode({
            'id': 1,
            'deviceId': 99,
            'deviceName': 'Galaxy Tab',
            'childId': 55,
            'childName': 'Bé Nam',
            'latitude': 10.762622,
            'longitude': 106.660172,
            'accuracy': 8.0,
            'recordedAt': '2026-10-29T08:30:00Z',
            'createdAt': '2026-10-29T08:30:01Z',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiService = ApiService(
        client: mockClient,
        tokenGetter: () async => 'PARENT_TOKEN_LEAK_PREVENTION',
      );
      final locationService = LocationService(apiService: apiService);

      final result = await locationService.recordLocation(
        latitude: 10.762622,
        longitude: 106.660172,
        accuracy: 8.0,
        recordedAt: DateTime.utc(2026, 10, 29, 8, 30),
        childDeviceToken: 'VALID_CHILD_DEVICE_JWT_XYZ',
      );

      expect(result.id, 1);
      // Verify Child token was used
      expect(sentAuthHeader, 'Bearer VALID_CHILD_DEVICE_JWT_XYZ');
      // Verify childId and deviceId were NOT in body
      expect(sentBody, isNotNull);
      expect(sentBody!.containsKey('childId'), isFalse);
      expect(sentBody!.containsKey('deviceId'), isFalse);
      expect(sentBody!['latitude'], 10.762622);
      expect(sentBody!['longitude'], 106.660172);
      expect(sentBody!['accuracy'], 8.0);
    });

    test('Throws 401 immediately if childDeviceToken is blank without sending HTTP request', () async {
      var requestSent = false;
      final mockClient = MockLocationHttpClient((req) async {
        requestSent = true;
        return http.Response('{}', 200);
      });

      final locationService = LocationService(apiService: ApiService(client: mockClient));

      expect(
        () => locationService.recordLocation(
          latitude: 10.0,
          longitude: 106.0,
          childDeviceToken: '',
        ),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
      );

      expect(requestSent, isFalse);
    });

    test('Parent queries child location using Parent JWT and handles valid response', () async {
      String? capturedAuthHeader;
      final mockClient = MockLocationHttpClient((req) async {
        capturedAuthHeader = req.headers['Authorization'];
        return http.Response(
          jsonEncode({
            'id': 10,
            'deviceId': 42,
            'deviceName': 'iPhone 13',
            'childId': 7,
            'childName': 'Bé Mai',
            'latitude': 10.778001,
            'longitude': 106.699002,
            'accuracy': 5.0,
            'recordedAt': '2026-10-29T08:35:00Z',
            'createdAt': '2026-10-29T08:35:01Z',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiService = ApiService(
        client: mockClient,
        tokenGetter: () async => 'PARENT_SECURE_JWT_TOKEN',
      );
      final locationService = LocationService(apiService: apiService);

      final location = await locationService.getLatestChildLocation(childId: 7);

      expect(capturedAuthHeader, 'Bearer PARENT_SECURE_JWT_TOKEN');
      expect(location, isNotNull);
      expect(location!.childId, 7);
      expect(location.latitude, 10.778001);
      expect(location.longitude, 106.699002);
    });

    test('Parent queries child with no recorded location (backend returns 200 OK null) -> returns null', () async {
      final mockClient = MockLocationHttpClient((req) async {
        // Backend returns 200 OK with body "null"
        return http.Response(
          'null',
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiService = ApiService(
        client: mockClient,
        tokenGetter: () async => 'PARENT_SECURE_JWT_TOKEN',
      );
      final locationService = LocationService(apiService: apiService);

      final location = await locationService.getLatestChildLocation(childId: 13);

      expect(location, isNull);
    });
  });

  group('3. ChildModeProvider GPS & Error Handling Unit Tests', () {
    test('GPS service turned off sets clear error message and prevents crash', () async {
      final mockGps = MockGpsService()..serviceEnabled = false;
      final storage = MockSecureStorage();
      await storage.write(key: ApiConstants.childDeviceTokenStorageKey, value: 'MOCK_TOKEN');
      await storage.write(key: ApiConstants.childDeviceIdStorageKey, value: '42');

      final provider = ChildModeProvider(
        gpsService: mockGps,
        secureStorage: storage,
      );
      await provider.checkChildSession();

      final success = await provider.updateAndSendLocation();

      expect(success, isFalse);
      expect(provider.locationError, contains('đang tắt'));
      expect(provider.isUpdatingLocation, isFalse);
      expect(provider.lastLocation, isNull);
    });

    test('Location permission denied sets clear error message', () async {
      final mockGps = MockGpsService()..permission = LocationPermission.denied;
      final storage = MockSecureStorage();
      await storage.write(key: ApiConstants.childDeviceTokenStorageKey, value: 'MOCK_TOKEN');
      await storage.write(key: ApiConstants.childDeviceIdStorageKey, value: '42');

      final provider = ChildModeProvider(
        gpsService: mockGps,
        secureStorage: storage,
      );
      await provider.checkChildSession();

      final success = await provider.updateAndSendLocation();

      expect(success, isFalse);
      expect(provider.locationError, contains('từ chối'));
      expect(provider.isUpdatingLocation, isFalse);
    });

    test('Location permission permanently denied prompts to open App Settings', () async {
      final mockGps = MockGpsService()..permission = LocationPermission.deniedForever;
      final storage = MockSecureStorage();
      await storage.write(key: ApiConstants.childDeviceTokenStorageKey, value: 'MOCK_TOKEN');
      await storage.write(key: ApiConstants.childDeviceIdStorageKey, value: '42');

      final provider = ChildModeProvider(
        gpsService: mockGps,
        secureStorage: storage,
      );
      await provider.checkChildSession();

      final success = await provider.updateAndSendLocation();

      expect(success, isFalse);
      expect(provider.locationError, contains('vĩnh viễn'));
      expect(provider.locationError, contains('Cài đặt'));

      // Test openAppSettingsScreen
      await provider.openAppSettingsScreen();
      expect(mockGps.openAppSettingsCalled, isTrue);
    });

    test('Network error or timeout does NOT wipe credentials or create fake locations', () async {
      final mockGps = MockGpsService();
      final storage = MockSecureStorage();
      await storage.write(key: ApiConstants.childDeviceTokenStorageKey, value: 'VALID_TOKEN');
      await storage.write(key: ApiConstants.childDeviceIdStorageKey, value: '1');

      final mockClient = MockLocationHttpClient((req) async {
        throw const ApiException(statusCode: 0, message: 'Mất kết nối mạng.');
      });
      final locationService = LocationService(apiService: ApiService(client: mockClient));

      final provider = ChildModeProvider(
        gpsService: mockGps,
        locationService: locationService,
        secureStorage: storage,
      );
      await provider.checkChildSession();

      final success = await provider.updateAndSendLocation();

      expect(success, isFalse);
      expect(provider.locationError, contains('Mất kết nối mạng'));
      expect(provider.lastLocation, isNull);
      // Credentials must NOT be revoked
      expect(provider.isTokenRevoked, isFalse);
      expect(provider.deviceToken, 'VALID_TOKEN');
    });

    test('HTTP 401 Unauthorized marks token revoked, HTTP 403 Forbidden does NOT', () async {
      final mockGps = MockGpsService();
      final storage = MockSecureStorage();
      await storage.write(key: ApiConstants.childDeviceTokenStorageKey, value: 'VALID_TOKEN');
      await storage.write(key: ApiConstants.childDeviceIdStorageKey, value: '1');

      // Test 401
      final mock401 = MockLocationHttpClient((req) async {
        return http.Response('{"message": "Token expired"}', 401);
      });
      final provider = ChildModeProvider(
        gpsService: mockGps,
        locationService: LocationService(apiService: ApiService(client: mock401)),
        secureStorage: storage,
      );
      await provider.checkChildSession();

      await provider.updateAndSendLocation();
      expect(provider.isTokenRevoked, isTrue);

      // Test 403
      final mock403 = MockLocationHttpClient((req) async {
        return http.Response('{"message": "Forbidden"}', 403);
      });
      final provider403 = ChildModeProvider(
        gpsService: mockGps,
        locationService: LocationService(apiService: ApiService(client: mock403)),
        secureStorage: storage,
      );
      await provider403.checkChildSession();

      await provider403.updateAndSendLocation();
      expect(provider403.isTokenRevoked, isFalse);
    });

    test('Prevents concurrent requests while update is in-flight', () async {
      final completer = Completer<Position>();
      // Delay position resolution
      final storage = MockSecureStorage();
      await storage.write(key: ApiConstants.childDeviceTokenStorageKey, value: 'MOCK_TOKEN');
      await storage.write(key: ApiConstants.childDeviceIdStorageKey, value: '42');

      var positionCallCount = 0;
      final customGps = _CustomDelayedGps(completer, () => positionCallCount++);

      final provider = ChildModeProvider(
        gpsService: customGps,
        secureStorage: storage,
      );
      await provider.checkChildSession();

      final future1 = provider.updateAndSendLocation();
      expect(provider.isUpdatingLocation, isTrue);

      // Concurrent second tap must return false immediately
      final future2 = provider.updateAndSendLocation();
      expect(await future2, isFalse);

      // Complete first call
      completer.complete(Position(
        latitude: 10.0,
        longitude: 106.0,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      ));

      await future1;
      expect(positionCallCount, 1);
      expect(provider.isUpdatingLocation, isFalse);
    });
  });

  group('4. ChildLocationDialog Widget Tests (Parent Mode)', () {
    final testChild = ChildModel(
      id: 7,
      fullName: 'Bé Lan Anh',
      dateOfBirth: DateTime(2017, 3, 15),
      parentId: 1,
      createdAt: DateTime.now(),
    );

    testWidgets('Displays child name, coordinates, accuracy, and external map button when location exists', (tester) async {
      final mockClient = MockLocationHttpClient((req) async {
        return http.Response(
          jsonEncode({
            'id': 1,
            'deviceId': 42,
            'deviceName': "iPad Mini",
            'childId': 7,
            'childName': 'Bé Lan Anh',
            'latitude': 10.762622,
            'longitude': 106.660172,
            'accuracy': 12.0,
            'recordedAt': DateTime.now().toUtc().toIso8601String(),
            'createdAt': DateTime.now().toUtc().toIso8601String(),
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final locationService = LocationService(apiService: ApiService(client: mockClient));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChildLocationDialog(
              child: testChild,
              locationServiceOverride: locationService,
            ),
          ),
        ),
      );

      // Initial loading
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      await tester.pumpAndSettle();

      // Verified details rendered
      expect(find.text('Vị trí của Bé Lan Anh'), findsOneWidget);
      expect(find.text('10.762622, 106.660172'), findsOneWidget);
      expect(find.text('±12.0 m'), findsOneWidget);
      expect(find.text('iPad Mini'), findsOneWidget);
      expect(find.text('Mở bản đồ ngoài'), findsOneWidget);
    });

    testWidgets('Displays empty state with helpful prompt when backend returns null (no location yet)', (tester) async {
      final mockClient = MockLocationHttpClient((req) async {
        return http.Response('null', 200, headers: {'content-type': 'application/json'});
      });
      final locationService = LocationService(apiService: ApiService(client: mockClient));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChildLocationDialog(
              child: testChild,
              locationServiceOverride: locationService,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Chưa có dữ liệu vị trí'), findsOneWidget);
      expect(find.textContaining('Thiết bị của bé chưa gửi bản ghi GPS'), findsOneWidget);
      expect(find.text('Kiểm tra lại'), findsOneWidget);
      expect(find.text('Mở bản đồ ngoài'), findsNothing);
    });
  });
}

class _CustomDelayedGps implements IGpsService {
  final Completer<Position> completer;
  final VoidCallback onGetPosition;

  _CustomDelayedGps(this.completer, this.onGetPosition);

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async => LocationPermission.whileInUse;

  @override
  Future<LocationPermission> requestPermission() async => LocationPermission.whileInUse;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<Position> getCurrentPosition() async {
    onGetPosition();
    return await completer.future;
  }
}
