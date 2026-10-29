/// Model representing successful Child Device Enrollment.
/// Mirrors `EnrollmentResponseDto` from ASP.NET Core backend.
class ChildEnrollmentModel {
  final String deviceToken;
  final int deviceId;
  final int childId;
  final String childName;
  final DateTime expiresAt;

  const ChildEnrollmentModel({
    required this.deviceToken,
    required this.deviceId,
    required this.childId,
    required this.childName,
    required this.expiresAt,
  });

  factory ChildEnrollmentModel.fromJson(Map<String, dynamic> json) {
    return ChildEnrollmentModel(
      deviceToken: json['deviceToken'] as String? ?? '',
      deviceId: json['deviceId'] as int? ?? 0,
      childId: json['childId'] as int? ?? 0,
      childName: json['childName'] as String? ?? '',
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'] as String)?.toUtc() ?? DateTime.now().toUtc()
          : DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceToken': deviceToken,
      'deviceId': deviceId,
      'childId': childId,
      'childName': childName,
      'expiresAt': expiresAt.toIso8601String(),
    };
  }
}

