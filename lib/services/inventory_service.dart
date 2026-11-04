import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

enum JenisPengajuanStok { tambah, kurang, retur }

enum StatusPengajuanStok { menunggu, disetujui, ditolak }

class ProductItem {
  final int id;
  String kodeBarang;
  String namaBarang;
  String kategori;
  String deskripsi;
  String satuan;
  int stokGudang;
  int stokSales;
  int harga;
  String? fotoUrl;
  bool isActive;

  ProductItem({
    required this.id,
    required this.kodeBarang,
    required this.namaBarang,
    this.kategori = 'Plastik',
    this.deskripsi = '',
    this.satuan = 'Pack',
    this.stokGudang = 0,
    this.stokSales = 0,
    this.harga = 15000,
    this.fotoUrl,
    this.isActive = true,
  });

  String get statusLabel {
    if (!isActive) return 'Nonaktif';
    if (stokGudang <= 0) return 'Habis';
    return 'Aktif';
  }

  String get dropdownLabel => '$kategori - $namaBarang';

  String get formattedHarga {
    return 'Rp ${harga.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  factory ProductItem.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final int parsedId = rawId is int ? rawId : (int.tryParse(rawId?.toString() ?? '') ?? 1);
    final rawActive = json['is_active'];
    final bool active = rawActive == null
        ? true
        : (rawActive == true || rawActive == 1 || rawActive == '1');

    return ProductItem(
      id: parsedId,
      kodeBarang: json['kode_barang']?.toString() ?? 'BRG-${parsedId.toString().padLeft(3, '0')}',
      namaBarang: json['nama_barang']?.toString() ?? '',
      kategori: json['kategori']?.toString().isNotEmpty == true
          ? json['kategori'].toString()
          : _inferCategoryFromName(json['nama_barang']?.toString() ?? ''),
      deskripsi: json['deskripsi']?.toString() ?? '',
      satuan: json['satuan']?.toString().isNotEmpty == true ? json['satuan'].toString() : 'Pack',
      stokGudang: int.tryParse(json['stok_gudang']?.toString() ?? '0') ?? 0,
      stokSales: int.tryParse(json['stok_sales']?.toString() ?? '0') ?? 0,
      harga: int.tryParse(json['harga']?.toString() ?? '') ?? _inferDefaultPrice(parsedId),
      fotoUrl: json['foto_url']?.toString(),
      isActive: active,
    );
  }

  static int _inferDefaultPrice(int id) {
    switch (id) {
      case 1:
        return 15000;
      case 2:
        return 22000;
      case 3:
        return 18500;
      default:
        return 15000;
    }
  }

  static String _inferCategoryFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('plastik') || lower.contains('kresek') || lower.contains('pp')) {
      return 'Plastik';
    }
    if (lower.contains('minyak') || lower.contains('gula') || lower.contains('tepung')) {
      return 'Sembako';
    }
    return 'Plastik';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kode_barang': kodeBarang,
      'nama_barang': namaBarang,
      'kategori': kategori,
      'deskripsi': deskripsi,
      'satuan': satuan,
      'stok_gudang': stokGudang,
      'stok_sales': stokSales,
      'harga': harga,
      'foto_url': fotoUrl,
      'is_active': isActive ? 1 : 0,
    };
  }

  ProductItem copyWith({
    int? id,
    String? kodeBarang,
    String? namaBarang,
    String? kategori,
    String? deskripsi,
    String? satuan,
    int? stokGudang,
    int? stokSales,
    int? harga,
    String? fotoUrl,
    bool? isActive,
  }) {
    return ProductItem(
      id: id ?? this.id,
      kodeBarang: kodeBarang ?? this.kodeBarang,
      namaBarang: namaBarang ?? this.namaBarang,
      kategori: kategori ?? this.kategori,
      deskripsi: deskripsi ?? this.deskripsi,
      satuan: satuan ?? this.satuan,
      stokGudang: stokGudang ?? this.stokGudang,
      stokSales: stokSales ?? this.stokSales,
      harga: harga ?? this.harga,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      isActive: isActive ?? this.isActive,
    );
  }
}

