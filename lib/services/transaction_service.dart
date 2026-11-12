import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'inventory_service.dart';
import 'session_service.dart';

enum StatusVerifikasiTransaksi { menunggu, disetujui, ditolak }

class TransactionItemDetail {
  final int id;
  final int productId;
  final String kodeBarang;
  final String namaBarang;
  final String satuan;
  final int qty;
  final int hargaSatuan; // Salinan harga saat transaksi
  final int subtotal;

  TransactionItemDetail({
    required this.id,
    required this.productId,
    required this.kodeBarang,
    required this.namaBarang,
    required this.satuan,
    required this.qty,
    required this.hargaSatuan,
    required this.subtotal,
  });

  factory TransactionItemDetail.fromJson(Map<String, dynamic> json) {
    final qtyVal = int.tryParse(json['qty']?.toString() ?? '0') ?? 0;
    final priceVal = double.tryParse(json['harga_satuan']?.toString() ?? '0')?.round() ?? 0;
    final subVal = double.tryParse(json['subtotal']?.toString() ?? '')?.round() ?? (qtyVal * priceVal);
    return TransactionItemDetail(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      productId: int.tryParse(json['product_id']?.toString() ?? '0') ?? 0,
      kodeBarang: json['kode_barang']?.toString() ?? '',
      namaBarang: json['nama_barang']?.toString() ?? 'Produk',
      satuan: json['satuan']?.toString() ?? 'Pack',
      qty: qtyVal,
      hargaSatuan: priceVal,
      subtotal: subVal,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'product_id': productId,
        'kode_barang': kodeBarang,
        'nama_barang': namaBarang,
        'satuan': satuan,
        'qty': qty,
        'harga_satuan': hargaSatuan,
        'subtotal': subtotal,
      };
}

class SalesTransaction {
  final int id;
  final String kodeTransaksi;
  final int salesId;
  final String salesName;
  final String tanggal; // YYYY-MM-DD
  final String namaPelanggan;
  final int total;
  StatusVerifikasiTransaksi statusVerifikasi;
  final String catatan;
  String? alasanPenolakan;
  String? verifiedByName;
  DateTime? verifiedAt;
  String? cancelledReason;
  final List<TransactionItemDetail> items;

  SalesTransaction({
    required this.id,
    required this.kodeTransaksi,
    required this.salesId,
    required this.salesName,
    required this.tanggal,
    required this.namaPelanggan,
    required this.total,
    this.statusVerifikasi = StatusVerifikasiTransaksi.menunggu,
    this.catatan = '',
    this.alasanPenolakan,
    this.verifiedByName,
    this.verifiedAt,
    this.cancelledReason,
    required this.items,
  });

  static StatusVerifikasiTransaksi parseStatus(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'disetujui':
        return StatusVerifikasiTransaksi.disetujui;
      case 'ditolak':
        return StatusVerifikasiTransaksi.ditolak;
      case 'menunggu':
      default:
        return StatusVerifikasiTransaksi.menunggu;
    }
  }

  static String statusToApi(StatusVerifikasiTransaksi s) {
    switch (s) {
      case StatusVerifikasiTransaksi.disetujui:
        return 'disetujui';
      case StatusVerifikasiTransaksi.ditolak:
        return 'ditolak';
      case StatusVerifikasiTransaksi.menunggu:
        return 'menunggu';
    }
  }

  String get statusLabel {
    switch (statusVerifikasi) {
      case StatusVerifikasiTransaksi.disetujui:
        return 'Disetujui';
      case StatusVerifikasiTransaksi.ditolak:
        return 'Ditolak';
      case StatusVerifikasiTransaksi.menunggu:
        return 'Menunggu';
    }
  }

  factory SalesTransaction.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return SalesTransaction(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      kodeTransaksi: json['kode_transaksi']?.toString() ?? 'TRX-000',
      salesId: int.tryParse(json['sales_id']?.toString() ?? '0') ?? 0,
      salesName: json['sales_name']?.toString() ?? 'Sales Lapangan',
      tanggal: json['tanggal']?.toString() ?? '',
      namaPelanggan: json['nama_pelanggan']?.toString() ?? 'Pelanggan Umum',
      total: double.tryParse(json['total']?.toString() ?? '0')?.round() ?? 0,
      statusVerifikasi: parseStatus(json['status_verifikasi']?.toString()),
      catatan: json['catatan']?.toString() ?? '',
      alasanPenolakan: json['alasan_penolakan']?.toString(),
      verifiedByName: json['verified_by_name']?.toString(),
      verifiedAt: json['verified_at'] != null ? DateTime.tryParse(json['verified_at'].toString()) : null,
      cancelledReason: json['cancelled_reason']?.toString(),
      items: rawItems
          .map((e) => TransactionItemDetail.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kode_transaksi': kodeTransaksi,
        'sales_id': salesId,
        'sales_name': salesName,
        'tanggal': tanggal,
        'nama_pelanggan': namaPelanggan,
        'total': total,
        'status_verifikasi': statusToApi(statusVerifikasi),
        'catatan': catatan,
        if (alasanPenolakan != null) 'alasan_penolakan': alasanPenolakan,
        if (verifiedByName != null) 'verified_by_name': verifiedByName,
        if (verifiedAt != null) 'verified_at': verifiedAt!.toIso8601String(),
        if (cancelledReason != null) 'cancelled_reason': cancelledReason,
        'items': items.map((e) => e.toJson()).toList(),
      };
}

class TransactionService {
  static const String _cacheKey = 'sales_transactions_cache_v1';
  static List<SalesTransaction>? _inMemory;

