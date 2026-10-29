/// Represents an authenticated user profile returned from the backend.
/// Exactly mirrors `AuthUserDto` in ASP.NET Core:
/// - id: int
/// - fullName: string
/// - email: string
/// - role: string ("Parent", "Admin", etc.)
class UserModel {
  final int id;
  final String fullName;
  final String email;
  final String role;

  const UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
  });

  /// Role checks derived from server-issued claim, never from client input.
  bool get isParent => role.trim().toLowerCase() == 'parent';
  bool get isAdmin => role.trim().toLowerCase() == 'admin';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int? ?? 0,
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'Parent',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'role': role,
    };
  }

  @override
  String toString() => 'UserModel(id: $id, fullName: $fullName, email: $email, role: $role)';
}

