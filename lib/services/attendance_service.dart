import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'session_service.dart';

class AttendanceRecord {
  final int id;
  final int salesId;
  final String salesName;
  final String tanggal; // YYYY-MM-DD
  final DateTime? checkinAt;
  final String? checkinTime;
  final DateTime? checkoutAt;
  final String? checkoutTime;
  final int? durasiKerja;
  String status; // hadir, terlambat, izin, sakit, alfa
  String? catatanAdmin;
  int correctionsCount;

  AttendanceRecord({
    required this.id,
    required this.salesId,
    required this.salesName,
    required this.tanggal,
    this.checkinAt,
    this.checkinTime,
    this.checkoutAt,
    this.checkoutTime,
    this.durasiKerja,
    required this.status,
    this.catatanAdmin,
    this.correctionsCount = 0,
  });

  String get statusLabel {
    switch (status.toLowerCase()) {
      case 'hadir':
        return 'Hadir';
      case 'terlambat':
        return 'Terlambat';
      case 'izin':
        return 'Izin';
      case 'sakit':
        return 'Sakit';
      case 'alfa':
      default:
        return 'Alpa';
    }
  }

  String get formattedDurasi {
    if (durasiKerja == null) return '-';
    final h = durasiKerja! ~/ 60;
    final m = durasiKerja! % 60;
    if (h > 0) return '$h jam $m mnt';
    return '$m menit';
  }

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      salesId: int.tryParse(json['sales_id']?.toString() ?? '0') ?? 0,
      salesName: json['sales_name']?.toString() ?? 'Sales Lapangan',
      tanggal: json['tanggal']?.toString() ?? '',
      checkinAt: json['checkin_at'] != null ? DateTime.tryParse(json['checkin_at'].toString()) : null,
      checkinTime: json['checkin_time']?.toString(),
      checkoutAt: json['checkout_at'] != null ? DateTime.tryParse(json['checkout_at'].toString()) : null,
      checkoutTime: json['checkout_time']?.toString(),
      durasiKerja: json['durasi_kerja'] != null ? int.tryParse(json['durasi_kerja'].toString()) : null,
      status: json['status']?.toString() ?? 'alfa',
      catatanAdmin: json['catatan_admin']?.toString(),
      correctionsCount: int.tryParse(json['corrections_count']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sales_id': salesId,
        'sales_name': salesName,
        'tanggal': tanggal,
        if (checkinAt != null) 'checkin_at': checkinAt!.toIso8601String(),
        if (checkinTime != null) 'checkin_time': checkinTime,
        if (checkoutAt != null) 'checkout_at': checkoutAt!.toIso8601String(),
        if (checkoutTime != null) 'checkout_time': checkoutTime,
        if (durasiKerja != null) 'durasi_kerja': durasiKerja,
        'status': status,
        if (catatanAdmin != null) 'catatan_admin': catatanAdmin,
        'corrections_count': correctionsCount,
      };
}

class AttendanceCorrectionItem {
  final int id;
  final int attendanceId;
  final String oldStatus;
  final String newStatus;
  final String? oldCheckinTime;
  final String? newCheckinTime;
  final String? oldCheckoutTime;
  final String? newCheckoutTime;
  final String reason;
  final String correctedByName;
  final DateTime createdAt;

  AttendanceCorrectionItem({
    required this.id,
    required this.attendanceId,
    required this.oldStatus,
    required this.newStatus,
    this.oldCheckinTime,
    this.newCheckinTime,
    this.oldCheckoutTime,
    this.newCheckoutTime,
    required this.reason,
    required this.correctedByName,
    required this.createdAt,
  });

  factory AttendanceCorrectionItem.fromJson(Map<String, dynamic> json) {
    return AttendanceCorrectionItem(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      attendanceId: int.tryParse(json['attendance_id']?.toString() ?? '0') ?? 0,
      oldStatus: json['old_status']?.toString() ?? '-',
      newStatus: json['new_status']?.toString() ?? 'hadir',
      oldCheckinTime: json['old_checkin_time']?.toString(),
      newCheckinTime: json['new_checkin_time']?.toString(),
      oldCheckoutTime: json['old_checkout_time']?.toString(),
      newCheckoutTime: json['new_checkout_time']?.toString(),
      reason: json['reason']?.toString() ?? '',
      correctedByName: json['corrected_by_name']?.toString() ?? 'Admin',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'attendance_id': attendanceId,
        'old_status': oldStatus,
        'new_status': newStatus,
        if (oldCheckinTime != null) 'old_checkin_time': oldCheckinTime,
        if (newCheckinTime != null) 'new_checkin_time': newCheckinTime,
        if (oldCheckoutTime != null) 'old_checkout_time': oldCheckoutTime,
        if (newCheckoutTime != null) 'new_checkout_time': newCheckoutTime,
        'reason': reason,
        'corrected_by_name': correctedByName,
        'created_at': createdAt.toIso8601String(),
      };
}

class AttendanceService {
  static const String _cacheKey = 'attendance_records_cache_v1';
  static const String _corrCacheKey = 'attendance_corrections_cache_v1';
  static List<AttendanceRecord>? _inMemory;
  static List<AttendanceCorrectionItem>? _inMemoryCorr;

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

