import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import '../models/auth_response_model.dart';
import '../models/user_model.dart';
import 'session_service.dart';

class AuthService {
  final SessionService _sessionService = SessionService();
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  // Base URL konfigurasi REST API backend (Laravel / Node / Go)
  static const String baseUrl = 'http://10.0.2.2:8000/api';
  
  // Flag apakah menggunakan mock in-memory untuk pengujian cepat
  bool useMock = true;

  // Akun bawaan (Mock Accounts) sesuai tim pengembang Kelompok 2 & Analisis Kebutuhan
  final List<Map<String, dynamic>> _mockUsers = [
    {
      'id': 1,
      'name': 'Dimas Brahamsyah Santosa Putra',
      'email': 'owner@majubersama.com',
      'password': 'password123',
      'phone': '081234567890',
      'role': 'superadmin',
      'is_active': 1,
      'google_id': null,
      'last_login_at': null,
    },
    {
      'id': 2,
      'name': 'Agung Prasetyo Wibowo',
      'email': 'admin@majubersama.com',
      'password': 'password123',
      'phone': '081234567891',
      'role': 'administrator',
      'is_active': 1,
      'google_id': null,
      'last_login_at': null,
    },
    {
      'id': 3,
      'name': 'Muhammad Ulil Abshor',
      'email': 'sales@majubersama.com',
      'password': 'password123',
      'phone': '081234567892',
      'role': 'sales',
      'is_active': 1,
      'google_id': null,
      'last_login_at': null,
    },
    {
      'id': 4,
      'name': 'Budi Santoso (Nonaktif)',
      'email': 'inactive@majubersama.com',
      'password': 'password123',
      'phone': '081234567899',
      'role': 'sales',
      'is_active': 0, // Akun dinonaktifkan
      'google_id': null,
      'last_login_at': null,
    },
  ];

