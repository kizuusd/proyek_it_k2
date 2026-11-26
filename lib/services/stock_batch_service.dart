import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'auth_service.dart';
import 'inventory_service.dart';
import 'session_service.dart';

enum StatusReviewBatch { menunggu, ditinjauAdmin, disetujuiOwner, ditolak }

enum StatusOpnameBatch { belumOpname, prosesOpname, valid }

class StockBatchItem {
  final int id;
  final int batchId;
  final int productId;
  final String kodeBarang;
  final String namaBarang;
  final String kategori;
  final String satuan;
  final String? fotoUrl;
  final int hargaSatuan;
  final int qtyDiambil;
  int? qtySisaOpname;
  String? catatanOpname;

  StockBatchItem({
    required this.id,
    required this.batchId,
    required this.productId,
    required this.kodeBarang,
    required this.namaBarang,
    this.kategori = 'Plastik',
    this.satuan = 'Pack',
    this.fotoUrl,
    required this.hargaSatuan,
    required this.qtyDiambil,
    this.qtySisaOpname,
    this.catatanOpname,
  });

  int get qtyTerjual =>
      qtySisaOpname != null ? (qtyDiambil - qtySisaOpname!).clamp(0, qtyDiambil) : 0;

  int get pendapatanItem => qtyTerjual * hargaSatuan;

  int get estimasiMaksimal => qtyDiambil * hargaSatuan;

  factory StockBatchItem.fromJson(Map<String, dynamic> json) {
    final qtyDiambilVal = int.tryParse(json['qty_diambil']?.toString() ?? '0') ?? 0;
    final rawSisa = json['qty_sisa_opname'];
    final int? sisaVal =
        rawSisa != null && rawSisa.toString().isNotEmpty ? int.tryParse(rawSisa.toString()) : null;

    return StockBatchItem(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      batchId: int.tryParse(json['batch_id']?.toString() ?? '0') ?? 0,
      productId: int.tryParse(json['product_id']?.toString() ?? '0') ?? 0,
      kodeBarang: json['kode_barang']?.toString() ?? '',
      namaBarang: json['nama_barang']?.toString() ?? 'Produk',
      kategori: json['kategori']?.toString() ?? 'Plastik',
      satuan: json['satuan']?.toString() ?? 'Pack',
      fotoUrl: json['foto_url']?.toString(),
      hargaSatuan: double.tryParse(json['harga_satuan']?.toString() ?? '0')?.round() ?? 0,
      qtyDiambil: qtyDiambilVal,
      qtySisaOpname: sisaVal,
      catatanOpname: json['catatan_opname']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'batch_id': batchId,
        'product_id': productId,
        'kode_barang': kodeBarang,
        'nama_barang': namaBarang,
        'kategori': kategori,
        'satuan': satuan,
        'foto_url': fotoUrl,
        'harga_satuan': hargaSatuan,
        'qty_diambil': qtyDiambil,
        if (qtySisaOpname != null) 'qty_sisa_opname': qtySisaOpname,
        if (catatanOpname != null && catatanOpname!.isNotEmpty) 'catatan_opname': catatanOpname,
      };
}

class StockBatch {
  final int id;
  final String kodeBatch;
  final String tanggal; // YYYY-MM-DD
  final int salesId;
  final String salesName;
  final String salesEmail;
  final String catatanPengajuan;
  StatusReviewBatch statusReview;
  String? reviewedByAdminName;
  DateTime? reviewedByAdminAt;
  String? catatanAdmin;
  String? reviewedByOwnerName;
  DateTime? reviewedByOwnerAt;
  String? catatanOwner;
  StatusOpnameBatch statusOpname;
  String? opnameByName;
  String? opnameByRole;
  DateTime? opnameAt;
  String? catatanOpname;
  final List<StockBatchItem> items;
  final DateTime createdAt;

