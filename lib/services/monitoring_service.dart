import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import 'attendance_service.dart';
import 'auth_service.dart';
import 'route_service.dart';
import 'transaction_service.dart';

class MonitoringActivityItem {
  final String modul;
  final String userName;
  final String deskripsi;
  final String tanggal;

  const MonitoringActivityItem({
    required this.modul,
    required this.userName,
    required this.deskripsi,
    required this.tanggal,
  });
}

class MonitoringSummaryData {
  final int activeSalesCount;
  final int hadirCount;
  final int terlambatCount;
  final int izinSakitCount;
  final int alfaCount;
  final int totalAttendanceCount;
  final int totalRoutes;
  final int completedRoutes;
  final int inProgressRoutes;
  final int pendingRoutes;
  final int cancelledRoutes;
  final int approvedOmzet;
  final int approvedTxCount;
  final int pendingTxCount;
  final int rejectedTxCount;
  final List<MonitoringActivityItem> recentActivities;
  final String timezone;

  const MonitoringSummaryData({
    required this.activeSalesCount,
    required this.hadirCount,
    required this.terlambatCount,
    required this.izinSakitCount,
    required this.alfaCount,
    required this.totalAttendanceCount,
    required this.totalRoutes,
    required this.completedRoutes,
    required this.inProgressRoutes,
    required this.pendingRoutes,
    required this.cancelledRoutes,
    required this.approvedOmzet,
    required this.approvedTxCount,
    required this.pendingTxCount,
    required this.rejectedTxCount,
    required this.recentActivities,
    this.timezone = 'WIB (Asia/Jakarta, UTC+7)',
  });

  int get totalPresentDays => hadirCount + terlambatCount;

  double get attendanceRate {
    if (totalAttendanceCount == 0) return 0;
    return (totalPresentDays / totalAttendanceCount) * 100;
  }

  double get routeCompletionRate {
    if (totalRoutes == 0) return 0;
    return (completedRoutes / totalRoutes) * 100;
  }

  bool get isCompletelyEmpty =>
      totalAttendanceCount == 0 &&
      totalRoutes == 0 &&
      (approvedTxCount + pendingTxCount + rejectedTxCount) == 0;
}

class MonitoringService {
  static bool get _isTestEnv {
    try {
      return WidgetsBinding.instance.runtimeType.toString().contains('Test');
    } catch (_) {
      return false;
    }
  }

