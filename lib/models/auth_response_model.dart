import 'user_model.dart';

/// Models the backend response upon successful authentication.
/// Exactly mirrors `AuthResponseDto` in ASP.NET Core:
/// - token: string (Application-issued JWT)
/// - expiresAt: DateTime
/// - user: AuthUserDto
class AuthResponseModel {
  final String token;
  final DateTime expiresAt;
  final UserModel user;

  const AuthResponseModel({
    required this.token,
    required this.expiresAt,
    required this.user,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      token: json['token'] as String? ?? '',
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'] as String) ?? DateTime.now().add(const Duration(hours: 1))
          : DateTime.now().add(const Duration(hours: 1)),
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>? ?? {}),
    );
  }
}

