import 'package:flutter_test/flutter_test.dart';
import 'package:tran_nguyen_vi_khang_app/models/user_model.dart';
import 'package:tran_nguyen_vi_khang_app/models/auth_response_model.dart';
import 'package:tran_nguyen_vi_khang_app/providers/auth_provider.dart';
import 'package:tran_nguyen_vi_khang_app/services/api_service.dart';
import 'package:tran_nguyen_vi_khang_app/services/auth_service.dart';

// In-memory test AuthService that isolates logic from platform channels
class TestAuthService extends Fake implements AuthService {
  String? inMemoryToken;
  DateTime? inMemoryExpiry;
  UserModel? inMemoryUser;
  bool shouldThrow = false;
  String? lastTokenPassedToVerify;
  int verifyCallCount = 0;

  @override
  Future<String?> getSavedToken() async => inMemoryToken;

  @override
  Future<DateTime?> getSavedTokenExpiry() async => inMemoryExpiry;

  @override
  Future<UserModel?> verifyCurrentSession(String token) async {
    verifyCallCount++;
    lastTokenPassedToVerify = token;
    if (shouldThrow) {
      throw const ApiException(
        statusCode: 401,
        message: 'Phiên làm việc đã hết hạn hoặc không có quyền truy cập (401 Unauthorized).',
      );
    }
    return inMemoryUser;
  }

  @override
  Future<void> logout() async {
    inMemoryToken = null;
    inMemoryExpiry = null;
  }

  @override
  Future<bool> isBiometricEnabled() async => false;

  @override
  Future<String?> getBiometricEnrolledEmail() async => null;

  @override
  Future<int?> getBiometricEnrolledUserId() async => null;

  @override
  Future<void> disableBiometricLogin() async {}

  @override
  Future<AuthResponseModel?> signInWithGoogle() async {
    if (shouldThrow) {
      throw const ApiException(
        statusCode: 400,
        message: 'Google Sign-In test failure',
      );
    }
    inMemoryToken = 'jwt.mock.token';
    inMemoryExpiry = DateTime.now().add(const Duration(hours: 1));
    return AuthResponseModel(
      token: 'jwt.mock.token',
      expiresAt: inMemoryExpiry!,
      user: const UserModel(
        id: 1,
        fullName: 'Test Parent',
        email: 'parent@example.com',
        role: 'Parent',
      ),
    );
  }
}

void main() {
  group('Authentication & Session Management Unit Tests', () {
    late TestAuthService testAuthService;
    late AuthProvider authProvider;

    setUp(() {
      testAuthService = TestAuthService();
      authProvider = AuthProvider(authService: testAuthService);
    });

    test('checkSession with no stored token resolves to unauthenticated', () async {
      await authProvider.checkSession();
      expect(authProvider.status, AuthStatus.unauthenticated);
      expect(authProvider.isAuthenticated, false);
      expect(authProvider.user, isNull);
      expect(authProvider.token, isNull);
      expect(testAuthService.verifyCallCount, 0);
    });

    test('checkSession with expired token triggers logout and resets state', () async {
      // Store an expired token
      testAuthService.inMemoryToken = 'expired.jwt.token';
      testAuthService.inMemoryExpiry = DateTime.now().subtract(const Duration(minutes: 10));

      await authProvider.checkSession();
      expect(authProvider.status, AuthStatus.unauthenticated);
      expect(authProvider.isAuthenticated, false);
      expect(authProvider.errorMessage, contains('hết hạn'));
      expect(testAuthService.inMemoryToken, isNull);
    });

    test('checkSession with valid token loads user and marks authenticated', () async {
      // Store a valid token
      testAuthService.inMemoryToken = 'valid.jwt.token';
      testAuthService.inMemoryExpiry = DateTime.now().add(const Duration(hours: 2));
      testAuthService.inMemoryUser = const UserModel(
        id: 99,
        fullName: 'Admin Khang',
        email: 'admin@khang.vn',
        role: 'Admin',
      );

      await authProvider.checkSession();
      expect(authProvider.status, AuthStatus.authenticated);
      expect(authProvider.isAuthenticated, true);
      expect(authProvider.user?.id, 99);
      expect(authProvider.user?.isAdmin, true);
      expect(authProvider.token, 'valid.jwt.token');
      expect(testAuthService.lastTokenPassedToVerify, 'valid.jwt.token');
    });

    test('checkSession when backend rejects token with 401 purges credentials and stops (no loop)', () async {
      testAuthService.inMemoryToken = 'rejected.jwt.token';
      testAuthService.shouldThrow = true;

      await authProvider.checkSession();
      expect(authProvider.status, AuthStatus.unauthenticated);
      expect(authProvider.isAuthenticated, false);
      expect(authProvider.user, isNull);
      expect(testAuthService.verifyCallCount, 1); // Called exactly once, no infinite loop
    });

    test('signInWithGoogle updates state on success', () async {
      final success = await authProvider.signInWithGoogle();
      expect(success, true);
      expect(authProvider.isAuthenticated, true);
      expect(authProvider.user?.fullName, 'Test Parent');
      expect(authProvider.user?.isParent, true);
    });

    test('signInWithGoogle captures error and resets status on failure', () async {
      testAuthService.shouldThrow = true;
      final success = await authProvider.signInWithGoogle();
      expect(success, false);
      expect(authProvider.status, AuthStatus.unauthenticated);
      expect(authProvider.errorMessage, 'Google Sign-In test failure');
    });

    test('logout clears user, token, and notifies listeners', () async {
      // First sign in
      await authProvider.signInWithGoogle();
      expect(authProvider.isAuthenticated, true);

      // Now logout
      await authProvider.logout();
      expect(authProvider.isAuthenticated, false);
      expect(authProvider.status, AuthStatus.unauthenticated);
      expect(authProvider.user, isNull);
      expect(authProvider.token, isNull);
      expect(testAuthService.inMemoryToken, isNull);
    });
  });
}