  static Future<MonitoringSummaryData> loadSummary({
    required UserModel currentUser,
    String? startDate,
    String? endDate,
    int? filterSalesId,
  }) async {
    // Terapkan kontrol akses: Sales hanya boleh melihat data miliknya sendiri
    final int? effectiveSalesId = currentUser.isManager ? filterSalesId : currentUser.id;

    if (!_isTestEnv) {
      try {
        await AuthService.resolveBaseUrl();
        final qp = <String, String>{
          if (startDate != null && startDate.isNotEmpty) 'start_date': startDate,
          if (endDate != null && endDate.isNotEmpty) 'end_date': endDate,
          if (effectiveSalesId != null) 'sales_id': effectiveSalesId.toString(),
          if (currentUser.id != null) 'actor_id': currentUser.id.toString(),
          'actor_email': currentUser.email,
        };
        final uri = Uri.parse('${AuthService.activeBaseUrl}/monitoring/summary')
            .replace(queryParameters: qp);
        final response = await http
            .get(uri, headers: {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          final d = body['data'] as Map<String, dynamic>;
          final att = d['attendance'] as Map<String, dynamic>? ?? {};
          final rt = d['routes'] as Map<String, dynamic>? ?? {};
          final tx = d['transactions'] as Map<String, dynamic>? ?? {};
          final logs = (d['recent_activities'] as List<dynamic>? ?? []).map((e) {
            final m = Map<String, dynamic>.from(e as Map);
            return MonitoringActivityItem(
              modul: m['modul']?.toString() ?? 'SISTEM',
              userName: m['user_name']?.toString() ?? 'Sistem',
              deskripsi: m['deskripsi']?.toString() ?? '',
              tanggal: (m['created_at']?.toString() ?? '').split('T').first,
            );
          }).toList();

          return MonitoringSummaryData(
            activeSalesCount: int.tryParse(d['active_sales_count']?.toString() ?? '0') ?? 0,
            hadirCount: int.tryParse(att['hadir']?.toString() ?? '0') ?? 0,
            terlambatCount: int.tryParse(att['terlambat']?.toString() ?? '0') ?? 0,
            izinSakitCount: (int.tryParse(att['izin']?.toString() ?? '0') ?? 0) +
                (int.tryParse(att['sakit']?.toString() ?? '0') ?? 0),
            alfaCount: int.tryParse(att['alfa']?.toString() ?? '0') ?? 0,
            totalAttendanceCount: int.tryParse(att['total']?.toString() ?? '0') ?? 0,
            totalRoutes: int.tryParse(rt['total']?.toString() ?? '0') ?? 0,
            completedRoutes: int.tryParse(rt['selesai']?.toString() ?? '0') ?? 0,
            inProgressRoutes: int.tryParse(rt['dalam_perjalanan']?.toString() ?? '0') ?? 0,
            pendingRoutes: int.tryParse(rt['belum_dikunjungi']?.toString() ?? '0') ?? 0,
            cancelledRoutes: int.tryParse(rt['dibatalkan']?.toString() ?? '0') ?? 0,
            approvedOmzet: double.tryParse(tx['approved_omzet']?.toString() ?? '0')?.round() ?? 0,
            approvedTxCount: int.tryParse(tx['disetujui_count']?.toString() ?? '0') ?? 0,
            pendingTxCount: int.tryParse(tx['menunggu_count']?.toString() ?? '0') ?? 0,
            rejectedTxCount: int.tryParse(tx['ditolak_count']?.toString() ?? '0') ?? 0,
            recentActivities: logs,
            timezone: body['timezone']?.toString() ?? 'WIB (Asia/Jakarta, UTC+7)',
          );
        }
      } catch (_) {}
    }

    // Agregasi langsung dari modul sumber (cache/lokal) jika server offline atau mode test
    final users = await AuthService().getAllUsers();
    final activeSalesCount = users.where((u) => u.isSales && u.isActive).length;

    bool inRange(String dateStr) {
      if (startDate != null && startDate.isNotEmpty && dateStr.compareTo(startDate) < 0) {
        return false;
      }
      if (endDate != null && endDate.isNotEmpty && dateStr.compareTo(endDate) > 0) {
        return false;
      }
      return true;
    }

    final attendances = (await AttendanceService.loadCached(salesId: effectiveSalesId))
        .where((a) => inRange(a.tanggal))
        .toList();
    final routes = (await RouteService.loadCached(salesId: effectiveSalesId))
        .where((r) => inRange(r.tanggal))
        .toList();
    final transactions = (await TransactionService.loadCached(salesId: effectiveSalesId))
        .where((t) => inRange(t.tanggal))
        .toList();

    final hadir = attendances.where((a) => a.status == 'hadir').length;
    final terlambat = attendances.where((a) => a.status == 'terlambat').length;
    final izinSakit = attendances.where((a) => a.status == 'izin' || a.status == 'sakit').length;
    final alfa = attendances.where((a) => a.status == 'alfa').length;

    final completedRoutes = routes.where((r) => r.status == StatusKunjungan.selesai).length;
    final inProgressRoutes = routes.where((r) => r.status == StatusKunjungan.dalamPerjalanan).length;
    final pendingRoutes = routes.where((r) => r.status == StatusKunjungan.belumDikunjungi).length;
    final cancelledRoutes = routes.where((r) => r.status == StatusKunjungan.dibatalkan).length;

    final approvedTxs =
        transactions.where((t) => t.statusVerifikasi == StatusVerifikasiTransaksi.disetujui).toList();
    final pendingTxs =
        transactions.where((t) => t.statusVerifikasi == StatusVerifikasiTransaksi.menunggu).toList();
    final rejectedTxs =
        transactions.where((t) => t.statusVerifikasi == StatusVerifikasiTransaksi.ditolak).toList();
    final approvedOmzet = approvedTxs.fold<int>(0, (sum, t) => sum + t.total);

    final activities = <MonitoringActivityItem>[];
    for (final tx in transactions.take(4)) {
      activities.add(
        MonitoringActivityItem(
          modul: 'PENDAPATAN',
          userName: tx.salesName,
          deskripsi:
              'Transaksi ${tx.kodeTransaksi} (${tx.namaPelanggan}) — ${TransactionService.formatRp(tx.total)} [${tx.statusLabel}]',
          tanggal: tx.tanggal,
        ),
      );
    }
    for (final rt in routes.take(4)) {
      activities.add(
        MonitoringActivityItem(
          modul: 'JADWAL RUTE',
          userName: rt.salesName,
          deskripsi: 'Kunjungan ke ${rt.namaTujuan} (${rt.waktuMulai}-${rt.waktuSelesai}) [${rt.statusLabel}]',
          tanggal: rt.tanggal,
        ),
      );
    }
    for (final att in attendances.take(4)) {
      activities.add(
        MonitoringActivityItem(
          modul: 'ABSENSI',
          userName: att.salesName,
          deskripsi:
              'Absensi ${att.statusLabel}${att.checkinTime != null ? ' (Masuk ${att.checkinTime}' : ''}${att.checkoutTime != null ? ', Pulang ${att.checkoutTime})' : (att.checkinTime != null ? ')' : '')}',
          tanggal: att.tanggal,
        ),
      );
    }

    activities.sort((a, b) => b.tanggal.compareTo(a.tanggal));

    return MonitoringSummaryData(
      activeSalesCount: activeSalesCount,
      hadirCount: hadir,
      terlambatCount: terlambat,
      izinSakitCount: izinSakit,
      alfaCount: alfa,
      totalAttendanceCount: attendances.length,
      totalRoutes: routes.length,
      completedRoutes: completedRoutes,
      inProgressRoutes: inProgressRoutes,
      pendingRoutes: pendingRoutes,
      cancelledRoutes: cancelledRoutes,
      approvedOmzet: approvedOmzet,
      approvedTxCount: approvedTxs.length,
      pendingTxCount: pendingTxs.length,
      rejectedTxCount: rejectedTxs.length,
      recentActivities: activities.take(10).toList(),
    );
  }
}
