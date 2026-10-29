import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/device_activity_event_model.dart';

class ActivityLocalStorage {
  static const String _queueKey = 'child_offline_activity_queue';
  final FlutterSecureStorage _storage;

  ActivityLocalStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<List<DeviceActivityEventModel>> _readAll() async {
    try {
      final jsonStr = await _storage.read(key: _queueKey);
      if (jsonStr == null || jsonStr.isEmpty) return [];
      final List<dynamic> list = jsonDecode(jsonStr);
      return list
          .map((e) => DeviceActivityEventModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeAll(List<DeviceActivityEventModel> events) async {
    try {
      final jsonStr = jsonEncode(events.map((e) => e.toJson()).toList());
      await _storage.write(key: _queueKey, value: jsonStr);
    } catch (_) {
      // Storage write error handled gracefully
    }
  }

  /// Adds a new activity event to the offline storage queue.
  Future<void> enqueue(DeviceActivityEventModel event) async {
    final list = await _readAll();
    list.add(event);
    await _writeAll(list);
  }

  /// Adds multiple events to the queue in one write operation.
  Future<void> enqueueBatch(List<DeviceActivityEventModel> events) async {
    if (events.isEmpty) return;
    final list = await _readAll();
    list.addAll(events);
    await _writeAll(list);
  }

  /// Retrieves events that have not yet been synchronized to the backend.
  Future<List<DeviceActivityEventModel>> getUnsyncedEvents({int limit = 100}) async {
    final list = await _readAll();
    return list.where((e) => !e.isSynced).take(limit).toList();
  }

  /// Marks a list of client event IDs as successfully synchronized.
  Future<void> markEventsSynced(List<String> clientEventIds) async {
    if (clientEventIds.isEmpty) return;
    final idSet = clientEventIds.toSet();
    final list = await _readAll();
    final updated = list.map((e) {
      if (idSet.contains(e.clientEventId)) {
        return e.copyWith(isSynced: true);
      }
      return e;
    }).toList();
    await _writeAll(updated);
  }

  /// Prunes old synchronized events to avoid unlimited local storage growth.
  Future<void> pruneOldSyncedEvents({Duration maxAge = const Duration(days: 3)}) async {
    final threshold = DateTime.now().toUtc().subtract(maxAge);
    final list = await _readAll();
    final retained = list.where((e) {
      if (!e.isSynced) return true; // Never delete unsynced events
      return e.recordedAt.isAfter(threshold);
    }).toList();
    await _writeAll(retained);
  }

  Future<void> clearAll() async {
    await _storage.delete(key: _queueKey);
  }
}

