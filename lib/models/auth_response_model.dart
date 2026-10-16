import 'user_model.dart';

class AuthResponseModel {
  final String token;
  final DateTime? expiresAt;
  final UserModel user;

  const AuthResponseModel({
    required this.token,
    this.expiresAt,
    required this.user,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      token: json['token'] as String? ?? json['access_token'] as String? ?? '',
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'].toString())
          : null,
      user: json['user'] != null
          ? UserModel.fromJson(json['user'] as Map<String, dynamic>)
          : UserModel.fromJson(json),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      if (expiresAt != null) 'expires_at': expiresAt!.toIso8601String(),
      'user': user.toJson(),
    };
  }
}