  StockBatch({
    required this.id,
    required this.kodeBatch,
    required this.tanggal,
    required this.salesId,
    required this.salesName,
    this.salesEmail = '',
    this.catatanPengajuan = '',
    this.statusReview = StatusReviewBatch.menunggu,
    this.reviewedByAdminName,
    this.reviewedByAdminAt,
    this.catatanAdmin,
    this.reviewedByOwnerName,
    this.reviewedByOwnerAt,
    this.catatanOwner,
    this.statusOpname = StatusOpnameBatch.belumOpname,
    this.opnameByName,
    this.opnameByRole,
    this.opnameAt,
    this.catatanOpname,
    required this.items,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isValid => statusOpname == StatusOpnameBatch.valid;
  bool get isRejected => statusReview == StatusReviewBatch.ditolak;
  int get totalJenisBarang => items.length;
  int get totalQtyDiambil => items.fold(0, (s, i) => s + i.qtyDiambil);
  int get totalQtySisa => items.fold(0, (s, i) => s + (i.qtySisaOpname ?? 0));
  int get totalQtyTerjual => items.fold(0, (s, i) => s + i.qtyTerjual);
  int get totalPendapatan => items.fold(0, (s, i) => s + i.pendapatanItem);
  int get totalEstimasiNilai => items.fold(0, (s, i) => s + i.estimasiMaksimal);

  static StatusReviewBatch parseReviewStatus(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'ditinjau_admin':
        return StatusReviewBatch.ditinjauAdmin;
      case 'disetujui_owner':
      case 'disetujui':
        return StatusReviewBatch.disetujuiOwner;
      case 'ditolak':
        return StatusReviewBatch.ditolak;
      case 'menunggu':
      default:
        return StatusReviewBatch.menunggu;
    }
  }

  static String reviewStatusToApi(StatusReviewBatch s) {
    switch (s) {
      case StatusReviewBatch.ditinjauAdmin:
        return 'ditinjau_admin';
      case StatusReviewBatch.disetujuiOwner:
        return 'disetujui_owner';
      case StatusReviewBatch.ditolak:
        return 'ditolak';
      case StatusReviewBatch.menunggu:
        return 'menunggu';
    }
  }

  String get reviewStatusLabel {
    switch (statusReview) {
      case StatusReviewBatch.menunggu:
        return 'Menunggu Tinjauan';
      case StatusReviewBatch.ditinjauAdmin:
        return 'Ditinjau Admin';
      case StatusReviewBatch.disetujuiOwner:
        return 'Disetujui Owner';
      case StatusReviewBatch.ditolak:
        return 'Ditolak';
    }
  }

  static StatusOpnameBatch parseOpnameStatus(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'proses_opname':
      case 'proses':
        return StatusOpnameBatch.prosesOpname;
      case 'valid':
      case 'selesai':
        return StatusOpnameBatch.valid;
      case 'belum_opname':
      default:
        return StatusOpnameBatch.belumOpname;
    }
  }

  static String opnameStatusToApi(StatusOpnameBatch s) {
    switch (s) {
      case StatusOpnameBatch.prosesOpname:
        return 'proses_opname';
      case StatusOpnameBatch.valid:
        return 'valid';
      case StatusOpnameBatch.belumOpname:
        return 'belum_opname';
    }
  }

  String get opnameStatusLabel {
    if (isRejected) return 'Dibatalkan';
    switch (statusOpname) {
      case StatusOpnameBatch.belumOpname:
        return 'Menunggu Opname';
      case StatusOpnameBatch.prosesOpname:
        return 'Proses Opname';
      case StatusOpnameBatch.valid:
        return 'Valid';
    }
  }

