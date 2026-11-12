import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shop_app/models/user_model.dart';
import 'package:shop_app/providers/auth_provider.dart';
import 'package:shop_app/screens/tracking_sales/fr02_master_barang_screen.dart';
import 'package:shop_app/screens/tracking_sales/fr03_master_harga_screen.dart';
import 'package:shop_app/screens/tracking_sales/fr04_jadwal_rute_screen.dart';
import 'package:shop_app/screens/tracking_sales/fr05_pendapatan_screen.dart';
import 'package:shop_app/screens/tracking_sales/fr06_monitoring_posisi_screen.dart';
import 'package:shop_app/screens/tracking_sales/fr07_keanggotaan_screen.dart';
import 'package:shop_app/screens/tracking_sales/fr08_absensi_screen.dart';
import 'package:shop_app/screens/tracking_sales/fr11_profil_screen.dart';
import 'package:shop_app/screens/tracking_sales/home_dashboard_screen.dart';
import 'package:shop_app/services/attendance_service.dart';
import 'package:shop_app/services/auth_service.dart';
import 'package:shop_app/services/inventory_service.dart';
import 'package:shop_app/services/monitoring_service.dart';
import 'package:shop_app/services/route_service.dart';
import 'package:shop_app/services/transaction_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await InventoryService.clearCache();
    await AttendanceService.clearCache();
    await RouteService.clearCache();
    await TransactionService.clearCache();
  });

  group('Doc 01 — Profil & Ubah Password', () {
    test('Rejects wrong old password and same new password, succeeds on valid input', () async {
      final authService = AuthService();

      expect(
        () => authService.updatePassword(
          email: 'sales@majubersama.com',
          oldPassword: 'wrong_password',
          newPassword: 'newpassword123',
        ),
        throwsA(predicate((e) => e.toString().contains('Password lama yang Anda masukkan salah'))),
      );

      expect(
        () => authService.updatePassword(
          email: 'sales@majubersama.com',
          oldPassword: 'password123',
          newPassword: 'password123',
        ),
        throwsA(predicate((e) => e.toString().contains('tidak boleh sama'))),
      );

      final ok = await authService.updatePassword(
        email: 'sales@majubersama.com',
        oldPassword: 'password123',
        newPassword: 'salesnew789',
      );
      expect(ok, isTrue);

      final loginNew = await authService.loginWithEmail('sales@majubersama.com', 'salesnew789');
      expect(loginNew.user.email, 'sales@majubersama.com');
    });

    testWidgets('FR11ProfilScreen shows Password Lama, Password Baru, Konfirmasi Password Baru',
        (WidgetTester tester) async {
      final provider = AuthProvider();
      await tester.runAsync(() async {
        await provider.login('sales@majubersama.com', 'password123');
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider<AuthProvider>.value(value: provider)],
          child: const MaterialApp(home: FR11ProfilScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Password Lama'), findsOneWidget);
      expect(find.text('Password Baru'), findsOneWidget);
      expect(find.text('Konfirmasi Password Baru'), findsOneWidget);
    });
  });

  group('Doc 02 — Data Barang Sales untuk Role Sales', () {
    testWidgets('Sales can see Data Barang Sales menu and active product catalog with detail only',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await InventoryService.saveCachedProducts([
        ProductItem(
          id: 1,
          kodeBarang: 'BRG-001',
          namaBarang: 'Plastik Kresek 1kg',
          kategori: 'Plastik',
          deskripsi: 'Plastik tebal untuk toko',
          harga: 15000,
          stokGudang: 100,
          stokSales: 15,
          isActive: true,
        ),
        ProductItem(
          id: 2,
          kodeBarang: 'BRG-002',
          namaBarang: 'Barang Gudang Saja',
          kategori: 'Sembako',
          harga: 20000,
          stokGudang: 200,
          stokSales: 0,
          isActive: true,
        ),
        ProductItem(
          id: 3,
          kodeBarang: 'BRG-003',
          namaBarang: 'Produk Nonaktif Rahasia',
          kategori: 'Lainnya',
          harga: 30000,
          stokGudang: 50,
          stokSales: 10,
          isActive: false,
        ),
      ]);

      final salesProvider = AuthProvider();
      await tester.runAsync(() async {
        await salesProvider.login('sales@majubersama.com', 'password123');
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider<AuthProvider>.value(value: salesProvider)],
          child: const MaterialApp(home: HomeDashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Quick Action Barang Sales tersedia di Dashboard Sales
      expect(find.text('Barang Sales'), findsOneWidget);

      // Drawer memuat "Data Barang Sales" untuk role Sales
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();
      final drawerFinder = find.byType(Drawer);
      expect(find.descendant(of: drawerFinder, matching: find.text('Data Barang Sales')), findsOneWidget);

      // Navigasi ke Data Barang Sales
      await tester.tap(find.descendant(of: drawerFinder, matching: find.text('Data Barang Sales')));
      await tester.pumpAndSettle();

      expect(find.byType(FR02MasterBarangScreen), findsOneWidget);
      expect(find.text('Data Barang Sales'), findsOneWidget);
      expect(find.text('Barang yang Dibawa Sales'), findsOneWidget);
      expect(find.text('Stok Dibawa'), findsOneWidget);
      expect(find.text('Stok Gudang'), findsNothing);
      expect(find.text('Plastik Kresek 1kg'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(find.text('100'), findsNothing);
      expect(find.text('Barang Gudang Saja'), findsNothing);
      expect(find.text('Produk Nonaktif Rahasia'), findsNothing);
      expect(find.text('Tambah Barang'), findsNothing);
      expect(find.text('Detail'), findsOneWidget);

      // Buka Detail barang
      await tester.tap(find.text('Detail'));
      await tester.pumpAndSettle();
      expect(find.text('Harga Berlaku'), findsOneWidget);
      expect(find.text('Stok Dibawa Sales'), findsOneWidget);
      expect(find.text('15 Pack'), findsOneWidget);
      expect(find.text('Plastik tebal untuk toko'), findsOneWidget);
    });
  });

  group('Doc 03 — Harga Produk & Riwayat Harga', () {
    test('updateProductPrice saves price history and closes previous active price', () async {
      await InventoryService.updateProductPrice(
        1,
        17500,
        updatedBy: 2,
        updatedByName: 'Agung Prasetyo Wibowo',
        keterangan: 'Penyesuaian harga Q4',
      );

      final history = await InventoryService.fetchPriceHistory(1);
      expect(history.length, greaterThanOrEqualTo(2));
      expect(history.first.hargaJual, 17500);
      expect(history.first.keterangan, 'Penyesuaian harga Q4');
      expect(history.first.isCurrentlyActive, isTrue);
      expect(history[1].isCurrentlyActive, isFalse);
    });

    testWidgets('FR03 hides inactive products from Sales and displays Riwayat Harga',
        (WidgetTester tester) async {
      await InventoryService.saveCachedProducts([
        ProductItem(
          id: 1,
          kodeBarang: 'BRG-001',
          namaBarang: 'Produk Aktif',
          harga: 15000,
          stokGudang: 10,
          isActive: true,
        ),
        ProductItem(
          id: 2,
          kodeBarang: 'BRG-002',
          namaBarang: 'Produk Nonaktif',
          harga: 25000,
          stokGudang: 10,
          isActive: false,
        ),
      ]);

      final salesProvider = AuthProvider();
      await tester.runAsync(() async {
        await salesProvider.login('sales@majubersama.com', 'password123');
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider<AuthProvider>.value(value: salesProvider)],
          child: const MaterialApp(home: FR03MasterHargaScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Produk Aktif'), findsWidgets);
      expect(find.text('Produk Nonaktif'), findsNothing);
      expect(find.byIcon(Icons.history_rounded), findsOneWidget);
    });
  });

  group('Doc 04 — Keanggotaan Sales', () {
    test('Admin can suspend Sales and record status history; Sales cannot change status', () async {
      final authService = AuthService();
      final admin = (await authService.loginWithEmail('admin@majubersama.com', 'password123')).user;
      final sales = (await authService.loginWithEmail('ahmad.sales@majubersama.com', 'password123')).user;

      expect(
        () => authService.updateMembershipStatus(
          targetUserId: 3,
          actor: sales,
          membershipStatus: 'nonaktif',
          reason: 'Coba ubah sendiri',
        ),
        throwsA(predicate((e) => e.toString().contains('Akses ditolak'))),
      );

      final updated = await authService.updateMembershipStatus(
        targetUserId: sales.id!,
        actor: admin,
        membershipStatus: 'ditangguhkan',
        reason: 'Evaluasi bulanan',
      );
      expect(updated.membershipStatus, 'ditangguhkan');
      expect(updated.isActive, isFalse);

      final logs = await authService.getMembershipStatusHistory(sales.id!);
      expect(logs.isNotEmpty, isTrue);
      expect(logs.first.newStatus, 'ditangguhkan');
      expect(logs.first.reason, 'Evaluasi bulanan');
    });

    testWidgets('FR07 shows personal membership card for Sales', (WidgetTester tester) async {
      final salesProvider = AuthProvider();
      await tester.runAsync(() async {
        await salesProvider.login('sales@majubersama.com', 'password123');
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider<AuthProvider>.value(value: salesProvider)],
          child: const MaterialApp(home: FR07KeanggotaanScreen()),
        ),
      );
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      expect(find.text('Keanggotaan Saya'), findsOneWidget);
      expect(find.text('Edit Informasi Pribadi'), findsOneWidget);
    });
  });

  group('Doc 05 — Absensi Sales', () {
    test('Check-in prevents duplicates, check-out calculates duration, Admin can correct with audit trail',
        () async {
      final rec = await AttendanceService.checkIn(
        salesId: 3,
        salesName: 'Muhammad Ulil Abshor',
        salesEmail: 'sales@majubersama.com',
        catatan: 'Masuk pagi',
      );
      expect(rec.checkinTime, isNotNull);

      expect(
        () => AttendanceService.checkIn(
          salesId: 3,
          salesName: 'Muhammad Ulil Abshor',
          salesEmail: 'sales@majubersama.com',
        ),
        throwsA(predicate((e) => e.toString().contains('sudah melakukan check-in'))),
      );

      final outRec = await AttendanceService.checkOut(
        salesId: 3,
        salesEmail: 'sales@majubersama.com',
      );
      expect(outRec.checkoutTime, isNotNull);
      expect(outRec.durasiKerja, isNotNull);

      final corrected = await AttendanceService.correctAttendance(
        attendanceId: outRec.id,
        actorId: 2,
        actorEmail: 'admin@majubersama.com',
        actorName: 'Agung Prasetyo Wibowo',
        status: 'hadir',
        checkinTime: '08:00',
        checkoutTime: '17:00',
        reason: 'Koreksi jam kerja sesuai surat tugas',
      );
      expect(corrected.status, 'hadir');
      expect(corrected.durasiKerja, 540);

      final corrLogs = await AttendanceService.fetchCorrections(outRec.id);
      expect(corrLogs.length, 1);
      expect(corrLogs.first.reason, 'Koreksi jam kerja sesuai surat tugas');
    });

    testWidgets('FR08 renders Check-In and Check-Out buttons for Sales', (WidgetTester tester) async {
      final salesProvider = AuthProvider();
      await tester.runAsync(() async {
        await salesProvider.login('sales@majubersama.com', 'password123');
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider<AuthProvider>.value(value: salesProvider)],
          child: const MaterialApp(home: FR08AbsensiScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Status Absensi Hari Ini'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Check-In'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Check-Out'), findsOneWidget);
    });
  });

  group('Doc 06 — Penjadwalan Rute Sales', () {
    test('Detects schedule conflict and validates end time after start time', () async {
      final today = RouteService.todayYmd();
      expect(
        () => RouteService.createRoute(
          actorId: 2,
          actorEmail: 'admin@majubersama.com',
          salesId: 3,
          salesName: 'Muhammad Ulil Abshor',
          isSalesActive: true,
          tanggal: today,
          waktuMulai: '11:00',
          waktuSelesai: '10:00',
          namaTujuan: 'Toko Invalid',
          alamatTujuan: 'Jl. Test',
          urutan: 3,
        ),
        throwsA(predicate((e) => e.toString().contains('lebih akhir'))),
      );

      // Default route for sales 3 is 08:30-09:30 -> 09:00-10:00 should conflict
      expect(
        () => RouteService.createRoute(
          actorId: 2,
          actorEmail: 'admin@majubersama.com',
          salesId: 3,
          salesName: 'Muhammad Ulil Abshor',
          isSalesActive: true,
          tanggal: today,
          waktuMulai: '09:00',
          waktuSelesai: '10:00',
          namaTujuan: 'Toko Bentrok',
          alamatTujuan: 'Jl. Test',
          urutan: 3,
        ),
        throwsA(predicate((e) => e.toString().contains('bentrok'))),
      );

      final created = await RouteService.createRoute(
        actorId: 2,
        actorEmail: 'admin@majubersama.com',
        salesId: 3,
        salesName: 'Muhammad Ulil Abshor',
        isSalesActive: true,
        tanggal: today,
        waktuMulai: '13:00',
        waktuSelesai: '14:00',
        namaTujuan: 'Toko Lancar',
        alamatTujuan: 'Jl. Pahlawan 9',
        urutan: 3,
      );
      expect(created.namaTujuan, 'Toko Lancar');
    });

    testWidgets('FR04 renders Sales visit update UI', (WidgetTester tester) async {
      final salesProvider = AuthProvider();
      await tester.runAsync(() async {
        await salesProvider.login('sales@majubersama.com', 'password123');
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider<AuthProvider>.value(value: salesProvider)],
          child: const MaterialApp(home: FR04PenjadwalanRuteScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Penjadwalan Rute'), findsOneWidget);
      expect(find.text('Update Status Kunjungan'), findsWidgets);
    });
  });

  group('Doc 07 — Pencatatan Pendapatan Sales', () {
    test('Preserves historical price snapshot and blocks direct edit on approved transaction', () async {
      await InventoryService.saveCachedProducts([
        ProductItem(
          id: 1,
          kodeBarang: 'BRG-001',
          namaBarang: 'Plastik Kresek 1kg',
          harga: 15000,
          stokGudang: 100,
          isActive: true,
        ),
      ]);

      final tx = await TransactionService.createTransaction(
        salesId: 3,
        salesName: 'Muhammad Ulil Abshor',
        isSalesActive: true,
        tanggal: TransactionService.todayYmd(),
        namaPelanggan: 'Toko Maju',
        catatan: 'Order perdana',
        items: [
          {'product_id': 1, 'qty': 4},
        ],
      );
      expect(tx.total, 60000);
      expect(tx.items.first.hargaSatuan, 15000);

      // Update master price to 20000 -> old tx snapshot must stay 15000 / total 60000
      await InventoryService.updateProductPrice(1, 20000);
      final allTxs = await TransactionService.loadCached();
      final savedTx = allTxs.firstWhere((t) => t.id == tx.id);
      expect(savedTx.total, 60000);
      expect(savedTx.items.first.hargaSatuan, 15000);

      // Approve and verify direct re-verification is blocked
      final approved = await TransactionService.verifyTransaction(
        transactionId: tx.id,
        actorId: 2,
        actorEmail: 'admin@majubersama.com',
        actorName: 'Agung Prasetyo Wibowo',
        status: StatusVerifikasiTransaksi.disetujui,
      );
      expect(approved.statusVerifikasi, StatusVerifikasiTransaksi.disetujui);

      expect(
        () => TransactionService.verifyTransaction(
          transactionId: tx.id,
          actorId: 2,
          actorEmail: 'admin@majubersama.com',
          actorName: 'Agung Prasetyo Wibowo',
          status: StatusVerifikasiTransaksi.ditolak,
          alasanPenolakan: 'Ubah langsung',
        ),
        throwsA(predicate((e) => e.toString().contains('tidak dapat diedit langsung'))),
      );
    });

    testWidgets('FR05 renders Sales income screen with Catat Penjualan button',
        (WidgetTester tester) async {
      final salesProvider = AuthProvider();
      await tester.runAsync(() async {
        await salesProvider.login('sales@majubersama.com', 'password123');
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider<AuthProvider>.value(value: salesProvider)],
          child: const MaterialApp(home: FR05PendapatanScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Total Omzet Penjualan (Disetujui)'), findsOneWidget);
      expect(find.text('Catat Penjualan'), findsOneWidget);
    });
  });

  group('Doc 08 — Monitoring Sales', () {
    test('Summary computes approved omzet only from approved transactions', () async {
      const admin = UserModel(
        id: 2,
        name: 'Agung Prasetyo Wibowo',
        email: 'admin@majubersama.com',
        role: 'administrator',
      );
      final summary = await MonitoringService.loadSummary(currentUser: admin);
      // Default transactions: id 1 disetujui (370000), id 2 menunggu (185000), id 3 ditolak (220000)
      expect(summary.approvedOmzet, 370000);
      expect(summary.approvedTxCount, 1);
      expect(summary.pendingTxCount, 1);
      expect(summary.rejectedTxCount, 1);
    });

    testWidgets('FR06 renders Monitoring dashboard without Google Maps placeholder',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final adminProvider = AuthProvider();
      await tester.runAsync(() async {
        await adminProvider.login('admin@majubersama.com', 'password123');
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider<AuthProvider>.value(value: adminProvider)],
          child: const MaterialApp(home: FR06MonitoringPosisiScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Google Maps Placeholder'), findsNothing);
      expect(find.text('Monitoring Kinerja Sales'), findsOneWidget);
      expect(find.text('Definisi & Rumus Indikator Dashboard'), findsOneWidget);
      expect(find.text('Aktivitas Terbaru (Dari Modul Sumber)'), findsOneWidget);
    });
  });
}
