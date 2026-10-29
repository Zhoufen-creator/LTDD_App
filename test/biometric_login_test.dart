import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:tran_nguyen_vi_khang_app/constants/api_constants.dart';
import 'package:tran_nguyen_vi_khang_app/providers/auth_provider.dart';
import 'package:tran_nguyen_vi_khang_app/screens/login_screen.dart';
import 'package:tran_nguyen_vi_khang_app/services/api_service.dart';
import 'package:tran_nguyen_vi_khang_app/services/auth_service.dart';
import 'package:tran_nguyen_vi_khang_app/services/biometric_service.dart';
import 'package:tran_nguyen_vi_khang_app/widgets/biometric_enrollment_dialog.dart';

// ==========================================
// TEST DOUBLES & MOCKS
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

class MockBiometricService implements IBiometricService {
  bool supported = true;
  bool canCheck = true;
  bool authResult = true;
  int authCallCount = 0;
  String? lastLocalizedReason;

  @override
  Future<bool> isDeviceSupported() async => supported;

  @override
  Future<bool> canCheckBiometrics() async => supported && canCheck;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async =>
      supported ? [BiometricType.fingerprint, BiometricType.face] : [];

  @override
  Future<bool> authenticate({required String localizedReason}) async {
    authCallCount++;
    lastLocalizedReason = localizedReason;
    return authResult;
  }
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
  // 1. AUTH SERVICE BIOMETRIC STORAGE TESTS
  // ==========================================
  group('1. AuthService Biometric Credential Storage Tests', () {
    late MockSecureStorage mockStorage;
    late AuthService authService;

    setUp(() {
      mockStorage = MockSecureStorage();
      authService = AuthService(secureStorage: mockStorage);
    });

    test('enableBiometricLogin stores enrollment flag, email, and userId', () async {
      await authService.enableBiometricLogin(
        email: 'parent@example.com',
        userId: 10,
      );

      expect(await authService.isBiometricEnabled(), isTrue);
      expect(await authService.getBiometricEnrolledEmail(), 'parent@example.com');
      expect(await authService.getBiometricEnrolledUserId(), 10);
    });

    test('disableBiometricLogin removes all biometric keys', () async {
      await authService.enableBiometricLogin(
        email: 'parent@example.com',
        userId: 10,
      );
      expect(await authService.isBiometricEnabled(), isTrue);

      await authService.disableBiometricLogin();
      expect(await authService.isBiometricEnabled(), isFalse);
      expect(await authService.getBiometricEnrolledEmail(), isNull);
      expect(await authService.getBiometricEnrolledUserId(), isNull);
    });

    test('logout clears JWT credentials AND invalidates biometric enrollment', () async {
      await mockStorage.write(key: ApiConstants.tokenStorageKey, value: 'parent-jwt');
      await mockStorage.write(key: ApiConstants.tokenExpiryStorageKey, value: '2026-12-31');
      await authService.enableBiometricLogin(email: 'parent@test.com', userId: 5);

      await authService.logout();

      expect(await authService.getSavedToken(), isNull);
      expect(await authService.isBiometricEnabled(), isFalse);
      expect(await authService.getBiometricEnrolledEmail(), isNull);
    });
  });