  factory StockBatch.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return StockBatch(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      kodeBatch: json['kode_batch']?.toString() ?? 'BATCH-001',
      tanggal: json['tanggal']?.toString() ?? StockBatchService.todayYmd(),
      salesId: int.tryParse(json['sales_id']?.toString() ?? '0') ?? 0,
      salesName: json['sales_name']?.toString() ?? 'Sales Lapangan',
      salesEmail: json['sales_email']?.toString() ?? '',
      catatanPengajuan: json['catatan_pengajuan']?.toString() ?? '',
      statusReview: parseReviewStatus(json['status_review']?.toString()),
      reviewedByAdminName: json['reviewed_by_admin_name']?.toString(),
      reviewedByAdminAt: json['reviewed_by_admin_at'] != null
          ? DateTime.tryParse(json['reviewed_by_admin_at'].toString())
          : null,
      catatanAdmin: json['catatan_admin']?.toString(),
      reviewedByOwnerName: json['reviewed_by_owner_name']?.toString(),
      reviewedByOwnerAt: json['reviewed_by_owner_at'] != null
          ? DateTime.tryParse(json['reviewed_by_owner_at'].toString())
          : null,
      catatanOwner: json['catatan_owner']?.toString(),
      statusOpname: parseOpnameStatus(json['status_opname']?.toString()),
      opnameByName: json['opname_by_name']?.toString(),
      opnameByRole: json['opname_by_role']?.toString(),
      opnameAt: json['opname_at'] != null ? DateTime.tryParse(json['opname_at'].toString()) : null,
      catatanOpname: json['catatan_opname']?.toString(),
      items: rawItems
          .map((e) => StockBatchItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kode_batch': kodeBatch,
        'tanggal': tanggal,
        'sales_id': salesId,
        'sales_name': salesName,
        'sales_email': salesEmail,
        'catatan_pengajuan': catatanPengajuan,
        'status_review': reviewStatusToApi(statusReview),
        if (reviewedByAdminName != null) 'reviewed_by_admin_name': reviewedByAdminName,
        if (reviewedByAdminAt != null) 'reviewed_by_admin_at': reviewedByAdminAt!.toIso8601String(),
        if (catatanAdmin != null) 'catatan_admin': catatanAdmin,
        if (reviewedByOwnerName != null) 'reviewed_by_owner_name': reviewedByOwnerName,
        if (reviewedByOwnerAt != null) 'reviewed_by_owner_at': reviewedByOwnerAt!.toIso8601String(),
        if (catatanOwner != null) 'catatan_owner': catatanOwner,
        'status_opname': opnameStatusToApi(statusOpname),
        if (opnameByName != null) 'opname_by_name': opnameByName,
        if (opnameByRole != null) 'opname_by_role': opnameByRole,
        if (opnameAt != null) 'opname_at': opnameAt!.toIso8601String(),
        if (catatanOpname != null) 'catatan_opname': catatanOpname,
        'items': items.map((e) => e.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
      };
}

class StockBatchService {
  static const String _cacheKey = 'stock_batches_cache_v1';
  static List<StockBatch>? _inMemory;

  static bool get isTestEnv {
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

  static String formatShortDate(String ymd) {
    final parsed = DateTime.tryParse(ymd);
    if (parsed == null) return ymd;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
  }

  static List<StockBatch> defaultBatches() {
    final today = todayYmd();
    return [
      StockBatch(
        id: 1,
        kodeBatch: 'BATCH-${today.replaceAll('-', '')}-001',
        tanggal: today,
        salesId: 3,
        salesName: 'Muhammad Ulil Abshor',
        salesEmail: 'sales@majubersama.com',
        catatanPengajuan: 'Muatan barang kanvas rute area barat hari ini',
        statusReview: StatusReviewBatch.ditinjauAdmin,
        reviewedByAdminName: 'Agung Prasetyo Wibowo',
        reviewedByAdminAt: DateTime.now().subtract(const Duration(hours: 2)),
        catatanAdmin: 'Jumlah barang sesuai muatan gudang, diteruskan untuk tinjauan Owner.',
        statusOpname: StatusOpnameBatch.belumOpname,
        items: [
          StockBatchItem(
            id: 1,
            batchId: 1,
            productId: 1,
            kodeBarang: 'BRG-001',
            namaBarang: 'Plastik Kresek 1kg',
            kategori: 'Plastik',
            satuan: 'Pack',
            fotoUrl: 'preset:plastik',
            hargaSatuan: 15000,
            qtyDiambil: 20,
          ),
          StockBatchItem(
            id: 2,
            batchId: 1,
            productId: 2,
            kodeBarang: 'BRG-002',
            namaBarang: 'Plastik HD Bening 20x30',
            kategori: 'Plastik',
            satuan: 'Pack',
            fotoUrl: 'preset:plastik',
            hargaSatuan: 22000,
            qtyDiambil: 10,
          ),
        ],
      ),
      StockBatch(
        id: 2,
        kodeBatch: 'BATCH-${today.replaceAll('-', '')}-002',
        tanggal: today,
        salesId: 5,
        salesName: 'Ahmad Hidayat',
        salesEmail: 'ahmad.sales@majubersama.com',
        catatanPengajuan: 'Pengambilan stok rutin pagi',
        statusReview: StatusReviewBatch.menunggu,
        statusOpname: StatusOpnameBatch.belumOpname,
        items: [
          StockBatchItem(
            id: 3,
            batchId: 2,
            productId: 3,
            kodeBarang: 'BRG-003',
            namaBarang: 'Minyak Goreng 1L',
            kategori: 'Sembako',
            satuan: 'Pcs',
            fotoUrl: 'preset:minyak',
            hargaSatuan: 18500,
            qtyDiambil: 15,
          ),
        ],
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

  static Future<List<StockBatch>> loadCached({int? salesId}) async {
    List<StockBatch> list;
    if (_inMemory != null) {
      list = List<StockBatch>.from(_inMemory!);
    } else {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_cacheKey);
        if (raw != null && raw.isNotEmpty) {
          final decoded = jsonDecode(raw) as List<dynamic>;
          list = decoded
              .map((e) => StockBatch.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          _inMemory = List<StockBatch>.from(list);
        } else {
          list = defaultBatches();
          _inMemory = List<StockBatch>.from(list);
        }
      } catch (_) {
        list = defaultBatches();
        _inMemory = List<StockBatch>.from(list);
      }
    }
    list.sort((a, b) {
      final dateCmp = b.tanggal.compareTo(a.tanggal);
      if (dateCmp != 0) return dateCmp;
      return b.id.compareTo(a.id);
    });
    return salesId != null ? list.where((b) => b.salesId == salesId).toList() : list;
  }

  static Future<void> saveCached(List<StockBatch> list) async {
    _inMemory = List<StockBatch>.from(list);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(list.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  static Future<List<StockBatch>> fetchBatches({int? salesId}) async {
    final cached = await loadCached(salesId: salesId);
    if (isTestEnv) return cached;

    try {
      await AuthService.resolveBaseUrl();
      final qp = salesId != null ? '?sales_id=$salesId' : '';
      final response = await http
          .get(
            Uri.parse('${AuthService.activeBaseUrl}/stock-batches$qp'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final list = (body['data'] as List<dynamic>? ?? [])
            .map((e) => StockBatch.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        if (salesId == null) {
          await saveCached(list);
        } else {
          final all = await loadCached();
          final merged = all.where((b) => b.salesId != salesId).toList()..addAll(list);
          await saveCached(merged);
        }
        return list;
      }
    } catch (_) {}
    return cached;
  }

  /// Sales mengajukan batch barang per hari.
  /// Setelah dikirim, batch langsung otomatis masuk ke Pendapatan Sales
  /// untuk dilakukan Stok Opnam per batch bersama Administrator atau Owner.
  static Future<StockBatch> createDailyBatch({
    required UserModel salesUser,
    required String tanggal,
    required String catatanPengajuan,
    required List<Map<String, int>> items, // [{'product_id': 1, 'qty_diambil': 10}]
  }) async {
    if (!salesUser.isActive || salesUser.isSuspended) {
      throw Exception(
          'Akun Sales sedang nonaktif/ditangguhkan dan tidak dapat mengajukan batch barang.');
    }
    if (items.isEmpty) {
      throw Exception('Pilih minimal satu barang dalam batch pengajuan.');
    }

    // Gabungkan duplikat product_id dalam satu batch harian
    final Map<int, int> consolidatedQty = {};
    for (final raw in items) {
      final pid = raw['product_id'] ?? 0;
      final qty = raw['qty_diambil'] ?? raw['qty'] ?? 0;
      if (pid <= 0 || qty <= 0) {
        throw Exception('Jumlah setiap barang yang diambil harus lebih dari 0.');
      }
      consolidatedQty[pid] = (consolidatedQty[pid] ?? 0) + qty;
    }

    final normalizedItems = consolidatedQty.entries
        .map((e) => {'product_id': e.key, 'qty_diambil': e.value})
        .toList();

    if (!isTestEnv) {
      try {
        await AuthService.resolveBaseUrl();
        final token = await SessionService().getToken();
        final response = await http
            .post(
              Uri.parse('${AuthService.activeBaseUrl}/stock-batches'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
              },
              body: jsonEncode({
                'sales_id': salesUser.id,
                'sales_email': salesUser.email,
                'tanggal': tanggal,
                'catatan_pengajuan': catatanPengajuan.trim(),
                'items': normalizedItems,
              }),
            )
            .timeout(const Duration(seconds: 5));

        final body = jsonDecode(response.body);
        if (response.statusCode == 201 || response.statusCode == 200) {
          final created = StockBatch.fromJson(Map<String, dynamic>.from(body['data']));
          final all = await loadCached();
          all.removeWhere((b) => b.id == created.id || b.kodeBatch == created.kodeBatch);
          all.insert(0, created);
          await saveCached(all);
          return created;
        } else if (response.statusCode >= 400 && response.statusCode < 500) {
          throw Exception(body['message'] ?? 'Gagal mengirim batch pengajuan.');
        }
      } catch (e) {
        if (e.toString().contains('nonaktif') ||
            e.toString().contains('lebih dari 0') ||
            e.toString().contains('minimal satu') ||
            e.toString().contains('Gagal mengirim')) {
          rethrow;
        }
      }
    }

    // Offline / test fallback
    final products = await InventoryService.loadCachedProducts();
    final all = await loadCached();
    final nextId = all.isEmpty ? 1 : (all.map((e) => e.id).reduce((a, b) => a > b ? a : b) + 1);
    final sameDayCount = all.where((b) => b.tanggal == tanggal).length + 1;
    final kodeBatch =
        'BATCH-${tanggal.replaceAll('-', '')}-${sameDayCount.toString().padLeft(3, '0')}';

    final List<StockBatchItem> preparedItems = [];
    int itemSeq = 1;
    for (final entry in normalizedItems) {
      final pid = entry['product_id']!;
      final qty = entry['qty_diambil']!;
      final matches = products.where((p) => p.id == pid).toList();
      if (matches.isEmpty) {
        throw Exception('Barang dengan ID $pid tidak ditemukan.');
      }
      final prod = matches.first;
      if (!prod.isActive) {
        throw Exception('Barang "${prod.namaBarang}" berstatus nonaktif.');
      }
      preparedItems.add(
        StockBatchItem(
          id: nextId * 100 + itemSeq++,
          batchId: nextId,
          productId: prod.id,
          kodeBarang: prod.kodeBarang,
          namaBarang: prod.namaBarang,
          kategori: prod.kategori,
          satuan: prod.satuan,
          fotoUrl: prod.fotoUrl ?? 'preset:plastik',
          hargaSatuan: prod.harga,
          qtyDiambil: qty,
        ),
      );
    }

    final created = StockBatch(
      id: nextId,
      kodeBatch: kodeBatch,
      tanggal: tanggal,
      salesId: salesUser.id ?? 3,
      salesName: salesUser.name.isNotEmpty ? salesUser.name : 'Sales',
      salesEmail: salesUser.email,
      catatanPengajuan: catatanPengajuan.trim().isNotEmpty
          ? catatanPengajuan.trim()
          : 'Pengambilan barang batch harian',
      statusReview: StatusReviewBatch.menunggu,
      statusOpname: StatusOpnameBatch.belumOpname,
      items: preparedItems,
    );

    all.insert(0, created);
    await saveCached(all);
    return created;
  }

  /// Tinjauan oleh Admin / Owner pada FR10:
  /// - Admin: 'ditinjau_admin' atau 'ditolak'
  /// - Owner: 'disetujui_owner' (meninjau & menyetujui pengajuan) atau 'ditolak'
  static Future<StockBatch> reviewBatch({
    required int batchId,
    required UserModel actor,
    required StatusReviewBatch nextStatus,
    String? note,
  }) async {
    if (!actor.isManager) {
      throw Exception('Hanya Admin dan Owner yang berhak meninjau batch pengajuan barang.');
    }
    if (nextStatus == StatusReviewBatch.disetujuiOwner && !actor.isSuperAdmin) {
      throw Exception('Persetujuan final batch pengajuan harus ditinjau oleh Owner.');
    }
    if (nextStatus == StatusReviewBatch.ditolak && (note == null || note.trim().isEmpty)) {
      throw Exception('Alasan penolakan batch wajib diisi.');
    }

    if (!isTestEnv) {
      try {
        await AuthService.resolveBaseUrl();
        final token = await SessionService().getToken();
        final response = await http
            .put(
              Uri.parse('${AuthService.activeBaseUrl}/stock-batches/$batchId/review'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
              },
              body: jsonEncode({
                'actor_id': actor.id,
                'actor_email': actor.email,
                'status_review': StockBatch.reviewStatusToApi(nextStatus),
                if (note != null) 'catatan': note.trim(),
              }),
            )
            .timeout(const Duration(seconds: 5));

        final body = jsonDecode(response.body);
        if (response.statusCode == 200) {
          final updated = StockBatch.fromJson(Map<String, dynamic>.from(body['data']));
          final all = await loadCached();
          final idx = all.indexWhere((b) => b.id == batchId);
          if (idx != -1) all[idx] = updated;
          await saveCached(all);
          if (nextStatus == StatusReviewBatch.disetujuiOwner) {
            await _syncProductStockOnOwnerApproval(updated);
          }
          return updated;
        } else if (response.statusCode >= 400 && response.statusCode < 500) {
          throw Exception(body['message'] ?? 'Gagal memproses tinjauan batch.');
        }
      } catch (e) {
        if (e.toString().contains('Hanya') ||
            e.toString().contains('Persetujuan') ||
            e.toString().contains('Alasan') ||
            e.toString().contains('Gagal memproses')) {
          rethrow;
        }
      }
    }

    final all = await loadCached();
    final idx = all.indexWhere((b) => b.id == batchId);
    if (idx == -1) throw Exception('Batch pengajuan tidak ditemukan.');
    final batch = all[idx];
    final previousReview = batch.statusReview;

    final cleanNote = note?.trim();
    if (nextStatus == StatusReviewBatch.ditinjauAdmin) {
      batch.statusReview = StatusReviewBatch.ditinjauAdmin;
      batch.reviewedByAdminName = actor.name;
      batch.reviewedByAdminAt = DateTime.now();
      batch.catatanAdmin = (cleanNote != null && cleanNote.isNotEmpty)
          ? cleanNote
          : 'Telah diperiksa Admin, siap ditinjau Owner.';
    } else if (nextStatus == StatusReviewBatch.disetujuiOwner) {
      batch.statusReview = StatusReviewBatch.disetujuiOwner;
      batch.reviewedByOwnerName = actor.name;
      batch.reviewedByOwnerAt = DateTime.now();
      batch.catatanOwner = (cleanNote != null && cleanNote.isNotEmpty)
          ? cleanNote
          : 'Ditinjau dan disetujui oleh Owner (${actor.name}).';
      if (previousReview != StatusReviewBatch.disetujuiOwner) {
        await _syncProductStockOnOwnerApproval(batch);
      }
    } else if (nextStatus == StatusReviewBatch.ditolak) {
      batch.statusReview = StatusReviewBatch.ditolak;
      if (actor.isSuperAdmin) {
        batch.reviewedByOwnerName = actor.name;
        batch.reviewedByOwnerAt = DateTime.now();
        batch.catatanOwner = cleanNote;
      } else {
        batch.reviewedByAdminName = actor.name;
        batch.reviewedByAdminAt = DateTime.now();
        batch.catatanAdmin = cleanNote;
      }
    }

    await saveCached(all);
    return batch;
  }

  /// Stok Opnam per batch dilakukan bersama Administrator atau Owner pada FR05 Pendapatan Sales.
  /// Ketika selesai (finalize = true), statusOpname menjadi Valid.
  static Future<StockBatch> submitBatchOpname({
    required int batchId,
    required UserModel actor,
    required Map<int, int> sisaByItemId,
    Map<int, String>? catatanByItemId,
    String? catatanOpname,
    bool finalize = true,
  }) async {
    if (!actor.isManager) {
      throw Exception(
          'Stok opnam batch harus diverifikasi oleh Administrator atau Owner.');
    }

    final all = await loadCached();
    final idx = all.indexWhere((b) => b.id == batchId);
    if (idx == -1) throw Exception('Batch tidak ditemukan.');
    final target = all[idx];

    if (target.isRejected) {
      throw Exception('Batch yang ditolak tidak dapat dilakukan stok opname.');
    }
    if (target.isValid) {
      throw Exception('Batch ini sudah selesai stok opname dan berstatus Valid.');
    }

    for (final it in target.items) {
      if (!sisaByItemId.containsKey(it.id)) {
        throw Exception('Sisa stok untuk "${it.namaBarang}" wajib diisi.');
      }
      final sisa = sisaByItemId[it.id]!;
      if (sisa < 0 || sisa > it.qtyDiambil) {
        throw Exception(
            'Sisa stok "${it.namaBarang}" harus antara 0 dan ${it.qtyDiambil} ${it.satuan}.');
      }
    }

    if (!isTestEnv) {
      try {
        await AuthService.resolveBaseUrl();
        final token = await SessionService().getToken();
        final response = await http
            .put(
              Uri.parse('${AuthService.activeBaseUrl}/stock-batches/$batchId/opname'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
              },
              body: jsonEncode({
                'actor_id': actor.id,
                'actor_email': actor.email,
                'finalize': finalize,
                'catatan_opname': catatanOpname?.trim() ?? '',
                'items': target.items
                    .map((it) => {
                          'id': it.id,
                          'qty_sisa_opname': sisaByItemId[it.id]!,
                          'catatan_opname': catatanByItemId?[it.id]?.trim() ?? '',
                        })
                    .toList(),
              }),
            )
            .timeout(const Duration(seconds: 5));

        final body = jsonDecode(response.body);
        if (response.statusCode == 200) {
          final updated = StockBatch.fromJson(Map<String, dynamic>.from(body['data']));
          all[idx] = updated;
          await saveCached(all);
          if (finalize) {
            await _syncProductStockAfterOpname(updated);
          }
          return updated;
        } else if (response.statusCode >= 400 && response.statusCode < 500) {
          throw Exception(body['message'] ?? 'Gagal menyimpan stok opname.');
        }
      } catch (e) {
        if (e.toString().contains('Sisa stok') ||
            e.toString().contains('Batch') ||
            e.toString().contains('Stok opnam') ||
            e.toString().contains('Gagal menyimpan')) {
          rethrow;
        }
      }
    }

    for (final it in target.items) {
      it.qtySisaOpname = sisaByItemId[it.id]!;
      if (catatanByItemId != null && catatanByItemId.containsKey(it.id)) {
        it.catatanOpname = catatanByItemId[it.id]?.trim();
      }
    }

    target.opnameByName = actor.name;
    target.opnameByRole = actor.isSuperAdmin ? 'Owner' : 'Administrator';
    target.opnameAt = DateTime.now();
    target.catatanOpname = (catatanOpname != null && catatanOpname.trim().isNotEmpty)
        ? catatanOpname.trim()
        : (finalize
            ? 'Stok opnam per batch selesai bersama ${target.opnameByRole} (${actor.name}).'
            : 'Draft stok opname disimpan.');

    if (finalize) {
      target.statusOpname = StatusOpnameBatch.valid;
      // Jika Owner yang menyelesaikan opname dan sebelumnya belum ditandai disetujui Owner, catat tinjauan Owner
      if (actor.isSuperAdmin && target.statusReview != StatusReviewBatch.disetujuiOwner) {
        target.statusReview = StatusReviewBatch.disetujuiOwner;
        target.reviewedByOwnerName = actor.name;
        target.reviewedByOwnerAt = DateTime.now();
        target.catatanOwner ??= 'Ditinjau dan divalidasi oleh Owner pada stok opname.';
      }
      await _syncProductStockAfterOpname(target);
    } else {
      target.statusOpname = StatusOpnameBatch.prosesOpname;
    }

    await saveCached(all);
    return target;
  }

  static Future<void> deleteBatch(int batchId) async {
    final all = await loadCached();
    all.removeWhere((b) => b.id == batchId);
    await saveCached(all);

    if (!isTestEnv) {
      try {
        await AuthService.resolveBaseUrl();
        await http
            .delete(Uri.parse('${AuthService.activeBaseUrl}/stock-batches/$batchId'))
            .timeout(const Duration(seconds: 4));
      } catch (_) {}
    }
  }

  static Future<void> _syncProductStockOnOwnerApproval(StockBatch batch) async {
    final products = await InventoryService.loadCachedProducts();
    bool changed = false;
    for (final it in batch.items) {
      final pIdx = products.indexWhere((p) => p.id == it.productId);
      if (pIdx != -1) {
        final p = products[pIdx];
        p.stokSales += it.qtyDiambil;
        if (p.stokGudang >= it.qtyDiambil) {
          p.stokGudang -= it.qtyDiambil;
        }
        changed = true;
      }
    }
    if (changed) {
      await InventoryService.saveCachedProducts(products);
    }
  }

  static Future<void> _syncProductStockAfterOpname(StockBatch batch) async {
    final products = await InventoryService.loadCachedProducts();
    bool changed = false;
    for (final it in batch.items) {
      final pIdx = products.indexWhere((p) => p.id == it.productId);
      if (pIdx != -1) {
        final p = products[pIdx];
        p.stokSales = (p.stokSales - it.qtyTerjual).clamp(0, 999999);
        changed = true;
      }
    }
    if (changed) {
      await InventoryService.saveCachedProducts(products);
    }
  }
}
