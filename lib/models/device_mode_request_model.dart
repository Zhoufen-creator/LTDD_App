/// Model representing a request to switch modes or unlink an enrolled child device.
/// Matches backend `DeviceModeRequestResponseDto` from ASP.NET Core API.
class DeviceModeRequestModel {
  final int id;
  final int deviceId;
  final String deviceName;
  final int childId;
  final String childName;
  final String targetMode;
  final String? reason;
  final String status;
  final String? approvalToken;
  final DateTime requestedAt;
  final DateTime expiresAt;
  final DateTime? reviewedAt;
  final String? reviewedByName;
  final DateTime? executedAt;

  const DeviceModeRequestModel({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.childId,
    required this.childName,
    required this.targetMode,
    this.reason,
    required this.status,
    this.approvalToken,
    required this.requestedAt,
    required this.expiresAt,
    this.reviewedAt,
    this.reviewedByName,
    this.executedAt,
  });

  bool get isPending => status == 'Pending';
  bool get isApproved => status == 'Approved';
  bool get isRejected => status == 'Rejected';
  bool get isExpired => status == 'Expired';
  bool get isExecuted => status == 'Executed';
  bool get isUnlink => targetMode == 'Unlink';

  String get targetModeLabelVi {
    switch (targetMode) {
      case 'Unlink':
        return 'Hủy liên kết thiết bị';
      case 'ParentMode':
      default:
        return 'Chuyển sang Chế độ Phụ huynh';
    }
  }

  String get statusLabelVi {
    switch (status) {
      case 'Pending':
        return 'Đang chờ phụ huynh duyệt';
      case 'Approved':
        return 'Phụ huynh đã phê duyệt';
      case 'Rejected':
        return 'Phụ huynh đã từ chối';
      case 'Expired':
        return 'Yêu cầu đã hết hạn';
      case 'Executed':
        return 'Đã hoàn tất';
      default:
        return status;
    }
  }

  static DeviceModeRequestModel? fromJson(dynamic json) {
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

    final reqAt = json['requestedAt']?.toString();
    final requestedAt = reqAt != null
        ? (DateTime.tryParse(reqAt)?.toUtc() ?? DateTime.now().toUtc())
        : DateTime.now().toUtc();

    final expAt = json['expiresAt']?.toString();
    final expiresAt = expAt != null
        ? (DateTime.tryParse(expAt)?.toUtc() ?? DateTime.now().toUtc())
        : DateTime.now().toUtc();

    final revAt = json['reviewedAt']?.toString();
    final reviewedAt = revAt != null ? DateTime.tryParse(revAt)?.toUtc() : null;

    final execAt = json['executedAt']?.toString();
    final executedAt = execAt != null ? DateTime.tryParse(execAt)?.toUtc() : null;

    return DeviceModeRequestModel(
      id: id,
      deviceId: deviceId,
      deviceName: json['deviceName']?.toString() ?? '',
      childId: childId,
      childName: json['childName']?.toString() ?? '',
      targetMode: json['targetMode']?.toString() ?? 'ParentMode',
      reason: json['reason']?.toString(),
      status: json['status']?.toString() ?? 'Pending',
      approvalToken: json['approvalToken']?.toString(),
      requestedAt: requestedAt,
      expiresAt: expiresAt,
      reviewedAt: reviewedAt,
      reviewedByName: json['reviewedByName']?.toString(),
      executedAt: executedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'childId': childId,
      'childName': childName,
      'targetMode': targetMode,
      'reason': reason,
      'status': status,
      if (approvalToken != null) 'approvalToken': approvalToken,
      'requestedAt': requestedAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      if (reviewedAt != null) 'reviewedAt': reviewedAt!.toIso8601String(),
      if (reviewedByName != null) 'reviewedByName': reviewedByName,
      if (executedAt != null) 'executedAt': executedAt!.toIso8601String(),
    };
  }
}

