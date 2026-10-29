import 'package:flutter/foundation.dart';

/// Centralized API and environment configuration.
/// 
/// Supports dynamic overrides via `--dart-define`:
/// - `BASE_URL`: e.g. `--dart-define=BASE_URL=https://api.yourdomain.com`
/// - `GOOGLE_SERVER_CLIENT_ID`: Web application client ID for Google ID Token audience
class ApiConstants {
  ApiConstants._();

  // Environment variables passed via --dart-define
  static const String _envBaseUrl = String.fromEnvironment('BASE_URL');
  static const String _envGoogleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    // Default configured Web Client ID matching backend .env (Authentication:Google:ClientId)
    defaultValue: '818917238880-dtsl08ml2ekg9fa4gi7pavq8afc4tjvq.apps.googleusercontent.com',
  );

  /// Resolves the API Base URL strictly according to the environment.
  /// 
  /// - In Release mode: MUST be supplied via `--dart-define=BASE_URL=...`.
  ///   Does NOT fallback to local emulator address or invented hostname.
  /// - In Debug / Development mode:
  ///   - Uses `BASE_URL` if explicitly supplied.
  ///   - Otherwise defaults to Android Emulator host loopback `http://10.0.2.2:5153` on Android,
  ///     or `http://localhost:5153` on Web/Desktop/iOS.
  /// 
  /// Normalization rules:
  /// - Strips trailing slashes to prevent `//` double slashes.
  /// - Strips trailing `/api` if present to prevent `/api/api` duplication,
  ///   since all endpoints in this class are already prefixed with `/api/`.
  static String get baseUrl {
    if (_envBaseUrl.isNotEmpty) {
      var url = _envBaseUrl.trim();
      while (url.endsWith('/')) {
        url = url.substring(0, url.length - 1);
      }
      if (url.toLowerCase().endsWith('/api')) {
        url = url.substring(0, url.length - 4);
      }
      while (url.endsWith('/')) {
        url = url.substring(0, url.length - 1);
      }
      return url;
    }

    if (kReleaseMode) {
      throw StateError(
        'CRITICAL CONFIGURATION ERROR: Production Base URL is not configured. '
        'Compile with --dart-define=BASE_URL=https://<your-production-api-host>',
      );
    }

    // Development fallback
    if (defaultTargetPlatform == TargetPlatform.android && !kIsWeb) {
      return 'http://10.0.2.2:5153';
    }
    return 'http://localhost:5153';
  }

  /// Web Application Client ID from Google Cloud Console.
  /// Used as `serverClientId` in Flutter Google Sign-In so Google issues an ID token
  /// with this audience, matching the ASP.NET Core backend validation settings.
  static String get googleServerClientId => _envGoogleServerClientId;

  // Auth endpoints
  static const String googleSignInEndpoint = '/api/auth/google';
  static const String currentUserEndpoint = '/api/auth/me';
  static const String sendOtpEndpoint = '/api/auth/register/send-otp';
  static const String registerEndpoint = '/api/auth/register';
  static const String loginEndpoint = '/api/auth/login';
  static const String verifyLoginOtpEndpoint = '/api/auth/login/verify-otp';
  static const String resendLoginOtpEndpoint = '/api/auth/login/resend-otp';

  // Business CRUD endpoints
  static const String childrenEndpoint = '/api/children';
  static String childSafetyAdvisorEndpoint(int childId) => '/api/children/$childId/safety-advisor';
  static const String devicesEndpoint = '/api/devices';
  static const String monitoringRulesEndpoint = '/api/monitoringrules';

  // QR Pairing and Child Device endpoints
  static const String pairingTicketEndpoint = '/api/devices/qr/pairing-ticket';
  static const String enrollDeviceEndpoint = '/api/devices/qr/enroll';
  static const String myRulesEndpoint = '/api/devices/my-rules';
  static const String myRulesAckEndpoint = '/api/devices/my-rules/ack';

  // Child Activity and Rule Enforcement endpoints
  static const String activitiesBatchEndpoint = '/api/activities/batch';
  static String childActivitiesEndpoint(int childId) => '/api/activities/child/$childId';

  // Location endpoints
  static const String locationsEndpoint = '/api/locations';
  static String childLocationEndpoint(int childId) => '/api/locations/child/$childId';

  // Battery and Device Monitoring endpoints
  static const String deviceBatteryEndpoint = '/api/devices/battery';

  // Location Refresh Request endpoints
  static const String locationRefreshRequestsEndpoint = '/api/locations/refresh-requests';
  static String locationRefreshRequestStatusEndpoint(int id) => '/api/locations/refresh-requests/$id';
  static const String pendingRefreshRequestEndpoint = '/api/locations/refresh-requests/pending';
  static String completeRefreshRequestEndpoint(int id) => '/api/locations/refresh-requests/$id/complete';

  // Device Mode Requests endpoints (Parent authorization for Child Mode change/unlock/unlink)
  static const String deviceModeRequestsEndpoint = '/api/devices/mode-requests';
  static const String pendingDeviceModeRequestsEndpoint = '/api/devices/mode-requests/pending';
  static String deviceModeRequestStatusEndpoint(int id) => '/api/devices/mode-requests/$id';
  static String approveDeviceModeRequestEndpoint(int id) => '/api/devices/mode-requests/$id/approve';
  static String rejectDeviceModeRequestEndpoint(int id) => '/api/devices/mode-requests/$id/reject';
  static String executeDeviceModeRequestEndpoint(int id) => '/api/devices/mode-requests/$id/execute';
  static const String directParentUnlockEndpoint = '/api/devices/mode-requests/direct-unlock';

  // Configurable monitoring synchronization intervals
  static const Duration foregroundSyncInterval = Duration(minutes: 20);
  static const Duration backgroundSyncInterval = Duration(minutes: 20);
  static const Duration pendingRequestPollInterval = Duration(seconds: 30);

  // Secure storage keys - Parent Mode
  static const String tokenStorageKey = 'app_jwt_token';
  static const String tokenExpiryStorageKey = 'app_jwt_expiry';
  static const String biometricEnabledStorageKey = 'biometric_enabled';
  static const String biometricEnrolledEmailStorageKey = 'biometric_enrolled_email';
  static const String biometricEnrolledUserIdStorageKey = 'biometric_enrolled_user_id';

  // Secure storage keys - Application Mode & Child Mode
  static const String appModeStorageKey = 'app_mode';
  static const String childDeviceTokenStorageKey = 'child_device_token';
  static const String childDeviceIdStorageKey = 'child_device_id';
  static const String childIdStorageKey = 'child_id';
  static const String childNameStorageKey = 'child_name';
  static const String childDeviceNameStorageKey = 'child_device_name';
  static const String childDeviceIdentifierStorageKey = 'child_device_identifier';
}