  static String _hhmm(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  static List<AttendanceRecord> defaultRecords() {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yStr =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
    return [
      AttendanceRecord(
        id: 1,
        salesId: 3,
        salesName: 'Muhammad Ulil Abshor',
        tanggal: yStr,
        checkinAt: DateTime(yesterday.year, yesterday.month, yesterday.day, 8, 5),
        checkinTime: '08:05',
        checkoutAt: DateTime(yesterday.year, yesterday.month, yesterday.day, 17, 10),
        checkoutTime: '17:10',
        durasiKerja: 545,
        status: 'hadir',
      ),
      AttendanceRecord(
        id: 2,
        salesId: 5,
        salesName: 'Ahmad Hidayat',
        tanggal: yStr,
        checkinAt: DateTime(yesterday.year, yesterday.month, yesterday.day, 8, 45),
        checkinTime: '08:45',
        checkoutAt: DateTime(yesterday.year, yesterday.month, yesterday.day, 17, 0),
        checkoutTime: '17:00',
        durasiKerja: 495,
        status: 'terlambat',
      ),
    ];
  }

  static Future<void> clearCache() async {
    _inMemory = null;
    _inMemoryCorr = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_corrCacheKey);
    } catch (_) {}
  }

  static Future<List<AttendanceRecord>> loadCached({int? salesId}) async {
    if (_inMemory != null) {
      final list = List<AttendanceRecord>.from(_inMemory!);
      return salesId != null ? list.where((r) => r.salesId == salesId).toList() : list;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        final list = decoded
            .map((e) => AttendanceRecord.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        _inMemory = List<AttendanceRecord>.from(list);
        return salesId != null ? list.where((r) => r.salesId == salesId).toList() : list;
      }
    } catch (_) {}
    final defaults = defaultRecords();
    _inMemory = List<AttendanceRecord>.from(defaults);
    return salesId != null ? defaults.where((r) => r.salesId == salesId).toList() : defaults;
  }