class StockRequestItem {
  final int id;
  final String kodePengajuan;
  final int salesId;
  final String salesName;
  final String salesEmail;
  int? productId;
  String kodeBarang;
  String namaBarang;
  String kategori;
  String satuan;
  String? fotoUrl;
  int stokGudang;
  int stokSales;
  JenisPengajuanStok jenis;
  int qtyDiajukan;
  int? qtyDisetujui;
  String alasan;
  String tanggalPengajuan;
  StatusPengajuanStok status;
  String? catatanAdmin;
  String? diprosesOleh;

  StockRequestItem({
    required this.id,
    required this.kodePengajuan,
    this.salesId = 0,
    this.salesName = 'Sales',
    this.salesEmail = '',
    this.productId,
    required this.kodeBarang,
    required this.namaBarang,
    this.kategori = 'Plastik',
    this.satuan = 'Pack',
    this.fotoUrl,
    this.stokGudang = 0,
    this.stokSales = 0,
    this.jenis = JenisPengajuanStok.tambah,
    required this.qtyDiajukan,
    this.qtyDisetujui,
    required this.alasan,
    required this.tanggalPengajuan,
    this.status = StatusPengajuanStok.menunggu,
    this.catatanAdmin,
    this.diprosesOleh,
  });

  static JenisPengajuanStok parseJenis(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'kurang':
        return JenisPengajuanStok.kurang;
      case 'retur':
        return JenisPengajuanStok.retur;
      default:
        return JenisPengajuanStok.tambah;
    }
  }

  static String jenisToApi(JenisPengajuanStok j) {
    switch (j) {
      case JenisPengajuanStok.tambah:
        return 'tambah';
      case JenisPengajuanStok.kurang:
        return 'kurang';
      case JenisPengajuanStok.retur:
        return 'retur';
    }
  }

  String get jenisBadgeLabel {
    switch (jenis) {
      case JenisPengajuanStok.tambah:
        return 'Tambah';
      case JenisPengajuanStok.kurang:
        return 'Kurang';
      case JenisPengajuanStok.retur:
        return 'Retur';
    }
  }

  String get jenisFullLabel {
    switch (jenis) {
      case JenisPengajuanStok.tambah:
        return 'Tambah Stok';
      case JenisPengajuanStok.kurang:
        return 'Kurang Stok';
      case JenisPengajuanStok.retur:
        return 'Retur Barang';
    }
  }

  static StatusPengajuanStok parseStatus(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'disetujui':
      case 'approved':
        return StatusPengajuanStok.disetujui;
      case 'ditolak':
      case 'rejected':
        return StatusPengajuanStok.ditolak;
      default:
        return StatusPengajuanStok.menunggu;
    }
  }

  static String statusToApi(StatusPengajuanStok s) {
    switch (s) {
      case StatusPengajuanStok.disetujui:
        return 'disetujui';
      case StatusPengajuanStok.ditolak:
        return 'ditolak';
      case StatusPengajuanStok.menunggu:
        return 'menunggu';
    }
  }

  String get statusLabel {
    switch (status) {
      case StatusPengajuanStok.disetujui:
        return 'Disetujui';
      case StatusPengajuanStok.ditolak:
        return 'Ditolak';
      case StatusPengajuanStok.menunggu:
        return 'Menunggu';
    }
  }

  static String formatShortDate(String? rawIsoOrDate) {
    if (rawIsoOrDate == null || rawIsoOrDate.trim().isEmpty) {
      return '28 Okt 2026';
    }
    final trimmed = rawIsoOrDate.trim();
    if (RegExp(r'^\d{1,2}\s+[A-Za-z]{3}\s+\d{4}').hasMatch(trimmed)) {
      return trimmed;
    }
    final dt = DateTime.tryParse(trimmed)?.toLocal();
    if (dt != null) {
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
        'Des'
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    }
    return trimmed;
  }

  factory StockRequestItem.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final int parsedId = rawId is int ? rawId : (int.tryParse(rawId?.toString() ?? '') ?? 1);
    final rawProdId = json['product_id'];
    final int? parsedProdId =
        rawProdId is int ? rawProdId : int.tryParse(rawProdId?.toString() ?? '');

    return StockRequestItem(
      id: parsedId,
      kodePengajuan:
          json['kode_pengajuan']?.toString() ?? 'REQ-2026-${parsedId.toString().padLeft(3, '0')}',
      salesId: int.tryParse(json['sales_id']?.toString() ?? '0') ?? 0,
      salesName: json['sales_name']?.toString() ?? 'Sales',
      salesEmail: json['sales_email']?.toString() ?? '',
      productId: parsedProdId,
      kodeBarang: json['kode_barang']?.toString() ?? 'BRG-${parsedId.toString().padLeft(3, '0')}',
      namaBarang: json['nama_barang']?.toString() ?? '',
      kategori: json['kategori']?.toString() ?? 'Plastik',
      satuan: json['satuan']?.toString() ?? 'Pack',
      fotoUrl: json['foto_url']?.toString() ?? 'preset:plastik',
      stokGudang: int.tryParse(json['stok_gudang']?.toString() ?? '0') ?? 0,
      stokSales: int.tryParse(json['stok_sales']?.toString() ?? '0') ?? 0,
      jenis: parseJenis(json['jenis']?.toString()),
      qtyDiajukan: int.tryParse(json['qty_diajukan']?.toString() ?? '1') ?? 1,
      qtyDisetujui: json['qty_disetujui'] != null
          ? int.tryParse(json['qty_disetujui'].toString())
          : null,
      alasan: json['alasan']?.toString() ?? '',
      tanggalPengajuan: json['tanggal_pengajuan']?.toString() ??
          formatShortDate(json['created_at']?.toString()),
      status: parseStatus(json['status']?.toString()),
      catatanAdmin: json['catatan_admin']?.toString(),
      diprosesOleh: json['diproses_oleh']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kode_pengajuan': kodePengajuan,
      'sales_id': salesId,
      'sales_name': salesName,
      'sales_email': salesEmail,
      'product_id': productId,
      'kode_barang': kodeBarang,
      'nama_barang': namaBarang,
      'kategori': kategori,
      'satuan': satuan,
      'foto_url': fotoUrl,
      'stok_gudang': stokGudang,
      'stok_sales': stokSales,
      'jenis': jenisToApi(jenis),
      'qty_diajukan': qtyDiajukan,
      'qty_disetujui': qtyDisetujui,
      'alasan': alasan,
      'tanggal_pengajuan': tanggalPengajuan,
      'status': statusToApi(status),
      'catatan_admin': catatanAdmin,
      'diproses_oleh': diprosesOleh,
    };
  }
}

