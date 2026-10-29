/// Representation of a GPS location record synchronized between a Child Device and Backend.
/// Matches backend `DeviceLocationResponseDto` from ASP.NET Core API.
class DeviceLocationModel {
  final int id;
  final int deviceId;
  final String deviceName;
  final int childId;
  final String childName;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final String eventType;
  final double? displacementMeters;
  final DateTime recordedAt;
  final DateTime createdAt;

  const DeviceLocationModel({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.childId,
    required this.childName,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.eventType = 'Periodic',
    this.displacementMeters,
    required this.recordedAt,
    required this.createdAt,
  });

  /// Safely parses backend JSON response into [DeviceLocationModel].
  /// Returns null if [json] is null or not a Map.
  static DeviceLocationModel? fromJson(dynamic json) {
    if (json == null || json is! Map<String, dynamic>) {
      return null;
    }

    final id = json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '') ?? 0;
    final deviceId = json['deviceId'] is int
        ? json['deviceId'] as int
        : int.tryParse(json['deviceId']?.toString() ?? '') ?? 0;
    final childId = json['childId'] is int
        ? json['childId'] as int
        : int.tryParse(json['childId']?.toString() ?? '') ?? 0;

    final latRaw = json['latitude'];
    final double latitude = latRaw is num ? latRaw.toDouble() : double.tryParse(latRaw?.toString() ?? '') ?? 0.0;

    final lngRaw = json['longitude'];
    final double longitude = lngRaw is num ? lngRaw.toDouble() : double.tryParse(lngRaw?.toString() ?? '') ?? 0.0;

    final accRaw = json['accuracy'];
    final double? accuracy = accRaw != null
        ? (accRaw is num ? accRaw.toDouble() : double.tryParse(accRaw.toString()))
        : null;

    final eventType = json['eventType']?.toString() ?? 'Periodic';

    final dispRaw = json['displacementMeters'];
    final double? displacementMeters = dispRaw != null
        ? (dispRaw is num ? dispRaw.toDouble() : double.tryParse(dispRaw.toString()))
        : null;

    final recordedAtRaw = json['recordedAt']?.toString();
    final DateTime recordedAt = recordedAtRaw != null
        ? (DateTime.tryParse(recordedAtRaw)?.toUtc() ?? DateTime.now().toUtc())
        : DateTime.now().toUtc();

    final createdAtRaw = json['createdAt']?.toString();
    final DateTime createdAt = createdAtRaw != null
        ? (DateTime.tryParse(createdAtRaw)?.toUtc() ?? DateTime.now().toUtc())
        : DateTime.now().toUtc();

    return DeviceLocationModel(
      id: id,
      deviceId: deviceId,
      deviceName: json['deviceName']?.toString() ?? '',
      childId: childId,
      childName: json['childName']?.toString() ?? '',
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      eventType: eventType,
      displacementMeters: displacementMeters,
      recordedAt: recordedAt,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'childId': childId,
      'childName': childName,
      'latitude': latitude,
      'longitude': longitude,
      if (accuracy != null) 'accuracy': accuracy,
      'eventType': eventType,
      if (displacementMeters != null) 'displacementMeters': displacementMeters,
      'recordedAt': recordedAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Event type in Vietnamese for clear UI badges.
  String get eventTypeFormatted {
    switch (eventType) {
      case 'SignificantMovement':
        return 'Sự kiện di chuyển';
      case 'ManualRefresh':
        return 'Phụ huynh làm mới';
      case 'Periodic':
      default:
        return 'Định kỳ';
    }
  }

  /// Displacement distance formatted with meter or kilometer.
  String get displacementFormatted {
    if (displacementMeters == null || displacementMeters! <= 0) return '0 m';
    if (displacementMeters! >= 1000) {
      return '${(displacementMeters! / 1000).toStringAsFixed(1)} km';
    }
    return '${displacementMeters!.toStringAsFixed(0)} m';
  }

  bool get isSignificantMovement => eventType == 'SignificantMovement';
  bool get isManualRefresh => eventType == 'ManualRefresh';

  /// Formatted coordinates string, e.g. "10.762622, 106.660172".
  String get coordinatesFormatted =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

  /// Accuracy formatted with meter unit or unknown indicator.
  String get accuracyFormatted =>
      accuracy != null ? '±${accuracy!.toStringAsFixed(1)} m' : 'Không xác định';

  /// Checks if location data is considered stale (> 1 hour old).
  bool get isStale {
    final diff = DateTime.now().toUtc().difference(recordedAt.toUtc());
    return diff.inMinutes >= 60;
  }

  /// Human-friendly relative time string (e.g. "Vừa xong", "15 phút trước", "2 giờ trước").
  String get relativeTimeFormatted {
    final now = DateTime.now().toUtc();
    final diff = now.difference(recordedAt.toUtc());

    if (diff.isNegative || diff.inSeconds < 45) {
      return 'Vừa xong';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} phút trước';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} giờ trước';
    } else {
      return '${diff.inDays} ngày trước';
    }
  }

  /// Formatted timestamp in local device time zone (HH:mm:ss - dd/MM/yyyy).
  String get localTimestampFormatted {
    final local = recordedAt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    final s = local.second.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    return '$h:$m:$s - $day/$month/$year';
  }

  /// External Google Maps query URL.
  String get googleMapsUrl =>
      'https://maps.google.com/?q=$latitude,$longitude';
}

