import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';

class SessionService {
  static const String _keyToken = 'auth_bearer_token';
  static const String _keyUser = 'auth_user_data';
  static const String _keyExpiresAt = 'auth_token_expires_at';

  // Save session when login or register is successful
  Future<void> saveSession(AuthResponseModel authResponse) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, authResponse.token);
    await prefs.setString(_keyUser, jsonEncode(authResponse.user.toJson()));
    if (authResponse.expiresAt != null) {
      await prefs.setString(
          _keyExpiresAt, authResponse.expiresAt!.toIso8601String());
    } else {
      await prefs.remove(_keyExpiresAt);
    }
  }

  // Get active bearer token
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_keyToken);
    if (token == null || token.isEmpty) return null;

    final expiresAtStr = prefs.getString(_keyExpiresAt);
    if (expiresAtStr != null) {
      final expiresAt = DateTime.tryParse(expiresAtStr);
      if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
        // Token has expired
        await clearSession();
        return null;
      }
    }
    return token;
  }

  // Get active cached user
  Future<UserModel?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJsonStr = prefs.getString(_keyUser);
    if (userJsonStr == null || userJsonStr.isEmpty) return null;

    try {
      final userMap = jsonDecode(userJsonStr) as Map<String, dynamic>;
      return UserModel.fromJson(userMap);
    } catch (_) {
      return null;
    }
  }

  // Check if session is authenticated and still valid
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    final user = await getUser();
    return token != null && user != null && user.isActive;
  }

  // Clear session on logout
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUser);
    await prefs.remove(_keyExpiresAt);
  }
}
