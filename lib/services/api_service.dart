import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';

/// Custom exception thrown when backend returns a non-2xx HTTP status.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final dynamic details;

  const ApiException({
    required this.statusCode,
    required this.message,
    this.details,
  });

  @override
  String toString() => message;
}

/// Centralized HTTP Service with JWT Bearer injection and standard error parsing.
class ApiService {
  final http.Client _client;
  final Future<String?> Function()? _tokenGetter;
  final void Function()? _onUnauthorized;

  ApiService({
    http.Client? client,
    Future<String?> Function()? tokenGetter,
    void Function()? onUnauthorized,
  })  : _client = client ?? http.Client(),
        // ignore: prefer_initializing_formals
        _tokenGetter = tokenGetter,
        // ignore: prefer_initializing_formals
        _onUnauthorized = onUnauthorized;

  /// Builds standardized headers with optional Authorization bearer token.
  Future<Map<String, String>> _buildHeaders({bool requiresAuth = true, String? overrideToken}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (overrideToken != null) {
      if (overrideToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $overrideToken';
      }
      return headers;
    }

    final tokenGetter = _tokenGetter;
    if (requiresAuth && tokenGetter != null) {
      final token = await tokenGetter();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  /// Constructs a normalized URI by joining Base URL and endpoint safely.
  /// Guarantees single `/` separator between host and path.
  static Uri buildUri(String endpoint) {
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    return Uri.parse('${ApiConstants.baseUrl}$cleanEndpoint');
  }

  /// Executes HTTP GET request.
  Future<dynamic> get(String endpoint, {bool requiresAuth = true, String? overrideToken}) async {
    return _sendRequest(() async {
      final uri = buildUri(endpoint);
      final headers = await _buildHeaders(requiresAuth: requiresAuth, overrideToken: overrideToken);
      return await _client.get(uri, headers: headers).timeout(const Duration(seconds: 15));
    });
  }

  /// Executes HTTP POST request with JSON payload.
  Future<dynamic> post(String endpoint, {dynamic body, bool requiresAuth = true, String? overrideToken}) async {
    return _sendRequest(() async {
      final uri = buildUri(endpoint);
      final headers = await _buildHeaders(requiresAuth: requiresAuth, overrideToken: overrideToken);
      return await _client
          .post(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
          .timeout(const Duration(seconds: 15));
    });
  }

  /// Executes HTTP PUT request with JSON payload.
  Future<dynamic> put(String endpoint, {dynamic body, bool requiresAuth = true, String? overrideToken}) async {
    return _sendRequest(() async {
      final uri = buildUri(endpoint);
      final headers = await _buildHeaders(requiresAuth: requiresAuth, overrideToken: overrideToken);
      return await _client
          .put(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
          .timeout(const Duration(seconds: 15));
    });
  }

  /// Executes HTTP DELETE request.
  Future<dynamic> delete(String endpoint, {bool requiresAuth = true, String? overrideToken}) async {
    return _sendRequest(() async {
      final uri = buildUri(endpoint);
      final headers = await _buildHeaders(requiresAuth: requiresAuth, overrideToken: overrideToken);
      return await _client.delete(uri, headers: headers).timeout(const Duration(seconds: 15));
    });
  }

  /// Internal wrapper handling HTTP responses, network timeouts, and status codes.
  Future<dynamic> _sendRequest(Future<http.Response> Function() requestFn) async {
    try {
      final response = await requestFn();
      return _processResponse(response);
    } on SocketException catch (e) {
      throw ApiException(
        statusCode: 0,
        message: 'Không thể kết nối đến máy chủ backend tại ${ApiConstants.baseUrl}. '
            'Vui lòng kiểm tra kết nối mạng hoặc đảm bảo backend đang chạy.',
        details: e.message,
      );
    } on TimeoutException {
      throw const ApiException(
        statusCode: 408,
        message: 'Kết nối mạng bị quá hạn (Timeout). Vui lòng thử lại sau.',
      );
    } on FormatException catch (e) {
      throw ApiException(
        statusCode: 0,
        message: 'Dữ liệu máy chủ trả về không đúng định dạng JSON.',
        details: e.message,
      );
    }
  }

  /// Parses HTTP response status code and extracts error message if status is not 2xx.
  dynamic _processResponse(http.Response response) {
    final statusCode = response.statusCode;

    // Handle 204 No Content
    if (statusCode == 204 || response.body.isEmpty) {
      return null;
    }

    dynamic decodedJson;
    try {
      decodedJson = jsonDecode(response.body);
    } catch (_) {
      decodedJson = null;
    }

    if (statusCode >= 200 && statusCode < 300) {
      return decodedJson;
    }

    // Extract message from JSON payload (e.g. {"message": "..."})
    String message = '';
    if (decodedJson is Map<String, dynamic> && decodedJson.containsKey('message')) {
      message = decodedJson['message']?.toString() ?? '';
    }

    if (message.isEmpty) {
      switch (statusCode) {
        case 400:
          message = 'Dữ liệu gửi lên không hợp lệ (400 Bad Request).';
          break;
        case 401:
          message = 'Phiên làm việc đã hết hạn hoặc không có quyền truy cập (401 Unauthorized).';
          break;
        case 403:
          message = 'Bạn không có quyền thực hiện thao tác này (403 Forbidden).';
          break;
        case 404:
          message = 'Tài nguyên yêu cầu không tồn tại (404 Not Found).';
          break;
        case 500:
          message = 'Máy chủ backend gặp lỗi xử lý nội bộ (500 Internal Server Error).';
          break;
        default:
          message = 'Yêu cầu thất bại với mã lỗi HTTP $statusCode.';
          break;
      }
    }

    // On 401 Unauthorized, notify once without creating an infinite loop
    if (statusCode == 401) {
      _onUnauthorized?.call();
    }

    throw ApiException(
      statusCode: statusCode,
      message: message,
      details: decodedJson,
    );
  }
}
