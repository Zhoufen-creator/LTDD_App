/// Model representing a parent-initiated location-refresh request.
/// Matches `LocationRefreshRequestResponseDto` from ASP.NET Core backend.
class LocationRefreshRequestModel {
  final int id;
  final int childId;
  final String childName;
  final int deviceId;
  final String deviceName;
  final String status;
  final DateTime requestedAt;
  final DateTime expiresAt;
  final DateTime? completedAt;
  final String? failureReason;

  const LocationRefreshRequestModel({
    required this.id,
    required this.childId,
    required this.childName,
    required this.deviceId,
    required this.deviceName,
    required this.status,
    required this.requestedAt,
    required this.expiresAt,
    this.completedAt,
    this.failureReason,
  });

  factory LocationRefreshRequestModel.fromJson(Map<String, dynamic> json) {
    return LocationRefreshRequestModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      childId: json['childId'] is int ? json['childId'] as int : int.tryParse(json['childId']?.toString() ?? '') ?? 0,
      childName: json['childName']?.toString() ?? '',
      deviceId: json['deviceId'] is int ? json['deviceId'] as int : int.tryParse(json['deviceId']?.toString() ?? '') ?? 0,
      deviceName: json['deviceName']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Pending',
      requestedAt: json['requestedAt'] != null
          ? (DateTime.tryParse(json['requestedAt'].toString())?.toUtc() ?? DateTime.now().toUtc())
          : DateTime.now().toUtc(),
      expiresAt: json['expiresAt'] != null
          ? (DateTime.tryParse(json['expiresAt'].toString())?.toUtc() ?? DateTime.now().toUtc())
          : DateTime.now().toUtc(),
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'].toString())?.toUtc()
          : null,
      failureReason: json['failureReason']?.toString(),
    );
  }

  bool get isPending => status == 'Pending';
  bool get isProcessing => status == 'Processing';
  bool get isCompleted => status == 'Completed';
  bool get isFailed => status == 'Failed';
  bool get isExpired => status == 'Expired';

  /// Truthful and clear human-readable status for Parent UI.
  String get statusLabelVi {
    switch (status) {
      case 'Pending':
        return 'Đang chờ thiết bị phản hồi';
      case 'Processing':
        return 'Thiết bị đang lấy vị trí GPS...';
      case 'Completed':
        return 'Đã cập nhật vị trí mới';
      case 'Failed':
        return failureReason != null && failureReason!.isNotEmpty
            ? 'Không thể lấy vị trí: $failureReason'
            : 'Không thể lấy vị trí';
      case 'Expired':
        return 'Yêu cầu đã hết hạn (thiết bị offline)';
      default:
        return status;
    }
  }
}