  // ==========================================
  // 2. AUTH PROVIDER BIOMETRIC STATE TESTS
  // ==========================================
  group('2. AuthProvider Biometric Logic & Session Restoration', () {
    late MockSecureStorage mockStorage;
    late MockBiometricService mockBiometric;
    late MockHttpClient mockClient;
    late AuthService authService;
    late AuthProvider authProvider;

    setUp(() {
      mockStorage = MockSecureStorage();
      mockBiometric = MockBiometricService();

      mockClient = MockHttpClient((req) async {
        if (req.url.path == ApiConstants.currentUserEndpoint) {
          final authHeader = req.headers['authorization'];
          if (authHeader == 'Bearer valid-jwt') {
            return http.Response(
              jsonEncode({
                'id': 10,
                'fullName': 'Nguyễn Văn Phụ Huynh',
                'email': 'parent@example.com',
                'role': 'Parent',
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (authHeader == 'Bearer forbidden-jwt') {
            return http.Response(
              '{"message":"Forbidden"}',
              403,
              headers: {'content-type': 'application/json'},
            );
          }
          if (authHeader == 'Bearer server-error-jwt') {
            return http.Response(
              '{"message":"Internal Server Error"}',
              500,
              headers: {'content-type': 'application/json'},
            );
          }
          if (authHeader == 'Bearer network-error-jwt') {
            throw const SocketException('Connection failed');
          }
          if (authHeader == 'Bearer wrong-user-jwt') {
            return http.Response(
              jsonEncode({
                'id': 99,
                'fullName': 'Người Khác',
                'email': 'parent@example.com',
                'role': 'Parent',
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (authHeader == 'Bearer wrong-email-jwt') {
            return http.Response(
              jsonEncode({
                'id': 10,
                'fullName': 'Nguyễn Văn Phụ Huynh',
                'email': 'other@example.com',
                'role': 'Parent',
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (authHeader == 'Bearer child-jwt') {
            return http.Response(
              jsonEncode({
                'id': 10,
                'fullName': 'Child Device User',
                'email': 'parent@example.com',
                'role': 'ChildDevice',
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('{"message":"Unauthorized"}', 401, headers: {'content-type': 'application/json'});
        }
        if (req.url.path == ApiConstants.verifyLoginOtpEndpoint) {
          return http.Response(
            jsonEncode({
              'token': 'new-user-jwt',
              'expiresAt': '2026-12-31T00:00:00.000Z',
              'user': {
                'id': 20,
                'fullName': 'User B Phụ Huynh',
                'email': 'userB@example.com',
                'role': 'Parent',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiService = ApiService(
        client: mockClient,
        tokenGetter: () => mockStorage.read(key: ApiConstants.tokenStorageKey),
      );
      authService = AuthService(apiService: apiService, secureStorage: mockStorage);
      authProvider = AuthProvider(authService: authService, biometricService: mockBiometric);
    });

    test('checkBiometricSupport detects hardware support and loads enrollment', () async {
      mockBiometric.supported = true;
      mockBiometric.canCheck = true;
      await authService.enableBiometricLogin(email: 'parent@example.com', userId: 10);

      await authProvider.checkBiometricSupport();

      expect(authProvider.isBiometricSupported, isTrue);
      expect(authProvider.isBiometricEnabled, isTrue);
      expect(authProvider.biometricEnrolledEmail, 'parent@example.com');
      expect(authProvider.canLoginWithBiometrics, isTrue);
    });

    test('enableBiometricLogin prompts biometric scan and completes enrollment', () async {
      // Simulate authenticated parent session
      await mockStorage.write(key: ApiConstants.tokenStorageKey, value: 'valid-jwt');
      await authProvider.checkSession();
      expect(authProvider.isAuthenticated, isTrue);

      mockBiometric.authResult = true;
      final success = await authProvider.enableBiometricLogin();

      expect(success, isTrue);
      expect(mockBiometric.authCallCount, 1);
      expect(authProvider.isBiometricEnabled, isTrue);
      expect(authProvider.biometricEnrolledEmail, 'parent@example.com');
    });

    test('enableBiometricLogin does NOT enroll if user cancels biometric prompt', () async {
      await mockStorage.write(key: ApiConstants.tokenStorageKey, value: 'valid-jwt');
      await authProvider.checkSession();

      mockBiometric.authResult = false; // User cancelled
      final success = await authProvider.enableBiometricLogin();

      expect(success, isFalse);
      expect(authProvider.isBiometricEnabled, isFalse);
      expect(await authService.isBiometricEnabled(), isFalse);
    });

    test('loginWithBiometrics verifies biometric, calls backend /api/auth/me, and restores session', () async {
      await mockStorage.write(key: ApiConstants.tokenStorageKey, value: 'valid-jwt');
      await mockStorage.write(
        key: ApiConstants.tokenExpiryStorageKey,
        value: DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
      );
      await authService.enableBiometricLogin(email: 'parent@example.com', userId: 10);
      await authProvider.checkBiometricSupport();

      mockBiometric.authResult = true;
      final success = await authProvider.loginWithBiometrics();

      expect(success, isTrue);
      expect(authProvider.isAuthenticated, isTrue);
      expect(authProvider.user?.fullName, 'Nguyễn Văn Phụ Huynh');
      expect(authProvider.user?.email, 'parent@example.com');
      expect(authProvider.errorMessage, isNull);
    });

    test('loginWithBiometrics does NOT delete credentials if user cancels biometric prompt', () async {
      await mockStorage.write(key: ApiConstants.tokenStorageKey, value: 'valid-jwt');
      await authService.enableBiometricLogin(email: 'parent@example.com', userId: 10);
      await authProvider.checkBiometricSupport();

      mockBiometric.authResult = false; // User cancels dialog
      final success = await authProvider.loginWithBiometrics();

      expect(success, isFalse);
      expect(authProvider.isAuthenticated, isFalse);
      // Valid credentials must NOT be erased merely because user cancelled
      expect(await authService.getSavedToken(), 'valid-jwt');
      expect(authProvider.canLoginWithBiometrics, isTrue);
    });

    test('loginWithBiometrics falls back when stored JWT is expired', () async {
      await mockStorage.write(key: ApiConstants.tokenStorageKey, value: 'valid-jwt');
      await mockStorage.write(
        key: ApiConstants.tokenExpiryStorageKey,
        value: DateTime.now().subtract(const Duration(minutes: 10)).toIso8601String(),
      );
      await authService.enableBiometricLogin(email: 'parent@example.com', userId: 10);
      await authProvider.checkBiometricSupport();

      mockBiometric.authResult = true;
      final success = await authProvider.loginWithBiometrics();

      expect(success, isFalse);
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.errorMessage, contains('Phiên đăng nhập đã hết hạn'));
      expect(await authService.getSavedToken(), isNull);
    });

    test('loginWithBiometrics preserves stored token and biometric enrollment on HTTP 403 Forbidden', () async {
      await mockStorage.write(key: ApiConstants.tokenStorageKey, value: 'forbidden-jwt');
      await mockStorage.write(
        key: ApiConstants.tokenExpiryStorageKey,
        value: DateTime.now().add(const Duration(hours: 10)).toIso8601String(),
      );
      await authService.enableBiometricLogin(email: 'parent@example.com', userId: 10);
      await authProvider.checkBiometricSupport();

      mockBiometric.authResult = true;
      final success = await authProvider.loginWithBiometrics();

      expect(success, isFalse);
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.errorMessage, contains('403'));
      // Security check: HTTP 403 must NOT automatically erase valid credentials or enrollment
      expect(await authService.getSavedToken(), 'forbidden-jwt');
      expect(await authService.isBiometricEnabled(), isTrue);
    });

    test('loginWithBiometrics preserves stored token and biometric enrollment on HTTP 500 Server Error', () async {
      await mockStorage.write(key: ApiConstants.tokenStorageKey, value: 'server-error-jwt');
      await mockStorage.write(
        key: ApiConstants.tokenExpiryStorageKey,
        value: DateTime.now().add(const Duration(hours: 10)).toIso8601String(),
      );
      await authService.enableBiometricLogin(email: 'parent@example.com', userId: 10);
      await authProvider.checkBiometricSupport();

      mockBiometric.authResult = true;
      final success = await authProvider.loginWithBiometrics();

      expect(success, isFalse);
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.errorMessage, contains('500'));
      // Server error must NOT erase credentials or enrollment
      expect(await authService.getSavedToken(), 'server-error-jwt');
      expect(await authService.isBiometricEnabled(), isTrue);
    });

    test('loginWithBiometrics preserves stored token and biometric enrollment on Network Failure', () async {
      await mockStorage.write(key: ApiConstants.tokenStorageKey, value: 'network-error-jwt');
      await mockStorage.write(
        key: ApiConstants.tokenExpiryStorageKey,
        value: DateTime.now().add(const Duration(hours: 10)).toIso8601String(),
      );
      await authService.enableBiometricLogin(email: 'parent@example.com', userId: 10);
      await authProvider.checkBiometricSupport();

      mockBiometric.authResult = true;
      final success = await authProvider.loginWithBiometrics();

      expect(success, isFalse);
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.errorMessage, contains('máy chủ'));
      // Network failure must NOT erase credentials or enrollment
      expect(await authService.getSavedToken(), 'network-error-jwt');
      expect(await authService.isBiometricEnabled(), isTrue);
    });

    test('loginWithBiometrics rejects authentication when backend user ID does not match enrolled user ID', () async {
      await mockStorage.write(key: ApiConstants.tokenStorageKey, value: 'wrong-user-jwt');
      await mockStorage.write(
        key: ApiConstants.tokenExpiryStorageKey,
        value: DateTime.now().add(const Duration(hours: 10)).toIso8601String(),
      );
      // Enrolled as userId: 10, but token returns userId: 99
      await authService.enableBiometricLogin(email: 'parent@example.com', userId: 10);
      await authProvider.checkBiometricSupport();

      mockBiometric.authResult = true;
      final success = await authProvider.loginWithBiometrics();

      expect(success, isFalse);
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.errorMessage, contains('không khớp'));
    });

    test('loginWithBiometrics rejects authentication when backend email does not match enrolled email', () async {
      await mockStorage.write(key: ApiConstants.tokenStorageKey, value: 'wrong-email-jwt');
      await mockStorage.write(
        key: ApiConstants.tokenExpiryStorageKey,
        value: DateTime.now().add(const Duration(hours: 10)).toIso8601String(),
      );
      // Enrolled as parent@example.com, but token returns other@example.com
      await authService.enableBiometricLogin(email: 'parent@example.com', userId: 10);
      await authProvider.checkBiometricSupport();

      mockBiometric.authResult = true;
      final success = await authProvider.loginWithBiometrics();

      expect(success, isFalse);
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.errorMessage, contains('không khớp'));
    });

    test('loginWithBiometrics rejects authentication when token belongs to a ChildDevice role', () async {
      await mockStorage.write(key: ApiConstants.tokenStorageKey, value: 'child-jwt');
      await mockStorage.write(
        key: ApiConstants.tokenExpiryStorageKey,
        value: DateTime.now().add(const Duration(hours: 10)).toIso8601String(),
      );
      await authService.enableBiometricLogin(email: 'parent@example.com', userId: 10);
      await authProvider.checkBiometricSupport();

      mockBiometric.authResult = true;
      final success = await authProvider.loginWithBiometrics();

      expect(success, isFalse);
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.errorMessage, contains('vai trò Phụ huynh'));
    });

    test('new user login invalidates previous user biometric enrollment', () async {
      // User A (id: 10, email: parent@example.com) had enabled biometric
      await authService.enableBiometricLogin(email: 'parent@example.com', userId: 10);
      await authProvider.checkBiometricSupport();
      expect(authProvider.isBiometricEnabled, isTrue);

      // Now User B (id: 20, email: userB@example.com) logs in
      final loginSuccess = await authProvider.verifyLoginOtp(
        email: 'userb@example.com',
        otp: '123456',
      );

      expect(loginSuccess, isTrue);
      expect(authProvider.isAuthenticated, isTrue);
      expect(authProvider.user?.id, 20);
      // Biometric enrollment belonging to User A must be invalidated!
      expect(authProvider.isBiometricEnabled, isFalse);
      expect(await authService.isBiometricEnabled(), isFalse);
    });
  });

  // ==========================================
  // 3. UI INTEGRATION & SCREEN TESTS
  // ==========================================
  group('3. UI Integration & Screen Tests', () {
    late MockSecureStorage mockStorage;
    late MockBiometricService mockBiometric;
    late AuthService authService;

    setUp(() {
      mockStorage = MockSecureStorage();
      mockBiometric = MockBiometricService();
      authService = AuthService(secureStorage: mockStorage);
    });

    testWidgets('LoginScreen hides biometric button when biometric is not enrolled', (tester) async {
      mockBiometric.supported = true;
      final authProvider = AuthProvider(
        authService: authService,
        biometricService: mockBiometric,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: authProvider,
            child: const LoginScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Đăng nhập bằng sinh trắc học'), findsNothing);
      expect(find.text('Đăng nhập với Email'), findsOneWidget);
    });

    testWidgets('LoginScreen displays biometric button when enrolled and supported', (tester) async {
      mockBiometric.supported = true;
      await authService.enableBiometricLogin(
        email: 'ba_me@example.com',
        userId: 1,
      );

      final authProvider = AuthProvider(
        authService: authService,
        biometricService: mockBiometric,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: authProvider,
            child: const LoginScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Đăng nhập bằng sinh trắc học'), findsOneWidget);
      expect(find.text('Tài khoản: ba_me@example.com'), findsOneWidget);
      expect(find.text('Xác thực vân tay / khuôn mặt'), findsOneWidget);
      expect(find.text('HOẶC ĐĂNG NHẬP BẰNG MẬT KHẨU'), findsOneWidget);
      expect(find.text('Đăng nhập với Email'), findsOneWidget);
    });

    testWidgets('BiometricSettingsDialog shows toggle and allows disabling', (tester) async {
      await authService.enableBiometricLogin(email: 'parent@home.vn', userId: 8);

      final mockClient = MockHttpClient((req) async {
        return http.Response(
          jsonEncode({
            'id': 8,
            'fullName': 'Nguyễn Mẹ',
            'email': 'parent@home.vn',
            'role': 'Parent',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final authProvider = AuthProvider(
        authService: AuthService(
          apiService: ApiService(client: mockClient),
          secureStorage: mockStorage,
        ),
        biometricService: mockBiometric,
      );

      await mockStorage.write(key: ApiConstants.tokenStorageKey, value: 'valid-jwt');
      await authProvider.checkSession();

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: authProvider,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => BiometricEnrollmentDialog.showSettingsDialog(context),
                  child: const Text('Open Settings'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Bảo mật & Sinh trắc học'), findsOneWidget);
      expect(find.text('Tài khoản: Nguyễn Mẹ'), findsOneWidget);
      expect(find.text('Đang bật (vân tay / khuôn mặt)'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsOneWidget);

      // Tap toggle to disable
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      expect(authProvider.isBiometricEnabled, isFalse);
      expect(find.text('Đang tắt - yêu cầu mật khẩu & OTP'), findsOneWidget);
    });
  });
}
