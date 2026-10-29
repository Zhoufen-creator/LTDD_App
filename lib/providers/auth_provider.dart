import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';

enum AuthStatus {
  initial,
  checking,
  authenticating,
  authenticated,
  unauthenticated,
}

/// Global authentication state management using Provider.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final IBiometricService _biometricService;

  AuthStatus _status = AuthStatus.initial;
  UserModel? _user;
  String? _token;
  String? _errorMessage;

  // Biometric authentication state
  bool _isBiometricSupported = false;
  bool _isBiometricEnabled = false;
  String? _biometricEnrolledEmail;

  AuthProvider({
    AuthService? authService,
    IBiometricService? biometricService,
  })  : _authService = authService ?? AuthService(),
        _biometricService = biometricService ?? BiometricService();

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get token => _token;
  String? get errorMessage => _errorMessage;

  bool get isBiometricSupported => _isBiometricSupported;
  bool get isBiometricEnabled => _isBiometricEnabled;
  String? get biometricEnrolledEmail => _biometricEnrolledEmail;
  bool get canLoginWithBiometrics =>
      _isBiometricSupported && _isBiometricEnabled && _biometricEnrolledEmail != null;

  bool get isAuthenticated => _status == AuthStatus.authenticated && _user != null;
  bool get isLoading => _status == AuthStatus.authenticating || _status == AuthStatus.checking;

  /// Checks local secure storage and verifies token against backend `GET /api/auth/me`.
  Future<void> checkSession() async {
    _status = AuthStatus.checking;
    _errorMessage = null;
    notifyListeners();

    // Check biometric support and enrollment state concurrently
    await checkBiometricSupport();

    try {
      final savedToken = await _authService.getSavedToken();
      if (savedToken == null || savedToken.isEmpty) {
        _status = AuthStatus.unauthenticated;
        _user = null;
        _token = null;
        notifyListeners();
        return;
      }

      // Check token expiry locally if stored
      final expiry = await _authService.getSavedTokenExpiry();
      if (expiry != null && DateTime.now().isAfter(expiry)) {
        await _authService.logout();
        _status = AuthStatus.unauthenticated;
        _user = null;
        _token = null;
        _isBiometricEnabled = false;
        _biometricEnrolledEmail = null;
        _errorMessage = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
        notifyListeners();
        return;
      }

      // Validate session with backend
      try {
        final validatedUser = await _authService.verifyCurrentSession(savedToken);

        if (validatedUser != null && (validatedUser.isParent || validatedUser.isAdmin)) {
          _token = savedToken;
          _user = validatedUser;
          _status = AuthStatus.authenticated;
          _errorMessage = null;
        } else {
          // Token rejected by backend or user does not possess Parent/Admin role
          await _authService.logout();
          _status = AuthStatus.unauthenticated;
          _user = null;
          _token = null;
          _isBiometricEnabled = false;
          _biometricEnrolledEmail = null;
          _errorMessage = 'Phiên làm việc không có quyền truy cập Chế độ Phụ huynh.';
        }
      } on ApiException catch (e) {
        if (e.statusCode == 401) {
          // Token expired or revoked by backend: purge session and biometric enrollment
          await _authService.logout();
          _status = AuthStatus.unauthenticated;
          _user = null;
          _token = null;
          _isBiometricEnabled = false;
          _biometricEnrolledEmail = null;
          _errorMessage = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
        } else {
          // Network failure (0), timeout (408), 5xx, or 403:
          // Preserve stored token and enrollment in secure storage! Do not wipe credentials.
          _status = AuthStatus.unauthenticated;
          _user = null;
          _token = null;
          _errorMessage = 'Không thể xác thực phiên làm việc: ${e.message}';
        }
      }
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _user = null;
      _token = null;
      _errorMessage = 'Không thể khôi phục phiên đăng nhập: $e';
    } finally {
      notifyListeners();
    }
  }

  /// Probes device biometric hardware and loads stored enrollment status.
  /// Uses [isDeviceSupported] (hardware present, PIN/pattern sufficient) so that
  /// the biometric settings UI can still appear on devices that have the hardware
  /// but have not yet enrolled any fingerprints or face data.
  Future<void> checkBiometricSupport() async {
    try {
      _isBiometricSupported = await _biometricService.isDeviceSupported();
      _isBiometricEnabled = await _authService.isBiometricEnabled();
      _biometricEnrolledEmail = await _authService.getBiometricEnrolledEmail();
    } catch (_) {
      _isBiometricSupported = false;
      _isBiometricEnabled = false;
      _biometricEnrolledEmail = null;
    }
    notifyListeners();
  }

  /// Enables biometric login for the currently authenticated parent.
  /// Requires successful biometric verification before enabling.
  Future<bool> enableBiometricLogin() async {
    if (_user == null || (!_user!.isParent && !_user!.isAdmin)) {
      _errorMessage = 'Chỉ tài khoản Phụ huynh mới có thể kích hoạt đăng nhập sinh trắc học.';
      notifyListeners();
      return false;
    }

    final isSupported = await _biometricService.isDeviceSupported();
    if (!isSupported) {
      _errorMessage = 'Thiết bị không hỗ trợ xác thực sinh trắc học.';
      notifyListeners();
      return false;
    }

    final canCheck = await _biometricService.canCheckBiometrics();
    if (!canCheck) {
      _errorMessage = 'Thiết bị chưa có vân tay hoặc khuôn mặt nào được đăng ký. Vui lòng vào Cài đặt hệ thống để thiết lập sinh trắc học trước.';
      notifyListeners();
      return false;
    }

    final authenticated = await _biometricService.authenticate(
      localizedReason: 'Xác thực sinh trắc học để kích hoạt đăng nhập nhanh vào Chế độ Phụ huynh',
    );

    if (!authenticated) {
      // User cancelled or verification refused
      return false;
    }

    await _authService.enableBiometricLogin(
      email: _user!.email,
      userId: _user!.id,
    );

    _isBiometricEnabled = true;
    _biometricEnrolledEmail = _user!.email;
    _errorMessage = null;
    notifyListeners();
    return true;
  }

  /// Disables and removes biometric login configuration.
  Future<void> disableBiometricLogin() async {
    await _authService.disableBiometricLogin();
    _isBiometricEnabled = false;
    _biometricEnrolledEmail = null;
    notifyListeners();
  }

  /// Ensures that if a new user logs in, any stale biometric enrollment belonging to a
  /// different user is invalidated so that the new account cannot inherit it.
  Future<void> _syncBiometricEnrollmentForAuthenticatedUser(UserModel newUser) async {
    try {
      final isEnrolled = await _authService.isBiometricEnabled();
      if (isEnrolled) {
        final enrolledId = await _authService.getBiometricEnrolledUserId();
        final enrolledEmail = await _authService.getBiometricEnrolledEmail();
        if (enrolledId != null &&
            (enrolledId != newUser.id ||
                enrolledEmail?.trim().toLowerCase() != newUser.email.trim().toLowerCase())) {
          await _authService.disableBiometricLogin();
          _isBiometricEnabled = false;
          _biometricEnrolledEmail = null;
        } else {
          _isBiometricEnabled = true;
          _biometricEnrolledEmail = enrolledEmail;
        }
      } else {
        _isBiometricEnabled = false;
        _biometricEnrolledEmail = null;
      }
    } catch (_) {
      _isBiometricEnabled = false;
      _biometricEnrolledEmail = null;
    }
  }

  /// Authenticates using biometrics on subsequent launches and restores Parent session.
  Future<bool> loginWithBiometrics() async {
    if (!_isBiometricEnabled || _biometricEnrolledEmail == null) {
      _errorMessage = 'Chức năng đăng nhập sinh trắc học chưa được kích hoạt.';
      notifyListeners();
      return false;
    }

    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final biometricSuccess = await _biometricService.authenticate(
        localizedReason: 'Xác thực sinh trắc học để đăng nhập vào Chế độ Phụ huynh',
      );

      if (!biometricSuccess) {
        // User cancelled or biometric failed: preserve credentials, return to unauthenticated
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return false;
      }

      // Biometric verified! Retrieve stored Parent session
      final savedToken = await _authService.getSavedToken();
      if (savedToken == null || savedToken.isEmpty) {
        await _authService.disableBiometricLogin();
        _isBiometricEnabled = false;
        _biometricEnrolledEmail = null;
        _status = AuthStatus.unauthenticated;
        _errorMessage = 'Không tìm thấy phiên làm việc an toàn. Vui lòng đăng nhập bằng mật khẩu.';
        notifyListeners();
        return false;
      }

      // Check token expiry locally
      final expiry = await _authService.getSavedTokenExpiry();
      if (expiry != null && DateTime.now().isAfter(expiry)) {
        await _authService.logout();
        _user = null;
        _token = null;
        _isBiometricEnabled = false;
        _biometricEnrolledEmail = null;
        _status = AuthStatus.unauthenticated;
        _errorMessage = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại bằng email và mật khẩu.';
        notifyListeners();
        return false;
      }

      // Retrieve stored enrolled identity
      final enrolledUserId = await _authService.getBiometricEnrolledUserId();
      final enrolledEmail = _biometricEnrolledEmail ?? await _authService.getBiometricEnrolledEmail();
      if (enrolledUserId == null || enrolledEmail == null || enrolledEmail.isEmpty) {
        await _authService.disableBiometricLogin();
        _isBiometricEnabled = false;
        _biometricEnrolledEmail = null;
        _status = AuthStatus.unauthenticated;
        _errorMessage = 'Dữ liệu đăng ký sinh trắc học không hợp lệ. Vui lòng đăng nhập bằng mật khẩu.';
        notifyListeners();
        return false;
      }

      // Verify token with backend
      UserModel? validatedUser;
      try {
        validatedUser = await _authService.verifyCurrentSession(savedToken);
      } on ApiException catch (e) {
        if (e.statusCode == 401) {
          // Token expired or revoked on backend: purge session and biometric enrollment
          await _authService.logout();
          _user = null;
          _token = null;
          _isBiometricEnabled = false;
          _biometricEnrolledEmail = null;
          _status = AuthStatus.unauthenticated;
          _errorMessage = 'Phiên đăng nhập không hợp lệ hoặc đã bị hủy. Vui lòng đăng nhập lại.';
          notifyListeners();
          return false;
        } else if (e.statusCode == 403) {
          // Forbidden: backend rejected access, but preserve stored credentials and biometric enrollment
          _status = AuthStatus.unauthenticated;
          _errorMessage = 'Tài khoản không có quyền truy cập Chế độ Phụ huynh (HTTP 403 Forbidden).';
          notifyListeners();
          return false;
        } else if (e.statusCode == 0 || e.statusCode == 408) {
          // Network failure or timeout: preserve stored credentials and biometric enrollment
          _status = AuthStatus.unauthenticated;
          _errorMessage = 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra kết nối mạng và thử lại.';
          notifyListeners();
          return false;
        } else {
          // HTTP 5xx or server error: preserve stored credentials and biometric enrollment
          _status = AuthStatus.unauthenticated;
          _errorMessage = 'Lỗi máy chủ (${e.statusCode}). Vui lòng thử lại sau.';
          notifyListeners();
          return false;
        }
      } catch (e) {
        // Unexpected exception (e.g. JSON parse error): preserve stored credentials and enrollment
        _status = AuthStatus.unauthenticated;
        _errorMessage = 'Lỗi không xác định khi xác thực phiên làm việc: $e';
        notifyListeners();
        return false;
      }

      if (validatedUser == null) {
        _status = AuthStatus.unauthenticated;
        _errorMessage = 'Không thể lấy thông tin người dùng từ máy chủ. Vui lòng thử lại.';
        notifyListeners();
        return false;
      }

      // 1. Role validation: Must be Parent or Admin (Never ChildDevice)
      if (!validatedUser.isParent && !validatedUser.isAdmin) {
        _status = AuthStatus.unauthenticated;
        _errorMessage = 'Tài khoản không có vai trò Phụ huynh (Role: ${validatedUser.role}).';
        notifyListeners();
        return false;
      }

      // 2. Identity validation: Backend user ID and email MUST match stored biometric enrollment
      if (validatedUser.id != enrolledUserId ||
          validatedUser.email.trim().toLowerCase() != enrolledEmail.trim().toLowerCase()) {
        _status = AuthStatus.unauthenticated;
        _errorMessage = 'Danh tính người dùng không khớp với thông tin sinh trắc học đã đăng ký.';
        notifyListeners();
        return false;
      }

      // Identity validation succeeded! Restore Parent session
      _token = savedToken;
      _user = validatedUser;
      _status = AuthStatus.authenticated;
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = 'Lỗi không xác định khi đăng nhập sinh trắc học: $e';
      notifyListeners();
      return false;
    }
  }

  /// Initiates Google Sign-In workflow.
  Future<bool> signInWithGoogle() async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.signInWithGoogle();

      if (result == null) {
        // User aborted the account selector
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return false;
      }

      _token = result.token;
      _user = result.user;
      _status = AuthStatus.authenticated;
      _errorMessage = null;
      await _syncBiometricEnrollmentForAuthenticatedUser(result.user);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Đã xảy ra lỗi không xác định trong quá trình đăng nhập.';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  /// Requests a registration OTP code for a given email address.
  Future<bool> sendRegistrationOtp(String email) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _authService.sendRegistrationOtp(email);
      _status = AuthStatus.unauthenticated;
      _errorMessage = null;
      notifyListeners();
      return success;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Gửi mã OTP thất bại. Vui lòng kiểm tra kết nối mạng.';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  /// Completes account registration using the submitted OTP.
  Future<bool> registerWithOtp({
    required String email,
    required String otp,
    required String fullName,
    required String password,
  }) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.registerWithOtp(
        email: email,
        otp: otp,
        fullName: fullName,
        password: password,
      );

      _token = result.token;
      _user = result.user;
      _status = AuthStatus.authenticated;
      _errorMessage = null;
      await _syncBiometricEnrollmentForAuthenticatedUser(result.user);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Đăng ký tài khoản thất bại. Vui lòng thử lại sau.';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  /// Submits email and password to initiate login and request an OTP.
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _authService.login(
        email: email,
        password: password,
      );
      _status = AuthStatus.unauthenticated;
      _errorMessage = null;
      notifyListeners();
      return success;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Đăng nhập thất bại. Vui lòng kiểm tra kết nối mạng.';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  /// Completes login using the submitted OTP.
  Future<bool> verifyLoginOtp({
    required String email,
    required String otp,
  }) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.verifyLoginOtp(
        email: email,
        otp: otp,
      );

      _token = result.token;
      _user = result.user;
      _status = AuthStatus.authenticated;
      _errorMessage = null;
      await _syncBiometricEnrollmentForAuthenticatedUser(result.user);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Xác thực OTP thất bại. Vui lòng thử lại sau.';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  /// Requests a new login OTP.
  Future<bool> resendLoginOtp(String email) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _authService.resendLoginOtp(email);
      _status = AuthStatus.unauthenticated;
      _errorMessage = null;
      notifyListeners();
      return success;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Gửi lại mã OTP thất bại. Vui lòng thử lại sau.';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  /// Terminates current session, purges secure tokens, and notifies listeners.
  Future<void> logout() async {
    try {
      await _authService.logout();
    } finally {
      _user = null;
      _token = null;
      _isBiometricEnabled = false;
      _biometricEnrolledEmail = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Clears active error notification.
  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }
}

