import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shop_app/models/user_model.dart';
import 'package:shop_app/providers/auth_provider.dart';
import 'package:shop_app/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AuthService & UserModel Unit Tests', () {
    final authService = AuthService();

    test('Login Superadmin Owner succeeds and assigns correct role', () async {
      final res = await authService.loginWithEmail(
        'owner@majubersama.com',
        'password123',
      );
      expect(res.user.role, 'superadmin');
      expect(res.user.isSuperAdmin, isTrue);
      expect(res.user.isManager, isTrue);
      expect(res.user.name, 'Dimas Brahamsyah Santosa Putra');
      expect(res.token.isNotEmpty, isTrue);
    });

    test('Login Administrator Sekretaris succeeds', () async {
      final res = await authService.loginWithEmail(
        'admin@majubersama.com',
        'password123',
      );
      expect(res.user.isAdmin, isTrue);
      expect(res.user.isManager, isTrue);
      expect(res.user.name, 'Agung Prasetyo Wibowo');
    });

    test('Login Sales Lapangan succeeds', () async {
      final res = await authService.loginWithEmail(
        'sales@majubersama.com',
        'password123',
      );
      expect(res.user.isSales, isTrue);
      expect(res.user.isManager, isFalse);
      expect(res.user.name, 'Muhammad Ulil Abshor');
    });

    test('Login Inactive account throws specific error message', () async {
      expect(
        () => authService.loginWithEmail(
          'inactive@majubersama.com',
          'password123',
        ),
        throwsA(predicate((e) =>
            e.toString().contains('Akun Anda dinonaktifkan. Hubungi Administrator.'))),
      );
    });

    test('Login with wrong password throws error', () async {
      expect(
        () => authService.loginWithEmail(
          'owner@majubersama.com',
          'wrongpass',
        ),
        throwsA(predicate((e) =>
            e.toString().contains('Password yang Anda masukkan salah'))),
      );
    });

    test('Sales self-registration is blocked', () async {
      const newUser = UserModel(
        name: 'Sales Mandiri',
        email: 'mandiri@majubersama.com',
        phone: '081299998888',
        role: 'sales',
        isActive: true,
      );

      expect(
        () => authService.register(newUser, 'secret123'),
        throwsA(predicate((e) =>
            e.toString().contains('Pendaftaran mandiri akun Sales tidak diizinkan'))),
      );
    });

    test('Owner & Admin can register new sales account', () async {
      final ownerRes = await authService.loginWithEmail(
        'owner@majubersama.com',
        'password123',
      );

      const newSales = UserModel(
        name: 'Budi Test Sales',
        email: 'buditest@majubersama.com',
        phone: '081299998888',
        role: 'sales',
        isActive: true,
      );

      final registeredUser = await authService.registerSalesByManager(
        managerUser: ownerRes.user,
        newSalesUser: newSales,
        password: 'secret123',
      );
      expect(registeredUser.name, 'Budi Test Sales');
      expect(registeredUser.role, 'sales');
      expect(registeredUser.isActive, isTrue);

      // Verify newly registered sales can log in with their credentials
      final freshAuthService = AuthService();
      final loginAfterRegister = await freshAuthService.loginWithEmail(
        'buditest@majubersama.com',
        'secret123',
      );
      expect(loginAfterRegister.user.name, 'Budi Test Sales');
      expect(loginAfterRegister.user.isSales, isTrue);
    });

    test('Sales user cannot register another sales account (Access Denied)', () async {
      final salesRes = await authService.loginWithEmail(
        'sales@majubersama.com',
        'password123',
      );

      const illegalSales = UserModel(
        name: 'Illegal Sales',
        email: 'illegal@majubersama.com',
        role: 'sales',
      );

      expect(
        () => authService.registerSalesByManager(
          managerUser: salesRes.user,
          newSalesUser: illegalSales,
          password: 'secret123',
        ),
        throwsA(predicate((e) => e.toString().contains('Akses ditolak'))),
      );
    });

    test('Google Login succeeds for pre-registered sales account', () async {
      final res = await authService.loginWithGoogle(testEmail: 'sales@majubersama.com');
      expect(res.user.isSales, isTrue);
      expect(res.user.email, 'sales@majubersama.com');
      expect(res.token.isNotEmpty, isTrue);
    });

    test('Google Login is rejected for unregistered account', () async {
      expect(
        () => authService.loginWithGoogle(testEmail: 'unregistered.sales@gmail.com'),
        throwsA(predicate((e) =>
            e.toString().contains('belum terdaftar dalam sistem'))),
      );
    });
  });

  group('AuthProvider State Management Tests', () {
    test('Initial checkAuthSession on empty storage results in unauthenticated', () async {
      final provider = AuthProvider();
      await provider.checkAuthSession();
      expect(provider.status, AuthStatus.unauthenticated);
      expect(provider.isAuthenticated, isFalse);
    });

    test('Login updates provider state to authenticated', () async {
      final provider = AuthProvider();
      final success = await provider.login('owner@majubersama.com', 'password123');
      expect(success, isTrue);
      expect(provider.status, AuthStatus.authenticated);
      expect(provider.currentUser?.name, 'Dimas Brahamsyah Santosa Putra');

      // Test session recovery (auto-login simulation)
      final newProvider = AuthProvider();
      await newProvider.checkAuthSession();
      expect(newProvider.isAuthenticated, isTrue);
      expect(newProvider.currentUser?.email, 'owner@majubersama.com');

      // Test logout
      await newProvider.logout();
      expect(newProvider.isAuthenticated, isFalse);
      expect(newProvider.status, AuthStatus.unauthenticated);
    });

    test('Admin/Owner can register sales via AuthProvider and remains logged in', () async {
      final provider = AuthProvider();
      await provider.login('admin@majubersama.com', 'password123');
      expect(provider.currentUser?.isAdmin, isTrue);

      final registered = await provider.registerSalesAccount(
        name: 'Sales Baru Admin',
        email: 'salesbaru.admin@gmail.com',
        phone: '081211112222',
        password: 'password123',
      );
      expect(registered, isTrue);
      // Verify Admin is still the active logged in user
      expect(provider.currentUser?.isAdmin, isTrue);
      expect(provider.currentUser?.name, 'Agung Prasetyo Wibowo');

      // Verify newly registered user can now log in with Google (Gmail)
      final googleLoginProvider = AuthProvider();
      final googleSuccess = await googleLoginProvider.loginWithGoogle(
        testEmail: 'salesbaru.admin@gmail.com',
      );
      expect(googleSuccess, isTrue);
      expect(googleLoginProvider.currentUser?.name, 'Sales Baru Admin');
      expect(googleLoginProvider.currentUser?.isSales, isTrue);
    });

    test('FR11 Sales role can change password', () async {
      final provider = AuthProvider();
      await provider.login('sales@majubersama.com', 'password123');
      expect(provider.currentUser?.isSales, isTrue);

      final updateSuccess = await provider.updatePassword('salesnewpassword456');
      expect(updateSuccess, isTrue);

      // Verify login with new password
      final freshAuthService = AuthService();
      final loginResult = await freshAuthService.loginWithEmail(
        'sales@majubersama.com',
        'salesnewpassword456',
      );
      expect(loginResult.user.email, 'sales@majubersama.com');
    });

    test('FR11 Update profile photo for roles', () async {
      final provider = AuthProvider();
      await provider.login('owner@majubersama.com', 'password123');

      const newPhoto = 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d';
      final photoSuccess = await provider.updateProfilePhoto(newPhoto);
      expect(photoSuccess, isTrue);
      expect(provider.currentUser?.photoUrl, newPhoto);
    });

    test('FR11 User can link and unlink Google Account in Profile', () async {
      final provider = AuthProvider();
      await provider.login('sales@majubersama.com', 'password123');
      expect(provider.currentUser?.googleId != null, isTrue);

      // Unlink Google
      final unlinkSuccess = await provider.unlinkGoogleAccount();
      expect(unlinkSuccess, isTrue);
      expect(provider.currentUser?.googleId, isNull);

      // Link Google again with Gmail
      final linkSuccess = await provider.linkGoogleAccount(googleEmail: 'sales@majubersama.com');
      expect(linkSuccess, isTrue);
      expect(provider.currentUser?.googleId != null, isTrue);
    });

    test('FR11 Sales account can link Google account and subsequently login via Google', () async {
      final provider = AuthProvider();
      // Login with password as Ahmad (Sales who has no Google ID initially)
      final loginOk = await provider.login('ahmad.sales@majubersama.com', 'password123');
      expect(loginOk, isTrue);
      expect(provider.currentUser?.isSales, isTrue);
      expect(provider.currentUser?.googleId, isNull);

      // Tautkan Akun Google
      final linkOk = await provider.linkGoogleAccount(googleEmail: 'ahmad.sales@majubersama.com');
      expect(linkOk, isTrue);
      expect(provider.currentUser?.googleId, isNotNull);

      // Logout
      await provider.logout();
      expect(provider.isAuthenticated, isFalse);

      // Login via Google sekarang berhasil
      final googleLoginOk = await provider.loginWithGoogle(testEmail: 'ahmad.sales@majubersama.com');
      expect(googleLoginOk, isTrue);
      expect(provider.currentUser?.email, 'ahmad.sales@majubersama.com');
      expect(provider.currentUser?.isSales, isTrue);
      expect(provider.currentUser?.googleId, isNotNull);
    });

    test('FR11 Sales account can link custom Gmail address and login with that Gmail', () async {
      final provider = AuthProvider();
      await provider.login('ahmad.sales@majubersama.com', 'password123');

      // Tautkan personal Gmail berbeda dari email perusahaan
      final linkOk = await provider.linkGoogleAccount(googleEmail: 'ahmad.personal@gmail.com');
      expect(linkOk, isTrue);
      expect(provider.currentUser?.googleId, isNotNull);
      expect(provider.currentUser?.googleEmail, 'ahmad.personal@gmail.com');
      expect(provider.currentUser?.displayGoogleEmail, 'ahmad.personal@gmail.com');

      // Logout
      await provider.logout();

      // Login dengan Gmail pribadi tersebut
      final googleLoginOk = await provider.loginWithGoogle(testEmail: 'ahmad.personal@gmail.com');
      expect(googleLoginOk, isTrue);
      expect(provider.currentUser?.name, 'Ahmad Hidayat');
      expect(provider.currentUser?.email, 'ahmad.sales@majubersama.com');
      expect(provider.currentUser?.googleEmail, 'ahmad.personal@gmail.com');
    });

    test('FR11 Role switching demo loads correct role profiles', () async {
      final provider = AuthProvider();
      await provider.login('owner@majubersama.com', 'password123');

      // Switch to Admin
      await provider.switchRoleDemo('admin');
      expect(provider.currentUser?.isAdmin, isTrue);
      expect(provider.currentUser?.name, 'Agung Prasetyo Wibowo');

      // Switch to Sales
      await provider.switchRoleDemo('sales');
      expect(provider.currentUser?.isSales, isTrue);
      expect(provider.currentUser?.name, 'Muhammad Ulil Abshor');

      // Switch to Owner
      await provider.switchRoleDemo('owner');
      expect(provider.currentUser?.isSuperAdmin, isTrue);
      expect(provider.currentUser?.name, 'Dimas Brahamsyah Santosa Putra');
    });
  });
}