  static Future<void> saveCached(List<AttendanceRecord> list) async {
    _inMemory = List<AttendanceRecord>.from(list);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(list.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  static Future<List<AttendanceRecord>> fetchAttendances({int? salesId}) async {
    final cached = await loadCached(salesId: salesId);
    if (_isTestEnv) return cached;

    try {
      await AuthService.resolveBaseUrl();
      final qp = salesId != null ? '?sales_id=$salesId' : '';
      final response = await http
          .get(
            Uri.parse('${AuthService.activeBaseUrl}/attendances$qp'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final list = (body['data'] as List<dynamic>? ?? [])
            .map((e) => AttendanceRecord.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        if (salesId == null) {
          await saveCached(list);
        } else {
          final all = await loadCached();
          final merged = all.where((r) => r.salesId != salesId).toList()..addAll(list);
          merged.sort((a, b) => b.tanggal.compareTo(a.tanggal));
          await saveCached(merged);
        }
        return list;
      }
    } catch (_) {}
    return cached;
  }

  static Future<AttendanceRecord?> fetchTodayAttendance(int salesId) async {
    final today = todayYmd();
    if (!_isTestEnv) {
      try {
        await AuthService.resolveBaseUrl();
        final response = await http
            .get(
              Uri.parse('${AuthService.activeBaseUrl}/attendances/today/$salesId'),
              headers: {'Accept': 'application/json'},
            )
            .timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          if (body['data'] != null) {
            return AttendanceRecord.fromJson(Map<String, dynamic>.from(body['data']));
          }
          return null;
        }
      } catch (_) {}
    }

    final list = await loadCached(salesId: salesId);
    final matches = list.where((r) => r.tanggal == today).toList();
    return matches.isNotEmpty ? matches.first : null;
  }

  static Future<AttendanceRecord> checkIn({
    required int salesId,
    required String salesName,
    required String salesEmail,
    bool isActiveAccount = true,
    String? catatan,
  }) async {
    if (!isActiveAccount) {
      throw Exception('Akun Sales sedang nonaktif atau ditangguhkan sehingga tidak dapat melakukan absensi.');
    }

    if (!_isTestEnv) {
      try {
        await AuthService.resolveBaseUrl();
        final response = await http
            .post(
              Uri.parse('${AuthService.activeBaseUrl}/attendances/checkin'),
              headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
              body: jsonEncode({
                'sales_id': salesId,
                'sales_email': salesEmail,
                if (catatan != null && catatan.trim().isNotEmpty) 'catatan': catatan.trim(),
              }),
            )
            .timeout(const Duration(seconds: 5));
        final body = jsonDecode(response.body);
        if (response.statusCode == 201 || response.statusCode == 200) {
          final record = AttendanceRecord.fromJson(Map<String, dynamic>.from(body['data']));
          final all = await loadCached();
          all.removeWhere((r) => r.salesId == salesId && r.tanggal == record.tanggal);
          all.insert(0, record);
          await saveCached(all);
          return record;
        } else {
          throw Exception(body['message'] ?? 'Gagal melakukan check-in.');
        }
      } catch (e) {
        if (e.toString().contains('sudah melakukan') ||
            e.toString().contains('nonaktif') ||
            e.toString().contains('ditangguhkan') ||
            e.toString().contains('Gagal')) {
          rethrow;
        }
      }
    }

    final all = await loadCached();
    final today = todayYmd();
    if (all.any((r) => r.salesId == salesId && r.tanggal == today)) {
      throw Exception('Anda sudah melakukan check-in hari ini. Satu record per hari per sales.');
    }

    final now = DateTime.now();
    final statusMasuk = (now.hour > 8 || (now.hour == 8 && now.minute > 30)) ? 'terlambat' : 'hadir';
    final nextId = all.isEmpty ? 1 : (all.map((e) => e.id).reduce((a, b) => a > b ? a : b) + 1);
    final record = AttendanceRecord(
      id: nextId,
      salesId: salesId,
      salesName: salesName,
      tanggal: today,
      checkinAt: now,
      checkinTime: _hhmm(now),
      status: statusMasuk,
      catatanAdmin: catatan?.trim().isNotEmpty == true ? catatan!.trim() : null,
    );
    all.insert(0, record);
    await saveCached(all);
    return record;
  }

  static Future<AttendanceRecord> checkOut({
    required int salesId,
    required String salesEmail,
  }) async {
    if (!_isTestEnv) {
      try {
        await AuthService.resolveBaseUrl();
        final response = await http
            .post(
              Uri.parse('${AuthService.activeBaseUrl}/attendances/checkout'),
              headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
              body: jsonEncode({
                'sales_id': salesId,
                'sales_email': salesEmail,
              }),
            )
            .timeout(const Duration(seconds: 5));
        final body = jsonDecode(response.body);
        if (response.statusCode == 200) {
          final record = AttendanceRecord.fromJson(Map<String, dynamic>.from(body['data']));
          final all = await loadCached();
          final idx = all.indexWhere((r) => r.salesId == salesId && r.tanggal == record.tanggal);
          if (idx != -1) {
            all[idx] = record;
          } else {
            all.insert(0, record);
          }
          await saveCached(all);
          return record;
        } else {
          throw Exception(body['message'] ?? 'Gagal melakukan check-out.');
        }
      } catch (e) {
        if (e.toString().contains('belum melakukan') ||
            e.toString().contains('sudah melakukan') ||
            e.toString().contains('lebih awal') ||
            e.toString().contains('Gagal')) {
          rethrow;
        }
      }
    }

    final all = await loadCached();
    final today = todayYmd();
    final idx = all.indexWhere((r) => r.salesId == salesId && r.tanggal == today);
    if (idx == -1) {
      throw Exception('Anda belum melakukan check-in hari ini. Silakan check-in terlebih dahulu.');
    }
    final existing = all[idx];
    if (existing.checkoutAt != null) {
      throw Exception('Anda sudah melakukan check-out hari ini.');
    }
    final now = DateTime.now();
    if (existing.checkinAt != null && now.isBefore(existing.checkinAt!)) {
      throw Exception('Waktu check-out tidak boleh lebih awal dari check-in.');
    }
    final durasi = existing.checkinAt != null ? now.difference(existing.checkinAt!).inMinutes : 0;
    final updated = AttendanceRecord(
      id: existing.id,
      salesId: existing.salesId,
      salesName: existing.salesName,
      tanggal: existing.tanggal,
      checkinAt: existing.checkinAt,
      checkinTime: existing.checkinTime,
      checkoutAt: now,
      checkoutTime: _hhmm(now),
      durasiKerja: durasi,
      status: existing.status,
      catatanAdmin: existing.catatanAdmin,
      correctionsCount: existing.correctionsCount,
    );
    all[idx] = updated;
    await saveCached(all);
    return updated;
  }

  static Future<AttendanceRecord> correctAttendance({
    required int attendanceId,
    required int actorId,
    required String actorEmail,
    required String actorName,
    required String status,
    String? checkinTime,
    String? checkoutTime,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      throw Exception('Alasan koreksi absensi wajib diisi.');
    }

    if (!_isTestEnv) {
      try {
        await AuthService.resolveBaseUrl();
        final token = await SessionService().getToken();
        final response = await http
            .put(
              Uri.parse('${AuthService.activeBaseUrl}/attendances/$attendanceId/correct'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
              },
              body: jsonEncode({
                'actor_id': actorId,
                'actor_email': actorEmail,
                'status': status,
                'checkin_time': checkinTime,
                'checkout_time': checkoutTime,
                'reason': reason.trim(),
              }),
            )
            .timeout(const Duration(seconds: 5));
        final body = jsonDecode(response.body);
        if (response.statusCode == 200) {
          final updated = AttendanceRecord.fromJson(Map<String, dynamic>.from(body['data']));
          final all = await loadCached();
          final idx = all.indexWhere((r) => r.id == attendanceId);
          if (idx != -1) all[idx] = updated;
          await saveCached(all);
          return updated;
        } else {
          throw Exception(body['message'] ?? 'Gagal mengoreksi absensi.');
        }
      } catch (e) {
        if (e.toString().contains('Akses ditolak') ||
            e.toString().contains('lebih awal') ||
            e.toString().contains('wajib') ||
            e.toString().contains('Format')) {
          rethrow;
        }
      }
    }

    final all = await loadCached();
    final idx = all.indexWhere((r) => r.id == attendanceId);
    if (idx == -1) throw Exception('Data absensi tidak ditemukan.');
    final existing = all[idx];

    DateTime? newIn = existing.checkinAt;
    if (checkinTime != null) {
      newIn = checkinTime.trim().isEmpty ? null : DateTime.tryParse('${existing.tanggal}T${checkinTime.trim()}:00');
    }
    DateTime? newOut = existing.checkoutAt;
    if (checkoutTime != null) {
      newOut = checkoutTime.trim().isEmpty ? null : DateTime.tryParse('${existing.tanggal}T${checkoutTime.trim()}:00');
    }
    if (newIn != null && newOut != null && newOut.isBefore(newIn)) {
      throw Exception('Waktu check-out tidak boleh lebih awal dari waktu check-in.');
    }

    final dur = (newIn != null && newOut != null) ? newOut.difference(newIn).inMinutes : null;
    final updated = AttendanceRecord(
      id: existing.id,
      salesId: existing.salesId,
      salesName: existing.salesName,
      tanggal: existing.tanggal,
      checkinAt: newIn,
      checkinTime: newIn != null ? _hhmm(newIn) : null,
      checkoutAt: newOut,
      checkoutTime: newOut != null ? _hhmm(newOut) : null,
      durasiKerja: dur,
      status: status,
      catatanAdmin: reason.trim(),
      correctionsCount: existing.correctionsCount + 1,
    );
    all[idx] = updated;
    await saveCached(all);

    final corrList = await _loadCachedCorrections();
    corrList.insert(
      0,
      AttendanceCorrectionItem(
        id: corrList.length + 1,
        attendanceId: attendanceId,
        oldStatus: existing.status,
        newStatus: status,
        oldCheckinTime: existing.checkinTime,
        newCheckinTime: updated.checkinTime,
        oldCheckoutTime: existing.checkoutTime,
        newCheckoutTime: updated.checkoutTime,
        reason: reason.trim(),
        correctedByName: actorName,
        createdAt: DateTime.now(),
      ),
    );
    await _saveCachedCorrections(corrList);
    return updated;
  }

  static Future<List<AttendanceCorrectionItem>> _loadCachedCorrections() async {
    if (_inMemoryCorr != null) return List<AttendanceCorrectionItem>.from(_inMemoryCorr!);
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_corrCacheKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        final list = decoded
            .map((e) => AttendanceCorrectionItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        _inMemoryCorr = List<AttendanceCorrectionItem>.from(list);
        return list;
      }
    } catch (_) {}
    _inMemoryCorr = [];
    return [];
  }

  static Future<void> _saveCachedCorrections(List<AttendanceCorrectionItem> list) async {
    _inMemoryCorr = List<AttendanceCorrectionItem>.from(list);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_corrCacheKey, jsonEncode(list.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  static Future<List<AttendanceCorrectionItem>> fetchCorrections(int attendanceId) async {
    if (!_isTestEnv) {
      try {
        await AuthService.resolveBaseUrl();
        final response = await http
            .get(
              Uri.parse('${AuthService.activeBaseUrl}/attendances/$attendanceId/corrections'),
              headers: {'Accept': 'application/json'},
            )
            .timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          return (body['data'] as List<dynamic>? ?? [])
              .map((e) => AttendanceCorrectionItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        }
      } catch (_) {}
    }
    return (await _loadCachedCorrections()).where((c) => c.attendanceId == attendanceId).toList();
  }
}
