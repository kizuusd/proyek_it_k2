import 'package:flutter/foundation.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/session_service.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final SessionService _sessionService = SessionService();

  AuthStatus _status = AuthStatus.initial;
  UserModel? _currentUser;
  String? _token;
  String? _errorMessage;

  AuthStatus get status => _status;
  UserModel? get currentUser => _currentUser;
  String? get token => _token;
  String? get errorMessage => _errorMessage;

  bool get isAuthenticated =>
      _status == AuthStatus.authenticated && _currentUser != null;
  bool get isLoading => _status == AuthStatus.loading;
  bool get useMock => _authService.useMock;
  set useMock(bool val) {
    _authService.useMock = val;
    notifyListeners();
  }

  // Inisialisasi: Auto-login jika session tersimpan di penyimpanan lokal
  Future<void> checkAuthSession() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      final hasValidSession = await _sessionService.isLoggedIn();
      if (hasValidSession) {
        _token = await _sessionService.getToken();
        _currentUser = await _sessionService.getUser();
        _status = AuthStatus.authenticated;
      } else {
        _status = AuthStatus.unauthenticated;
      }
    } catch (e) {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  // FR01 | Login Email & Password
  Future<bool> login(String email, String password) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final authResponse =
          await _authService.loginWithEmail(email, password);
      _currentUser = authResponse.user;
      _token = authResponse.token;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = _cleanErrorMessage(e.toString());
      notifyListeners();
      return false;
    }
  }

  // FR01 | Login Google (GMAIL)
  Future<bool> loginWithGoogle({String? testEmail}) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final authResponse = await _authService.loginWithGoogle(testEmail: testEmail);
      _currentUser = authResponse.user;
      _token = authResponse.token;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = _cleanErrorMessage(e.toString());
      notifyListeners();
      return false;
    }
  }

  // FR12 | Registrasi Akun Sales Khusus oleh Admin & Owner
  Future<bool> registerSalesAccount({
    required String name,
    required String email,
    required String password,
    String? phone,
    bool linkGoogle = false,
  }) async {
    if (_currentUser == null || !_currentUser!.isManager) {
      _errorMessage =
          'Akses ditolak: Hanya Admin dan Owner yang berhak mendaftarkan akun Sales baru.';
      notifyListeners();
      return false;
    }

    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final newSales = UserModel(
        name: name,
        email: email,
        phone: phone,
        role: 'sales',
        isActive: true,
      );

      await _authService.registerSalesByManager(
        managerUser: _currentUser!,
        newSalesUser: newSales,
        password: password,
        linkGoogle: linkGoogle,
      );

      // Admin/Owner tetap login sebagai currentUser
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.authenticated;
      _errorMessage = _cleanErrorMessage(e.toString());
      notifyListeners();
      return false;
    }
  }

  // Tautkan Akun Google ke Profil Aktif
  Future<bool> linkGoogleAccount({String? googleEmail, String? photoUrl, String? googleId}) async {
    if (_currentUser == null) {
      _errorMessage = 'Tidak ada sesi pengguna aktif.';
      return false;
    }

    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedUser = await _authService.linkGoogleAccount(
        userId: _currentUser!.id,
        currentUserEmail: _currentUser!.email,
        googleEmail: googleEmail,
        googleId: googleId,
        photoUrl: photoUrl,
      );
      _currentUser = updatedUser;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.authenticated;
      _errorMessage = _cleanErrorMessage(e.toString());
      notifyListeners();
      return false;
    }
  }

  // Putuskan Tautan Akun Google dari Profil Aktif
  Future<bool> unlinkGoogleAccount() async {
    if (_currentUser == null) {
      _errorMessage = 'Tidak ada sesi pengguna aktif.';
      return false;
    }

    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedUser = await _authService.unlinkGoogleAccount(
        userId: _currentUser!.id,
        email: _currentUser!.email,
      );
      _currentUser = updatedUser;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.authenticated;
      _errorMessage = _cleanErrorMessage(e.toString());
      notifyListeners();
      return false;
    }
  }

  // Registrasi mandiri ditolak sesuai spesifikasi
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final newUser = UserModel(
        name: name,
        email: email,
        phone: phone,
        role: 'sales',
        isActive: true,
      );

      await _authService.register(newUser, password);
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = _cleanErrorMessage(e.toString());
      notifyListeners();
      return false;
    }
  }

  // Ambil daftar seluruh akun (untuk panel Keanggotaan)
  Future<List<UserModel>> getAllUsers() async {
    return await _authService.getAllUsers();
  }

  // FR11 | Ubah Password (Khusus Sales & Pengguna)
  Future<bool> updatePassword(String newPassword) async {
    if (_currentUser == null) {
      _errorMessage = 'Tidak ada sesi pengguna aktif.';
      return false;
    }
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.updatePassword(
        email: _currentUser!.email,
        newPassword: newPassword,
      );
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.authenticated;
      _errorMessage = _cleanErrorMessage(e.toString());
      notifyListeners();
      return false;
    }
  }

  // FR11 | Ubah Foto Profil (Untuk Setiap Role: Owner, Admin, Sales)
  Future<bool> updateProfilePhoto(String photoUrl) async {
    if (_currentUser == null) {
      _errorMessage = 'Tidak ada sesi pengguna aktif.';
      return false;
    }
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedUser = await _authService.updateProfilePhoto(
        email: _currentUser!.email,
        photoUrl: photoUrl,
      );
      _currentUser = updatedUser;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.authenticated;
      _errorMessage = _cleanErrorMessage(e.toString());
      notifyListeners();
      return false;
    }
  }

  // FR11 | Ubah Data Profil (Nama, Telepon, dsb)
  Future<bool> updateProfile({String? name, String? phone, String? photoUrl}) async {
    if (_currentUser == null) {
      _errorMessage = 'Tidak ada sesi pengguna aktif.';
      return false;
    }
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedUser = await _authService.updateUserProfile(
        email: _currentUser!.email,
        name: name,
        phone: phone,
        photoUrl: photoUrl,
      );
      _currentUser = updatedUser;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.authenticated;
      _errorMessage = _cleanErrorMessage(e.toString());
      notifyListeners();
      return false;
    }
  }

  // Ganti Role Demo (Admin, Owner, Sales) untuk kemudahan pengujian screen profil
  Future<bool> switchRoleDemo(String targetRole) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.getUserByRole(targetRole);
      if (user != null) {
        _currentUser = user;
        final authResponse = AuthResponseModel(
          token: 'demo_token_${user.id}_${DateTime.now().millisecondsSinceEpoch}',
          expiresAt: DateTime.now().add(const Duration(days: 7)),
          user: user,
        );
        await _sessionService.saveSession(authResponse);
        _status = AuthStatus.authenticated;
        notifyListeners();
        return true;
      }
      _status = AuthStatus.authenticated;
      return false;
    } catch (e) {
      _status = AuthStatus.authenticated;
      _errorMessage = _cleanErrorMessage(e.toString());
      notifyListeners();
      return false;
    }
  }

  // Logout & Cabut Sesi
  Future<void> logout() async {
    _status = AuthStatus.loading;
    notifyListeners();

    await _authService.logout();
    _currentUser = null;
    _token = null;
    _errorMessage = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    if (_status == AuthStatus.error) {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  String _cleanErrorMessage(String raw) {
    if (raw.startsWith('Exception: ')) {
      return raw.substring(11);
    }
    return raw;
  }
}