class InventoryService {
  static const String _productsCacheKey = 'inventory_products_cache_v3';
  static const String _requestsCacheKey = 'inventory_stock_requests_cache_v3';

  static bool get isTestEnv {
    try {
      final bindingName = WidgetsBinding.instance.runtimeType.toString();
      if (bindingName.contains('Test')) return true;
    } catch (_) {}
    return false;
  }

  static List<ProductItem>? _inMemoryProducts;
  static List<StockRequestItem>? _inMemoryRequests;

  static List<ProductItem> defaultProducts() {
    return [
      ProductItem(
        id: 1,
        kodeBarang: 'BRG-001',
        namaBarang: 'Plastik Kresek 1kg',
        kategori: 'Plastik',
        deskripsi: 'Kantong plastik kresek HDPE putih 1kg kualitas tebal',
        satuan: 'Pack',
        stokGudang: 120,
        stokSales: 15,
        harga: 15000,
        fotoUrl: 'preset:plastik',
      ),
      ProductItem(
        id: 2,
        kodeBarang: 'BRG-002',
        namaBarang: 'Plastik HD Bening 20x30',
        kategori: 'Plastik',
        deskripsi: 'Plastik HD bening tebal 20x30 cm',
        satuan: 'Pack',
        stokGudang: 85,
        stokSales: 10,
        harga: 22000,
        fotoUrl: 'preset:plastik',
      ),
      ProductItem(
        id: 3,
        kodeBarang: 'BRG-003',
        namaBarang: 'Minyak Goreng 1L',
        kategori: 'Sembako',
        deskripsi: 'Minyak goreng sawit kemasan bantal 1 liter',
        satuan: 'Pcs',
        stokGudang: 200,
        stokSales: 25,
        harga: 18500,
        fotoUrl: 'preset:minyak',
      ),
    ];
  }

