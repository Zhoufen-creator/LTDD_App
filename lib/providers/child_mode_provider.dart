import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import '../constants/api_constants.dart';
import '../models/battery_status_model.dart';
import '../models/device_activity_event_model.dart';
import '../models/device_location_model.dart';
import '../models/device_mode_request_model.dart';
import '../models/monitoring_rule_model.dart';
import '../models/pairing_ticket_model.dart';
import '../services/activity_local_storage.dart';
import '../services/activity_service.dart';
import '../services/api_service.dart';
import '../services/app_monitoring_service.dart';
import '../services/battery_service.dart';
import '../services/device_service.dart';
import '../services/gps_service.dart';
import '../services/location_service.dart';
import '../services/rule_execution_engine.dart';

/// Cryptographically secure UUID v4 generator for device identification.
String generateSecureUuidV4() {
  final rng = Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // Version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // Variant 10
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// State management for Child Mode, Device Enrollment, Automatic Location Sync, and Battery Monitoring.
/// Maintains complete credential isolation from Parent Mode JWT sessions.
class ChildModeProvider extends ChangeNotifier {
  final DeviceService _deviceService;
  final LocationService _locationService;
  final IGpsService _gpsService;
  final IBatteryService _batteryService;
  final FlutterSecureStorage _secureStorage;
  final IAppMonitoringService _appMonitoringService;
  final ActivityLocalStorage _activityLocalStorage;
  final RuleExecutionEngine _ruleEngine;
  final ActivityService _activityService;

  String? _deviceToken;
  int? _deviceId;
  int? _childId;
  String? _childName;
  String? _deviceName;
  String? _deviceIdentifier;

  List<MonitoringRuleModel> _rules = [];
  bool _isEnrolling = false;
  bool _isLoadingRules = false;
  String? _enrollmentError;
  String? _rulesError;
  DateTime? _lastSyncTime;
  bool _isSessionLoaded = false;
  bool _isTokenRevoked = false;

  // App Monitoring & Rule Execution State
  bool _hasUsagePermission = false;
  bool _hasOverlayPermission = false;
  DateTime? _lastActivityPollTime;
  String? _currentForegroundPackage;
  RuleEvaluationResult? _lastViolation;
  int _pendingOfflineEventsCount = 0;

  // Location & Battery State
  DeviceLocationModel? _lastLocation;
  BatteryStatusModel? _batteryStatus;
  bool _isUpdatingLocation = false;
  String? _locationError;
  String? _locationSuccessMessage;

  // Automatic Background & Foreground Sync
  bool _isAutoSyncRunning = false;
  DateTime? _lastAutoSyncTime;
  Timer? _periodicSyncTimer;
  Timer? _pendingRequestPollTimer;
  StreamSubscription? _batterySubscription;
  int _lastReportedBatteryPercentage = -1;
  bool? _lastReportedIsCharging;

  // Mode Change Request State (Parent approval workflow)
  DeviceModeRequestModel? _pendingModeRequest;
  bool _isRequestingModeChange = false;
  String? _modeRequestError;

  ChildModeProvider({
    DeviceService? deviceService,
    LocationService? locationService,
    IGpsService? gpsService,
    IBatteryService? batteryService,
    FlutterSecureStorage? secureStorage,
    IAppMonitoringService? appMonitoringService,
    ActivityLocalStorage? activityLocalStorage,
    RuleExecutionEngine? ruleEngine,
    ActivityService? activityService,
  })  : _deviceService = deviceService ?? DeviceService(),
        _locationService = locationService ?? LocationService(),
        _gpsService = gpsService ?? const GeolocatorGpsService(),
        _batteryService = batteryService ?? BatteryService(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _appMonitoringService = appMonitoringService ?? const AppMonitoringService(),
        _activityLocalStorage = activityLocalStorage ?? ActivityLocalStorage(storage: secureStorage),
        _ruleEngine = ruleEngine ?? RuleExecutionEngine(),
        _activityService = activityService ?? ActivityService();

  bool get isEnrolled => _deviceToken != null && _deviceToken!.isNotEmpty && _deviceId != null;
  bool get isEnrolling => _isEnrolling;
  bool get isLoadingRules => _isLoadingRules;
  bool get isSessionLoaded => _isSessionLoaded;
  bool get isTokenRevoked => _isTokenRevoked;

  // App Monitoring & Rule Execution Getters
  bool get hasUsagePermission => _hasUsagePermission;
  bool get hasOverlayPermission => _hasOverlayPermission;
  RuleEvaluationResult? get lastViolation => _lastViolation;
  String? get currentForegroundPackage => _currentForegroundPackage;
  int get pendingOfflineEventsCount => _pendingOfflineEventsCount;
  RuleExecutionEngine get ruleEngine => _ruleEngine;

  String? get deviceToken => _deviceToken;
  int? get deviceId => _deviceId;
  int? get childId => _childId;
  String? get childName => _childName;
  String? get deviceName => _deviceName;
  String? get deviceIdentifier => _deviceIdentifier;
  List<MonitoringRuleModel> get rules => _rules;
  String? get enrollmentError => _enrollmentError;
  String? get rulesError => _rulesError;
  DateTime? get lastSyncTime => _lastSyncTime;

  // Location & Battery getters
  DeviceLocationModel? get lastLocation => _lastLocation;
  BatteryStatusModel? get batteryStatus => _batteryStatus;
  bool get isUpdatingLocation => _isUpdatingLocation;
  String? get locationError => _locationError;
  String? get locationSuccessMessage => _locationSuccessMessage;
  bool get isAutoSyncRunning => _isAutoSyncRunning;
  DateTime? get lastAutoSyncTime => _lastAutoSyncTime;

  // Mode change getters
  DeviceModeRequestModel? get pendingModeRequest => _pendingModeRequest;
  bool get isRequestingModeChange => _isRequestingModeChange;
  String? get modeRequestError => _modeRequestError;

  /// Checks local secure storage for Child Device credentials without touching Parent JWT.
  Future<void> checkChildSession({bool autoStartSync = false}) async {
    _isLoadingRules = true;
    _rulesError = null;
    notifyListeners();

    try {
      final token = await _secureStorage.read(key: ApiConstants.childDeviceTokenStorageKey);
      final devIdStr = await _secureStorage.read(key: ApiConstants.childDeviceIdStorageKey);
      final cIdStr = await _secureStorage.read(key: ApiConstants.childIdStorageKey);
      final cName = await _secureStorage.read(key: ApiConstants.childNameStorageKey);
      final dName = await _secureStorage.read(key: ApiConstants.childDeviceNameStorageKey);
      final dIdent = await _secureStorage.read(key: ApiConstants.childDeviceIdentifierStorageKey);

      if (token != null && token.isNotEmpty && devIdStr != null) {
        _deviceToken = token;
        _deviceId = int.tryParse(devIdStr);
        _childId = cIdStr != null ? int.tryParse(cIdStr) : null;
        _childName = cName;
        _deviceName = dName;
        _deviceIdentifier = dIdent;
        _isSessionLoaded = true;
        _isTokenRevoked = false;
        notifyListeners();

        // Load rules using the saved token
        await _loadCachedRules();
        await checkPermissions();
        await fetchMyRules();

        // Start automatic location & battery background/foreground sync
        if (autoStartSync) {
          startAutoSync();
        }
      } else {
        _deviceToken = null;
        _deviceId = null;
        _childId = null;
        _childName = null;
        _deviceName = null;
        _deviceIdentifier = dIdent;
        _isSessionLoaded = true;
        _isTokenRevoked = false;
        stopAutoSync();
      }
    } catch (e) {
      _rulesError = 'Lỗi khôi phục phiên thiết bị: $e';
    } finally {
      _isLoadingRules = false;
      notifyListeners();
    }
  }

  /// Enrolls the device using a QR ticket or manual pairing code.
  Future<bool> enrollDevice({
    required String rawPairingCode,
    required String deviceName,
    String? platform,
  }) async {
    if (_isEnrolling) return false;

    _isEnrolling = true;
    _enrollmentError = null;
    notifyListeners();

    try {
      final cleanCode = PairingTicketModel.extractPairingCode(rawPairingCode);
      if (cleanCode.isEmpty) {
        _enrollmentError = 'Vui lòng nhập hoặc quét mã ghép nối hợp lệ.';
        _isEnrolling = false;
        notifyListeners();
        return false;
      }

      final trimmedDeviceName = deviceName.trim().isEmpty ? 'Thiết bị của trẻ' : deviceName.trim();

      var identifier = _deviceIdentifier;
      if (identifier == null || identifier.isEmpty) {
        identifier = await _secureStorage.read(key: ApiConstants.childDeviceIdentifierStorageKey);
        if (identifier == null || identifier.isEmpty) {
          identifier = generateSecureUuidV4();
          await _secureStorage.write(
            key: ApiConstants.childDeviceIdentifierStorageKey,
            value: identifier,
          );
        }
        _deviceIdentifier = identifier;
      }

      final resolvedPlatform = platform ?? (defaultTargetPlatform == TargetPlatform.iOS ? 'iOS' : 'Android');

      final enrollment = await _deviceService.enrollChildDevice(
        pairingCode: cleanCode,
        deviceName: trimmedDeviceName,
        deviceIdentifier: identifier,
        platform: resolvedPlatform,
      );

      // Save Child credentials in secure storage
      await _secureStorage.write(
        key: ApiConstants.childDeviceTokenStorageKey,
        value: enrollment.deviceToken,
      );
      await _secureStorage.write(
        key: ApiConstants.childDeviceIdStorageKey,
        value: enrollment.deviceId.toString(),
      );
      await _secureStorage.write(
        key: ApiConstants.childIdStorageKey,
        value: enrollment.childId.toString(),
      );
      await _secureStorage.write(
        key: ApiConstants.childNameStorageKey,
        value: enrollment.childName,
      );
      await _secureStorage.write(
        key: ApiConstants.childDeviceNameStorageKey,
        value: trimmedDeviceName,
      );
      await _secureStorage.write(
        key: ApiConstants.appModeStorageKey,
        value: 'child',
      );

      _deviceToken = enrollment.deviceToken;
      _deviceId = enrollment.deviceId;
      _childId = enrollment.childId;
      _childName = enrollment.childName;
      _deviceName = trimmedDeviceName;
      _isTokenRevoked = false;
      _isSessionLoaded = true;

      _isEnrolling = false;
      notifyListeners();

      await fetchMyRules();
      startAutoSync();
      return true;
    } on ApiException catch (e) {
      _enrollmentError = e.message;
      _isEnrolling = false;
      notifyListeners();
      return false;
    } catch (e) {
      _enrollmentError = 'Lỗi kết nối máy chủ khi kích hoạt thiết bị. Vui lòng thử lại: $e';
      _isEnrolling = false;
      notifyListeners();
      return false;
    }
  }

  /// Fetches monitoring rules assigned to this child device via `GET /api/devices/my-rules`.
  Future<void> fetchMyRules() async {
    final token = _deviceToken;
    if (token == null || token.isEmpty) return;

    _isLoadingRules = true;
    _rulesError = null;
    notifyListeners();

    try {
      final fetchedRules = await _deviceService.getMyRules(childDeviceToken: token);
      _rules = fetchedRules;
      _lastSyncTime = DateTime.now();
      _isTokenRevoked = false;
      _rulesError = null;

      // Cache rules locally for offline enforcement
      try {
        final rulesJson = jsonEncode(fetchedRules.map((r) => r.toJson()).toList());
        await _secureStorage.write(key: 'child_cached_rules', value: rulesJson);
      } catch (_) {}

      // Acknowledge rules to server
      try {
        final acks = fetchedRules.map((r) => {
          'ruleId': r.id,
          'version': r.version,
          'status': _hasUsagePermission ? 'Active' : 'PermissionDenied',
          'message': _hasUsagePermission ? 'Đang hoạt động trên thiết bị' : 'Thiếu quyền Usage Access',
        }).toList();
        await _deviceService.acknowledgeRules(acks: acks, childDeviceToken: token);
      } catch (_) {}
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        _isTokenRevoked = true;
        _rulesError = 'Mã xác thực của thiết bị đã hết hạn hoặc không hợp lệ (401 Unauthorized). Vui lòng ghép nối lại thiết bị.';
      } else if (e.statusCode == 403) {
        _isTokenRevoked = false;
        _rulesError = 'Thiết bị không có quyền truy cập quy tắc giám sát này (403 Forbidden).';
      } else {
        _isTokenRevoked = false;
        _rulesError = e.message;
      }
      await _loadCachedRules();
    } catch (e) {
      _isTokenRevoked = false;
      _rulesError = 'Không thể đồng bộ quy tắc: $e';
      await _loadCachedRules();
    } finally {
      _isLoadingRules = false;
      notifyListeners();
    }
  }

  Future<void> _loadCachedRules() async {
    try {
      final cachedJson = await _secureStorage.read(key: 'child_cached_rules');
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final List<dynamic> list = jsonDecode(cachedJson);
        _rules = list
            .map((e) => MonitoringRuleModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {}
  }

  /// Starts automatic foreground/background synchronization for Location and Battery.
  void startAutoSync({Duration? interval}) {
    if (_isAutoSyncRunning) return;
    if (!isEnrolled) return;

    _isAutoSyncRunning = true;
    notifyListeners();

    // 1. Initial immediate sync
    _runPeriodicSyncTask();

    // 2. Periodic location & battery sync timer (configurable, default 2 minutes)
    final syncDuration = interval ?? ApiConstants.foregroundSyncInterval;
    _periodicSyncTimer = Timer.periodic(syncDuration, (_) {
      _runPeriodicSyncTask();
    });

    // 3. Poll for Parent-Requested Location Refresh commands (every 30 seconds)
    _pendingRequestPollTimer = Timer.periodic(ApiConstants.pendingRequestPollInterval, (_) {
      checkAndHandlePendingRefreshRequests();
    });

    // 4. Listen for charging state changes
    try {
      _batterySubscription = _batteryService.onBatteryStateChanged.listen((_) {
        syncBatteryStatus();
      });
    } catch (_) {
      // Platform without battery events supported gracefully
    }
  }

  /// Stops automatic periodic synchronization.
  void stopAutoSync() {
    _isAutoSyncRunning = false;
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
    _pendingRequestPollTimer?.cancel();
    _pendingRequestPollTimer = null;
    _batterySubscription?.cancel();
    _batterySubscription = null;
    notifyListeners();
  }

  /// Internal handler executing a single periodic synchronization cycle.
  Future<void> _runPeriodicSyncTask() async {
    if (!isEnrolled || _isTokenRevoked) return;
    await syncBatteryStatus();
    await updateAndSendLocation(isSilent: true);
    await checkAndHandlePendingRefreshRequests();
    await checkAndEnforceAppActivities();
    await syncOfflineActivityQueue();
    _lastAutoSyncTime = DateTime.now();
    notifyListeners();
  }

  /// Verifies Android Usage Access and Overlay permissions.
  Future<void> checkPermissions() async {
    final usage = await _appMonitoringService.checkUsagePermission();
    final overlay = await _appMonitoringService.checkOverlayPermission();
    if (usage != _hasUsagePermission || overlay != _hasOverlayPermission) {
      _hasUsagePermission = usage;
      _hasOverlayPermission = overlay;
      notifyListeners();
    }
  }

  Future<void> requestUsageAccess() async {
    await _appMonitoringService.openUsageSettings();
    await checkPermissions();
  }

  Future<void> requestOverlayPermission() async {
    await _appMonitoringService.openOverlaySettings();
    await checkPermissions();
  }

  void clearViolation() {
    _lastViolation = null;
    notifyListeners();
  }

  /// Queries native UsageStatsManager events, records activity sessions, and enforces rules.
  Future<void> checkAndEnforceAppActivities() async {
    final token = _deviceToken;
    if (token == null || token.isEmpty || _isTokenRevoked) return;

    _hasUsagePermission = await _appMonitoringService.checkUsagePermission();
    _hasOverlayPermission = await _appMonitoringService.checkOverlayPermission();

    if (!_hasUsagePermission) {
      return;
    }

    final now = DateTime.now();
    final startTime = _lastActivityPollTime ?? now.subtract(const Duration(minutes: 5));
    _lastActivityPollTime = now;

    try {
      final rawEvents = await _appMonitoringService.queryUsageEvents(
        startTime: startTime,
        endTime: now,
      );

      final eventsToQueue = <DeviceActivityEventModel>[];
      String? latestForegroundPkg;
      String? latestForegroundApp;

      for (final ev in rawEvents) {
        final evType = ev['eventType']?.toString() ?? '';
        final pkg = ev['packageName']?.toString() ?? '';
        final app = ev['appName']?.toString() ?? pkg;
        final tsMs = ev['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch;
        final eventTime = DateTime.fromMillisecondsSinceEpoch(tsMs, isUtc: true);

        if (evType == 'SCREEN_INTERACTIVE') {
          eventsToQueue.add(DeviceActivityEventModel.create(
            eventType: 'ScreenOn',
            recordedAt: eventTime,
          ));
        } else if (evType == 'SCREEN_NON_INTERACTIVE') {
          eventsToQueue.add(DeviceActivityEventModel.create(
            eventType: 'ScreenOff',
            recordedAt: eventTime,
          ));
        } else if (evType == 'KEYGUARD_SHOWN') {
          eventsToQueue.add(DeviceActivityEventModel.create(
            eventType: 'DeviceLocked',
            recordedAt: eventTime,
          ));
        } else if (evType == 'KEYGUARD_HIDDEN') {
          eventsToQueue.add(DeviceActivityEventModel.create(
            eventType: 'DeviceUnlocked',
            recordedAt: eventTime,
          ));
        } else if (evType == 'ACTIVITY_RESUMED') {
          if (pkg.isNotEmpty && pkg != 'com.example.tran_nguyen_vi_khang_app') {
            latestForegroundPkg = pkg;
            latestForegroundApp = app;
          }
        } else if (evType == 'ACTIVITY_PAUSED') {
          if (pkg.isNotEmpty && pkg != 'com.example.tran_nguyen_vi_khang_app') {
            const durationSec = 30;
            _ruleEngine.recordAppUsage(pkg, durationSec);
            eventsToQueue.add(DeviceActivityEventModel.create(
              eventType: 'AppSession',
              packageName: pkg,
              appName: app,
              durationSeconds: durationSec,
              recordedAt: eventTime,
            ));
          }
        }
      }

      if (eventsToQueue.isNotEmpty) {
        await _activityLocalStorage.enqueueBatch(eventsToQueue);
      }

      // Check foreground app against parental monitoring rules
      if (latestForegroundPkg != null) {
        _currentForegroundPackage = latestForegroundPkg;
        final evalResult = _ruleEngine.evaluateForegroundApp(
          packageName: latestForegroundPkg,
          rules: _rules,
        );

        if (evalResult.isBlocked) {
          _lastViolation = evalResult;
          final violationEv = _ruleEngine.createViolationEvent(
            result: evalResult,
            packageName: latestForegroundPkg,
            appName: latestForegroundApp,
          );
          await _activityLocalStorage.enqueue(violationEv);

          // Enforce block by redirecting to Home screen or bringing Parental Control app to front
          await _appMonitoringService.goToHomeScreen();
          await _appMonitoringService.bringAppToFront();
        }
      }

      final unsynced = await _activityLocalStorage.getUnsyncedEvents();
      _pendingOfflineEventsCount = unsynced.length;
    } catch (_) {
      // Activity monitoring error handled silently in background
    }
  }

  /// Flushes queued offline activity events to the backend with deduplication.
  Future<void> syncOfflineActivityQueue() async {
    final token = _deviceToken;
    if (token == null || token.isEmpty || _isTokenRevoked) return;

    try {
      final unsynced = await _activityLocalStorage.getUnsyncedEvents(limit: 50);
      if (unsynced.isEmpty) {
        _pendingOfflineEventsCount = 0;
        return;
      }

      final response = await _activityService.syncBatchActivities(
        events: unsynced,
        childDeviceToken: token,
      );

      final syncedIds = (response['syncedClientEventIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];

      if (syncedIds.isNotEmpty) {
        await _activityLocalStorage.markEventsSynced(syncedIds);
      } else if (response['syncedCount'] != null) {
        await _activityLocalStorage.markEventsSynced(unsynced.map((e) => e.clientEventId).toList());
      }

      await _activityLocalStorage.pruneOldSyncedEvents();
      final remaining = await _activityLocalStorage.getUnsyncedEvents();
      _pendingOfflineEventsCount = remaining.length;
    } catch (_) {
      // Offline queue will retry on next periodic sync
    }
  }

  /// Reads battery status and uploads to server if level changed by >= 5% or charging state changed.
  Future<void> syncBatteryStatus({bool force = false}) async {
    final token = _deviceToken;
    if (token == null || token.isEmpty || _isTokenRevoked) return;

    try {
      final status = await _batteryService.getBatteryStatus();
      _batteryStatus = status;

      final levelDiff = (_lastReportedBatteryPercentage - status.percentage).abs();
      final chargingChanged = _lastReportedIsCharging != status.isCharging;

      if (force || _lastReportedBatteryPercentage < 0 || levelDiff >= 5 || chargingChanged) {
        await _deviceService.updateBatteryStatus(
          percentage: status.percentage,
          isCharging: status.isCharging,
          childDeviceToken: token,
        );
        _lastReportedBatteryPercentage = status.percentage;
        _lastReportedIsCharging = status.isCharging;
      }
    } catch (_) {
      // Battery sync is non-blocking and silent
    }
  }

  /// Checks if parent requested a fresh location via `GET /api/locations/refresh-requests/pending`.
  /// If a pending request is found, acquires high-accuracy GPS coordinates and submits completion.
  Future<void> checkAndHandlePendingRefreshRequests() async {
    final token = _deviceToken;
    if (token == null || token.isEmpty || _isTokenRevoked) return;

    try {
      final request = await _locationService.getPendingRefreshRequest(childDeviceToken: token);
      if (request == null) return;

      // Pending request exists! Fulfill it with fresh high-accuracy GPS position
      final isServiceEnabled = await _gpsService.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        await _locationService.completeRefreshRequest(
          requestId: request.id,
          isSuccess: false,
          failureReason: 'GPS trên thiết bị đang tắt.',
          childDeviceToken: token,
        );
        return;
      }

      final permission = await _gpsService.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        await _locationService.completeRefreshRequest(
          requestId: request.id,
          isSuccess: false,
          failureReason: 'Quyền truy cập vị trí chưa được cấp.',
          childDeviceToken: token,
        );
        return;
      }

      final position = await _gpsService.getCurrentPosition();
      final battery = await _batteryService.getBatteryStatus();

      await _locationService.completeRefreshRequest(
        requestId: request.id,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        recordedAt: position.timestamp,
        batteryPercentage: battery.percentage,
        isCharging: battery.isCharging,
        isSuccess: true,
        childDeviceToken: token,
      );

      _lastLocation = DeviceLocationModel(
        id: request.id,
        deviceId: _deviceId ?? 0,
        deviceName: _deviceName ?? '',
        childId: _childId ?? 0,
        childName: _childName ?? '',
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        recordedAt: position.timestamp,
        createdAt: DateTime.now().toUtc(),
      );
      _batteryStatus = battery;
      notifyListeners();
    } catch (_) {
      // Silent catch for periodic polling
    }
  }

  /// Captures current GPS coordinates and synchronizes them to `POST /api/locations`
  /// using the Child Device JWT. Includes latest battery observation if available.
  Future<bool> updateAndSendLocation({
    IGpsService? gpsServiceOverride,
    bool isSilent = false,
  }) async {
    if (_isUpdatingLocation) return false;

    _isUpdatingLocation = true;
    if (!isSilent) {
      _locationError = null;
      _locationSuccessMessage = null;
    }
    notifyListeners();

    final token = _deviceToken;
    if (token == null || token.isEmpty) {
      _locationError = 'Thiết bị chưa được ghép nối hoặc không có mã xác thực.';
      _isUpdatingLocation = false;
      notifyListeners();
      return false;
    }

    final gps = gpsServiceOverride ?? _gpsService;

    try {
      final isServiceEnabled = await gps.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        _locationError = 'Dịch vụ định vị (GPS) trên thiết bị đang tắt. Vui lòng bật GPS trong cài đặt hệ thống.';
        _isUpdatingLocation = false;
        notifyListeners();
        return false;
      }

      var permission = await gps.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await gps.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _locationError = 'Quyền truy cập vị trí bị từ chối. Vui lòng cấp quyền để cập nhật vị trí.';
        _isUpdatingLocation = false;
        notifyListeners();
        return false;
      }

      if (permission == LocationPermission.deniedForever) {
        _locationError = 'Quyền truy cập vị trí bị từ chối vĩnh viễn. Vui lòng mở Cài đặt ứng dụng để cấp quyền vị trí.';
        _isUpdatingLocation = false;
        notifyListeners();
        return false;
      }

      final position = await gps.getCurrentPosition();

      // Read battery status to send together
      try {
        _batteryStatus = await _batteryService.getBatteryStatus();
      } catch (_) {}

      final recorded = await _locationService.recordLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        recordedAt: position.timestamp,
        batteryPercentage: _batteryStatus?.percentage,
        isCharging: _batteryStatus?.isCharging,
        childDeviceToken: token,
      );

      _lastLocation = recorded;
      _locationSuccessMessage = 'Đã cập nhật vị trí thành công (${recorded.accuracyFormatted})';
      _locationError = null;
      _isTokenRevoked = false;
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        _isTokenRevoked = true;
        _locationError = 'Mã xác thực của thiết bị đã hết hạn hoặc bị thu hồi (401 Unauthorized). Vui lòng ghép nối lại thiết bị.';
        stopAutoSync();
      } else if (e.statusCode == 403) {
        _isTokenRevoked = false;
        _locationError = 'Thiết bị không có quyền gửi dữ liệu vị trí (403 Forbidden).';
      } else {
        _isTokenRevoked = false;
        _locationError = e.message;
      }
      return false;
    } on TimeoutException {
      _isTokenRevoked = false;
      _locationError = 'Lấy vị trí GPS bị quá hạn (Timeout). Vui lòng di chuyển ra nơi thông thoáng và thử lại.';
      return false;
    } catch (e) {
      _isTokenRevoked = false;
      _locationError = 'Không thể lấy hoặc gửi vị trí: $e';
      return false;
    } finally {
      _isUpdatingLocation = false;
      notifyListeners();
    }
  }

  /// Opens the device app settings screen when location permissions are permanently denied.
  Future<bool> openAppSettingsScreen() async {
    return await _gpsService.openAppSettings();
  }

  /// Submits a request to change mode (e.g. Switch to Parent or Unlink) to the backend.
  Future<DeviceModeRequestModel?> requestModeChange({
    required String targetMode,
    String? reason,
  }) async {
    final token = _deviceToken;
    if (token == null || token.isEmpty) {
      _modeRequestError = 'Thiết bị chưa được xác thực.';
      notifyListeners();
      return null;
    }

    _isRequestingModeChange = true;
    _modeRequestError = null;
    notifyListeners();

    try {
      final req = await _deviceService.createModeRequest(
        targetMode: targetMode,
        reason: reason,
        childDeviceToken: token,
      );
      _pendingModeRequest = req;
      _isRequestingModeChange = false;
      notifyListeners();
      return req;
    } on ApiException catch (e) {
      _modeRequestError = e.message;
      _isRequestingModeChange = false;
      notifyListeners();
      return null;
    } catch (e) {
      _modeRequestError = 'Không thể gửi yêu cầu: $e';
      _isRequestingModeChange = false;
      notifyListeners();
      return null;
    }
  }

  /// Polls the active pending mode request status for this device.
  Future<DeviceModeRequestModel?> checkPendingModeRequestStatus() async {
    final token = _deviceToken;
    if (token == null || token.isEmpty) return null;

    try {
      final req = await _deviceService.getPendingModeRequestForDevice(childDeviceToken: token);
      _pendingModeRequest = req;
      notifyListeners();
      return req;
    } catch (_) {
      return _pendingModeRequest;
    }
  }

  /// Executes an approved mode change using the approval token.
  Future<bool> executeApprovedModeChange({
    required int requestId,
    required String approvalToken,
  }) async {
    final token = _deviceToken;
    if (token == null || token.isEmpty) return false;

    try {
      final success = await _deviceService.executeModeChange(
        requestId: requestId,
        approvalToken: approvalToken,
        childDeviceToken: token,
      );
      if (success) {
        _pendingModeRequest = null;
        notifyListeners();
      }
      return success;
    } on ApiException catch (e) {
      _modeRequestError = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _modeRequestError = 'Lỗi thực thi đổi chế độ: $e';
      notifyListeners();
      return false;
    }
  }

  /// Directly verifies parent credentials on child device for immediate unlock/unlink.
  Future<bool> directParentUnlock({
    required String email,
    required String password,
    String targetMode = 'ParentMode',
  }) async {
    final token = _deviceToken;
    if (token == null || token.isEmpty) {
      _modeRequestError = 'Thiết bị chưa được xác thực.';
      notifyListeners();
      return false;
    }

    _isRequestingModeChange = true;
    _modeRequestError = null;
    notifyListeners();

    try {
      await _deviceService.directParentUnlock(
        email: email,
        password: password,
        targetMode: targetMode,
        childDeviceToken: token,
      );
      _pendingModeRequest = null;
      _isRequestingModeChange = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _modeRequestError = e.message;
      _isRequestingModeChange = false;
      notifyListeners();
      return false;
    } catch (e) {
      _modeRequestError = 'Xác thực mật khẩu thất bại: $e';
      _isRequestingModeChange = false;
      notifyListeners();
      return false;
    }
  }

  void clearModeRequestError() {
    _modeRequestError = null;
    notifyListeners();
  }

  /// Clears only Child Mode session keys from storage.
  /// Preserves Parent JWT and system settings.
  Future<void> clearChildSession() async {
    stopAutoSync();
    await _secureStorage.delete(key: ApiConstants.childDeviceTokenStorageKey);
    await _secureStorage.delete(key: ApiConstants.childDeviceIdStorageKey);
    await _secureStorage.delete(key: ApiConstants.childIdStorageKey);
    await _secureStorage.delete(key: ApiConstants.childNameStorageKey);
    await _secureStorage.delete(key: ApiConstants.childDeviceNameStorageKey);

    _deviceToken = null;
    _deviceId = null;
    _childId = null;
    _childName = null;
    _deviceName = null;
    _pendingModeRequest = null;
    _modeRequestError = null;
    _rules = [];
    _isTokenRevoked = false;
    _rulesError = null;
    _enrollmentError = null;
    _lastLocation = null;
    _batteryStatus = null;
    _locationError = null;
    _locationSuccessMessage = null;
    _isUpdatingLocation = false;
    notifyListeners();
  }

  bool _isDisposed = false;

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    stopAutoSync();
    super.dispose();
  }
}
