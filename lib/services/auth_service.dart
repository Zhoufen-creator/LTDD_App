import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../constants/api_constants.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';
import 'api_service.dart';

/// Service dedicated to authentication workflows: Google Sign-In, token storage, and session validation.
class AuthService {
  final ApiService _apiService;
  final FlutterSecureStorage _secureStorage;
  bool _isGoogleInitialized = false;

  AuthService({
    ApiService? apiService,
    FlutterSecureStorage? secureStorage,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _apiService = apiService ?? ApiService();

  /// Ensures GoogleSignIn singleton is initialized exactly once with the configured serverClientId.
  Future<void> _ensureGoogleInitialized() async {
    if (!_isGoogleInitialized) {
      await GoogleSignIn.instance.initialize(
        serverClientId: ApiConstants.googleServerClientId,
      );
      _isGoogleInitialized = true;
    }
  }

  /// Executes full Google Sign-In flow:
  /// 1. Prompts native Google Account picker via `GoogleSignIn.instance.authenticate()`.
  /// 2. Retrieves cryptographically signed Google ID Token (issued for Web Client ID).
  /// 3. Sends ID Token to backend `POST /api/auth/google`.
  /// 4. Stores returned application JWT securely.
  /// 5. Returns parsed AuthResponseModel with User and JWT.
  Future<AuthResponseModel?> signInWithGoogle() async {
    try {
      await _ensureGoogleInitialized();

      // 1. Trigger Google interactive sign-in
      final GoogleSignInAccount account = await GoogleSignIn.instance.authenticate();

      // 2. Obtain Google Auth token (synchronous getter in google_sign_in 7.x)
      final String? idToken = account.authentication.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw const ApiException(
          statusCode: 400,
          message: 'Không nhận được Google ID Token. Vui lòng đảm bảo cấu hình '
              'Android OAuth Client ID và mã SHA-1 fingerprint trên Google Cloud Console đã chính xác.',
        );
      }

      // 3. Post to backend endpoint /api/auth/google
      // Payload strictly matches GoogleSignInRequestDto: {"idToken": "..."}
      final response = await _apiService.post(
        ApiConstants.googleSignInEndpoint,
        body: {'idToken': idToken},
        requiresAuth: false,
      );

      if (response == null || response is! Map<String, dynamic>) {
        throw const ApiException(
          statusCode: 500,
          message: 'Phản hồi từ máy chủ xác thực không hợp lệ.',
        );
      }

      // 4. Parse response into AuthResponseModel
      final authResult = AuthResponseModel.fromJson(response);

      if (authResult.token.isEmpty) {
        throw const ApiException(
          statusCode: 500,
          message: 'Máy chủ không trả về Application JWT hợp lệ.',
        );
      }

      // 5. Store application JWT securely (Do NOT confuse with Google ID Token)
      await _secureStorage.write(
        key: ApiConstants.tokenStorageKey,
        value: authResult.token,
      );
      await _secureStorage.write(
        key: ApiConstants.tokenExpiryStorageKey,
        value: authResult.expiresAt.toIso8601String(),
      );

      return authResult;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        // User aborted the account selector dialog
        return null;
      }
      throw ApiException(
        statusCode: 400,
        message: 'Lỗi xác thực Google (${e.code.name}): ${e.description ?? "Vui lòng thử lại"}',
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        statusCode: 0,
        message: 'Đăng nhập Google thất bại: $e',
      );
    }
  }

  /// Verifies current session by calling `GET /api/auth/me` with the specified application JWT.
  /// Throws [ApiException] when the request fails (401 Unauthorized, 403 Forbidden, 5xx, or network failure).
  Future<UserModel?> verifyCurrentSession(String token) async {
    final response = await _apiService.get(
      ApiConstants.currentUserEndpoint,
      requiresAuth: true,
      overrideToken: token,
    );

    if (response != null && response is Map<String, dynamic>) {
      return UserModel.fromJson(response);
    }
    return null;
  }

  /// Reads stored application JWT token.
  Future<String?> getSavedToken() async {
    return await _secureStorage.read(key: ApiConstants.tokenStorageKey);
  }

  /// Reads stored JWT expiry date.
  Future<DateTime?> getSavedTokenExpiry() async {
    final expiryStr = await _secureStorage.read(key: ApiConstants.tokenExpiryStorageKey);
    if (expiryStr != null) {
      return DateTime.tryParse(expiryStr);
    }
    return null;
  }

  /// Requests backend to send a 6-digit registration OTP to the specified email.
  Future<bool> sendRegistrationOtp(String email) async {
    final response = await _apiService.post(
      ApiConstants.sendOtpEndpoint,
      body: {'email': email.trim()},
      requiresAuth: false,
    );

    return response != null;
  }

