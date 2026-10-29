import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shop_app/main.dart';
import 'package:shop_app/providers/auth_provider.dart';
import 'package:shop_app/routes.dart';
import 'package:shop_app/screens/tracking_sales/fr02_master_barang_screen.dart';
import 'package:shop_app/screens/tracking_sales/fr09_pengajuan_izin_screen.dart';
import 'package:shop_app/screens/tracking_sales/fr10_pengajuan_barang_screen.dart';
import 'package:shop_app/screens/tracking_sales/fr11_profil_screen.dart';
import 'package:shop_app/screens/tracking_sales/fr12_register_screen.dart';
import 'package:shop_app/screens/tracking_sales/home_dashboard_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App renders login screen without debug chips and with Google login',
      (WidgetTester tester) async {
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

    // Verifikasi elemen debug/mock akun telah dihapus sepenuhnya
    expect(find.text('Akses Cepat Pengujian (Role Akun):'), findsNothing);
    expect(find.text('Nonaktif'), findsNothing);

    // Verifikasi tombol Google/Gmail login terhubung
    expect(find.text('Masuk dengan Google (Gmail)'), findsOneWidget);

    // Verifikasi info sales tidak bisa mendaftar mandiri
    expect(
      find.text(
        'Khusus akun Sales tidak dapat mendaftar mandiri. Akun Sales baru hanya dapat didaftarkan oleh Admin atau Owner perusahaan.',
      ),
      findsOneWidget,
    );
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
    expect(find.text('Akses Dashboard Dibatasi'), findsOneWidget);
    expect(find.text('Masuk ke Akun (Login)'), findsOneWidget);
    // Menu privat tidak tampil untuk user yang belum login
    expect(find.text('Ringkasan Kinerja Hari Ini'), findsNothing);
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
    expect(find.text('Ringkasan Kinerja Hari Ini'), findsOneWidget);
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

  testWidgets('FR12 Register screen restricts Sales role and allows Admin role',
      (WidgetTester tester) async {
    final salesProvider = AuthProvider();
    await tester.runAsync(() async {
      await salesProvider.login('sales@majubersama.com', 'password123');
    });

    // 1. Sales mengakses FR12 -> Akses dibatasi
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: salesProvider),
        ],
        child: const MaterialApp(
          home: FR12RegisterScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Akses Pendaftaran Dibatasi'), findsOneWidget);
    expect(find.text('Daftarkan Akun Sales'), findsWidgets);

    // 2. Admin mengakses FR12 -> Formulir pendaftaran manajerial tampil
    final adminProvider = AuthProvider();
    await tester.runAsync(() async {
      await adminProvider.login('admin@majubersama.com', 'password123');
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: adminProvider),
        ],
        child: const MaterialApp(
          home: FR12RegisterScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Akses Pendaftaran Dibatasi'), findsNothing);
    expect(find.text('Pendaftaran Akun Sales Baru'), findsOneWidget);
    expect(find.text('Nama Lengkap Sales'), findsOneWidget);
    expect(find.text('Email Sales / Gmail'), findsOneWidget);
  });

  testWidgets('Sidebar menu (Drawer) can be opened and contains all main menu modules',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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
    await tester.pumpAndSettle();

    // Buka sidebar menu melalui tombol hamburger di AppBar
    final hamburgerFinder = find.byIcon(Icons.menu_rounded);
    expect(hamburgerFinder, findsOneWidget);
    await tester.tap(hamburgerFinder);
    await tester.pumpAndSettle();

    final drawerFinder = find.byType(Drawer);
    expect(drawerFinder, findsOneWidget);

    // Verifikasi Header Sidebar Menu
    expect(find.descendant(of: drawerFinder, matching: find.text('CV MAJU BERSAMA')), findsOneWidget);
    expect(find.descendant(of: drawerFinder, matching: find.text('Dimas Brahamsyah Santosa Putra')), findsOneWidget);
    expect(find.descendant(of: drawerFinder, matching: find.text('Superadmin (Owner)')), findsOneWidget);

    // Verifikasi Modul Utama di dalam Sidebar Menu
    expect(find.descendant(of: drawerFinder, matching: find.text('NAVIGASI UTAMA')), findsOneWidget);
    expect(find.descendant(of: drawerFinder, matching: find.text('Dashboard Sales')), findsOneWidget);
    expect(find.descendant(of: drawerFinder, matching: find.text('MASTER DATA & LOGISTIK')), findsOneWidget);
    expect(find.descendant(of: drawerFinder, matching: find.text('Master Barang')), findsOneWidget);
    expect(find.descendant(of: drawerFinder, matching: find.text('Master Harga')), findsOneWidget);
    expect(find.descendant(of: drawerFinder, matching: find.text('Jadwal Rute')), findsOneWidget);
    // Menu Pengajuan Barang tidak ditampilkan untuk role Owner & Admin
    expect(find.descendant(of: drawerFinder, matching: find.text('Pengajuan Barang (Req)')), findsNothing);

    expect(find.descendant(of: drawerFinder, matching: find.text('OPERASIONAL SALES')), findsOneWidget);
    expect(find.descendant(of: drawerFinder, matching: find.text('Pendapatan Sales')), findsOneWidget);
    expect(find.descendant(of: drawerFinder, matching: find.text('Monitoring Posisi')), findsOneWidget);
    expect(find.descendant(of: drawerFinder, matching: find.text('Data Keanggotaan')), findsOneWidget);
    expect(find.descendant(of: drawerFinder, matching: find.text('Presensi & Absensi')), findsOneWidget);
    expect(find.descendant(of: drawerFinder, matching: find.text('Daftar Izin Sales')), findsOneWidget);

    // Modul Daftarkan Sales Baru tampil untuk Owner
    expect(find.descendant(of: drawerFinder, matching: find.text('Daftarkan Sales Baru')), findsOneWidget);

    expect(find.descendant(of: drawerFinder, matching: find.text('AKUN & PENGATURAN')), findsOneWidget);
    expect(find.descendant(of: drawerFinder, matching: find.text('Profil Saya')), findsOneWidget);
    expect(find.descendant(of: drawerFinder, matching: find.text('Keluar (Logout)')), findsOneWidget);

    // Uji navigasi: Klik salah satu menu di sidebar (Master Barang)
    await tester.tap(find.descendant(of: drawerFinder, matching: find.text('Master Barang')));
    await tester.pumpAndSettle();

    // Layar Master Barang berhasil terbuka
    expect(find.text('Master Barang Sales'), findsOneWidget);

    // Tekan tombol Back di AppBar -> langsung kembali ke Dashboard Sales dalam sekali klik
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard Sales'), findsOneWidget);
  });

  testWidgets('Sidebar menu can also be opened via Quick Action button on Dashboard',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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
          home: HomeDashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Buka sidebar menu melalui tombol hamburger di AppBar
    final hamburgerFinder = find.byIcon(Icons.menu_rounded);
    expect(hamburgerFinder, findsOneWidget);
    await tester.tap(hamburgerFinder);
    await tester.pumpAndSettle();

    final drawerFinder = find.byType(Drawer);
    expect(drawerFinder, findsOneWidget);

    // Verifikasi drawer terbuka dan role sales ditampilkan di dalam header drawer
    expect(find.descendant(of: drawerFinder, matching: find.text('Muhammad Ulil Abshor')), findsOneWidget);
    expect(find.descendant(of: drawerFinder, matching: find.text('Sales Lapangan')), findsOneWidget);
    expect(find.descendant(of: drawerFinder, matching: find.text('Pengajuan Barang (Req)')), findsOneWidget);
    expect(find.descendant(of: drawerFinder, matching: find.text('Pengajuan Izin Sales')), findsOneWidget);
    // Menu Master Barang dan Daftarkan Sales Baru TIDAK TAMPIL untuk role Sales
    expect(find.descendant(of: drawerFinder, matching: find.text('Master Barang')), findsNothing);
    expect(find.descendant(of: drawerFinder, matching: find.text('Daftarkan Sales Baru')), findsNothing);
  });

  testWidgets('Sales dashboard and profile reflect Google account linking status',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // 1. Ahmad (Sales belum tertaut Google)
    final salesProvider = AuthProvider();
    await tester.runAsync(() async {
      await salesProvider.login('ahmad.sales@majubersama.com', 'password123');
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: salesProvider),
        ],
        child: const MaterialApp(
          home: HomeDashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verifikasi banner rekomendasi penautan Google muncul di dashboard Sales
    expect(find.text('Tautkan Akun Google Anda'), findsOneWidget);
    expect(find.text('Masuk cepat di lapangan tanpa perlu ketik kata sandi.'), findsOneWidget);

    // 2. Buka FR11 Profil Screen untuk Sales
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: salesProvider),
        ],
        child: const MaterialApp(
          home: FR11ProfilScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tautan Akun Google Sales'), findsOneWidget);
    expect(find.text('Belum Terhubung'), findsOneWidget);
    expect(find.text('Tautkan dengan Akun Google'), findsOneWidget);

    // 3. Tautkan Akun Google
    await tester.runAsync(() async {
      await salesProvider.linkGoogleAccount(googleEmail: 'ahmad.sales@majubersama.com');
    });
    await tester.pumpAndSettle();

    expect(find.text('Terhubung'), findsOneWidget);
    expect(find.text('Putuskan Tautan Akun Google'), findsOneWidget);
  });

  testWidgets('FR10 Sales can submit stock request via Ajukan Barang without Tambah Barang button',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final salesProvider = AuthProvider();
    await tester.runAsync(() async {
      await salesProvider.login('sales@majubersama.com', 'password123');
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: salesProvider),
        ],
        child: const MaterialApp(
          home: FR10PengajuanBarangScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verifikasi tombol Tambah Barang sudah dihapus untuk Sales dan diganti dengan Ajukan Barang
    expect(find.text('Profil Sales'), findsOneWidget);
    expect(find.text('Pengajuan Stok'), findsWidgets);
    expect(find.text('Belum ada data pengajuan stok pada filter ini.'), findsOneWidget);
    expect(find.text('Tambah Barang'), findsNothing);
    expect(find.text('Ajukan Pengajuan'), findsNothing);
    expect(find.text('Ajukan Barang'), findsOneWidget);
    expect(find.text('Ajukan Pengajuan Barang'), findsNothing);

    // 2. Uji Sales membuka pop-up "Ajukan Barang" dan mengirim pengajuan stok
    await tester.tap(find.text('Ajukan Barang'));
    await tester.pumpAndSettle();

    expect(find.text('Ajukan Pengajuan Barang'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Plastik Kresek 1kg',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      '5',
    );
    await tester.enterText(
      find.byType(TextFormField).at(2),
      'Stok plastik di toko hampir habis, mohon untuk ditambahkan.',
    );
    await tester.tap(find.text('Kirim Pengajuan'));
    await tester.pumpAndSettle();

    // Pop-up tertutup dan data masuk ke tabel dengan status Menunggu
    expect(find.text('Ajukan Pengajuan Barang'), findsNothing);
    expect(find.text('Menunggu'), findsWidgets);
  });

  testWidgets('FR02 & FR10 Sales, Admin, and Owner can add products and approve sales stock requests',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final adminProvider = AuthProvider();
    await tester.runAsync(() async {
      await adminProvider.login('admin@majubersama.com', 'password123');
    });

    // 1. Uji Manajemen Produk (FR02) untuk Admin / Owner & Sales
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: adminProvider),
        ],
        child: const MaterialApp(
          home: FR02MasterBarangScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Profil Admin'), findsOneWidget);
    expect(find.text('Manajemen Produk'), findsOneWidget);
    expect(find.text('Tambah Barang'), findsOneWidget);
    // Pastikan form tidak tampil di bawah tabel sebelum pop-up dibuka
    expect(find.text('Simpan Produk'), findsNothing);

    // Buka pop-up Tambah Barang lalu tutup (close X) -> pastikan hilang dan tidak tampil di bawahnya
    await tester.tap(find.text('Tambah Barang'));
    await tester.pumpAndSettle();
    expect(find.text('Simpan Produk'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Simpan Produk'), findsNothing);

    // Buka kembali pop-up Tambah Barang dan simpan produk baru
    await tester.tap(find.text('Tambah Barang'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Plastik PP 25x35',
    );
    await tester.enterText(
      find.byType(TextFormField).at(3),
      '50',
    );
    await tester.tap(find.text('Simpan Produk'));
    await tester.pumpAndSettle();

    expect(find.text('Simpan Produk'), findsNothing);
    expect(find.text('Plastik PP 25x35'), findsWidgets);

    // 2. Uji Pengajuan Stok oleh Sales di FR10, lalu Persetujuan oleh Admin/Owner di FR02
    final salesProvider = AuthProvider();
    await tester.runAsync(() async {
      await salesProvider.login('sales@majubersama.com', 'password123');
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: salesProvider),
        ],
        child: const MaterialApp(
          home: FR10PengajuanBarangScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ajukan Barang'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '5');
    await tester.enterText(find.byType(TextFormField).at(1), 'Kebutuhan stok kanvas sales');
    await tester.tap(find.text('Kirim Pengajuan'));
    await tester.pumpAndSettle();

    // 3. Admin / Owner membuka Master Barang (FR02) dan menyetujui pengajuan stok dari Sales
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: adminProvider),
        ],
        child: MaterialApp(
          home: FR02MasterBarangScreen(key: UniqueKey()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Setujui & Tambah Stok'), findsWidgets);
    await tester.tap(find.text('Setujui & Tambah Stok').first);
    await tester.pumpAndSettle();

    expect(find.text('Setujui & Tambah Stok'), findsNothing);
  });
}
