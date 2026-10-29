import 'package:flutter_test/flutter_test.dart';
import 'package:tran_nguyen_vi_khang_app/models/auth_response_model.dart';
import 'package:tran_nguyen_vi_khang_app/models/user_model.dart';
import 'package:tran_nguyen_vi_khang_app/providers/auth_provider.dart';
import 'package:tran_nguyen_vi_khang_app/services/api_service.dart';
import 'package:tran_nguyen_vi_khang_app/services/auth_service.dart';

/// In-memory mock AuthService for testing Login + 2FA OTP workflows.
class MockLoginAuthService extends Fake implements AuthService {
  bool shouldThrowLogin = false;
  String loginErrorMessage = '';

  bool shouldThrowVerifyOtp = false;
  String verifyOtpErrorMessage = '';

  bool shouldThrowResendOtp = false;
  String resendOtpErrorMessage = '';

  String? lastLoginEmail;
  String? lastLoginPassword;
  String? lastVerifyOtp;
  String? lastResendEmail;

  @override
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    lastLoginEmail = email;
    lastLoginPassword = password;

    if (shouldThrowLogin) {
      throw ApiException(
        statusCode: 400,
        message: loginErrorMessage,
      );
    }
    return true;
  }

  @override
  Future<AuthResponseModel> verifyLoginOtp({
    required String email,
    required String otp,
  }) async {
    lastVerifyOtp = otp;

    if (shouldThrowVerifyOtp) {
      throw ApiException(
        statusCode: 400,
        message: verifyOtpErrorMessage,
      );
    }

    return AuthResponseModel(
      token: 'jwt.sample.token.for.test',
      expiresAt: DateTime.now().add(const Duration(days: 7)),
      user: UserModel(
        id: 10,
        fullName: 'Nguyễn Văn Phụ Huynh',
        email: email,
        role: 'Parent',
      ),
    );
  }

  @override
  Future<bool> resendLoginOtp(String email) async {
    lastResendEmail = email;

    if (shouldThrowResendOtp) {
      throw ApiException(
        statusCode: 400,
        message: resendOtpErrorMessage,
      );
    }
    return true;
  }
}

void main() {
  group('Login and 2FA Email OTP Unit Tests (Mocked Service)', () {
    late MockLoginAuthService mockAuthService;
    late AuthProvider authProvider;

    setUp(() {
      mockAuthService = MockLoginAuthService();
      authProvider = AuthProvider(authService: mockAuthService);
    });

    test('login with wrong password captures error and remains unauthenticated', () async {
      mockAuthService.shouldThrowLogin = true;
      mockAuthService.loginErrorMessage = 'Email hoặc mật khẩu không chính xác.';

      final success = await authProvider.login(
        email: 'parent@example.com',
        password: 'WrongPassword123',
      );

      expect(success, isFalse);
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.errorMessage, 'Email hoặc mật khẩu không chính xác.');
      expect(authProvider.user, isNull);
      expect(authProvider.token, isNull);
      expect(authProvider.status, AuthStatus.unauthenticated);
    });

    test('login with valid credentials succeeds and enters pending OTP state without issuing full token', () async {
      final success = await authProvider.login(
        email: 'parent@example.com',
        password: 'CorrectPassword123',
      );

      expect(success, isTrue);
      expect(mockAuthService.lastLoginEmail, 'parent@example.com');
      expect(mockAuthService.lastLoginPassword, 'CorrectPassword123');
      expect(authProvider.errorMessage, isNull);
      // Notice: Before OTP is verified, the user is NOT yet authenticated!
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.token, isNull);
    });

    test('verifyLoginOtp with invalid OTP captures error and remains unauthenticated', () async {
      mockAuthService.shouldThrowVerifyOtp = true;
      mockAuthService.verifyOtpErrorMessage = 'Mã OTP không chính xác. Bạn còn 4 lần thử.';

      final success = await authProvider.verifyLoginOtp(
        email: 'parent@example.com',
        otp: '999999',
      );

      expect(success, isFalse);
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.errorMessage, contains('Mã OTP không chính xác'));
      expect(authProvider.user, isNull);
      expect(authProvider.token, isNull);
    });

    test('verifyLoginOtp with expired OTP captures error and retains message', () async {
      mockAuthService.shouldThrowVerifyOtp = true;
      mockAuthService.verifyOtpErrorMessage = 'Mã OTP đã hết hạn hoặc không tồn tại. Vui lòng đăng nhập lại.';

      final success = await authProvider.verifyLoginOtp(
        email: 'parent@example.com',
        otp: '123456',
      );

      expect(success, isFalse);
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.errorMessage, contains('Mã OTP đã hết hạn'));
      expect(authProvider.user, isNull);
      expect(authProvider.token, isNull);
    });

    test('verifyLoginOtp with valid OTP succeeds, sets token, user, and transitions to authenticated', () async {
      final success = await authProvider.verifyLoginOtp(
        email: 'parent@example.com',
        otp: '123456',
      );

      expect(success, isTrue);
      expect(authProvider.isAuthenticated, isTrue);
      expect(authProvider.errorMessage, isNull);
      expect(authProvider.token, 'jwt.sample.token.for.test');
      expect(authProvider.user, isNotNull);
      expect(authProvider.user!.id, 10);
      expect(authProvider.user!.email, 'parent@example.com');
      expect(authProvider.user!.fullName, 'Nguyễn Văn Phụ Huynh');
      expect(authProvider.user!.isParent, isTrue);
      expect(authProvider.status, AuthStatus.authenticated);
    });

    test('resendLoginOtp triggers resend successfully', () async {
      final success = await authProvider.resendLoginOtp('parent@example.com');

      expect(success, isTrue);
      expect(mockAuthService.lastResendEmail, 'parent@example.com');
      expect(authProvider.errorMessage, isNull);
    });

    test('resendLoginOtp captures rate limit error when requested too soon', () async {
      mockAuthService.shouldThrowResendOtp = true;
      mockAuthService.resendOtpErrorMessage = 'Vui lòng đợi 45 giây trước khi yêu cầu gửi lại mã OTP.';

      final success = await authProvider.resendLoginOtp('parent@example.com');

      expect(success, isFalse);
      expect(authProvider.errorMessage, contains('Vui lòng đợi 45 giây'));
    });
  });
}

