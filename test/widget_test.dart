import 'package:flutter_test/flutter_test.dart';
import 'package:tran_nguyen_vi_khang_app/constants/api_constants.dart';
import 'package:tran_nguyen_vi_khang_app/models/user_model.dart';
import 'package:tran_nguyen_vi_khang_app/models/auth_response_model.dart';
import 'package:tran_nguyen_vi_khang_app/providers/auth_provider.dart';
import 'package:tran_nguyen_vi_khang_app/services/api_service.dart';

void main() {
  group('Parental Control App Smoke & Model Tests', () {
    test('UserModel serialization and role mapping test', () {
      final jsonParent = {
        'id': 1,
        'fullName': 'Tran Nguyen Vi Khang',
        'email': 'khang@example.com',
        'role': 'Parent',
      };

      final parentUser = UserModel.fromJson(jsonParent);
      expect(parentUser.id, 1);
      expect(parentUser.fullName, 'Tran Nguyen Vi Khang');
      expect(parentUser.email, 'khang@example.com');
      expect(parentUser.role, 'Parent');
      expect(parentUser.isParent, true);
      expect(parentUser.isAdmin, false);

      final jsonAdmin = {
        'id': 2,
        'fullName': 'Admin User',
        'email': 'admin@example.com',
        'role': 'Admin',
      };

      final adminUser = UserModel.fromJson(jsonAdmin);
      expect(adminUser.isAdmin, true);
      expect(adminUser.isParent, false);
    });

    test('AuthResponseModel deserialization test', () {
      final authJson = {
        'token': 'mock.jwt.token',
        'expiresAt': '2026-10-29T14:00:00Z',
        'user': {
          'id': 10,
          'fullName': 'Test Parent',
          'email': 'test@parental.local',
          'role': 'Parent',
        }
      };

      final authResponse = AuthResponseModel.fromJson(authJson);
      expect(authResponse.token, 'mock.jwt.token');
      expect(authResponse.user.id, 10);
      expect(authResponse.user.fullName, 'Test Parent');
      expect(authResponse.user.isParent, true);
    });

    test('ApiConstants development BaseUrl resolves correctly', () {
      final url = ApiConstants.baseUrl;
      expect(url.isNotEmpty, true);
      expect(url.startsWith('http://') || url.startsWith('https://'), true);
      expect(url.endsWith('/'), false, reason: 'baseUrl must not have trailing slash');
      expect(url.endsWith('/api'), false, reason: 'baseUrl must not end with /api');
      expect(ApiConstants.googleServerClientId.isNotEmpty, true);
    });

    test('ApiService.buildUri constructs normalized URL without duplicate slashes or /api/api', () {
      final uri = ApiService.buildUri(ApiConstants.loginEndpoint);
      expect(uri.path, '/api/auth/login');
      expect(uri.toString(), '${ApiConstants.baseUrl}/api/auth/login');

      // Test with endpoint missing leading slash
      final uriWithoutSlash = ApiService.buildUri('api/children');
      expect(uriWithoutSlash.path, '/api/children');
      expect(uriWithoutSlash.toString(), '${ApiConstants.baseUrl}/api/children');
    });

    test('All critical ApiConstants endpoints begin with /api/ and follow route contracts', () {
      final endpoints = [
        ApiConstants.googleSignInEndpoint,
        ApiConstants.currentUserEndpoint,
        ApiConstants.sendOtpEndpoint,
        ApiConstants.registerEndpoint,
        ApiConstants.loginEndpoint,
        ApiConstants.verifyLoginOtpEndpoint,
        ApiConstants.resendLoginOtpEndpoint,
        ApiConstants.childrenEndpoint,
        ApiConstants.childSafetyAdvisorEndpoint(1),
        ApiConstants.devicesEndpoint,
        ApiConstants.monitoringRulesEndpoint,
        ApiConstants.pairingTicketEndpoint,
        ApiConstants.enrollDeviceEndpoint,
        ApiConstants.myRulesEndpoint,
        ApiConstants.locationsEndpoint,
        ApiConstants.childLocationEndpoint(1),
        ApiConstants.deviceBatteryEndpoint,
        ApiConstants.locationRefreshRequestsEndpoint,
        ApiConstants.locationRefreshRequestStatusEndpoint(1),
        ApiConstants.pendingRefreshRequestEndpoint,
        ApiConstants.completeRefreshRequestEndpoint(1),
      ];

      for (final ep in endpoints) {
        expect(ep.startsWith('/api/'), true, reason: 'Endpoint $ep should start with /api/');
        expect(ep.contains('//'), false, reason: 'Endpoint $ep must not contain double slashes');
      }
    });

    test('AuthProvider initial state is unauthenticated/initial', () {
      final provider = AuthProvider();
      expect(provider.status, AuthStatus.initial);
      expect(provider.isAuthenticated, false);
      expect(provider.user, isNull);
      expect(provider.token, isNull);
      expect(provider.isLoading, false);
    });
  });
}
