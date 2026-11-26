import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shop_app/main.dart';
import 'package:shop_app/providers/auth_provider.dart';
import 'package:shop_app/routes.dart';
import 'package:shop_app/screens/tracking_sales/fr02_master_barang_screen.dart';
import 'package:shop_app/screens/tracking_sales/fr03_master_harga_screen.dart';
import 'package:shop_app/screens/tracking_sales/fr09_pengajuan_izin_screen.dart';
import 'package:shop_app/screens/tracking_sales/fr10_pengajuan_barang_screen.dart';
import 'package:shop_app/screens/tracking_sales/fr11_profil_screen.dart';
import 'package:shop_app/screens/tracking_sales/fr12_register_screen.dart';
import 'package:shop_app/screens/tracking_sales/home_dashboard_screen.dart';
import 'package:shop_app/services/inventory_service.dart';
import 'package:shop_app/services/stock_batch_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StockBatchService.clearCache();
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

  testWidgets('Login screen submits and navigates to dashboard on Enter key press',
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

    final emailFinder = find.byType(TextFormField).at(0);
    final passwordFinder = find.byType(TextFormField).at(1);

    await tester.enterText(emailFinder, 'owner@majubersama.com');
    await tester.enterText(passwordFinder, 'password123');
    await tester.showKeyboard(passwordFinder);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.byType(HomeDashboardScreen), findsOneWidget);
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
    await InventoryService.saveCachedRequests([]);

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
    expect(find.descendant(of: drawerFinder, matching: find.text('Data Barang')), findsOneWidget);
    expect(find.descendant(of: drawerFinder, matching: find.text('Daftar Harga')), findsOneWidget);
    expect(find.descendant(of: drawerFinder, matching: find.text('Jadwal Rute')), findsOneWidget);
    // Menu Pengajuan Barang tampil sebagai Penerimaan Pengajuan Barang untuk role Owner & Admin
    expect(find.descendant(of: drawerFinder, matching: find.text('Pengajuan Barang (Req)')), findsNothing);
    expect(find.descendant(of: drawerFinder, matching: find.text('Penerimaan Pengajuan Barang')), findsOneWidget);

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

    // Uji navigasi: Klik salah satu menu di sidebar (Data Barang)
    await tester.tap(find.descendant(of: drawerFinder, matching: find.text('Data Barang')));
    await tester.pumpAndSettle();

    // Layar Data Barang berhasil terbuka
    expect(find.text('Data Barang'), findsOneWidget);

    // Tekan tombol Back di AppBar -> langsung kembali ke Dashboard Sales dalam sekali klik
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(HomeDashboardScreen), findsOneWidget);
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
    expect(find.descendant(of: drawerFinder, matching: find.text('Data Barang')), findsNothing);
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

  testWidgets('FR10 Sales can submit daily batch request and automatically appear in Pendapatan Sales',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    addTearDown(() async {
      await InventoryService.clearCache();
      await StockBatchService.clearCache();
    });

    final testProduct = ProductItem(
      id: 1,
      kodeBarang: 'BRG-001',
      namaBarang: 'Plastik Kresek 1kg',
      kategori: 'Plastik',
      satuan: 'Pack',
      stokGudang: 120,
      stokSales: 15,
      harga: 15000,
      fotoUrl: 'preset:plastik',
    );
    await InventoryService.saveCachedProducts([testProduct]);
    await StockBatchService.saveCached([]);

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

    expect(find.text('Profil Sales'), findsOneWidget);
    expect(find.text('Batch Pengajuan Harian Saya'), findsOneWidget);
    expect(find.text('Ajukan Batch Barang'), findsOneWidget);
    expect(find.text('Tambah Barang'), findsNothing);

    // Sales membuka modal pengajuan batch harian dan menambah barang ke dalam batch
    await tester.tap(find.text('Ajukan Batch Barang'));
    await tester.pumpAndSettle();

    expect(find.text('Ajukan Batch Barang Harian'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, '12');
    await tester.tap(find.text('Tambah Item'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Plastik Kresek 1kg • 12 Pack'), findsOneWidget);

    await tester.tap(find.text('Kirim Batch Pengajuan'));
    await tester.pumpAndSettle();

    expect(find.text('Ajukan Batch Barang Harian'), findsNothing);
    expect(find.text('Menunggu Tinjauan'), findsWidgets);
    expect(find.text('Otomatis masuk ke Pendapatan Sales (Menunggu Opname)'), findsOneWidget);
  });

  testWidgets('FR02 Admin and Owner can add products in Master Barang',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    addTearDown(() async {
      await InventoryService.clearCache();
    });

    final adminProvider = AuthProvider();
    await tester.runAsync(() async {
      await adminProvider.login('admin@majubersama.com', 'password123');
    });
    await InventoryService.saveCachedRequests([]);

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
    expect(find.text('Simpan Produk'), findsNothing);

    await tester.tap(find.text('Tambah Barang'));
    await tester.pumpAndSettle();
    expect(find.text('Simpan Produk'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Simpan Produk'), findsNothing);

    await tester.tap(find.text('Tambah Barang'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(1), 'Plastik PP 25x35');
    await tester.enterText(find.byType(TextFormField).at(3), '50');
    await tester.tap(find.text('Simpan Produk'));
    await tester.pumpAndSettle();

    expect(find.text('Simpan Produk'), findsNothing);
    expect(find.text('Plastik PP 25x35'), findsWidgets);
  });

  testWidgets('FR10 Admin reviews batch and Owner performs final review on daily batch',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    addTearDown(() async {
      await InventoryService.clearCache();
      await StockBatchService.clearCache();
    });

    final adminProvider = AuthProvider();
    final ownerProvider = AuthProvider();
    await tester.runAsync(() async {
      await adminProvider.login('admin@majubersama.com', 'password123');
      await ownerProvider.login('owner@majubersama.com', 'password123');
    });

    final dummyBatch = StockBatch(
      id: 99,
      kodeBatch: 'BATCH-20261126-099',
      tanggal: '2026-11-26',
      salesId: 3,
      salesName: 'Muhammad Ulil Abshor',
      salesEmail: 'sales@majubersama.com',
      catatanPengajuan: 'Muatan harian',
      statusReview: StatusReviewBatch.menunggu,
      statusOpname: StatusOpnameBatch.belumOpname,
      items: [
        StockBatchItem(
          id: 9901,
          batchId: 99,
          productId: 1,
          kodeBarang: 'BRG-001',
          namaBarang: 'Plastik Kresek 1kg',
          satuan: 'Pack',
          hargaSatuan: 15000,
          qtyDiambil: 10,
        ),
      ],
    );
    await StockBatchService.saveCached([dummyBatch]);

    // 1. Admin meninjau batch terlebih dahulu
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: adminProvider),
        ],
        child: const MaterialApp(
          home: FR10PengajuanBarangScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tinjauan Pengajuan Barang (Batch)'), findsOneWidget);
    expect(find.text('Profil Admin'), findsOneWidget);
    expect(find.text('Tinjau Admin'), findsOneWidget);
    expect(find.text('Ajukan Batch Barang'), findsNothing);

    await tester.tap(find.text('Tinjau Admin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan Tinjauan Admin'));
    await tester.pumpAndSettle();

    expect(find.text('Ditinjau Admin'), findsWidgets);

    // 2. Owner meninjau dan menyetujui batch
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: ownerProvider),
        ],
        child: MaterialApp(
          key: UniqueKey(),
          home: const FR10PengajuanBarangScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Profil Owner'), findsOneWidget);
    expect(find.text('Setujui Owner'), findsOneWidget);

    await tester.tap(find.text('Setujui Owner'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Setujui Batch (Owner)'));
    await tester.pumpAndSettle();

    expect(find.text('Disetujui Owner'), findsWidgets);
  });

  testWidgets('FR03 Admin and Owner can view Master Harga, verify metric cards, and update product prices',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    addTearDown(() async {
      await InventoryService.clearCache();
    });

    final adminProvider = AuthProvider();
    await tester.runAsync(() async {
      await adminProvider.login('admin@majubersama.com', 'password123');
    });

    final testProduct = ProductItem(
      id: 1,
      kodeBarang: 'BRG-001',
      namaBarang: 'Plastik Kresek 1kg',
      kategori: 'Plastik',
      satuan: 'Pack',
      stokGudang: 120,
      stokSales: 15,
      harga: 15000,
      fotoUrl: 'preset:plastik',
    );
    await InventoryService.saveCachedProducts([testProduct]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: adminProvider),
        ],
        child: const MaterialApp(
          home: FR03MasterHargaScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verifikasi UI Header, Profil Banner, dan Summary Stat Cards
    expect(find.text('Master & Penetapan Harga Barang'), findsOneWidget);
    expect(find.text('Profil Admin'), findsOneWidget);
    expect(find.text('Total Produk'), findsOneWidget);
    expect(find.text('Rata-Rata Harga'), findsOneWidget);
    expect(find.text('Harga Tertinggi'), findsOneWidget);
    expect(find.text('Harga Terendah'), findsOneWidget);
    expect(find.text('Daftar & Pengaturan Harga Jual'), findsOneWidget);

    // 2. Verifikasi produk dan harga tampil di tabel
    expect(find.text('Plastik Kresek 1kg'), findsWidgets);
    expect(find.text('Rp 15.000'), findsWidgets);
    expect(find.text('Ubah'), findsOneWidget);

    // 3. Klik tombol Ubah untuk membuka dialog modal pengaturan harga
    await tester.tap(find.text('Ubah'));
    await tester.pumpAndSettle();

    expect(find.text('Ubah Harga Barang'), findsOneWidget);
    expect(find.text('Harga Jual Saat Ini:'), findsOneWidget);
    expect(find.text('+10%'), findsOneWidget);

    // 4. Klik chip +10% untuk kalkulasi otomatis markup
    await tester.tap(find.text('+10%'));
    await tester.pumpAndSettle();

    // 5. Simpan harga baru
    await tester.tap(find.text('Simpan Harga'));
    await tester.pumpAndSettle();

    // Dialog tertutup dan harga diperbarui
    expect(find.text('Ubah Harga Barang'), findsNothing);
    expect(find.text('Rp 16.500'), findsWidgets);
  });
}