  static bool get _isTestEnv {
    try {
      return WidgetsBinding.instance.runtimeType.toString().contains('Test');
    } catch (_) {
      return false;
    }
  }

  static String formatRp(int amount) {
    return 'Rp ${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  static String todayYmd() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static List<SalesTransaction> defaultTransactions() {
    final today = todayYmd();
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yStr =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    return [
      SalesTransaction(
        id: 1,
        kodeTransaksi: 'TRX-${yStr.replaceAll('-', '')}-0001',
        salesId: 3,
        salesName: 'Muhammad Ulil Abshor',
        tanggal: yStr,
        namaPelanggan: 'Toko Sinar Makmur',
        total: 370000,
        statusVerifikasi: StatusVerifikasiTransaksi.disetujui,
        catatan: 'Pembelian rutin mingguan',
        verifiedByName: 'Agung Prasetyo Wibowo',
        verifiedAt: yesterday,
        items: [
          TransactionItemDetail(
            id: 1,
            productId: 1,
            kodeBarang: 'BRG-001',
            namaBarang: 'Plastik Kresek 1kg',
            satuan: 'Pack',
            qty: 10,
            hargaSatuan: 15000,
            subtotal: 150000,
          ),
          TransactionItemDetail(
            id: 2,
            productId: 2,
            kodeBarang: 'BRG-002',
            namaBarang: 'Plastik HD Bening 20x30',
            satuan: 'Pack',
            qty: 10,
            hargaSatuan: 22000,
            subtotal: 220000,
          ),
        ],
      ),
      SalesTransaction(
        id: 2,
        kodeTransaksi: 'TRX-${today.replaceAll('-', '')}-0002',
        salesId: 3,
        salesName: 'Muhammad Ulil Abshor',
        tanggal: today,
        namaPelanggan: 'Warung Berkah Jaya',
        total: 185000,
        statusVerifikasi: StatusVerifikasiTransaksi.menunggu,
        catatan: 'Menunggu pengecekan admin',
        items: [
          TransactionItemDetail(
            id: 3,
            productId: 3,
            kodeBarang: 'BRG-003',
            namaBarang: 'Minyak Goreng 1L',
            satuan: 'Pcs',
            qty: 10,
            hargaSatuan: 18500,
            subtotal: 185000,
          ),
        ],
      ),
      SalesTransaction(
        id: 3,
        kodeTransaksi: 'TRX-${yStr.replaceAll('-', '')}-0003',
        salesId: 5,
        salesName: 'Ahmad Hidayat',
        tanggal: yStr,
        namaPelanggan: 'Minimarket Sumber Rejeki',
        total: 220000,
        statusVerifikasi: StatusVerifikasiTransaksi.ditolak,
        catatan: 'Order kemasan 20x30',
        alasanPenolakan: 'Jumlah unit pada nota tidak sesuai dengan stok keluar.',
        verifiedByName: 'Agung Prasetyo Wibowo',
        verifiedAt: yesterday,
        items: [
          TransactionItemDetail(
            id: 4,
            productId: 2,
            kodeBarang: 'BRG-002',
            namaBarang: 'Plastik HD Bening 20x30',
            satuan: 'Pack',
            qty: 10,
            hargaSatuan: 22000,
            subtotal: 220000,
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

  static Future<List<SalesTransaction>> loadCached({int? salesId}) async {
    List<SalesTransaction> list;
    if (_inMemory != null) {
      list = List<SalesTransaction>.from(_inMemory!);
    } else {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_cacheKey);
        if (raw != null && raw.isNotEmpty) {
          final decoded = jsonDecode(raw) as List<dynamic>;
          list = decoded
              .map((e) => SalesTransaction.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          _inMemory = List<SalesTransaction>.from(list);
        } else {
          list = defaultTransactions();
          _inMemory = List<SalesTransaction>.from(list);
        }
      } catch (_) {
        list = defaultTransactions();
        _inMemory = List<SalesTransaction>.from(list);
      }
    }
    list.sort((a, b) => b.tanggal.compareTo(a.tanggal));
    return salesId != null ? list.where((t) => t.salesId == salesId).toList() : list;
  }

  static Future<void> saveCached(List<SalesTransaction> list) async {
    _inMemory = List<SalesTransaction>.from(list);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(list.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  static Future<List<SalesTransaction>> fetchTransactions({int? salesId}) async {
    final cached = await loadCached(salesId: salesId);
    if (_isTestEnv) return cached;

    try {
      await AuthService.resolveBaseUrl();
      final qp = salesId != null ? '?sales_id=$salesId' : '';
      final response = await http
          .get(
            Uri.parse('${AuthService.activeBaseUrl}/transactions$qp'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final list = (body['data'] as List<dynamic>? ?? [])
            .map((e) => SalesTransaction.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        if (salesId == null) {
          await saveCached(list);
        } else {
          final all = await loadCached();
          final merged = all.where((t) => t.salesId != salesId).toList()..addAll(list);
          await saveCached(merged);
        }
        return list;
      }
    } catch (_) {}
    return cached;
  }

  static Future<SalesTransaction> createTransaction({
    required int salesId,
    required String salesName,
    required bool isSalesActive,
    required String tanggal,
    required String namaPelanggan,
    required String catatan,
    required List<Map<String, int>> items, // [{'product_id': 1, 'qty': 5}]
  }) async {
    if (!isSalesActive) {
      throw Exception('Akun Sales sedang nonaktif/ditangguhkan dan tidak dapat membuat catatan penjualan.');
    }
    if (items.isEmpty) {
      throw Exception('Minimal satu produk harus dipilih.');
    }
    for (final it in items) {
      if ((it['qty'] ?? 0) <= 0) {
        throw Exception('Jumlah setiap produk harus lebih besar dari 0.');
      }
    }

    if (!_isTestEnv) {
      try {
        await AuthService.resolveBaseUrl();
        final token = await SessionService().getToken();
        final response = await http
            .post(
              Uri.parse('${AuthService.activeBaseUrl}/transactions'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
              },
              body: jsonEncode({
                'sales_id': salesId,
                'tanggal': tanggal,
                'nama_pelanggan': namaPelanggan.trim().isEmpty ? 'Pelanggan Umum' : namaPelanggan.trim(),
                'catatan': catatan.trim(),
                'items': items,
              }),
            )
            .timeout(const Duration(seconds: 5));
        final body = jsonDecode(response.body);
        if (response.statusCode == 201 || response.statusCode == 200) {
          final created = SalesTransaction.fromJson(Map<String, dynamic>.from(body['data']));
          final all = await loadCached();
          all.insert(0, created);
          await saveCached(all);
          return created;
        } else {
          throw Exception(body['message'] ?? 'Gagal mencatat penjualan.');
        }
      } catch (e) {
        if (e.toString().contains('nonaktif') ||
            e.toString().contains('lebih besar') ||
            e.toString().contains('Minimal')) {
          rethrow;
        }
      }
    }

    // Offline / mock fallback: hitung harga satuan & total secara otoritatif dari daftar produk
    final products = await InventoryService.loadCachedProducts();
    final List<TransactionItemDetail> prepared = [];
    int serverTotal = 0;

    for (final raw in items) {
      final pid = raw['product_id']!;
      final qty = raw['qty']!;
      final prodMatches = products.where((p) => p.id == pid).toList();
      if (prodMatches.isEmpty) throw Exception('Produk tidak ditemukan.');
      final prod = prodMatches.first;
      if (!prod.isActive) {
        throw Exception('Produk "${prod.namaBarang}" nonaktif dan tidak dapat dipilih untuk transaksi baru.');
      }
      final sub = prod.harga * qty;
      serverTotal += sub;
      prepared.add(
        TransactionItemDetail(
          id: prepared.length + 1,
          productId: prod.id,
          kodeBarang: prod.kodeBarang,
          namaBarang: prod.namaBarang,
          satuan: prod.satuan,
          qty: qty,
          hargaSatuan: prod.harga, // Salinan harga saat transaksi
          subtotal: sub,
        ),
      );
    }

    final all = await loadCached();
    final nextId = all.isEmpty ? 1 : (all.map((e) => e.id).reduce((a, b) => a > b ? a : b) + 1);
    final kode = 'TRX-${tanggal.replaceAll('-', '')}-${nextId.toString().padLeft(4, '0')}';

    final created = SalesTransaction(
      id: nextId,
      kodeTransaksi: kode,
      salesId: salesId,
      salesName: salesName,
      tanggal: tanggal,
      namaPelanggan: namaPelanggan.trim().isEmpty ? 'Pelanggan Umum' : namaPelanggan.trim(),
      total: serverTotal,
      statusVerifikasi: StatusVerifikasiTransaksi.menunggu,
      catatan: catatan.trim(),
      items: prepared,
    );
    all.insert(0, created);
    await saveCached(all);
    return created;
  }

  static Future<SalesTransaction> verifyTransaction({
    required int transactionId,
    required int actorId,
    required String actorEmail,
    required String actorName,
    required StatusVerifikasiTransaksi status,
    String? alasanPenolakan,
  }) async {
    if (status == StatusVerifikasiTransaksi.ditolak &&
        (alasanPenolakan == null || alasanPenolakan.trim().isEmpty)) {
      throw Exception('Alasan penolakan wajib diisi.');
    }

    if (!_isTestEnv) {
      try {
        await AuthService.resolveBaseUrl();
        final token = await SessionService().getToken();
        final response = await http
            .put(
              Uri.parse('${AuthService.activeBaseUrl}/transactions/$transactionId/verify'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
              },
              body: jsonEncode({
                'actor_id': actorId,
                'actor_email': actorEmail,
                'status_verifikasi': SalesTransaction.statusToApi(status),
                if (alasanPenolakan != null) 'alasan_penolakan': alasanPenolakan.trim(),
              }),
            )
            .timeout(const Duration(seconds: 5));
        final body = jsonDecode(response.body);
        if (response.statusCode == 200) {
          final updated = SalesTransaction.fromJson(Map<String, dynamic>.from(body['data']));
          final all = await loadCached();
          final idx = all.indexWhere((t) => t.id == transactionId);
          if (idx != -1) all[idx] = updated;
          await saveCached(all);
          return updated;
        } else {
          throw Exception(body['message'] ?? 'Gagal memverifikasi transaksi.');
        }
      } catch (e) {
        if (e.toString().contains('Akses ditolak') ||
            e.toString().contains('Alasan') ||
            e.toString().contains('tidak dapat diedit')) {
          rethrow;
        }
      }
    }

    final all = await loadCached();
    final idx = all.indexWhere((t) => t.id == transactionId);
    if (idx == -1) throw Exception('Transaksi tidak ditemukan.');
    if (all[idx].statusVerifikasi == StatusVerifikasiTransaksi.disetujui) {
      throw Exception('Catatan penjualan yang sudah disetujui tidak dapat diedit langsung.');
    }
    all[idx].statusVerifikasi = status;
    all[idx].alasanPenolakan =
        status == StatusVerifikasiTransaksi.ditolak ? alasanPenolakan?.trim() : null;
    all[idx].verifiedByName = actorName;
    all[idx].verifiedAt = DateTime.now();
    await saveCached(all);
    return all[idx];
  }

  static Future<SalesTransaction> cancelApprovedTransaction({
    required int transactionId,
    required int actorId,
    required String actorEmail,
    required String actorName,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      throw Exception('Alasan pembatalan/koreksi wajib diisi.');
    }

    if (!_isTestEnv) {
      try {
        await AuthService.resolveBaseUrl();
        final token = await SessionService().getToken();
        final response = await http
            .post(
              Uri.parse('${AuthService.activeBaseUrl}/transactions/$transactionId/cancel'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
              },
              body: jsonEncode({
                'actor_id': actorId,
                'actor_email': actorEmail,
                'reason': reason.trim(),
              }),
            )
            .timeout(const Duration(seconds: 5));
        final body = jsonDecode(response.body);
        if (response.statusCode == 200) {
          final updated = SalesTransaction.fromJson(Map<String, dynamic>.from(body['data']));
          final all = await loadCached();
          final idx = all.indexWhere((t) => t.id == transactionId);
          if (idx != -1) all[idx] = updated;
          await saveCached(all);
          return updated;
        } else {
          throw Exception(body['message'] ?? 'Gagal membatalkan transaksi.');
        }
      } catch (e) {
        if (e.toString().contains('Akses ditolak') || e.toString().contains('Alasan')) {
          rethrow;
        }
      }
    }

    final all = await loadCached();
    final idx = all.indexWhere((t) => t.id == transactionId);
    if (idx == -1) throw Exception('Transaksi tidak ditemukan.');
    all[idx].statusVerifikasi = StatusVerifikasiTransaksi.ditolak;
    all[idx].cancelledReason = reason.trim();
    all[idx].alasanPenolakan = 'Dibatalkan/Koreksi: ${reason.trim()}';
    all[idx].verifiedByName = actorName;
    all[idx].verifiedAt = DateTime.now();
    await saveCached(all);
    return all[idx];
  }
}
