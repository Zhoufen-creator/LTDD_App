/// Model representing a child profile retrieved from `/api/children`.
/// Exactly mirrors `ChildResponseDto` from ASP.NET Core backend.
class ChildModel {
  final int id;
  final String fullName;
  final DateTime? dateOfBirth;
  final int parentId;
  final DateTime createdAt;
  final int deviceCount;
  final int monitoringRuleCount;

  const ChildModel({
    required this.id,
    required this.fullName,
    this.dateOfBirth,
    required this.parentId,
    required this.createdAt,
    this.deviceCount = 0,
    this.monitoringRuleCount = 0,
  });

  /// Calculates current age based on dateOfBirth.
  int? get age {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    int age = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      age--;
    }
    return age >= 0 ? age : 0;
  }

  factory ChildModel.fromJson(Map<String, dynamic> json) {
    return ChildModel(
      id: json['id'] as int? ?? 0,
      fullName: json['fullName'] as String? ?? '',
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.tryParse(json['dateOfBirth'] as String)
          : null,
      parentId: json['parentId'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      deviceCount: json['deviceCount'] as int? ?? 0,
      monitoringRuleCount: json['monitoringRuleCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'parentId': parentId,
      'createdAt': createdAt.toIso8601String(),
      'deviceCount': deviceCount,
      'monitoringRuleCount': monitoringRuleCount,
    };
  }

  /// Request payload for creating a new child profile (CreateChildDto).
  static Map<String, dynamic> createPayload({
    required String fullName,
    DateTime? dateOfBirth,
    required int parentId,
  }) {
    return {
      'fullName': fullName.trim(),
      if (dateOfBirth != null) 'dateOfBirth': dateOfBirth.toIso8601String(),
      'parentId': parentId,
    };
  }

  /// Request payload for updating an existing child profile (UpdateChildDto).
  static Map<String, dynamic> updatePayload({
    required String fullName,
    DateTime? dateOfBirth,
  }) {
    return {
      'fullName': fullName.trim(),
      'dateOfBirth': dateOfBirth?.toIso8601String(),
    };
  }

  @override
  String toString() => 'ChildModel(id: $id, fullName: $fullName, parentId: $parentId)';
}

