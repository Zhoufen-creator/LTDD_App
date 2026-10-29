import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:tran_nguyen_vi_khang_app/models/child_model.dart';
import 'package:tran_nguyen_vi_khang_app/models/safety_advisor_model.dart';
import 'package:tran_nguyen_vi_khang_app/services/api_service.dart';
import 'package:tran_nguyen_vi_khang_app/services/safety_advisor_service.dart';
import 'package:tran_nguyen_vi_khang_app/widgets/safety_advisor_card.dart';

// =========================================================================
// MOCKS & TEST DOUBLES
// =========================================================================

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

class FakeSafetyAdvisorService implements ISafetyAdvisorService {
  SafetyAdvisorModel? responseToReturn;
  Exception? exceptionToThrow;
  int callCount = 0;
  int? lastRequestedChildId;

  FakeSafetyAdvisorService({this.responseToReturn, this.exceptionToThrow});

  @override
  Future<SafetyAdvisorModel> getSafetyAdvisor({required int childId}) async {
    callCount++;
    lastRequestedChildId = childId;
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return responseToReturn!;
  }
}

void main() {
  final testChild = ChildModel(
    id: 42,
    fullName: 'Nguyen Van An',
    parentId: 1,
    createdAt: DateTime(2026, 1, 1),
    deviceCount: 1,
  );

  group('1. SafetyAdvisorModel & SafetyWarningModel Unit Tests', () {
    test('Correctly parses LowBattery warning (< 20%) and severity mapping', () {
      final json = {
        'childId': 42,
        'childName': 'Nguyen Van An',
        'overallStatus': 'Warning',
        'statusTitle': 'Cảnh báo an toàn',
        'statusMessage': 'Phát hiện vấn đề an toàn cần phụ huynh xử lý sớm.',
        'evaluatedAt': '2026-10-29T12:00:00Z',
        'hasSufficientData': true,
        'totalDevices': 1,
        'activeDevices': 1,
        'warnings': [
          {
            'type': 'LowBattery',
            'severity': 'Warning',
            'title': 'Cảnh báo pin yếu',
            'message': 'Thiết bị Galaxy S21 chỉ còn 14% pin và chưa được cắm sạc.',
            'reading': '14%',
            'suggestedAction': 'Liên hệ ngay với trẻ để nhắc nhở cắm sạc.',
            'actionType': 'ContactChild',
            'deviceId': 7,
            'deviceName': 'Galaxy S21'
          }
        ]
      };

      final model = SafetyAdvisorModel.fromJson(json);

      expect(model.childId, equals(42));
      expect(model.isWarning, isTrue);
      expect(model.isSafe, isFalse);
      expect(model.statusBadgeLabel, equals('Cảnh báo an toàn'));
      expect(model.warnings.length, equals(1));

      final warning = model.warnings.first;
      expect(warning.isLowBattery, isTrue);
      expect(warning.isWarning, isTrue);
      expect(warning.reading, equals('14%'));
      expect(warning.canContactChild, isTrue);
      expect(warning.severityColor, equals(const Color(0xFFD32F2F)));
    });

    test('Correctly parses StaleLocation warning (> 30 minutes)', () {
      final json = {
        'childId': 42,
        'childName': 'Nguyen Van An',
        'overallStatus': 'NeedsAttention',
        'statusTitle': 'Cần lưu ý',
        'statusMessage': 'Có một số trạng thái thiết bị cần phụ huynh lưu ý.',
        'evaluatedAt': '2026-10-29T12:00:00Z',
        'hasSufficientData': true,
        'latestLocation': {
          'locationId': 101,
          'latitude': 10.762622,
          'longitude': 106.660172,
          'recordedAt': '2026-10-29T11:15:00Z',
          'isStaleLocation': true,
          'ageMinutes': 45
        },
        'warnings': [
          {
            'type': 'StaleLocation',
            'severity': 'NeedsAttention',
            'title': 'Vị trí chưa được cập nhật',
            'message': 'Vị trí GPS được ghi nhận lần cuối 45 phút trước.',
            'reading': '45 phút trước',
            'timestamp': '2026-10-29T11:15:00Z',
            'suggestedAction': 'Nhấn "Làm mới vị trí" để cập nhật toạ độ.',
            'actionType': 'RefreshLocation'
          }
        ]
      };

      final model = SafetyAdvisorModel.fromJson(json);

      expect(model.isNeedsAttention, isTrue);
      expect(model.statusBadgeLabel, equals('Cần lưu ý'));
      expect(model.latestLocation?.isStaleLocation, isTrue);
      expect(model.latestLocation?.ageMinutes, equals(45));

      final warning = model.warnings.first;
      expect(warning.isStaleLocation, isTrue);
      expect(warning.canRefreshLocation, isTrue);
      expect(warning.reading, equals('45 phút trước'));
    });

    test('Correctly identifies Safe state with no warnings', () {
      final json = {
        'childId': 42,
        'childName': 'Nguyen Van An',
        'overallStatus': 'Safe',
        'statusTitle': 'An toàn dựa trên dữ liệu hiện có',
        'statusMessage': 'Không phát hiện cảnh báo nào dựa trên dữ liệu hiện tại.',
        'evaluatedAt': '2026-10-29T12:00:00Z',
        'hasSufficientData': true,
        'warnings': []
      };

      final model = SafetyAdvisorModel.fromJson(json);

      expect(model.isSafe, isTrue);
      expect(model.isWarning, isFalse);
      expect(model.isNeedsAttention, isFalse);
      expect(model.isInsufficientData, isFalse);
      expect(model.statusBadgeLabel, equals('An toàn (theo dữ liệu)'));
    });

    test('Correctly identifies InsufficientData state when no telemetry available', () {
      final json = {
        'childId': 42,
        'childName': 'Nguyen Van An',
        'overallStatus': 'InsufficientData',
        'statusTitle': 'Chưa đủ dữ liệu',
        'statusMessage': 'Chưa có đủ dữ liệu giám sát từ thiết bị của trẻ.',
        'evaluatedAt': '2026-10-29T12:00:00Z',
        'hasSufficientData': false,
        'warnings': [
          {
            'type': 'NoDevice',
            'severity': 'NeedsAttention',
            'title': 'Chưa có thiết bị kết nối',
            'message': 'Hồ sơ của trẻ chưa có thiết bị nào.',
            'reading': '0 thiết bị',
            'suggestedAction': 'Tạo mã QR ghép nối.',
            'actionType': 'PairDevice'
          }
        ]
      };

      final model = SafetyAdvisorModel.fromJson(json);

      expect(model.isInsufficientData, isTrue);
      expect(model.isSafe, isFalse); // Must never be safe when insufficient data
      expect(model.statusBadgeLabel, equals('Chưa đủ dữ liệu'));
      expect(model.warnings.first.canPairDevice, isTrue);
    });
  });

  group('2. SafetyAdvisorService HTTP Integration Tests', () {
    test('getSafetyAdvisor sends GET to correct endpoint with JWT Authorization', () async {
      late http.BaseRequest capturedRequest;

      final mockClient = MockHttpClient((request) async {
        capturedRequest = request;
        final responsePayload = {
          'childId': 42,
          'childName': 'Nguyen Van An',
          'overallStatus': 'Safe',
          'statusTitle': 'An toàn',
          'statusMessage': 'Bình thường',
          'evaluatedAt': DateTime.now().toUtc().toIso8601String(),
          'hasSufficientData': true,
          'warnings': []
        };
        return http.Response(
          jsonEncode(responsePayload),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiService = ApiService(
        client: mockClient,
        tokenGetter: () async => 'test-parent-jwt-token-xyz',
      );

      final service = SafetyAdvisorService(apiService: apiService);
      final result = await service.getSafetyAdvisor(childId: 42);

      expect(result.childId, equals(42));
      expect(capturedRequest.method, equals('GET'));
      expect(capturedRequest.url.path, equals('/api/children/42/safety-advisor'));
      expect(capturedRequest.headers['authorization'], equals('Bearer test-parent-jwt-token-xyz'));
    });

    test('getSafetyAdvisor throws ApiException on 404 or backend failure', () async {
      final mockClient = MockHttpClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Child with ID 999 was not found.'}),
          404,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiService = ApiService(
        client: mockClient,
        tokenGetter: () async => 'test-token',
      );

      final service = SafetyAdvisorService(apiService: apiService);

      expect(
        () async => await service.getSafetyAdvisor(childId: 999),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', equals(404))),
      );
    });
  });

  group('3. SafetyAdvisorCard Widget Tests', () {
    testWidgets('Displays Loading state initially when fetching data', (tester) async {
      final completer = Completer<SafetyAdvisorModel>();

      // Override getSafetyAdvisor to hang until completer resolves
      final delayedFuture = completer.future;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafetyAdvisorCard(
              child: testChild,
              safetyAdvisorOverride: _DelayedSafetyAdvisorService(delayedFuture),
            ),
          ),
        ),
      );

      // Verify loading indicator and Vietnamese text
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Đang phân tích dữ liệu an toàn...'), findsOneWidget);

      // Resolve
      completer.complete(
        SafetyAdvisorModel(
          childId: 42,
          childName: 'Nguyen Van An',
          overallStatus: 'Safe',
          statusTitle: 'An toàn',
          statusMessage: 'Bình thường',
          evaluatedAt: DateTime.now(),
          hasSufficientData: true,
          warnings: const [],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('An toàn (theo dữ liệu)'), findsOneWidget);
    });

    testWidgets('Displays Error state and retry button on failure', (tester) async {
      final fakeService = FakeSafetyAdvisorService(
        exceptionToThrow: const ApiException(statusCode: 500, message: 'Lỗi kết nối máy chủ'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafetyAdvisorCard(
              child: testChild,
              safetyAdvisorOverride: fakeService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lỗi kết nối máy chủ'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);

      // Click retry
      fakeService.exceptionToThrow = null;
      fakeService.responseToReturn = SafetyAdvisorModel(
        childId: 42,
        childName: 'Nguyen Van An',
        overallStatus: 'Safe',
        statusTitle: 'An toàn',
        statusMessage: 'Bình thường',
        evaluatedAt: DateTime.now(),
        hasSufficientData: true,
        warnings: const [],
      );

      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();

      expect(find.text('Lỗi kết nối máy chủ'), findsNothing);
      expect(find.text('An toàn (theo dữ liệu)'), findsOneWidget);
    });

    testWidgets('Displays InsufficientData state when telemetry is missing', (tester) async {
      final fakeService = FakeSafetyAdvisorService(
        responseToReturn: SafetyAdvisorModel(
          childId: 42,
          childName: 'Nguyen Van An',
          overallStatus: 'InsufficientData',
          statusTitle: 'Chưa đủ dữ liệu',
          statusMessage: 'Chưa có đủ dữ liệu giám sát từ thiết bị của trẻ để đưa ra đánh giá an toàn.',
          evaluatedAt: DateTime.now(),
          hasSufficientData: false,
          warnings: const [
            SafetyWarningModel(
              type: 'NoDevice',
              severity: 'NeedsAttention',
              title: 'Chưa có thiết bị kết nối',
              message: 'Hồ sơ của trẻ chưa có thiết bị nào đang hoạt động.',
              reading: '0 thiết bị',
              suggestedAction: 'Tạo mã QR ghép nối để liên kết thiết bị của trẻ.',
              actionType: 'PairDevice',
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafetyAdvisorCard(
              child: testChild,
              safetyAdvisorOverride: fakeService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chưa đủ dữ liệu'), findsOneWidget);
      expect(find.text('Chưa có đủ dữ liệu giám sát từ thiết bị của trẻ để đưa ra đánh giá an toàn.'), findsOneWidget);
      expect(find.text('Chưa có thiết bị kết nối'), findsOneWidget);
      expect(find.text('Ghép nối'), findsOneWidget);
    });

    testWidgets('Displays Safe state with positive reassurance message', (tester) async {
      final fakeService = FakeSafetyAdvisorService(
        responseToReturn: SafetyAdvisorModel(
          childId: 42,
          childName: 'Nguyen Van An',
          overallStatus: 'Safe',
          statusTitle: 'An toàn dựa trên dữ liệu hiện có',
          statusMessage: 'Không phát hiện cảnh báo nào dựa trên dữ liệu hiện tại.',
          evaluatedAt: DateTime.now(),
          hasSufficientData: true,
          warnings: const [],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafetyAdvisorCard(
              child: testChild,
              safetyAdvisorOverride: fakeService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('An toàn (theo dữ liệu)'), findsOneWidget);
      expect(find.text('Không phát hiện cảnh báo nào dựa trên dữ liệu hiện tại.'), findsOneWidget);
    });

    testWidgets('Displays Low Battery warning (< 20%) and detail button', (tester) async {
      final fakeService = FakeSafetyAdvisorService(
        responseToReturn: SafetyAdvisorModel(
          childId: 42,
          childName: 'Nguyen Van An',
          overallStatus: 'Warning',
          statusTitle: 'Cảnh báo an toàn',
          statusMessage: 'Phát hiện vấn đề an toàn cần phụ huynh xử lý sớm.',
          evaluatedAt: DateTime.now(),
          hasSufficientData: true,
          warnings: const [
            SafetyWarningModel(
              type: 'LowBattery',
              severity: 'Warning',
              title: 'Cảnh báo pin yếu',
              message: 'Thiết bị Galaxy S21 chỉ còn 12% pin và chưa được cắm sạc.',
              reading: '12%',
              suggestedAction: 'Liên hệ ngay với trẻ để nhắc nhở cắm sạc thiết bị.',
              actionType: 'ContactChild',
              deviceName: 'Galaxy S21',
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafetyAdvisorCard(
              child: testChild,
              safetyAdvisorOverride: fakeService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cảnh báo an toàn'), findsOneWidget);
      expect(find.text('Cảnh báo pin yếu'), findsOneWidget);
      expect(find.text('12%'), findsOneWidget);
      expect(find.text('Thiết bị Galaxy S21 chỉ còn 12% pin và chưa được cắm sạc.'), findsOneWidget);
      expect(find.text('Chi tiết'), findsOneWidget);
    });

    testWidgets('Displays Stale Location warning (> 30 min) and "Làm mới" button', (tester) async {
      final fakeService = FakeSafetyAdvisorService(
        responseToReturn: SafetyAdvisorModel(
          childId: 42,
          childName: 'Nguyen Van An',
          overallStatus: 'NeedsAttention',
          statusTitle: 'Cần lưu ý',
          statusMessage: 'Có một số trạng thái thiết bị cần phụ huynh lưu ý.',
          evaluatedAt: DateTime.now(),
          hasSufficientData: true,
          warnings: const [
            SafetyWarningModel(
              type: 'StaleLocation',
              severity: 'NeedsAttention',
              title: 'Vị trí chưa được cập nhật',
              message: 'Vị trí GPS được ghi nhận lần cuối 45 phút trước.',
              reading: '45 phút trước',
              suggestedAction: 'Nhấn "Làm mới vị trí" để yêu cầu thiết bị cập nhật toạ độ GPS.',
              actionType: 'RefreshLocation',
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafetyAdvisorCard(
              child: testChild,
              safetyAdvisorOverride: fakeService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cần lưu ý'), findsOneWidget);
      expect(find.text('Vị trí chưa được cập nhật'), findsOneWidget);
      expect(find.text('45 phút trước'), findsOneWidget);
      expect(find.text('Làm mới'), findsOneWidget);
    });

    testWidgets('Displays multiple warnings existing simultaneously', (tester) async {
      final fakeService = FakeSafetyAdvisorService(
        responseToReturn: SafetyAdvisorModel(
          childId: 42,
          childName: 'Nguyen Van An',
          overallStatus: 'Warning',
          statusTitle: 'Cảnh báo an toàn',
          statusMessage: 'Phát hiện vấn đề an toàn cần phụ huynh xử lý sớm.',
          evaluatedAt: DateTime.now(),
          hasSufficientData: true,
          warnings: const [
            SafetyWarningModel(
              type: 'LowBattery',
              severity: 'Warning',
              title: 'Cảnh báo pin yếu',
              message: 'Thiết bị Galaxy S21 chỉ còn 10% pin.',
              reading: '10%',
              suggestedAction: 'Liên hệ ngay với trẻ để cắm sạc.',
              actionType: 'ContactChild',
            ),
            SafetyWarningModel(
              type: 'StaleLocation',
              severity: 'NeedsAttention',
              title: 'Vị trí chưa được cập nhật',
              message: 'Toạ độ GPS ghi nhận lần cuối 60 phút trước.',
              reading: '60 phút trước',
              suggestedAction: 'Gửi yêu cầu làm mới vị trí.',
              actionType: 'RefreshLocation',
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafetyAdvisorCard(
              child: testChild,
              safetyAdvisorOverride: fakeService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Both warnings co-exist on screen
      expect(find.text('Cảnh báo an toàn'), findsOneWidget);
      expect(find.text('Cảnh báo pin yếu'), findsOneWidget);
      expect(find.text('10%'), findsOneWidget);
      expect(find.text('Vị trí chưa được cập nhật'), findsOneWidget);
      expect(find.text('60 phút trước'), findsOneWidget);
      expect(find.text('Làm mới'), findsOneWidget);
      expect(find.text('Chi tiết'), findsOneWidget);
    });
  });
}

class _DelayedSafetyAdvisorService implements ISafetyAdvisorService {
  final Future<SafetyAdvisorModel> future;
  _DelayedSafetyAdvisorService(this.future);

  @override
  Future<SafetyAdvisorModel> getSafetyAdvisor({required int childId}) => future;
}

