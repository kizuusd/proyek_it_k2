import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'session_service.dart';

enum StatusKunjungan { belumDikunjungi, dalamPerjalanan, selesai, dibatalkan }

class RouteScheduleItem {
  final int id;
  final int salesId;
  final String salesName;
  String tanggal; // YYYY-MM-DD
  String waktuMulai; // HH:mm
  String waktuSelesai; // HH:mm
  String namaTujuan;
  String alamatTujuan;
  int urutan;
  String catatan;
  String catatanHasil;
  String alasanPerubahan;
  StatusKunjungan status;
  String? updatedByName;

  RouteScheduleItem({
    required this.id,
    required this.salesId,
    required this.salesName,
    required this.tanggal,
    required this.waktuMulai,
    required this.waktuSelesai,
    required this.namaTujuan,
    required this.alamatTujuan,
    this.urutan = 1,
    this.catatan = '',
    this.catatanHasil = '',
    this.alasanPerubahan = '',
    this.status = StatusKunjungan.belumDikunjungi,
    this.updatedByName,
  });

  static StatusKunjungan parseStatus(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'dalam_perjalanan':
        return StatusKunjungan.dalamPerjalanan;
      case 'selesai':
        return StatusKunjungan.selesai;
      case 'dibatalkan':
      case 'dilewati':
        return StatusKunjungan.dibatalkan;
      case 'belum_dikunjungi':
      case 'dijadwalkan':
      default:
        return StatusKunjungan.belumDikunjungi;
    }
  }

  static String statusToApi(StatusKunjungan s) {
    switch (s) {
      case StatusKunjungan.dalamPerjalanan:
        return 'dalam_perjalanan';
      case StatusKunjungan.selesai:
        return 'selesai';
      case StatusKunjungan.dibatalkan:
        return 'dibatalkan';
      case StatusKunjungan.belumDikunjungi:
        return 'belum_dikunjungi';
    }
  }

  String get statusLabel {
    switch (status) {
      case StatusKunjungan.dalamPerjalanan:
        return 'Dalam Perjalanan';
      case StatusKunjungan.selesai:
        return 'Selesai';
      case StatusKunjungan.dibatalkan:
        return 'Batal';
      case StatusKunjungan.belumDikunjungi:
        return 'Belum Dikunjungi';
    }
  }

  factory RouteScheduleItem.fromJson(Map<String, dynamic> json) {
    return RouteScheduleItem(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      salesId: int.tryParse(json['sales_id']?.toString() ?? '0') ?? 0,
      salesName: json['sales_name']?.toString() ?? 'Sales Lapangan',
      tanggal: json['tanggal']?.toString() ?? '',
      waktuMulai: json['waktu_mulai']?.toString() ?? '09:00',
      waktuSelesai: json['waktu_selesai']?.toString() ?? '10:00',
      namaTujuan: json['nama_tujuan']?.toString() ?? '',
      alamatTujuan: json['alamat_tujuan']?.toString() ?? '',
      urutan: int.tryParse(json['urutan']?.toString() ?? '1') ?? 1,
      catatan: json['catatan']?.toString() ?? '',
      catatanHasil: json['catatan_hasil']?.toString() ?? '',
      alasanPerubahan: json['alasan_perubahan']?.toString() ?? '',
      status: parseStatus(json['status']?.toString()),
      updatedByName: json['updated_by_name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sales_id': salesId,
        'sales_name': salesName,
        'tanggal': tanggal,
        'waktu_mulai': waktuMulai,
        'waktu_selesai': waktuSelesai,
        'nama_tujuan': namaTujuan,
        'alamat_tujuan': alamatTujuan,
        'urutan': urutan,
        'catatan': catatan,
        'catatan_hasil': catatanHasil,
        'alasan_perubahan': alasanPerubahan,
        'status': statusToApi(status),
        if (updatedByName != null) 'updated_by_name': updatedByName,
      };
}

class RouteService {
  static const String _cacheKey = 'route_schedules_cache_v1';
  static List<RouteScheduleItem>? _inMemory;

  static bool get _isTestEnv {
    try {
      return WidgetsBinding.instance.runtimeType.toString().contains('Test');
    } catch (_) {
      return false;
    }
  }

  static String todayYmd() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static List<RouteScheduleItem> defaultRoutes() {
    final today = todayYmd();
    return [
      RouteScheduleItem(
        id: 1,
        salesId: 3,
        salesName: 'Muhammad Ulil Abshor',
        tanggal: today,
        waktuMulai: '08:30',
        waktuSelesai: '09:30',
        namaTujuan: 'Toko Sinar Makmur',
        alamatTujuan: 'Jl. Merdeka No. 45, Surabaya',
        urutan: 1,
        catatan: 'Tawarkan stok Plastik Kresek 1kg dan cek display toko.',
        status: StatusKunjungan.selesai,
        catatanHasil: 'Order 10 pack plastik kresek diterima pemilik toko.',
      ),
      RouteScheduleItem(
        id: 2,
        salesId: 3,
        salesName: 'Muhammad Ulil Abshor',
        tanggal: today,
        waktuMulai: '10:00',
        waktuSelesai: '11:00',
        namaTujuan: 'Warung Berkah Jaya',
        alamatTujuan: 'Jl. Ahmad Yani No. 12, Surabaya',
        urutan: 2,
        catatan: 'Follow up pemesanan Minyak Goreng 1L.',
        status: StatusKunjungan.dalamPerjalanan,
      ),
      RouteScheduleItem(
        id: 3,
        salesId: 5,
        salesName: 'Ahmad Hidayat',
        tanggal: today,
        waktuMulai: '09:00',
        waktuSelesai: '10:30',
        namaTujuan: 'Minimarket Sumber Rejeki',
        alamatTujuan: 'Jl. Raya Darmo No. 88, Surabaya',
        urutan: 1,
        catatan: 'Pengenalan katalog harga terbaru bulan ini.',
        status: StatusKunjungan.belumDikunjungi,
      ),
    ];
  }

  static Future<void> clearCache() async {
    _inMemory = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
    } catch (_) {}
  }

  static Future<List<RouteScheduleItem>> loadCached({int? salesId}) async {
    List<RouteScheduleItem> list;
    if (_inMemory != null) {
      list = List<RouteScheduleItem>.from(_inMemory!);
    } else {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_cacheKey);
        if (raw != null && raw.isNotEmpty) {
          final decoded = jsonDecode(raw) as List<dynamic>;
          list = decoded
              .map((e) => RouteScheduleItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          _inMemory = List<RouteScheduleItem>.from(list);
        } else {
          list = defaultRoutes();
          _inMemory = List<RouteScheduleItem>.from(list);
        }
      } catch (_) {
        list = defaultRoutes();
        _inMemory = List<RouteScheduleItem>.from(list);
      }
    }
    list.sort((a, b) {
      final d = a.tanggal.compareTo(b.tanggal);
      if (d != 0) return d;
      final u = a.urutan.compareTo(b.urutan);
      if (u != 0) return u;
      return a.waktuMulai.compareTo(b.waktuMulai);
    });
    return salesId != null ? list.where((r) => r.salesId == salesId).toList() : list;
  }

  static Future<void> saveCached(List<RouteScheduleItem> list) async {
    _inMemory = List<RouteScheduleItem>.from(list);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(list.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  static int _toMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return -1;
    final h = int.tryParse(parts[0]) ?? -1;
    final m = int.tryParse(parts[1]) ?? -1;
    if (h < 0 || h > 23 || m < 0 || m > 59) return -1;
    return h * 60 + m;
  }

  static Future<List<RouteScheduleItem>> fetchRoutes({int? salesId}) async {
    final cached = await loadCached(salesId: salesId);
    if (_isTestEnv) return cached;

    try {
      await AuthService.resolveBaseUrl();
      final qp = salesId != null ? '?sales_id=$salesId' : '';
      final response = await http
          .get(
            Uri.parse('${AuthService.activeBaseUrl}/routes$qp'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final list = (body['data'] as List<dynamic>? ?? [])
            .map((e) => RouteScheduleItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        if (salesId == null) {
          await saveCached(list);
        } else {
          final all = await loadCached();
          final merged = all.where((r) => r.salesId != salesId).toList()..addAll(list);
          await saveCached(merged);
        }
        return list;
      }
    } catch (_) {}
    return cached;
  }

  static Future<RouteScheduleItem> createRoute({
    required int actorId,
    required String actorEmail,
    required int salesId,
    required String salesName,
    required bool isSalesActive,
    required String tanggal,
    required String waktuMulai,
    required String waktuSelesai,
    required String namaTujuan,
    required String alamatTujuan,
    required int urutan,
    String catatan = '',
  }) async {
    if (!isSalesActive) {
      throw Exception('Sales "$salesName" sedang nonaktif/ditangguhkan dan tidak dapat dijadwalkan.');
    }
    final sMin = _toMinutes(waktuMulai);
    final eMin = _toMinutes(waktuSelesai);
    if (sMin < 0 || eMin < 0 || eMin <= sMin) {
      throw Exception('Waktu selesai kunjungan harus lebih akhir daripada waktu mulai.');
    }

    if (!_isTestEnv) {
      try {
        await AuthService.resolveBaseUrl();
        final token = await SessionService().getToken();
        final response = await http
            .post(
              Uri.parse('${AuthService.activeBaseUrl}/routes'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
              },
              body: jsonEncode({
                'actor_id': actorId,
                'actor_email': actorEmail,
                'created_by': actorId,
                'sales_id': salesId,
                'tanggal': tanggal,
                'waktu_mulai': waktuMulai,
                'waktu_selesai': waktuSelesai,
                'nama_tujuan': namaTujuan.trim(),
                'alamat_tujuan': alamatTujuan.trim(),
                'urutan': urutan,
                'catatan': catatan.trim(),
              }),
            )
            .timeout(const Duration(seconds: 5));
        final body = jsonDecode(response.body);
        if (response.statusCode == 201 || response.statusCode == 200) {
          final created = RouteScheduleItem.fromJson(Map<String, dynamic>.from(body['data']));
          final all = await loadCached();
          all.add(created);
          await saveCached(all);
          return created;
        } else {
          throw Exception(body['message'] ?? 'Gagal membuat jadwal kunjungan.');
        }
      } catch (e) {
        if (e.toString().contains('bentrok') ||
            e.toString().contains('lebih akhir') ||
            e.toString().contains('nonaktif') ||
            e.toString().contains('Akses ditolak')) {
          rethrow;
        }
      }
    }

    final all = await loadCached();
    for (final existing in all) {
      if (existing.salesId == salesId &&
          existing.tanggal == tanggal &&
          existing.status != StatusKunjungan.dibatalkan) {
        final exS = _toMinutes(existing.waktuMulai);
        final exE = _toMinutes(existing.waktuSelesai);
        if (!(eMin <= exS || sMin >= exE)) {
          throw Exception(
            'Jadwal bentrok dengan kunjungan "${existing.namaTujuan}" (${existing.waktuMulai} - ${existing.waktuSelesai}) pada tanggal yang sama.',
          );
        }
      }
    }

    final nextId = all.isEmpty ? 1 : (all.map((e) => e.id).reduce((a, b) => a > b ? a : b) + 1);
    final item = RouteScheduleItem(
      id: nextId,
      salesId: salesId,
      salesName: salesName,
      tanggal: tanggal,
      waktuMulai: waktuMulai,
      waktuSelesai: waktuSelesai,
      namaTujuan: namaTujuan.trim(),
      alamatTujuan: alamatTujuan.trim(),
      urutan: urutan < 1 ? 1 : urutan,
      catatan: catatan.trim(),
      status: StatusKunjungan.belumDikunjungi,
    );
    all.add(item);
    await saveCached(all);
    return item;
  }

  static Future<RouteScheduleItem> updateRoute({
    required int routeId,
    required int actorId,
    required String actorEmail,
    required int salesId,
    required String salesName,
    required String tanggal,
    required String waktuMulai,
    required String waktuSelesai,
    required String namaTujuan,
    required String alamatTujuan,
    required int urutan,
    required String catatan,
    required StatusKunjungan status,
    String alasanPerubahan = '',
  }) async {
    final sMin = _toMinutes(waktuMulai);
    final eMin = _toMinutes(waktuSelesai);
    if (sMin < 0 || eMin < 0 || eMin <= sMin) {
      throw Exception('Waktu selesai kunjungan harus lebih akhir daripada waktu mulai.');
    }

    if (!_isTestEnv) {
      try {
        await AuthService.resolveBaseUrl();
        final token = await SessionService().getToken();
        final response = await http
            .put(
              Uri.parse('${AuthService.activeBaseUrl}/routes/$routeId'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
              },
              body: jsonEncode({
                'actor_id': actorId,
                'actor_email': actorEmail,
                'sales_id': salesId,
                'tanggal': tanggal,
                'waktu_mulai': waktuMulai,
                'waktu_selesai': waktuSelesai,
                'nama_tujuan': namaTujuan.trim(),
                'alamat_tujuan': alamatTujuan.trim(),
                'urutan': urutan,
                'catatan': catatan.trim(),
                'status': RouteScheduleItem.statusToApi(status),
                'alasan_perubahan': alasanPerubahan.trim(),
              }),
            )
            .timeout(const Duration(seconds: 5));
        final body = jsonDecode(response.body);
        if (response.statusCode == 200) {
          final updated = RouteScheduleItem.fromJson(Map<String, dynamic>.from(body['data']));
          final all = await loadCached();
          final idx = all.indexWhere((r) => r.id == routeId);
          if (idx != -1) all[idx] = updated;
          await saveCached(all);
          return updated;
        } else {
          throw Exception(body['message'] ?? 'Gagal memperbarui jadwal.');
        }
      } catch (e) {
        if (e.toString().contains('bentrok') ||
            e.toString().contains('lebih akhir') ||
            e.toString().contains('Akses ditolak')) {
          rethrow;
        }
      }
    }

    final all = await loadCached();
    if (status != StatusKunjungan.dibatalkan) {
      for (final existing in all) {
        if (existing.id != routeId &&
            existing.salesId == salesId &&
            existing.tanggal == tanggal &&
            existing.status != StatusKunjungan.dibatalkan) {
          final exS = _toMinutes(existing.waktuMulai);
          final exE = _toMinutes(existing.waktuSelesai);
          if (!(eMin <= exS || sMin >= exE)) {
            throw Exception(
              'Jadwal bentrok dengan "${existing.namaTujuan}" (${existing.waktuMulai} - ${existing.waktuSelesai}).',
            );
          }
        }
      }
    }

    final idx = all.indexWhere((r) => r.id == routeId);
    if (idx == -1) throw Exception('Jadwal tidak ditemukan.');
    final updated = RouteScheduleItem(
      id: routeId,
      salesId: salesId,
      salesName: salesName,
      tanggal: tanggal,
      waktuMulai: waktuMulai,
      waktuSelesai: waktuSelesai,
      namaTujuan: namaTujuan.trim(),
      alamatTujuan: alamatTujuan.trim(),
      urutan: urutan < 1 ? 1 : urutan,
      catatan: catatan.trim(),
      catatanHasil: all[idx].catatanHasil,
      alasanPerubahan: alasanPerubahan.trim(),
      status: status,
    );
    all[idx] = updated;
    await saveCached(all);
    return updated;
  }

  static Future<RouteScheduleItem> updateVisitStatus({
    required int routeId,
    required int actorId,
    required String actorEmail,
    required StatusKunjungan status,
    String? catatanHasil,
  }) async {
    if (!_isTestEnv) {
      try {
        await AuthService.resolveBaseUrl();
        final token = await SessionService().getToken();
        final response = await http
            .patch(
              Uri.parse('${AuthService.activeBaseUrl}/routes/$routeId/status'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
              },
              body: jsonEncode({
                'actor_id': actorId,
                'actor_email': actorEmail,
                'status': RouteScheduleItem.statusToApi(status),
                if (catatanHasil != null) 'catatan_hasil': catatanHasil.trim(),
              }),
            )
            .timeout(const Duration(seconds: 5));
        final body = jsonDecode(response.body);
        if (response.statusCode == 200) {
          final updated = RouteScheduleItem.fromJson(Map<String, dynamic>.from(body['data']));
          final all = await loadCached();
          final idx = all.indexWhere((r) => r.id == routeId);
          if (idx != -1) all[idx] = updated;
          await saveCached(all);
          return updated;
        } else {
          throw Exception(body['message'] ?? 'Gagal memperbarui status kunjungan.');
        }
      } catch (e) {
        if (e.toString().contains('Akses ditolak')) rethrow;
      }
    }

    final all = await loadCached();
    final idx = all.indexWhere((r) => r.id == routeId);
    if (idx == -1) throw Exception('Jadwal tidak ditemukan.');
    all[idx].status = status;
    if (catatanHasil != null) {
      all[idx].catatanHasil = catatanHasil.trim();
    }
    await saveCached(all);
    return all[idx];
  }
}