  // ============================================================
  // FR01 | LOGIN WITH EMAIL & PASSWORD
  // ============================================================
  Future<AuthResponseModel> loginWithEmail(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();

    if (!useMock) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/auth/login'),
          headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
          body: jsonEncode({'email': cleanEmail, 'password': password}),
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final authResponse = AuthResponseModel.fromJson(data);
          
          if (!authResponse.user.isActive) {
            throw Exception('Akun Anda dinonaktifkan. Hubungi Administrator.');
          }

          await _sessionService.saveSession(authResponse);
          return authResponse;
        } else {
          final errBody = jsonDecode(response.body);
          throw Exception(errBody['message'] ?? 'Login gagal. Periksa kembali email dan password.');
        }
      } catch (e) {
        // Jika koneksi server gagal dan fallback mock aktif, lanjutkan ke mock
        if (!e.toString().contains('Akun Anda dinonaktifkan')) {
          return _loginWithMockEmail(cleanEmail, password);
        }
        rethrow;
      }
    }

    return _loginWithMockEmail(cleanEmail, password);
  }

  // Logika Autentikasi Mock
  Future<AuthResponseModel> _loginWithMockEmail(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 600)); // simulasi latency

    final foundIndex = _mockUsers.indexWhere(
      (u) => (u['email'] as String).toLowerCase() == email,
    );

    if (foundIndex == -1) {
      throw Exception('Email tidak terdaftar dalam sistem.');
    }

    final userData = _mockUsers[foundIndex];

    if (userData['password'] != password) {
      throw Exception('Password yang Anda masukkan salah.');
    }

    // Validasi Status Akun (is_active)
    if (userData['is_active'] == 0 || userData['is_active'] == false) {
      throw Exception('Akun Anda dinonaktifkan. Hubungi Administrator.');
    }

    // Update users.last_login_at saat login berhasil
    userData['last_login_at'] = DateTime.now().toIso8601String();

    final user = UserModel.fromJson(userData);
    final authResponse = AuthResponseModel(
      token: 'mock_bearer_token_${user.id}_${DateTime.now().millisecondsSinceEpoch}',
      expiresAt: DateTime.now().add(const Duration(days: 7)),
      user: user,
    );

    await _sessionService.saveSession(authResponse);
    return authResponse;
  }

  // ============================================================
  // FR01 | LOGIN WITH GOOGLE (GMAIL)
  // ============================================================
  Future<AuthResponseModel> loginWithGoogle() async {
    try {
      GoogleSignInAccount? googleUser;
      try {
        googleUser = await _googleSignIn.signIn();
      } catch (err) {
        // Fallback jika Google Play Services / SHA-1 belum dikonfigurasi pada environment dev
        return await _loginWithMockGoogle();
      }

      if (googleUser == null) {
        throw Exception('Proses login Google dibatalkan pengguna.');
      }

      final googleAuth = await googleUser.authentication;
      final googleId = googleUser.id;
      final email = googleUser.email.toLowerCase();
      final displayName = googleUser.displayName ?? 'Sales Maju Bersama';
      final photoUrl = googleUser.photoUrl;

      // Cari atau daftarkan akun dengan google_id / email
      final existingIndex = _mockUsers.indexWhere(
        (u) => (u['email'] as String).toLowerCase() == email || u['google_id'] == googleId,
      );

      Map<String, dynamic> userData;
      if (existingIndex >= 0) {
        userData = _mockUsers[existingIndex];
        userData['google_id'] = googleId;
        if (photoUrl != null) userData['photo_url'] = photoUrl;
      } else {
        userData = {
          'id': _mockUsers.length + 1,
          'name': displayName,
          'email': email,
          'phone': null,
          'role': 'sales',
          'is_active': 1,
          'google_id': googleId,
          'photo_url': photoUrl,
          'last_login_at': DateTime.now().toIso8601String(),
        };
        _mockUsers.add(userData);
      }

      // Validasi is_active
      if (userData['is_active'] == 0 || userData['is_active'] == false) {
        throw Exception('Akun Anda dinonaktifkan. Hubungi Administrator.');
      }

      userData['last_login_at'] = DateTime.now().toIso8601String();
      final user = UserModel.fromJson(userData);
      final authResponse = AuthResponseModel(
        token: googleAuth.idToken ?? 'google_mock_token_${user.id}',
        expiresAt: DateTime.now().add(const Duration(days: 7)),
        user: user,
      );

      await _sessionService.saveSession(authResponse);
      return authResponse;
    } catch (e) {
      if (e.toString().contains('dibatalkan') || e.toString().contains('dinonaktifkan')) {
        rethrow;
      }
      return _loginWithMockGoogle();
    }
  }

  // Simulasi Google Sign-In untuk pengujian instan
  Future<AuthResponseModel> _loginWithMockGoogle() async {
    await Future.delayed(const Duration(milliseconds: 600));

    const googleEmail = 'sales.google@majubersama.com';
    var foundIndex = _mockUsers.indexWhere((u) => u['email'] == googleEmail);

    if (foundIndex == -1) {
      final newUser = {
        'id': _mockUsers.length + 1,
        'name': 'Muhammad Ulil Abshor (Google)',
        'email': googleEmail,
        'phone': '081234567800',
        'role': 'sales',
        'is_active': 1,
        'google_id': 'google_oauth_123456789',
        'last_login_at': DateTime.now().toIso8601String(),
      };
      _mockUsers.add(newUser);
      foundIndex = _mockUsers.length - 1;
    }

    final userData = _mockUsers[foundIndex];
    if (userData['is_active'] == 0 || userData['is_active'] == false) {
      throw Exception('Akun Anda dinonaktifkan. Hubungi Administrator.');
    }

    userData['last_login_at'] = DateTime.now().toIso8601String();
    final user = UserModel.fromJson(userData);

    final authResponse = AuthResponseModel(
      token: 'google_oauth_token_${user.id}_${DateTime.now().millisecondsSinceEpoch}',
      expiresAt: DateTime.now().add(const Duration(days: 7)),
      user: user,
    );

    await _sessionService.saveSession(authResponse);
    return authResponse;
  }

  // ============================================================
  // FR12 | REGISTRASI AKUN BARU
  // ============================================================
  Future<AuthResponseModel> register(UserModel user, String password) async {
    if (!useMock) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/auth/register'),
          headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
          body: jsonEncode({
            ...user.toJson(),
            'password': password,
            'role': 'sales',
            'is_active': 1,
          }),
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 201 || response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final authResponse = AuthResponseModel.fromJson(data);
          await _sessionService.saveSession(authResponse);
          return authResponse;
        } else {
          final errBody = jsonDecode(response.body);
          throw Exception(errBody['message'] ?? 'Registrasi akun gagal.');
        }
      } catch (e) {
        if (!e.toString().contains('Email sudah terdaftar')) {
          return _registerMock(user, password);
        }
        rethrow;
      }
    }

    return _registerMock(user, password);
  }

  Future<AuthResponseModel> _registerMock(UserModel user, String password) async {
    await Future.delayed(const Duration(milliseconds: 600));

    final cleanEmail = user.email.trim().toLowerCase();
    final isExist = _mockUsers.any(
      (u) => (u['email'] as String).toLowerCase() == cleanEmail,
    );

    if (isExist) {
      throw Exception('Email "$cleanEmail" sudah terdaftar. Silakan gunakan email lain atau masuk.');
    }

    final newUserData = {
      'id': _mockUsers.length + 1,
      'name': user.name.trim(),
      'email': cleanEmail,
      'password': password,
      'phone': user.phone?.trim(),
      'role': 'sales', // Default role 'sales' sesuai spesifikasi FR12
      'is_active': 1,  // Default aktif
      'google_id': null,
      'last_login_at': DateTime.now().toIso8601String(),
    };

    _mockUsers.add(newUserData);

    final createdUser = UserModel.fromJson(newUserData);
    final authResponse = AuthResponseModel(
      token: 'bearer_token_reg_${createdUser.id}_${DateTime.now().millisecondsSinceEpoch}',
      expiresAt: DateTime.now().add(const Duration(days: 7)),
      user: createdUser,
    );

    await _sessionService.saveSession(authResponse);
    return authResponse;
  }

  // ============================================================
  // LOGOUT (MENCABUT SESI & HAPUS TOKEN)
  // ============================================================
  Future<void> logout() async {
    try {
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
    } catch (_) {}
    await _sessionService.clearSession();
  }
}
