import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shop_app/main.dart';
import 'package:shop_app/providers/auth_provider.dart';
import 'package:shop_app/routes.dart';
import 'package:shop_app/screens/tracking_sales/fr09_pengajuan_izin_screen.dart';
import 'package:shop_app/screens/tracking_sales/home_dashboard_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App renders login screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CV Maju Bersama'), findsOneWidget);
    expect(find.text('Masuk ke Sistem'), findsOneWidget);
  });

  testWidgets('Dashboard blocks unauthenticated user and displays restricted access',
      (WidgetTester tester) async {
    final authProvider = AuthProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ],
        child: MaterialApp(
          initialRoute: '/dashboard',
          routes: routes,
        ),
      ),
    );
    await tester.pump();

    // Verifikasi bahwa user yang belum login diblokir dari dashboard
    // Menampilkan pesan proteksi akses
    expect(find.text('Akses Dashboard Dibatasi'), findsOneWidget);
    expect(find.text('Masuk ke Akun (Login)'), findsOneWidget);
    // Menu privat tidak tampil untuk user yang belum login
    expect(find.text('Menu Navigasi FR (Tracking Sales)'), findsNothing);
  });

  testWidgets('Dashboard allows authenticated user to view menu and profile banner',
      (WidgetTester tester) async {
    final authProvider = AuthProvider();
    await tester.runAsync(() async {
      await authProvider.login('owner@majubersama.com', 'password123');
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ],
        child: const MaterialApp(
          home: HomeDashboardScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // User yang sudah login dapat mengakses dashboard
    expect(find.text('Akses Dashboard Dibatasi'), findsNothing);
    expect(find.text('Menu Navigasi FR (Tracking Sales)'), findsOneWidget);
    expect(find.text('Halo, Dimas Brahamsyah Santosa Putra!'), findsOneWidget);
    expect(find.text('Superadmin (Owner)'), findsOneWidget);
  });

  testWidgets('FR09 screen displays Daftar Izin Sales with Approve and Reject buttons for Admin',
      (WidgetTester tester) async {
    final authProvider = AuthProvider();
    await tester.runAsync(() async {
      await authProvider.login('admin@majubersama.com', 'password123');
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ],
        child: const MaterialApp(
          home: FR09PengajuanIzinScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verifikasi judul layar Admin/Owner adalah "Daftar Izin Sales"
    expect(find.text('Daftar Izin Sales'), findsOneWidget);
    expect(find.text('Pusat Verifikasi Izin Sales'), findsOneWidget);

    // Verifikasi daftar izin menampilkan nama sales pertama
    expect(find.text('Muhammad Ulil Abshor'), findsOneWidget);

    // Verifikasi tombol Approve dan Reject tersedia
    expect(find.text('Approve'), findsWidgets);
    expect(find.text('Reject'), findsWidgets);

    // Uji klik tombol Approve pada item pertama
    await tester.tap(find.text('Approve').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Disetujui (Approved)'), findsWidgets);
  });

  testWidgets('FR09 screen displays Pengajuan Izin Sales with submission form for Sales',
      (WidgetTester tester) async {
    final authProvider = AuthProvider();
    await tester.runAsync(() async {
      await authProvider.login('sales@majubersama.com', 'password123');
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ],
        child: const MaterialApp(
          home: FR09PengajuanIzinScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verifikasi judul layar Sales adalah "Pengajuan Izin Sales"
    expect(find.text('Pengajuan Izin Sales'), findsOneWidget);
    expect(find.text('Formulir Izin'), findsOneWidget);
    expect(find.text('Riwayat Saya'), findsOneWidget);
    expect(find.text('Kirim Pengajuan Izin'), findsOneWidget);
  });
}
