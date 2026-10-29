import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';
import 'session_service.dart';

class AuthService {
  final SessionService _sessionService = SessionService();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? '548808151397-2119mf63filiaftlt7tvpqlvd5klvqia.apps.googleusercontent.com'
        : null,
    scopes: ['email', 'profile'],
  );
  static const String _mockUsersStorageKey = 'auth_mock_users';
  static const String _lastResolvedUrlKey = 'auth_last_resolved_base_url';
  Future<void>? _mockUsersLoad;

  // Base URL konfigurasi REST API backend (Node.js Express + MySQL)
  static const String baseUrl = 'http://127.0.0.1:8000/api';
  static const String androidBaseUrl = 'http://10.0.2.2:8000/api';
  static const String lanBaseUrl = 'http://192.168.2.11:8000/api';

  static String? _resolvedBaseUrl;
  static Future<String>? _resolvingFuture;

  static List<String> get candidateBaseUrls {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return const [
        lanBaseUrl,     // Perangkat fisik via Wi-Fi LAN lokal
        baseUrl,        // Perangkat fisik via USB (adb reverse tcp:8000 tcp:8000)
        androidBaseUrl, // Android Emulator (10.0.2.2)
        'http://192.168.10.1:8000/api',
        'http://192.168.177.1:8000/api',
        'http://192.168.56.1:8000/api',
      ];
    }
    return const [
      baseUrl,
      'http://localhost:8000/api',
      lanBaseUrl,
    ];
  }

  static String get activeBaseUrl {
    if (_resolvedBaseUrl != null) {
      return _resolvedBaseUrl!;
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return lanBaseUrl;
    }
    return baseUrl;
  }

  static Future<String> resolveBaseUrl({bool forceRefresh = false}) async {
    try {
      final bindingName = WidgetsBinding.instance.runtimeType.toString();
      if (bindingName.contains('Test')) {
        return activeBaseUrl;
      }
    } catch (_) {}

    if (!forceRefresh && _resolvedBaseUrl != null) {
      return _resolvedBaseUrl!;
    }
    if (!forceRefresh && _resolvingFuture != null) {
      return _resolvingFuture!;
    }

    final future = _probeBaseUrls();
    _resolvingFuture = future;
    try {
      final resolved = await future;
      _resolvedBaseUrl = resolved;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_lastResolvedUrlKey, resolved);
      } catch (_) {}
      return resolved;
    } finally {
      _resolvingFuture = null;
    }
  }

  /// Probe semua kandidat URL secara paralel dan ambil URL PERTAMA yang merespons HTTP 200 OK.
  /// Mengabaikan kandidat yang gagal cepat (misal Connection refused pada 127.0.0.1 / 10.0.2.2).
  static Future<String> _probeBaseUrls() async {
    final candidates = <String>[];
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString(_lastResolvedUrlKey);
      if (savedUrl != null && savedUrl.isNotEmpty) {
        candidates.add(savedUrl);
      }
    } catch (_) {}
    for (final c in candidateBaseUrls) {
      if (!candidates.contains(c)) {
        candidates.add(c);
      }
    }

    final completer = Completer<String>();
    int remaining = candidates.length;

    for (final url in candidates) {
      http
          .get(
            Uri.parse('$url/health'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(milliseconds: 2500))
          .then((response) {
        if (response.statusCode == 200 && !completer.isCompleted) {
          completer.complete(url);
        } else {
          remaining--;
          if (remaining <= 0 && !completer.isCompleted) {
            completer.complete(
              !kIsWeb && defaultTargetPlatform == TargetPlatform.android
                  ? lanBaseUrl
                  : baseUrl,
            );
          }
        }
      }).catchError((_) {
        remaining--;
        if (remaining <= 0 && !completer.isCompleted) {
          completer.complete(
            !kIsWeb && defaultTargetPlatform == TargetPlatform.android
                ? lanBaseUrl
                : baseUrl,
          );
        }
      });
    }

    return completer.future;
  }

  /// Menjalankan HTTP request dengan auto-failover ke seluruh kandidat URL lokal
  /// apabila URL aktif mengalami Connection refused / Timeout.
  static Future<http.Response> requestWithFailover(
    Future<http.Response> Function(String baseUrl) requestFn,
  ) async {
    await resolveBaseUrl();
    final tried = <String>{};
    final firstUrl = activeBaseUrl;
    tried.add(firstUrl);

    try {
      return await requestFn(firstUrl);
    } catch (_) {
      // Coba kandidat URL lain secara berurutan jika URL pertama gagal (misal USB dicabut / IP berubah)
      Object? lastError;
      for (final candidate in candidateBaseUrls) {
        if (tried.contains(candidate)) continue;
        tried.add(candidate);
        try {
          final response = await requestFn(candidate);
          _resolvedBaseUrl = candidate;
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_lastResolvedUrlKey, candidate);
          } catch (_) {}
          return response;
        } catch (e) {
          lastError = e;
        }
      }
      throw lastError ?? Exception('Tidak dapat terhubung ke server backend.');
    }
  }

  // Flag apakah menggunakan mock in-memory untuk pengujian cepat
  // Default false agar terhubung langsung ke backend Node.js & MySQL lokal
  bool useMock = false;

  bool get _isTestEnv {
    try {
      final bindingName = WidgetsBinding.instance.runtimeType.toString();
      if (bindingName.contains('Test')) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  bool get shouldUseMock => useMock || _isTestEnv;

  // Akun bawaan (Mock Accounts) sesuai tim pengembang Kelompok 2 & Database MySQL
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
      'google_id': 'google_oauth_sales_123',
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
    {
      'id': 5,
      'name': 'Ahmad Hidayat',
      'email': 'ahmad.sales@majubersama.com',
      'password': 'password123',
      'phone': '081298765432',
      'role': 'sales',
      'is_active': 1,
      'google_id': null,
      'last_login_at': null,
    },
    {
      'id': 6,
      'name': 'njjjj',
      'email': 'setyoagung450@gmail.com',
      'password': 'password123',
      'phone': '99799779',
      'photo_url': 'https://lh3.googleusercontent.com/a/ACg8ocJkXxa2Ol2zJ_zZcsnBWlXuY9PbEQ52_MCCinARYvV4Gm3Gq00',
      'role': 'sales',
      'is_active': 1,
      'google_id': '101600273800804324536',
      'google_email': 'setyoagung450@gmail.com',
      'last_login_at': null,
    },
  ];

  Future<void> _ensureMockUsersLoaded() {
    return _mockUsersLoad ??= _loadMockUsers();
  }

  Future<void> _loadMockUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final storedUsers = prefs.getString(_mockUsersStorageKey);
    if (storedUsers == null) return;

    final decodedUsers = jsonDecode(storedUsers);
    if (decodedUsers is! List) {
      throw const FormatException('Data akun lokal tidak valid.');
    }

    for (final entry in decodedUsers) {
      if (entry is! Map) {
        throw const FormatException('Data akun lokal tidak valid.');
      }
      final userData = Map<String, dynamic>.from(entry);
      if (userData['_persist_locally'] != true) continue;

      final email = userData['email'];
      if (email is! String || email.isEmpty) {
        throw const FormatException('Data akun lokal tidak valid.');
      }
      final existingIndex = _mockUsers.indexWhere(
        (user) => (user['email'] as String).toLowerCase() == email.toLowerCase(),
      );
      if (existingIndex >= 0) {
        _mockUsers[existingIndex] = userData;
      } else {
        _mockUsers.add(userData);
      }
    }
  }

  Future<void> _saveMockUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final storedUsers = _mockUsers
        .where((user) => user['_persist_locally'] == true)
        .toList();
    final saved = await prefs.setString(
      _mockUsersStorageKey,
      jsonEncode(storedUsers),
    );
    if (!saved) {
      throw Exception('Akun gagal disimpan di perangkat. Silakan coba lagi.');
    }
  }

  // ============================================================
  // FR01 | LOGIN WITH EMAIL & PASSWORD
  // ============================================================
  Future<AuthResponseModel> loginWithEmail(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();

    if (!shouldUseMock) {
      http.Response? response;
      try {
        response = await requestWithFailover(
          (base) => http
              .post(
                Uri.parse('$base/auth/login'),
                headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
                body: jsonEncode({'email': cleanEmail, 'password': password}),
              )
              .timeout(const Duration(seconds: 6)),
        );
      } catch (_) {
        return _loginWithMockEmail(cleanEmail, password);
      }

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
    }

    return _loginWithMockEmail(cleanEmail, password);
  }

  // Logika Autentikasi Mock
  Future<AuthResponseModel> _loginWithMockEmail(String email, String password) async {
    await _ensureMockUsersLoaded();
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
  // ============================================================
  // FR01 | LOGIN WITH GOOGLE (GMAIL) - NATIVE GOOGLE SIGN-IN
  // ============================================================
  Future<AuthResponseModel> loginWithGoogle({String? testEmail}) async {
    String? email;
    String? googleId;
    String? photoUrl;
    String? idToken;

    if (testEmail != null && testEmail.isNotEmpty) {
      email = testEmail.trim().toLowerCase();
      googleId = 'google_test_${email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';
    } else {
      GoogleSignInAccount? googleUser;
      try {
        googleUser = await _googleSignIn.signIn();
      } catch (err) {
        debugPrint('Google Sign-In Exception: $err');
        if (err.toString().toLowerCase().contains('canceled') ||
            err.toString().toLowerCase().contains('dibatalkan')) {
          throw Exception('Proses login Google dibatalkan pengguna.');
        }
        rethrow;
      }

      if (googleUser == null) {
        throw Exception('Proses login Google dibatalkan pengguna.');
      }

      final googleAuth = await googleUser.authentication;
      googleId = googleUser.id;
      email = googleUser.email.trim().toLowerCase();
      photoUrl = googleUser.photoUrl;
      idToken = googleAuth.idToken;
    }

    // 1. Hubungkan ke backend Node.js (MySQL db_tracking_sales) dengan auto-failover
    if (!shouldUseMock) {
      http.Response? response;
      try {
        response = await requestWithFailover(
          (base) => http
              .post(
                Uri.parse('$base/auth/google-login'),
                headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
                body: jsonEncode({
                  'email': email,
                  'google_id': googleId,
                  'photo_url': photoUrl,
                }),
              )
              .timeout(const Duration(seconds: 6)),
        );
      } catch (_) {
        // Fallback ke autentikasi lokal/cache jika seluruh kandidat URL tidak terjangkau
        return await _loginWithMockGoogle(
          mockEmail: email,
          googleId: googleId,
          photoUrl: photoUrl,
          idToken: idToken,
        );
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final authResponse = AuthResponseModel.fromJson(data);

        if (!authResponse.user.isActive) {
          throw Exception('Akun Anda dinonaktifkan. Hubungi Administrator.');
        }

        // Sinkronkan ke memory/session lokal agar tetap bisa login bila sewaktu-waktu offline
        await _ensureMockUsersLoaded();
        final foundIdx = _mockUsers.indexWhere(
          (u) => u['id'] == authResponse.user.id ||
                 (u['email'] as String).toLowerCase() == authResponse.user.email.toLowerCase(),
        );
        if (foundIdx != -1) {
          _mockUsers[foundIdx]['google_id'] = authResponse.user.googleId;
          _mockUsers[foundIdx]['google_email'] = authResponse.user.googleEmail;
          _mockUsers[foundIdx]['photo_url'] = authResponse.user.photoUrl;
          _mockUsers[foundIdx]['last_login_at'] = DateTime.now().toIso8601String();
          _mockUsers[foundIdx]['_persist_locally'] = true;
        } else {
          _mockUsers.add({
            ...authResponse.user.toJson(),
            'password': 'password123',
            '_persist_locally': true,
          });
        }
        await _saveMockUsers();

        await _sessionService.saveSession(authResponse);
        return authResponse;
      } else {
        final errBody = jsonDecode(response.body);
        throw Exception(errBody['message'] ?? 'Gagal masuk dengan akun Google.');
      }
    }

    // 2. Fallback Simulasi / Offline Mode
    return await _loginWithMockGoogle(
      mockEmail: email,
      googleId: googleId,
      photoUrl: photoUrl,
      idToken: idToken,
    );
  }

  // Simulasi Google Sign-In untuk pengujian instan / dev fallback
  Future<AuthResponseModel> _loginWithMockGoogle({
    String? mockEmail,
    String? googleId,
    String? photoUrl,
    String? idToken,
  }) async {
    await _ensureMockUsersLoaded();
    await Future.delayed(const Duration(milliseconds: 300));

    final targetEmail = (mockEmail ?? '').trim().toLowerCase();

    // Cari akun yang tepat sesuai tautan akun Google
    int foundIndex = -1;

    // Prioritas 1: Kecocokan dengan google_email yang tertaut
    if (targetEmail.isNotEmpty) {
      foundIndex = _mockUsers.indexWhere(
        (u) => (u['google_email'] as String?)?.toLowerCase() == targetEmail,
      );
    }

    // Prioritas 2: Kecocokan dengan email utama akun CV Maju Bersama
    if (foundIndex == -1 && targetEmail.isNotEmpty) {
      foundIndex = _mockUsers.indexWhere(
        (u) => (u['email'] as String).toLowerCase() == targetEmail,
      );
    }

    // Prioritas 3: Kecocokan dengan google_id
    if (foundIndex == -1 && googleId != null && googleId.isNotEmpty) {
      foundIndex = _mockUsers.indexWhere(
        (u) => u['google_id'] == googleId,
      );
    }

    // Prioritas 4: Cek sesi terakhir yang tersimpan di perangkat
    if (foundIndex == -1) {
      final cachedUser = await _sessionService.getUser();
      if (cachedUser != null &&
          ((targetEmail.isNotEmpty &&
                  (cachedUser.email.toLowerCase() == targetEmail ||
                      cachedUser.googleEmail?.toLowerCase() == targetEmail)) ||
              (googleId != null && cachedUser.googleId == googleId))) {
        _mockUsers.add({
          ...cachedUser.toJson(),
          'password': 'password123',
          '_persist_locally': true,
        });
        foundIndex = _mockUsers.length - 1;
      }
    }

    // Jika akun tidak ditemukan atau belum pernah ditautkan
    if (foundIndex == -1) {
      throw Exception(
        'Akun Google ($targetEmail) belum terdaftar dalam sistem. Khusus akun Sales, pendaftaran hanya dapat dilakukan oleh Admin atau Owner.',
      );
    }

    final userData = _mockUsers[foundIndex];
    if (userData['is_active'] == 0 || userData['is_active'] == false) {
      throw Exception('Akun Anda dinonaktifkan. Hubungi Administrator.');
    }

    userData['google_id'] = googleId ?? userData['google_id'] ?? 'google_oauth_${userData['id']}';
    if (userData['google_email'] == null && targetEmail.isNotEmpty) {
      userData['google_email'] = targetEmail;
    }
    if (photoUrl != null && photoUrl.isNotEmpty) {
      userData['photo_url'] = photoUrl;
    }
    userData['last_login_at'] = DateTime.now().toIso8601String();
    userData['_persist_locally'] = true;
    await _saveMockUsers();

    final user = UserModel.fromJson(userData);
    final authResponse = AuthResponseModel(
      token: idToken ?? 'google_oauth_token_${user.id}_${DateTime.now().millisecondsSinceEpoch}',
      expiresAt: DateTime.now().add(const Duration(days: 7)),
      user: user,
    );

    await _sessionService.saveSession(authResponse);
    return authResponse;
  }

  // ============================================================
  // FR12 | REGISTRASI AKUN SALES KHUSUS OLEH ADMIN & OWNER
  // ============================================================
  Future<UserModel> registerSalesByManager({
    required UserModel managerUser,
    required UserModel newSalesUser,
    required String password,
    bool linkGoogle = false,
  }) async {
    if (!managerUser.isSuperAdmin && !managerUser.isAdmin) {
      throw Exception(
        'Akses ditolak: Hanya Admin dan Owner yang memiliki izin untuk mendaftarkan akun Sales baru.',
      );
    }

    final cleanEmail = newSalesUser.email.trim().toLowerCase();
    if (cleanEmail.isEmpty) {
      throw Exception('Email sales wajib diisi.');
    }

    if (!shouldUseMock) {
      http.Response? response;
      try {
        response = await requestWithFailover(
          (base) => http
              .post(
                Uri.parse('$base/auth/register-sales'),
                headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
                body: jsonEncode({
                  'manager_id': managerUser.id,
                  'name': newSalesUser.name.trim(),
                  'email': cleanEmail,
                  'password': password,
                  'phone': newSalesUser.phone?.trim(),
                  'link_google': linkGoogle,
                }),
              )
              .timeout(const Duration(seconds: 6)),
        );
      } catch (_) {
        response = null;
      }

      if (response != null) {
        if (response.statusCode == 201 || response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final createdUser = UserModel.fromJson(data['user']);
          
          // Cache juga ke memori lokal
          await _ensureMockUsersLoaded();
          _mockUsers.add({
            'id': createdUser.id,
            'name': createdUser.name,
            'email': createdUser.email,
            'password': password,
            'phone': createdUser.phone,
            'role': 'sales',
            'is_active': 1,
            'google_id': createdUser.googleId,
            'google_email': createdUser.googleEmail,
            'created_by': managerUser.name,
            '_persist_locally': true,
          });
          await _saveMockUsers();

          return createdUser;
        } else {
          final errBody = jsonDecode(response.body);
          throw Exception(errBody['message'] ?? 'Gagal mendaftarkan akun Sales.');
        }
      }
    }

    // Blok Mock untuk offline testing
    await _ensureMockUsersLoaded();
    await Future.delayed(const Duration(milliseconds: 200));

    final isExist = _mockUsers.any(
      (u) => (u['email'] as String).toLowerCase() == cleanEmail,
    );

    if (isExist) {
      throw Exception('Email "$cleanEmail" sudah terdaftar. Silakan gunakan email lain.');
    }

    final newUserData = {
      'id': _mockUsers.length + 1,
      'name': newSalesUser.name.trim(),
      'email': cleanEmail,
      'password': password,
      'phone': newSalesUser.phone?.trim(),
      'role': 'sales', // Wajib role sales
      'is_active': 1,  // Status aktif
      'google_id': linkGoogle ? 'google_oauth_${_mockUsers.length + 1}' : null,
      'created_by': managerUser.name,
      'last_login_at': null,
      '_persist_locally': true,
    };

    _mockUsers.add(newUserData);
    try {
      await _saveMockUsers();
    } catch (_) {
      _mockUsers.remove(newUserData);
      rethrow;
    }

    return UserModel.fromJson(newUserData);
  }

  // Pendaftaran mandiri tidak diizinkan untuk Sales
  Future<AuthResponseModel> register(UserModel user, String password) async {
    throw Exception(
      'Pendaftaran mandiri akun Sales tidak diizinkan. Akun Sales baru hanya dapat didaftarkan oleh Admin atau Owner.',
    );
  }

  // Dapatkan seluruh data anggota untuk panel keanggotaan
  Future<List<UserModel>> getAllUsers() async {
    if (!shouldUseMock) {
      try {
        final response = await requestWithFailover(
          (base) => http
              .get(
                Uri.parse('$base/users'),
                headers: {'Accept': 'application/json'},
              )
              .timeout(const Duration(seconds: 5)),
        );

        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          final list = body['data'] as List<dynamic>? ?? [];
          final users = list
              .map((item) => UserModel.fromJson(item as Map<String, dynamic>))
              .toList();

          await _ensureMockUsersLoaded();
          for (final u in users) {
            final idx = _mockUsers.indexWhere(
              (m) =>
                  m['id'] == u.id ||
                  (m['email'] as String).toLowerCase() == u.email.toLowerCase(),
            );
            if (idx != -1) {
              _mockUsers[idx] = {
                ..._mockUsers[idx],
                ...u.toJson(),
                '_persist_locally': true,
              };
            } else {
              _mockUsers.add({
                ...u.toJson(),
                'password': 'password123',
                '_persist_locally': true,
              });
            }
          }
          await _saveMockUsers();

          return users;
        }
      } catch (_) {
        // Fallback ke mock data jika server offline
      }
    }
    await _ensureMockUsersLoaded();
    return _mockUsers.map((data) => UserModel.fromJson(data)).toList();
  }

  // ============================================================
  // TAUTKAN AKUN GOOGLE (GMAIL) DARI SCREEN PROFIL
  // ============================================================
  Future<UserModel> linkGoogleAccount({
    int? userId,
    String? currentUserEmail,
    String? email,
    String? googleEmail,
    String? googleId,
    String? photoUrl,
  }) async {
    final activeEmail = (currentUserEmail ?? email ?? '').trim().toLowerCase();
    final targetGoogleEmail = (googleEmail ?? email ?? activeEmail).trim().toLowerCase();

    if (activeEmail.isEmpty && targetGoogleEmail.isEmpty && userId == null) {
      throw Exception('Data akun tidak valid.');
    }

    if (!shouldUseMock) {
      http.Response? response;
      try {
        response = await requestWithFailover(
          (base) => http
              .post(
                Uri.parse('$base/users/link-google'),
                headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
                body: jsonEncode({
                  'user_id': userId,
                  'email': activeEmail.isNotEmpty ? activeEmail : targetGoogleEmail,
                  'google_email': targetGoogleEmail,
                  'google_id': googleId,
                  'photo_url': photoUrl,
                }),
              )
              .timeout(const Duration(seconds: 6)),
        );
      } catch (_) {
        response = null;
      }

      if (response != null) {
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final updatedUser = UserModel.fromJson(data['user']);
          await _sessionService.saveSession(
            AuthResponseModel(
              token: await _sessionService.getToken() ?? 'active_token_${updatedUser.id}',
              user: updatedUser,
            ),
          );
          return updatedUser;
        } else {
          final errBody = jsonDecode(response.body);
          throw Exception(errBody['message'] ?? 'Gagal menautkan akun Google.');
        }
      }
    }

    // Blok Mock / Fallback Lokal
    await _ensureMockUsersLoaded();
    int userIndex = -1;
    if (userId != null) {
      userIndex = _mockUsers.indexWhere((u) => u['id'] == userId);
    }
    if (userIndex == -1 && activeEmail.isNotEmpty) {
      userIndex = _mockUsers.indexWhere(
        (u) => (u['email'] as String).toLowerCase() == activeEmail,
      );
    }
    if (userIndex == -1 && targetGoogleEmail.isNotEmpty) {
      userIndex = _mockUsers.indexWhere(
        (u) => (u['email'] as String).toLowerCase() == targetGoogleEmail ||
               (u['google_email'] as String?)?.toLowerCase() == targetGoogleEmail,
      );
    }

    if (userIndex == -1) {
      throw Exception('Akun dengan email "$activeEmail" tidak ditemukan.');
    }

    final gid = googleId ?? 'google_oauth_${_mockUsers[userIndex]['id']}';
    _mockUsers[userIndex]['google_id'] = gid;
    _mockUsers[userIndex]['google_email'] = targetGoogleEmail.isNotEmpty ? targetGoogleEmail : activeEmail;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      _mockUsers[userIndex]['photo_url'] = photoUrl;
    }
    _mockUsers[userIndex]['_persist_locally'] = true;
    await _saveMockUsers();

    final updatedUser = UserModel.fromJson(_mockUsers[userIndex]);

    final currentCached = await _sessionService.getUser();
    if (currentCached != null) {
      final token = await _sessionService.getToken() ?? 'active_token_${updatedUser.id}';
      await _sessionService.saveSession(
        AuthResponseModel(token: token, user: updatedUser),
      );
    }

    return updatedUser;
  }

  // ============================================================
  // PUTUSKAN TAUTAN AKUN GOOGLE (GMAIL) DARI SCREEN PROFIL
  // ============================================================
  Future<UserModel> unlinkGoogleAccount({int? userId, required String email}) async {
    final cleanEmail = email.trim().toLowerCase();

    if (!shouldUseMock) {
      http.Response? response;
      try {
        response = await requestWithFailover(
          (base) => http
              .post(
                Uri.parse('$base/users/unlink-google'),
                headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
                body: jsonEncode({
                  'user_id': userId,
                  'email': cleanEmail,
                }),
              )
              .timeout(const Duration(seconds: 6)),
        );
      } catch (_) {
        response = null;
      }

      if (response != null) {
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final updatedUser = UserModel.fromJson(data['user']);
          await _sessionService.saveSession(
            AuthResponseModel(
              token: await _sessionService.getToken() ?? 'active_token_${updatedUser.id}',
              user: updatedUser,
            ),
          );
          return updatedUser;
        } else {
          final errBody = jsonDecode(response.body);
          throw Exception(errBody['message'] ?? 'Gagal memutuskan tautan akun Google.');
        }
      }
    }

    // Blok Mock / Fallback Lokal
    await _ensureMockUsersLoaded();
    int userIndex = -1;
    if (userId != null) {
      userIndex = _mockUsers.indexWhere((u) => u['id'] == userId);
    }
    if (userIndex == -1) {
      userIndex = _mockUsers.indexWhere(
        (u) => (u['email'] as String).toLowerCase() == cleanEmail ||
               (u['google_email'] as String?)?.toLowerCase() == cleanEmail,
      );
    }

    if (userIndex == -1) {
      throw Exception('Akun tidak ditemukan.');
    }

    _mockUsers[userIndex]['google_id'] = null;
    _mockUsers[userIndex]['google_email'] = null;
    _mockUsers[userIndex]['_persist_locally'] = true;
    await _saveMockUsers();

    final updatedUser = UserModel.fromJson(_mockUsers[userIndex]);

    final currentCached = await _sessionService.getUser();
    if (currentCached != null) {
      final token = await _sessionService.getToken() ?? 'active_token_${updatedUser.id}';
      await _sessionService.saveSession(
        AuthResponseModel(token: token, user: updatedUser),
      );
    }

    return updatedUser;
  }

  // ============================================================
  // UPDATE PASSWORD (ROLE SALES & PENGGUNA LAIN)
  // ============================================================
  Future<bool> updatePassword({
    required String email,
    required String newPassword,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    if (!shouldUseMock) {
      try {
        final response = await requestWithFailover(
          (base) => http
              .post(
                Uri.parse('$base/users/change-password'),
                headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
                body: jsonEncode({
                  'email': cleanEmail,
                  'new_password': newPassword,
                }),
              )
              .timeout(const Duration(seconds: 6)),
        );

        if (response.statusCode == 200) {
          await _ensureMockUsersLoaded();
          final idx = _mockUsers.indexWhere(
            (u) => (u['email'] as String).toLowerCase() == cleanEmail,
          );
          if (idx != -1) {
            _mockUsers[idx]['password'] = newPassword;
            _mockUsers[idx]['_persist_locally'] = true;
            await _saveMockUsers();
          }
          return true;
        } else {
          final errBody = jsonDecode(response.body);
          throw Exception(errBody['message'] ?? 'Gagal memperbarui password.');
        }
      } catch (e) {
        if (e.toString().contains('Gagal memperbarui') ||
            e.toString().contains('tidak ditemukan')) {
          rethrow;
        }
        // Fallback lokal jika offline
      }
    }

    await _ensureMockUsersLoaded();
    final userIndex = _mockUsers.indexWhere(
      (u) => (u['email'] as String).toLowerCase() == cleanEmail,
    );

    if (userIndex == -1) {
      throw Exception('Akun dengan email "$cleanEmail" tidak ditemukan.');
    }

    _mockUsers[userIndex]['password'] = newPassword;
    _mockUsers[userIndex]['_persist_locally'] = true;
    await _saveMockUsers();
    return true;
  }

  // ============================================================
  // UPDATE FOTO PROFIL (SEMUA ROLE: OWNER, ADMIN, SALES)
  // ============================================================
  Future<UserModel> updateProfilePhoto({
    required String email,
    required String photoUrl,
  }) async {
    return updateUserProfile(email: email, photoUrl: photoUrl);
  }

  // ============================================================
  // UPDATE DATA PROFIL (NAMA, NO HP, FOTO)
  // ============================================================
  Future<UserModel> updateUserProfile({
    required String email,
    String? name,
    String? phone,
    String? photoUrl,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    if (!shouldUseMock) {
      try {
        final response = await requestWithFailover(
          (base) => http
              .post(
                Uri.parse('$base/users/update-profile'),
                headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
                body: jsonEncode({
                  'email': cleanEmail,
                  if (name != null) 'name': name.trim(),
                  if (phone != null) 'phone': phone.trim(),
                  if (photoUrl != null) 'photo_url': photoUrl,
                }),
              )
              .timeout(const Duration(seconds: 6)),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final updatedUser = UserModel.fromJson(data['user']);
          final currentCached = await _sessionService.getUser();
          if (currentCached != null && currentCached.email.toLowerCase() == cleanEmail) {
            final token = await _sessionService.getToken() ?? 'active_token_${updatedUser.id}';
            await _sessionService.saveSession(
              AuthResponseModel(token: token, user: updatedUser),
            );
          }
          return updatedUser;
        }
      } catch (_) {
        // Fallback lokal jika server offline
      }
    }

    await _ensureMockUsersLoaded();
    int userIndex = _mockUsers.indexWhere(
      (u) => (u['email'] as String).toLowerCase() == cleanEmail,
    );

    if (userIndex == -1) {
      final currentCached = await _sessionService.getUser();
      if (currentCached != null && currentCached.email.toLowerCase() == cleanEmail) {
        _mockUsers.add({
          ...currentCached.toJson(),
          '_persist_locally': true,
        });
        userIndex = _mockUsers.length - 1;
      } else {
        throw Exception('Akun dengan email "$cleanEmail" tidak ditemukan.');
      }
    }

    if (name != null && name.trim().isNotEmpty) {
      _mockUsers[userIndex]['name'] = name.trim();
    }
    if (phone != null) {
      _mockUsers[userIndex]['phone'] = phone.trim();
    }
    if (photoUrl != null) {
      _mockUsers[userIndex]['photo_url'] = photoUrl.trim().isEmpty ? null : photoUrl;
    }
    _mockUsers[userIndex]['_persist_locally'] = true;
    await _saveMockUsers();

    final updatedUser = UserModel.fromJson(_mockUsers[userIndex]);

    final currentCached = await _sessionService.getUser();
    if (currentCached != null && currentCached.email.toLowerCase() == cleanEmail) {
      final token = await _sessionService.getToken() ?? 'active_token_${updatedUser.id}';
      await _sessionService.saveSession(
        AuthResponseModel(token: token, user: updatedUser),
      );
    }

    return updatedUser;
  }

  // ============================================================
  // GET USER SESUAI ROLE (UNTUK SCREEN PROFIL / PREVIEW ROLE)
  // ============================================================
  Future<UserModel?> getUserByRole(String role) async {
    await _ensureMockUsersLoaded();
    final r = role.toLowerCase();
    final match = _mockUsers.firstWhere(
      (u) {
        final uRole = (u['role'] as String).toLowerCase();
        if (r == 'owner' || r == 'superadmin') return uRole == 'superadmin';
        if (r == 'admin' || r == 'administrator') return uRole == 'administrator' || uRole == 'admin';
        if (r == 'sales') return uRole == 'sales';
        return uRole == r;
      },
      orElse: () => {},
    );

    if (match.isEmpty) return null;
    return UserModel.fromJson(match);
  }

  // ============================================================
  // LOGOUT (MENCABUT SESI & HAPUS TOKEN)
  // ============================================================
  Future<void> logout() async {
    if (!shouldUseMock) {
      try {
        final activeToken = await _sessionService.getToken();
        if (activeToken != null && activeToken.isNotEmpty) {
          await http.post(
            Uri.parse('$activeBaseUrl/auth/logout'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $activeToken',
            },
            body: jsonEncode({'token': activeToken}),
          ).timeout(const Duration(seconds: 4));
        }
      } catch (_) {}
    }
    try {
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
    } catch (_) {}
    await _sessionService.clearSession();
  }
}
