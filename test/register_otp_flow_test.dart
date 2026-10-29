import 'package:flutter_test/flutter_test.dart';
import 'package:tran_nguyen_vi_khang_app/models/user_model.dart';
import 'package:tran_nguyen_vi_khang_app/models/auth_response_model.dart';
import 'package:tran_nguyen_vi_khang_app/providers/auth_provider.dart';
import 'package:tran_nguyen_vi_khang_app/services/api_service.dart';
import 'package:tran_nguyen_vi_khang_app/services/auth_service.dart';

class MockRegisterAuthService extends Fake implements AuthService {
  bool shouldThrowSendOtp = false;
  String sendOtpErrorMessage = '';

  bool shouldThrowRegister = false;
  String registerErrorMessage = '';

  String? lastEmailSent;
  String? inMemoryToken;
  UserModel? inMemoryUser;

  @override
  Future<bool> sendRegistrationOtp(String email) async {
    lastEmailSent = email;
    if (shouldThrowSendOtp) {
      throw ApiException(
        statusCode: 400,
        message: sendOtpErrorMessage,
      );
    }
    return true;
  }

  @override
  Future<AuthResponseModel> registerWithOtp({
    required String email,
    required String otp,
    required String fullName,
    required String password,
  }) async {
    if (shouldThrowRegister) {
      throw ApiException(
        statusCode: 400,
        message: registerErrorMessage,
      );
    }

    inMemoryToken = 'mock_jwt_token_123';
    inMemoryUser = UserModel(
      id: 99,
      fullName: fullName,
      email: email,
      role: 'Parent',
    );

    return AuthResponseModel(
      token: inMemoryToken!,
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      user: inMemoryUser!,
    );
  }
}

void main() {
  group('Registration and Email OTP Unit Tests', () {
    late MockRegisterAuthService mockService;
    late AuthProvider authProvider;

    setUp(() {
      mockService = MockRegisterAuthService();
      authProvider = AuthProvider(authService: mockService);
    });

    test('sendRegistrationOtp succeeds with new email and clears errors', () async {
      final success = await authProvider.sendRegistrationOtp('newuser@example.com');

      expect(success, isTrue);
      expect(mockService.lastEmailSent, 'newuser@example.com');
      expect(authProvider.errorMessage, isNull);
      expect(authProvider.status, AuthStatus.unauthenticated);
    });

    test('sendRegistrationOtp captures error when email is already registered', () async {
      mockService.shouldThrowSendOtp = true;
      mockService.sendOtpErrorMessage =
          'Email này đã được đăng ký trong hệ thống. Vui lòng đăng nhập hoặc sử dụng email khác.';

      final success = await authProvider.sendRegistrationOtp('existing@example.com');

      expect(success, isFalse);
      expect(authProvider.errorMessage, contains('Email này đã được đăng ký'));
      expect(authProvider.status, AuthStatus.unauthenticated);
    });

    test('registerWithOtp succeeds with valid OTP and transitions to authenticated', () async {
      final success = await authProvider.registerWithOtp(
        email: 'test@example.com',
        otp: '123456',
        fullName: 'Nguyễn Văn A',
        password: 'password123',
      );

      expect(success, isTrue);
      expect(authProvider.isAuthenticated, isTrue);
      expect(authProvider.user?.fullName, 'Nguyễn Văn A');
      expect(authProvider.user?.email, 'test@example.com');
      expect(authProvider.token, 'mock_jwt_token_123');
      expect(authProvider.errorMessage, isNull);
    });

    test('registerWithOtp fails with invalid OTP and retains error message without crashing', () async {
      mockService.shouldThrowRegister = true;
      mockService.registerErrorMessage = 'Mã OTP không chính xác. Bạn còn 4 lần thử.';

      final success = await authProvider.registerWithOtp(
        email: 'test@example.com',
        otp: '000000',
        fullName: 'Nguyễn Văn A',
        password: 'password123',
      );

      expect(success, isFalse);
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.errorMessage, 'Mã OTP không chính xác. Bạn còn 4 lần thử.');
    });
  });
}