  /// Submits user details along with the received OTP to complete registration.
  /// Securely stores the returned application JWT and returns the parsed authentication response.
  Future<AuthResponseModel> registerWithOtp({
    required String email,
    required String otp,
    required String fullName,
    required String password,
  }) async {
    final response = await _apiService.post(
      ApiConstants.registerEndpoint,
      body: {
        'email': email.trim(),
        'otp': otp.trim(),
        'fullName': fullName.trim(),
        'password': password,
      },
      requiresAuth: false,
    );

    if (response == null || response is! Map<String, dynamic>) {
      throw const ApiException(
        statusCode: 500,
        message: 'Phản hồi từ máy chủ không hợp lệ.',
      );
    }

    final authResult = AuthResponseModel.fromJson(response);

    if (authResult.token.isEmpty) {
      throw const ApiException(
        statusCode: 500,
        message: 'Máy chủ không trả về token xác thực hợp lệ.',
      );
    }

    // Persist session JWT
    await _secureStorage.write(
      key: ApiConstants.tokenStorageKey,
      value: authResult.token,
    );
    await _secureStorage.write(
      key: ApiConstants.tokenExpiryStorageKey,
      value: authResult.expiresAt.toIso8601String(),
    );

    return authResult;
  }

  /// Submits email and password to initiate login and request an OTP.
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiService.post(
      ApiConstants.loginEndpoint,
      body: {
        'email': email.trim(),
        'password': password,
      },
      requiresAuth: false,
    );

    return response != null;
  }

  /// Submits email and OTP to verify login and receive full application JWT.
  Future<AuthResponseModel> verifyLoginOtp({
    required String email,
    required String otp,
  }) async {
    final response = await _apiService.post(
      ApiConstants.verifyLoginOtpEndpoint,
      body: {
        'email': email.trim(),
        'otp': otp.trim(),
      },
      requiresAuth: false,
    );

    if (response == null || response is! Map<String, dynamic>) {
      throw const ApiException(
        statusCode: 500,
        message: 'Phản hồi từ máy chủ không hợp lệ.',
      );
    }

    final authResult = AuthResponseModel.fromJson(response);

    if (authResult.token.isEmpty) {
      throw const ApiException(
        statusCode: 500,
        message: 'Máy chủ không trả về token xác thực hợp lệ.',
      );
    }

    // Persist session JWT
    await _secureStorage.write(
      key: ApiConstants.tokenStorageKey,
      value: authResult.token,
    );
    await _secureStorage.write(
      key: ApiConstants.tokenExpiryStorageKey,
      value: authResult.expiresAt.toIso8601String(),
    );

    return authResult;
  }

  /// Requests backend to resend a login OTP.
  Future<bool> resendLoginOtp(String email) async {
    final response = await _apiService.post(
      ApiConstants.resendLoginOtpEndpoint,
      body: {'email': email.trim()},
      requiresAuth: false,
    );

    return response != null;
  }

  /// Signs out from Google and purges local application JWT credentials and biometric enrollment.
  Future<void> logout() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Ignore Google signout failure if already disconnected
    }
    await _secureStorage.delete(key: ApiConstants.tokenStorageKey);
    await _secureStorage.delete(key: ApiConstants.tokenExpiryStorageKey);
    await disableBiometricLogin();
  }

  /// Checks whether biometric authentication is currently enabled for a parent account.
  Future<bool> isBiometricEnabled() async {
    final val = await _secureStorage.read(key: ApiConstants.biometricEnabledStorageKey);
    return val == 'true';
  }

  /// Retrieves the email associated with biometric login.
  Future<String?> getBiometricEnrolledEmail() async {
    return await _secureStorage.read(key: ApiConstants.biometricEnrolledEmailStorageKey);
  }

  /// Retrieves the user ID associated with biometric login.
  Future<int?> getBiometricEnrolledUserId() async {
    final idStr = await _secureStorage.read(key: ApiConstants.biometricEnrolledUserIdStorageKey);
    return idStr != null ? int.tryParse(idStr) : null;
  }

  /// Enables biometric login, binding it to the specified parent email and userId.
  Future<void> enableBiometricLogin({
    required String email,
    required int userId,
  }) async {
    await _secureStorage.write(
      key: ApiConstants.biometricEnabledStorageKey,
      value: 'true',
    );
    await _secureStorage.write(
      key: ApiConstants.biometricEnrolledEmailStorageKey,
      value: email.trim(),
    );
    await _secureStorage.write(
      key: ApiConstants.biometricEnrolledUserIdStorageKey,
      value: userId.toString(),
    );
  }

  /// Disables and removes biometric login configuration.
  Future<void> disableBiometricLogin() async {
    await _secureStorage.delete(key: ApiConstants.biometricEnabledStorageKey);
    await _secureStorage.delete(key: ApiConstants.biometricEnrolledEmailStorageKey);
    await _secureStorage.delete(key: ApiConstants.biometricEnrolledUserIdStorageKey);
  }
}