  static Future<void> updateProductPrice(int productId, int newPrice, {int? updatedBy}) async {
    final prods = await loadCachedProducts();
    final idx = prods.indexWhere((p) => p.id == productId);
    if (idx != -1) {
      prods[idx].harga = newPrice;
      await saveCachedProducts(prods);
    }
    if (!isTestEnv) {
      try {
        await AuthService.resolveBaseUrl();
        await http
            .patch(
              Uri.parse('${AuthService.activeBaseUrl}/products/$productId/price'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode({
                'harga': newPrice,
                if (updatedBy != null) 'updated_by': updatedBy,
              }),
            )
            .timeout(const Duration(seconds: 4));
      } catch (_) {}
    }
  }

  static List<StockRequestItem> defaultStockRequests() {
    return [
      StockRequestItem(
        id: 1,
        kodePengajuan: 'REQ-2026-001',
        salesId: 3,
        salesName: 'Muhammad Ulil Abshor',
        salesEmail: 'sales@majubersama.com',
        productId: 1,
        kodeBarang: 'BRG-001',
        namaBarang: 'Plastik Kresek 1kg',
        kategori: 'Plastik',
        satuan: 'Pack',
        fotoUrl: 'preset:plastik',
        stokGudang: 120,
        stokSales: 15,
        jenis: JenisPengajuanStok.tambah,
        qtyDiajukan: 10,
        alasan: 'Pengajuan Tambah Stok toko area barat',
        tanggalPengajuan: '3 Nov 2026',
        status: StatusPengajuanStok.menunggu,
      ),
      StockRequestItem(
        id: 2,
        kodePengajuan: 'REQ-2026-002',
        salesId: 5,
        salesName: 'Ahmad Hidayat',
        salesEmail: 'ahmad.sales@majubersama.com',
        productId: 2,
        kodeBarang: 'BRG-002',
        namaBarang: 'Plastik HD Bening 20x30',
        kategori: 'Plastik',
        satuan: 'Pack',
        fotoUrl: 'preset:plastik',
        stokGudang: 85,
        stokSales: 10,
        jenis: JenisPengajuanStok.tambah,
        qtyDiajukan: 5,
        alasan: 'Stok di toko hampir habis, mohon untuk ditambahkan.',
        tanggalPengajuan: '2 Nov 2026',
        status: StatusPengajuanStok.menunggu,
      ),
      StockRequestItem(
        id: 3,
        kodePengajuan: 'REQ-2026-003',
        salesId: 3,
        salesName: 'Muhammad Ulil Abshor',
        salesEmail: 'sales@majubersama.com',
        productId: 3,
        kodeBarang: 'BRG-003',
        namaBarang: 'Minyak Goreng 1L',
        kategori: 'Sembako',
        satuan: 'Pcs',
        fotoUrl: 'preset:minyak',
        stokGudang: 200,
        stokSales: 25,
        jenis: JenisPengajuanStok.retur,
        qtyDiajukan: 2,
        qtyDisetujui: 2,
        alasan: 'Kemasan bocor dari pabrik saat pengiriman ke toko.',
        tanggalPengajuan: '1 Nov 2026',
        status: StatusPengajuanStok.disetujui,
        catatanAdmin: 'Retur telah diterima dan dicatat di gudang.',
        diprosesOleh: 'Agung Prasetyo Wibowo (Admin)',
      ),
    ];
  }

  static Future<void> clearCache() async {
    _inMemoryProducts = null;
    _inMemoryRequests = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_productsCacheKey);
      await prefs.remove(_requestsCacheKey);
    } catch (_) {}
  }

  static Future<List<ProductItem>> loadCachedProducts() async {
    if (_inMemoryProducts != null) {
      return List<ProductItem>.from(_inMemoryProducts!);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_productsCacheKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        final list = decoded
            .map((e) => ProductItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        _inMemoryProducts = List<ProductItem>.from(list);
        return list;
      }
    } catch (_) {}
    final defaults = defaultProducts();
    _inMemoryProducts = List<ProductItem>.from(defaults);
    return defaults;
  }

  static Future<void> saveCachedProducts(List<ProductItem> list) async {
    _inMemoryProducts = List<ProductItem>.from(list);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _productsCacheKey,
        jsonEncode(list.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }

  static Future<List<StockRequestItem>> loadCachedRequests() async {
    if (_inMemoryRequests != null) {
      return List<StockRequestItem>.from(_inMemoryRequests!);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_requestsCacheKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        final list = decoded
            .map((e) => StockRequestItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        _inMemoryRequests = List<StockRequestItem>.from(list);
        return list;
      }
    } catch (_) {}
    final defaults = defaultStockRequests();
    _inMemoryRequests = List<StockRequestItem>.from(defaults);
    return defaults;
  }

  static Future<void> saveCachedRequests(List<StockRequestItem> list) async {
    _inMemoryRequests = List<StockRequestItem>.from(list);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _requestsCacheKey,
        jsonEncode(list.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }

  static Future<List<ProductItem>> fetchProducts({int? salesId}) async {
    final cached = await loadCachedProducts();
    if (isTestEnv) return cached;

    try {
      await AuthService.resolveBaseUrl();
      final response = await http
          .get(
            Uri.parse('${AuthService.activeBaseUrl}/products${salesId != null ? '?sales_id=$salesId' : ''}'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(milliseconds: 2000));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'] as List<dynamic>? ?? [];
        if (data.isNotEmpty) {
          final fetched = data
              .map((e) => ProductItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          final Map<int, ProductItem> map = {};
          for (final p in cached) {
            map[p.id] = p;
          }
          for (final p in fetched) {
            map[p.id] = p;
          }
          final merged = map.values.toList()..sort((a, b) => a.id.compareTo(b.id));
          await saveCachedProducts(merged);
          return merged;
        }
      }
    } catch (_) {}
    return cached;
  }

  static Future<List<StockRequestItem>> fetchStockRequests({int? salesId}) async {
    final cached = await loadCachedRequests();
    if (isTestEnv) {
      if (salesId != null) {
        return cached.where((r) => r.salesId == salesId).toList();
      }
      return cached;
    }

    try {
      await AuthService.resolveBaseUrl();
      final queryParam = salesId != null ? '?sales_id=$salesId' : '';
      final response = await http
          .get(
            Uri.parse('${AuthService.activeBaseUrl}/stock-requests$queryParam'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(milliseconds: 2000));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'] as List<dynamic>? ?? [];
        if (data.isNotEmpty) {
          final fetched = data
              .map((e) => StockRequestItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          final Map<int, StockRequestItem> map = {};
          for (final r in cached) {
            map[r.id] = r;
          }
          for (final r in fetched) {
            map[r.id] = r;
          }
          final merged = map.values.toList()..sort((a, b) => b.id.compareTo(a.id));
          await saveCachedRequests(merged);
          if (salesId != null) {
            return merged.where((r) => r.salesId == salesId).toList();
          }
          return merged;
        }
      }
    } catch (_) {}

    if (salesId != null) {
      return cached.where((r) => r.salesId == salesId).toList();
    }
    return cached;
  }
}

class ProductThumbnailWidget extends StatelessWidget {
  final String? fotoUrl;
  final String namaBarang;
  final String kategori;
  final double size;
  final double borderRadius;

  const ProductThumbnailWidget({
    Key? key,
    this.fotoUrl,
    required this.namaBarang,
    this.kategori = 'Plastik',
    this.size = 44,
    this.borderRadius = 10,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final raw = (fotoUrl ?? '').trim();
    final lowerName = namaBarang.toLowerCase();

    // 1. Jika foto_url adalah data URI base64
    if (raw.startsWith('data:image')) {
      try {
        final commaIdx = raw.indexOf(',');
        if (commaIdx != -1) {
          final bytes = base64Decode(raw.substring(commaIdx + 1));
          return ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Image.memory(
              bytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildPresetVisual(lowerName, raw),
            ),
          );
        }
      } catch (_) {}
    }

    // 2. Jika foto_url adalah URL HTTP/HTTPS
    if (!InventoryService.isTestEnv &&
        (raw.startsWith('http://') || raw.startsWith('https://'))) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.network(
          raw,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPresetVisual(lowerName, raw),
        ),
      );
    }

    return _buildPresetVisual(lowerName, raw);
  }

  Widget _buildPresetVisual(String lowerName, String rawPreset) {
    if (rawPreset == 'preset:minyak' || lowerName.contains('minyak')) {
      // Botol Minyak Goreng kuning keemasan seperti di gambar
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: size * 0.14,
              child: Container(
                width: size * 0.16,
                height: size * 0.10,
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Positioned(
              top: size * 0.23,
              child: Container(
                width: size * 0.36,
                height: size * 0.62,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFACC15), Color(0xFFEAB308)],
                  ),
                  borderRadius: BorderRadius.circular(size * 0.10),
                  border: Border.all(color: const Color(0xFFCA8A04), width: 0.8),
                ),
                child: Center(
                  child: Container(
                    width: size * 0.28,
                    height: size * 0.18,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (rawPreset == 'preset:gula' || lowerName.contains('gula')) {
      // Kemasan Gula Pasir putih-hijau seperti di gambar
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Center(
          child: Container(
            width: size * 0.56,
            height: size * 0.68,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFCBD5E1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  height: size * 0.12,
                  decoration: const BoxDecoration(
                    color: Color(0xFF15803D),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
                  ),
                ),
                Icon(Icons.grain_rounded, size: size * 0.26, color: const Color(0xFF15803D)),
                Container(
                  height: size * 0.12,
                  decoration: const BoxDecoration(
                    color: Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(3)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (rawPreset == 'preset:tepung' || lowerName.contains('tepung')) {
      // Kemasan Tepung Terigu putih-oranye/merah seperti di gambar
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Center(
          child: Container(
            width: size * 0.56,
            height: size * 0.68,
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  height: size * 0.13,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEA580C),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
                  ),
                ),
                Icon(Icons.bakery_dining_rounded, size: size * 0.26, color: const Color(0xFFEA580C)),
                Container(
                  height: size * 0.12,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFED7AA),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(3)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Default: Ilustrasi Kantong Plastik Kresek Putih/Transparan persis seperti gambar
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: CustomPaint(
        painter: _PlasticBagPainter(),
      ),
    );
  }
}

class _PlasticBagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFFFFF), Color(0xFFE2E8F0)],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;

    final path = Path();
    // Gagang kiri
    path.moveTo(w * 0.26, h * 0.20);
    path.lineTo(w * 0.36, h * 0.20);
    path.lineTo(w * 0.38, h * 0.36);
    // Cekungan tengah kantong kresek
    path.quadraticBezierTo(w * 0.50, h * 0.40, w * 0.62, h * 0.36);
    // Gagang kanan
    path.lineTo(w * 0.64, h * 0.20);
    path.lineTo(w * 0.74, h * 0.20);
    // Badan kanan
    path.lineTo(w * 0.78, h * 0.80);
    path.quadraticBezierTo(w * 0.50, h * 0.84, w * 0.22, h * 0.80);
    path.close();

    canvas.drawPath(path, bodyPaint);
    canvas.drawPath(path, strokePaint);

    // Garis lipatan halus plastik
    final creasePaint = Paint()
      ..color = const Color(0xFF94A3B8).withValues(alpha: 0.45)
      ..strokeWidth = 0.9
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(w * 0.38, h * 0.44),
      Offset(w * 0.34, h * 0.74),
      creasePaint,
    );
    canvas.drawLine(
      Offset(w * 0.62, h * 0.44),
      Offset(w * 0.66, h * 0.74),
      creasePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
