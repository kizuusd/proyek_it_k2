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
      expect(res.user.name, 'Dimas Brahamsyah Santosa Putra');
      expect(res.token.isNotEmpty, isTrue);
    });

    test('Login Administrator Sekretaris succeeds', () async {
      final res = await authService.loginWithEmail(
        'admin@majubersama.com',
        'password123',
      );
      expect(res.user.isAdmin, isTrue);
      expect(res.user.name, 'Agung Prasetyo Wibowo');
    });

    test('Login Sales Lapangan succeeds', () async {
      final res = await authService.loginWithEmail(
        'sales@majubersama.com',
        'password123',
      );
      expect(res.user.isSales, isTrue);
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

    test('FR12 Register new sales account', () async {
      final newUser = const UserModel(
        name: 'Budi Test Sales',
        email: 'buditest@majubersama.com',
        phone: '081299998888',
        role: 'sales',
        isActive: true,
      );

      final res = await authService.register(newUser, 'secret123');
      expect(res.user.name, 'Budi Test Sales');
      expect(res.user.role, 'sales');
      expect(res.user.isActive, isTrue);
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
  });
}
