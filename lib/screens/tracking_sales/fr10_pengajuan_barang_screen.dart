import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../constants.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../services/inventory_service.dart';
import '../../widgets/user_avatar.dart';
import 'fr11_profil_screen.dart';
import 'home_dashboard_screen.dart';

class FR10PengajuanBarangScreen extends StatefulWidget {
  const FR10PengajuanBarangScreen({Key? key}) : super(key: key);

  @override
  State<FR10PengajuanBarangScreen> createState() => _FR10PengajuanBarangScreenState();
}

class _FR10PengajuanBarangScreenState extends State<FR10PengajuanBarangScreen> {
  List<ProductItem> _products = InventoryService.defaultProducts();
  List<StockRequestItem> _requests = InventoryService.defaultStockRequests();
  bool _isLoading = false;
  bool _isSubmitting = false;

  String _selectedStatusFilter = 'Semua'; // 'Semua', 'Menunggu', 'Disetujui', 'Ditolak'

  // State Form "Ajukan Pengajuan Barang" (Tampil melalui Pop-up Modal)
  final _formKey = GlobalKey<FormState>();
  final _dialogFormKey = GlobalKey<FormState>();
  bool _isCustomNewProduct = false;
  int? _selectedProductId;
  JenisPengajuanStok _selectedJenis = JenisPengajuanStok.tambah;
  final TextEditingController _qtyCtrl = TextEditingController();
  final TextEditingController _alasanCtrl = TextEditingController();

  // Field tambahan jika Sales mengajukan barang baru yang belum ada di katalog
  final TextEditingController _namaBarangBaruCtrl = TextEditingController();
  String _kategoriBaru = 'Plastik';
  String _satuanBaru = 'Pack';

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _alasanCtrl.dispose();
    _namaBarangBaruCtrl.dispose();
    super.dispose();
  }

  ProductItem get _currentSelectedProduct {
    if (_isCustomNewProduct || _products.isEmpty) {
      final customName = _namaBarangBaruCtrl.text.trim().isNotEmpty
          ? _namaBarangBaruCtrl.text.trim()
          : 'Belum ada barang dipilih';
      return ProductItem(
        id: 0,
        kodeBarang: 'BRG-BARU',
        namaBarang: customName,
        kategori: _kategoriBaru,
        satuan: _satuanBaru,
        stokGudang: 0,
        stokSales: 0,
        fotoUrl: 'preset:plastik',
      );
    }

    final found = _products.where((p) => p.id == _selectedProductId).toList();
    if (found.isNotEmpty) return found.first;
    return _products.first;
  }

  Future<void> _loadAllData() async {
    final cachedProds = await InventoryService.loadCachedProducts();
    final cachedReqs = await InventoryService.loadCachedRequests();
    if (mounted) {
      setState(() {
        _products = cachedProds;
        _requests = cachedReqs;
        if (_products.isNotEmpty && !_products.any((p) => p.id == _selectedProductId)) {
          _selectedProductId = _products.first.id;
        }
      });
    }

    if (InventoryService.isTestEnv) return;

    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final salesId = authProvider.currentUser?.id;
      final fetchedProds = await InventoryService.fetchProducts(salesId: salesId);
      final fetchedReqs = await InventoryService.fetchStockRequests(salesId: salesId);
      if (mounted) {
        setState(() {
          _products = fetchedProds;
          _requests = fetchedReqs;
          if (!_products.any((p) => p.id == _selectedProductId) && _products.isNotEmpty) {
            final plastik = _products.where((p) => p.kategori.toLowerCase() == 'plastik').toList();
            _selectedProductId = plastik.isNotEmpty ? plastik.first.id : _products.first.id;
          }
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // KIRIM PENGAJUAN BARANG BARU / STOK OLEH SALES
  // ============================================================
  Future<void> _submitStockRequest({bool closeDialogOnSuccess = false}) async {
    final activeFormState =
        closeDialogOnSuccess ? _dialogFormKey.currentState : _formKey.currentState;
    if (activeFormState != null && !activeFormState.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    final salesId = user?.id ?? 0;
    final salesName = (user?.name.isNotEmpty == true) ? user!.name : 'Sales';
    final salesEmail = (user?.email.isNotEmpty == true) ? user!.email : '';

    final isNewProd = _isCustomNewProduct || _products.isEmpty;
    if (isNewProd && _namaBarangBaruCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama barang wajib diisi terlebih dahulu.'),
          backgroundColor: kDangerColor,
        ),
      );
      return;
    }

    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jumlah barang yang diajukan harus lebih dari 0.'),
          backgroundColor: kDangerColor,
        ),
      );
      return;
    }

    final alasanText = _alasanCtrl.text.trim();
    if (alasanText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alasan pengajuan wajib diisi.'),
          backgroundColor: kDangerColor,
        ),
      );
      return;
    }

    final selectedProd = _currentSelectedProduct;

    setState(() => _isSubmitting = true);

    final now = DateTime.now();
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
    final formattedDate = '${now.day} ${months[now.month - 1]} ${now.year}';
    final nextId = (_requests.isEmpty ? 1 : _requests.map((e) => e.id).reduce((a, b) => a > b ? a : b) + 1);

    StockRequestItem newReq = StockRequestItem(
      id: nextId,
      kodePengajuan: 'REQ-${now.year}-${nextId.toString().padLeft(3, '0')}',
      salesId: salesId,
      salesName: salesName,
      salesEmail: salesEmail,
      productId: isNewProd ? null : selectedProd.id,
      kodeBarang: isNewProd
          ? 'BRG-${nextId.toString().padLeft(3, '0')}'
          : selectedProd.kodeBarang,
      namaBarang: selectedProd.namaBarang,
      kategori: selectedProd.kategori,
      satuan: selectedProd.satuan,
      fotoUrl: selectedProd.fotoUrl ?? 'preset:plastik',
      stokGudang: selectedProd.stokGudang,
      stokSales: selectedProd.stokSales,
      jenis: _selectedJenis,
      qtyDiajukan: qty,
      alasan: alasanText,
      tanggalPengajuan: formattedDate,
      status: StatusPengajuanStok.menunggu,
    );

    if (!InventoryService.isTestEnv) {
      try {
        final response = await http
            .post(
              Uri.parse('${AuthService.activeBaseUrl}/stock-requests'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode({
                'sales_id': salesId,
                'sales_email': salesEmail,
                'product_id': isNewProd ? null : selectedProd.id,
                'kode_barang_custom': newReq.kodeBarang,
                'nama_barang_custom': selectedProd.namaBarang,
                'kategori_custom': selectedProd.kategori,
                'satuan_custom': selectedProd.satuan,
                'foto_url_custom': selectedProd.fotoUrl ?? 'preset:plastik',
                'jenis': StockRequestItem.jenisToApi(_selectedJenis),
                'qty_diajukan': qty,
                'alasan': alasanText,
              }),
            )
            .timeout(const Duration(seconds: 6));

        if (response.statusCode == 201 || response.statusCode == 200) {
          final body = jsonDecode(response.body);
          if (body['data'] != null) {
            newReq = StockRequestItem.fromJson(Map<String, dynamic>.from(body['data']));
          }
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _requests.insert(0, newReq);
      _isSubmitting = false;
      _qtyCtrl.clear();
      _alasanCtrl.clear();
      if (_isCustomNewProduct || _products.isEmpty) {
        _namaBarangBaruCtrl.clear();
        _isCustomNewProduct = false;
      }
    });

    await InventoryService.saveCachedRequests(_requests);

    if (closeDialogOnSuccess && mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Pengajuan ${newReq.jenisFullLabel} "${newReq.namaBarang}" (${newReq.qtyDiajukan} ${newReq.satuan}) berhasil dikirim dan menunggu persetujuan Admin/Owner!',
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1D4ED8),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // PROSES APPROVAL / PENOLAKAN OLEH ADMIN & OWNER
  // ============================================================
  Future<void> _approveRequestByManager(
    StockRequestItem item, {
    int? customApprovedQty,
    int extraWarehouseStock = 0,
    String? adminNote,
  }) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
    final reviewerRole = (currentUser?.isSuperAdmin == true) ? 'Owner' : 'Admin';
    final reviewerDisplay = currentUser != null && currentUser.name.isNotEmpty
        ? '${currentUser.name} ($reviewerRole)'
        : reviewerRole;

    final finalApprovedQty = customApprovedQty ?? item.qtyDiajukan;
    final finalNote = (adminNote != null && adminNote.trim().isNotEmpty)
        ? adminNote.trim()
        : 'Disetujui oleh $reviewerDisplay. Stok telah diperbarui pada sistem.';

    // 1. Update lokal: produk & stok
    setState(() {
      item.status = StatusPengajuanStok.disetujui;
      item.qtyDisetujui = finalApprovedQty;
      item.catatanAdmin = finalNote;
      item.diprosesOleh = reviewerDisplay;

      // Cek apakah produk sudah ada di _products
      int prodIdx = _products.indexWhere(
        (p) =>
            (item.productId != null && p.id == item.productId) ||
            p.namaBarang.toLowerCase() == item.namaBarang.toLowerCase(),
      );

      if (prodIdx == -1) {
        // Barang baru yang diajukan sales -> otomatis masuk ke tabel products saat disetujui!
        final newProdId = _products.isEmpty
            ? 1
            : (_products.map((e) => e.id).reduce((a, b) => a > b ? a : b) + 1);
        final createdProd = ProductItem(
          id: newProdId,
          kodeBarang: item.kodeBarang.isNotEmpty
              ? item.kodeBarang
              : 'BRG-${newProdId.toString().padLeft(3, '0')}',
          namaBarang: item.namaBarang,
          kategori: item.kategori,
          deskripsi: 'Produk ditambahkan dari pengajuan stok sales (${item.alasan})',
          satuan: item.satuan,
          stokGudang: extraWarehouseStock > 0 ? extraWarehouseStock : 50,
          stokSales: finalApprovedQty,
          fotoUrl: item.fotoUrl ?? 'preset:plastik',
          isActive: true,
        );
        _products.add(createdProd);
        item.productId = createdProd.id;
        item.stokGudang = createdProd.stokGudang;
        item.stokSales = createdProd.stokSales;
      } else {
        final prod = _products[prodIdx];
        if (extraWarehouseStock > 0) {
          prod.stokGudang += extraWarehouseStock;
        }
        if (item.jenis == JenisPengajuanStok.tambah) {
          prod.stokSales += finalApprovedQty;
          if (prod.stokGudang >= finalApprovedQty) {
            prod.stokGudang -= finalApprovedQty;
          }
          prod.isActive = true;
        } else if (item.jenis == JenisPengajuanStok.kurang) {
          prod.stokSales = (prod.stokSales - finalApprovedQty).clamp(0, 999999);
        } else if (item.jenis == JenisPengajuanStok.retur) {
          prod.stokSales = (prod.stokSales - finalApprovedQty).clamp(0, 999999);
          prod.stokGudang += finalApprovedQty;
        }
        item.stokGudang = prod.stokGudang;
        item.stokSales = prod.stokSales;
      }
    });

    await InventoryService.saveCachedProducts(_products);
    await InventoryService.saveCachedRequests(_requests);

    // 2. Sinkronkan ke Backend MySQL
    if (!InventoryService.isTestEnv) {
      try {
        final response = await http
            .put(
              Uri.parse('${AuthService.activeBaseUrl}/stock-requests/${item.id}/status'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode({
                'status': 'disetujui',
                'qty_disetujui': finalApprovedQty,
                'tambahan_stok_gudang': extraWarehouseStock,
                'catatan_admin': finalNote,
                'reviewer_id': currentUser?.id,
                'reviewer_email': currentUser?.email,
              }),
            )
            .timeout(const Duration(seconds: 6));

        if (response.statusCode == 200) {
          await _loadAllData();
        }
      } catch (_) {}
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Pengajuan "${item.namaBarang}" ($finalApprovedQty ${item.satuan}) DISETUJUI! Stok Sales & Gudang telah diperbarui.',
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF15803D),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _rejectRequestByManager(StockRequestItem item, String reason) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
    final reviewerRole = (currentUser?.isSuperAdmin == true) ? 'Owner' : 'Admin';
    final reviewerDisplay = currentUser != null && currentUser.name.isNotEmpty
        ? '${currentUser.name} ($reviewerRole)'
        : reviewerRole;

    final finalReason =
        reason.trim().isNotEmpty ? reason.trim() : 'Pengajuan stok ditolak oleh $reviewerDisplay.';

    setState(() {
      item.status = StatusPengajuanStok.ditolak;
      item.qtyDisetujui = 0;
      item.catatanAdmin = finalReason;
      item.diprosesOleh = reviewerDisplay;
    });

    await InventoryService.saveCachedRequests(_requests);

    if (!InventoryService.isTestEnv) {
      try {
        await http
            .put(
              Uri.parse('${AuthService.activeBaseUrl}/stock-requests/${item.id}/status'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode({
                'status': 'ditolak',
                'catatan_admin': finalReason,
                'reviewer_id': currentUser?.id,
                'reviewer_email': currentUser?.email,
              }),
            )
            .timeout(const Duration(seconds: 6));
      } catch (_) {}
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.cancel_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Pengajuan "${item.namaBarang}" telah DITOLAK.'),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deleteRequest(StockRequestItem item) async {
    setState(() {
      _requests.removeWhere((r) => r.id == item.id);
    });
    await InventoryService.saveCachedRequests(_requests);

    if (!InventoryService.isTestEnv) {
      try {
        await http
            .delete(Uri.parse('${AuthService.activeBaseUrl}/stock-requests/${item.id}'))
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pengajuan "${item.namaBarang}" telah dihapus.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // DIALOG DETAIL & APPROVAL PENGAJUAN STOK
  // ============================================================
  void _showDetailAndActionDialog(StockRequestItem item, {required bool isManager}) {
    final qtyApproveCtrl = TextEditingController(
      text: (item.qtyDisetujui ?? item.qtyDiajukan).toString(),
    );
    final restockGudangCtrl = TextEditingController(text: '0');
    final noteCtrl = TextEditingController(text: item.catatanAdmin ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
        title: Row(
          children: [
            const Icon(Icons.inventory_2_rounded, color: Color(0xFF1D4ED8)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isManager ? 'Verifikasi & Tambah Stok Sales' : 'Detail Pengajuan Barang',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: kTextColor,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 8),
                // Ringkasan Barang
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      ProductThumbnailWidget(
                        fotoUrl: item.fotoUrl,
                        namaBarang: item.namaBarang,
                        kategori: item.kategori,
                        size: 56,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.kategori,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.namaBarang,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1D4ED8),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Kode: ${item.kodeBarang} • Pengaju: ${item.salesName}',
                              style: const TextStyle(fontSize: 12, color: kSecondaryColor),
                            ),
                          ],
                        ),
                      ),
                      _buildStatusBadge(item.status),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Detail Angka
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 380) {
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildDetailMetricBox(
                                  label: 'Tanggal Pengajuan',
                                  value: item.tanggalPengajuan,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildDetailMetricBox(
                                  label: 'Jenis Pengajuan',
                                  value: item.jenisFullLabel,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: _buildDetailMetricBox(
                              label: 'Jumlah Diajukan',
                              value: '${item.qtyDiajukan} ${item.satuan}',
                              highlight: true,
                            ),
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(
                          child: _buildDetailMetricBox(
                            label: 'Tanggal Pengajuan',
                            value: item.tanggalPengajuan,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildDetailMetricBox(
                            label: 'Jenis Pengajuan',
                            value: item.jenisFullLabel,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildDetailMetricBox(
                            label: 'Jumlah Diajukan',
                            value: '${item.qtyDiajukan} ${item.satuan}',
                            highlight: true,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _buildDetailMetricBox(
                        label: 'Stok Saat Ini (di Sales)',
                        value: '${item.stokSales} ${item.satuan}',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildDetailMetricBox(
                        label: 'Stok Gudang Pusat',
                        value: '${item.stokGudang} ${item.satuan}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                const Text(
                  'Alasan Pengajuan Sales:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kTextColor),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    item.alasan,
                    style: const TextStyle(fontSize: 13, color: kTextColor, height: 1.4),
                  ),
                ),

                if (item.catatanAdmin != null && item.catatanAdmin!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Catatan Admin / Owner:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kTextColor),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Text(
                      item.catatanAdmin!,
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E40AF)),
                    ),
                  ),
                ],

                // Form Kontrol Persetujuan & Penambahan Stok untuk Admin / Owner
                if (isManager) ...[
                  const SizedBox(height: 18),
                  const Divider(),
                  const SizedBox(height: 10),
                  const Text(
                    'Panel Persetujuan & Penambahan Stok (Admin / Owner)',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: qtyApproveCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Jumlah Disetujui (${item.satuan})',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: restockGudangCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Tambah Stok Gudang (+)',
                            hintText: 'Opsional restock',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Catatan Persetujuan / Penolakan',
                      hintText: 'Masukkan catatan untuk sales...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        actions: [
          if (!isManager)
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
          if (isManager) ...[
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                side: const BorderSide(color: Color(0xFFDC2626)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _rejectRequestByManager(item, noteCtrl.text);
              },
              icon: const Icon(Icons.close, size: 17),
              label: const Text('Tolak Pengajuan'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF15803D),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                final approvedQty = int.tryParse(qtyApproveCtrl.text.trim()) ?? item.qtyDiajukan;
                final extraGudang = int.tryParse(restockGudangCtrl.text.trim()) ?? 0;
                _approveRequestByManager(
                  item,
                  customApprovedQty: approvedQty,
                  extraWarehouseStock: extraGudang,
                  adminNote: noteCtrl.text,
                );
              },
              icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
              label: const Text(
                'Setujui & Update Stok',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailMetricBox({
    required String label,
    required String value,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFFEFF6FF) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlight ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10.5, color: kSecondaryColor),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: highlight ? const Color(0xFF1D4ED8) : kTextColor,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DIALOG MODAL "+ AJUKAN PENGAJUAN" (UNTUK TAMPILAN MOBILE/MODAL)
  // ============================================================
  void _openAjukanPengajuanModal() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: SingleChildScrollView(
              child: _buildAjukanPengajuanCombinedSection(
                isInsideDialog: true,
                onDialogStateChanged: () => setDialogState(() {}),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    final isManager = (user?.isSuperAdmin == true || user?.isAdmin == true);

    final filteredRequests = _requests.where((r) {
      if (_selectedStatusFilter == 'Menunggu') {
        return r.status == StatusPengajuanStok.menunggu;
      }
      if (_selectedStatusFilter == 'Disetujui') {
        return r.status == StatusPengajuanStok.disetujui;
      }
      if (_selectedStatusFilter == 'Ditolak') {
        return r.status == StatusPengajuanStok.ditolak;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: kTextColor),
          tooltip: 'Kembali ke Dashboard',
          onPressed: _backToDashboard,
        ),
        title: const Text(
          'Pengajuan Barang Sales',
          style: TextStyle(
            color: kTextColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: kTextColor),
        actions: [
          IconButton(
            tooltip: 'Muat Ulang Data',
            onPressed: _isLoading ? null : _loadAllData,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: kPrimaryColor),
                  )
                : const Icon(Icons.refresh_rounded, color: kTextColor),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => _showSalesProfilePopup(user, isManager),
              child: UserAvatar(
                photoUrl: user?.photoUrl,
                name: user?.name ?? 'Sales',
                radius: 17,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSalesProfileBanner(user, isManager),
              const SizedBox(height: 14),
              _buildPengajuanTableCard(filteredRequests, isManager),
            ],
          ),
        ),
      ),
    );
  }

  String _profileLabelForRole(UserModel? user) {
    if (user?.isSuperAdmin == true) return 'Profil Owner';
    if (user?.isAdmin == true) return 'Profil Admin';
    return 'Profil Sales';
  }

  Color _rolePrimaryColor(UserModel? user) {
    if (user?.isSuperAdmin == true) return const Color(0xFF6B21A8);
    if (user?.isAdmin == true) return const Color(0xFF1D4ED8);
    return const Color(0xFF047857);
  }

  Color _roleLightColor(UserModel? user) {
    if (user?.isSuperAdmin == true) return const Color(0xFFF3E8FF);
    if (user?.isAdmin == true) return const Color(0xFFEFF6FF);
    return const Color(0xFFECFDF5);
  }

  LinearGradient _roleGradient(UserModel? user) {
    if (user?.isSuperAdmin == true) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF6B21A8), Color(0xFF4C1D95)],
      );
    }
    if (user?.isAdmin == true) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1D4ED8), Color(0xFF1E3A8A)],
      );
    }
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF047857), Color(0xFF065F46)],
    );
  }

  Widget _buildSalesProfileBanner(UserModel? user, bool isManager) {
    final userName = (user?.name.isNotEmpty == true) ? user!.name : 'Sales Aktif';
    final userEmail = (user?.email.isNotEmpty == true) ? user!.email : 'CV Maju Bersama';
    final roleTitle = user?.roleDisplayTitle ?? 'Sales Lapangan';
    final profileLabel = _profileLabelForRole(user);
    final roleColor = _rolePrimaryColor(user);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showSalesProfilePopup(user, isManager),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          gradient: _roleGradient(user),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: roleColor.withValues(alpha: 0.22),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: UserAvatar(
                photoUrl: user?.photoUrl,
                name: userName,
                radius: 24,
                backgroundColor: Colors.white,
                textColor: roleColor,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white54),
                        ),
                        child: Text(
                          roleTitle,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userEmail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white38),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_circle_outlined, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    profileLabel,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _backToDashboard() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeDashboardScreen()),
      );
    }
  }

  void _showSalesProfilePopup(UserModel? user, bool isManager) {
    final userName = (user?.name.isNotEmpty == true) ? user!.name : 'Sales Aktif';
    final userEmail = (user?.email.isNotEmpty == true) ? user!.email : '-';
    final userPhone = (user?.phone?.isNotEmpty == true) ? user!.phone! : '-';
    final roleTitle = user?.roleDisplayTitle ?? 'Sales Lapangan';
    final profileLabel = _profileLabelForRole(user);
    final roleColor = _rolePrimaryColor(user);
    final roleBgColor = _roleLightColor(user);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
        title: Row(
          children: [
            Icon(Icons.badge_outlined, color: roleColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                profileLabel,
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.bold,
                  color: kTextColor,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: roleColor, width: 2),
              ),
              child: UserAvatar(
                photoUrl: user?.photoUrl,
                name: userName,
                radius: 38,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              userName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: kTextColor,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: roleBgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                roleTitle,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: roleColor,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.email_outlined, size: 16, color: kSecondaryColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          userEmail,
                          style: const TextStyle(fontSize: 12.5, color: kTextColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 16, color: kSecondaryColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          userPhone,
                          style: const TextStyle(fontSize: 12.5, color: kTextColor),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: roleColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const FR11ProfilScreen()),
              );
            },
            icon: const Icon(Icons.person_outline, size: 17, color: Colors.white),
            label: const Text('Profil Saya', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // KARTU TABEL "PENGAJUAN STOK" (RESPONSIVE MOBILE & DESKTOP)
  // ============================================================
  Widget _buildPengajuanTableCard(List<StockRequestItem> filteredRequests, bool isManager) {
    final user = context.read<AuthProvider>().currentUser;
    final roleColor = _rolePrimaryColor(user);
    final roleBgColor = _roleLightColor(user);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 600;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: EdgeInsets.all(isMobile ? 14 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card: Icon + Title + "+ Ajukan Pengajuan" Button
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: roleBgColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.inventory_2_outlined,
                          color: roleColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Flexible(
                        child: Text(
                          'Pengajuan Stok',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!isManager)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: roleColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _openAjukanPengajuanModal,
                      icon: const Icon(Icons.add, size: 18, color: Colors.white),
                      label: const Text(
                        'Ajukan Barang',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 18),

              // Filter Pills: Semua, Menunggu, Disetujui, Ditolak
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['Semua', 'Menunggu', 'Disetujui', 'Ditolak'].map((tab) {
                    final bool active = _selectedStatusFilter == tab;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => setState(() => _selectedStatusFilter = tab),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          decoration: BoxDecoration(
                            color: active ? roleColor : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: active ? roleColor : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Text(
                            tab,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: active ? Colors.white : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 16),

              if (!isMobile) ...[
                // Header Tabel Desktop/Tablet
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          'No',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Tanggal Pengajuan',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          'Barang',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Jenis',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Jumlah',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Status',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 112,
                        child: Text(
                          'Aksi',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
              ],

              if (filteredRequests.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.inbox_outlined, size: 42, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        const Text(
                          'Belum ada data pengajuan stok pada filter ini.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: kSecondaryColor, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
              else if (isMobile)
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredRequests.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = filteredRequests[index];
                    return _buildMobileRequestCard(index + 1, item, isManager);
                  },
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredRequests.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  itemBuilder: (context, index) {
                    final item = filteredRequests[index];
                    return _buildRequestRow(index + 1, item, isManager);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileRequestCard(int rowNum, StockRequestItem item, bool isManager) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Text(
                  '#$rowNum • ${item.tanggalPengajuan}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
              const Spacer(),
              _buildStatusBadge(item.status),
              const SizedBox(width: 4),
              SizedBox(
                width: 28,
                height: 28,
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF64748B)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onSelected: (val) {
                    if (val == 'detail') {
                      _showDetailAndActionDialog(item, isManager: isManager);
                    } else if (val == 'approve') {
                      _approveRequestByManager(item);
                    } else if (val == 'reject') {
                      _rejectRequestByManager(
                        item,
                        'Ditolak oleh manajemen melalui aksi cepat.',
                      );
                    } else if (val == 'delete') {
                      _deleteRequest(item);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'detail',
                      child: Row(
                        children: [
                          Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF1D4ED8)),
                          SizedBox(width: 8),
                          Text('Lihat Detail'),
                        ],
                      ),
                    ),
                    if (isManager && item.status != StatusPengajuanStok.disetujui)
                      const PopupMenuItem(
                        value: 'approve',
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF15803D)),
                            SizedBox(width: 8),
                            Text('Setujui & Tambah Stok'),
                          ],
                        ),
                      ),
                    if (isManager && item.status != StatusPengajuanStok.ditolak)
                      const PopupMenuItem(
                        value: 'reject',
                        child: Row(
                          children: [
                            Icon(Icons.cancel_outlined, size: 18, color: Color(0xFFDC2626)),
                            SizedBox(width: 8),
                            Text('Tolak Pengajuan'),
                          ],
                        ),
                      ),
                    if (item.status == StatusPengajuanStok.menunggu || isManager)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                            SizedBox(width: 8),
                            Text('Hapus Pengajuan'),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ProductThumbnailWidget(
                fotoUrl: item.fotoUrl,
                namaBarang: item.namaBarang,
                kategori: item.kategori,
                size: 44,
                borderRadius: 10,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.namaBarang,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isManager
                          ? '${item.kategori} • Oleh: ${item.salesName}'
                          : 'Kategori: ${item.kategori}',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                _buildJenisBadge(item.jenis),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Jumlah: ${item.qtyDiajukan} ${item.satuan}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                SizedBox(
                  height: 30,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1D4ED8),
                      side: const BorderSide(color: Color(0xFF93C5FD)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _showDetailAndActionDialog(item, isManager: isManager),
                    child: const Text(
                      'Lihat',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isManager && item.status == StatusPengajuanStok.menunggu) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFECACA)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _rejectRequestByManager(
                      item,
                      'Pengajuan stok ditolak oleh Admin/Owner.',
                    ),
                    icon: const Icon(Icons.close, size: 15),
                    label: const Text(
                      'Tolak',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF15803D),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _approveRequestByManager(item),
                    icon: const Icon(Icons.check, size: 15, color: Colors.white),
                    label: const Text(
                      'Setujui & Tambah Stok',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRequestRow(int rowNum, StockRequestItem item, bool isManager) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              // No
              SizedBox(
                width: 28,
                child: Text(
                  '$rowNum',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
              ),

              // Tanggal Pengajuan
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.tanggalPengajuan,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    if (isManager)
                      Text(
                        item.salesName,
                        style: const TextStyle(fontSize: 10.5, color: kSecondaryColor),
                      ),
                  ],
                ),
              ),

              // Barang (Thumbnail + Kategori + Nama Barang)
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    ProductThumbnailWidget(
                      fotoUrl: item.fotoUrl,
                      namaBarang: item.namaBarang,
                      kategori: item.kategori,
                      size: 38,
                      borderRadius: 8,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.kategori,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            item.namaBarang,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Jenis Badge (Tambah / Kurang / Retur)
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildJenisBadge(item.jenis),
                ),
              ),

              // Jumlah (5 Pack)
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item.qtyDiajukan}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      item.satuan,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),

              // Status Badge (Menunggu / Disetujui / Ditolak)
              Expanded(
                flex: 3,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildStatusBadge(item.status),
                ),
              ),

              // Aksi (Lihat + Menu 3 Titik)
              SizedBox(
                width: 112,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        height: 30,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1D4ED8),
                            side: const BorderSide(color: Color(0xFF93C5FD)),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () =>
                              _showDetailAndActionDialog(item, isManager: isManager),
                          child: const Text(
                            'Lihat',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF64748B)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                      onSelected: (val) {
                        if (val == 'detail') {
                          _showDetailAndActionDialog(item, isManager: isManager);
                        } else if (val == 'approve') {
                          _approveRequestByManager(item);
                        } else if (val == 'reject') {
                          _rejectRequestByManager(
                            item,
                            'Ditolak oleh manajemen melalui aksi cepat.',
                          );
                        } else if (val == 'delete') {
                          _deleteRequest(item);
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'detail',
                          child: Row(
                            children: [
                              Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF1D4ED8)),
                              SizedBox(width: 8),
                              Text('Lihat Detail'),
                            ],
                          ),
                        ),
                        if (isManager && item.status != StatusPengajuanStok.disetujui)
                          const PopupMenuItem(
                            value: 'approve',
                            child: Row(
                              children: [
                                Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF15803D)),
                                SizedBox(width: 8),
                                Text('Setujui & Tambah Stok'),
                              ],
                            ),
                          ),
                        if (isManager && item.status != StatusPengajuanStok.ditolak)
                          const PopupMenuItem(
                            value: 'reject',
                            child: Row(
                              children: [
                                Icon(Icons.cancel_outlined, size: 18, color: Color(0xFFDC2626)),
                                SizedBox(width: 8),
                                Text('Tolak Pengajuan'),
                              ],
                            ),
                          ),
                        if (item.status == StatusPengajuanStok.menunggu || isManager)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                SizedBox(width: 8),
                                Text('Hapus Pengajuan'),
                              ],
                            ),
                          ),
                      ],
                      ),
                    ),
                  ],
                ),
                ),
              ),
            ],
          ),

          // Baris Cepat Approve / Reject khusus Admin & Owner jika status masih Menunggu
          if (isManager && item.status == StatusPengajuanStok.menunggu) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 15, color: Color(0xFF1D4ED8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Alasan: "${item.alasan}"',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _rejectRequestByManager(
                      item,
                      'Pengajuan stok ditolak oleh Admin/Owner.',
                    ),
                    icon: const Icon(Icons.close, size: 15),
                    label: const Text(
                      'Tolak',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF15803D),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _approveRequestByManager(item),
                    icon: const Icon(Icons.check, size: 15, color: Colors.white),
                    label: const Text(
                      'Setujui & Tambah Stok',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildJenisBadge(JenisPengajuanStok jenis) {
    Color bg;
    Color fg;
    String text;

    switch (jenis) {
      case JenisPengajuanStok.tambah:
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        text = 'Tambah';
        break;
      case JenisPengajuanStok.kurang:
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        text = 'Kurang';
        break;
      case JenisPengajuanStok.retur:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        text = 'Retur';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(StatusPengajuanStok status) {
    Color bg;
    Color fg;
    String text;

    switch (status) {
      case StatusPengajuanStok.menunggu:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        text = 'Menunggu';
        break;
      case StatusPengajuanStok.disetujui:
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        text = 'Disetujui';
        break;
      case StatusPengajuanStok.ditolak:
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        text = 'Ditolak';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  // ============================================================
  // PANEL FORM "AJUKAN PENGAJUAN BARANG" + PREVIEW STOK SAAT INI (SESUAI GAMBAR KANAN ATAS)
  // ============================================================
  Widget _buildAjukanPengajuanCombinedSection({
    required bool isInsideDialog,
    VoidCallback? onDialogStateChanged,
  }) {
    final selectedProd = _currentSelectedProduct;

    return LayoutBuilder(
      builder: (context, constraints) {
        final canSplitSideBySide = constraints.maxWidth >= 540;
        if (canSplitSideBySide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: _buildAjukanFormCard(
                  selectedProd,
                  isInsideDialog: isInsideDialog,
                  onDialogStateChanged: onDialogStateChanged,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 4,
                child: _buildStokSaatIniPreviewCard(selectedProd),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAjukanFormCard(
              selectedProd,
              isInsideDialog: isInsideDialog,
              onDialogStateChanged: onDialogStateChanged,
            ),
            const SizedBox(height: 14),
            _buildStokSaatIniPreviewCard(selectedProd),
          ],
        );
      },
    );
  }

  Widget _buildAjukanFormCard(
    ProductItem selectedProd, {
    required bool isInsideDialog,
    VoidCallback? onDialogStateChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Form(
        key: isInsideDialog ? _dialogFormKey : _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header "Ajukan Pengajuan Barang" + Close X
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Ajukan Pengajuan Barang',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 16),

            // Label Pilih Barang * + Toggle Ajukan Barang Baru / Tambah Barang
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Pilih Barang ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text('*', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ],
                ),
                if (_products.isNotEmpty)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF1D4ED8),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      setState(() => _isCustomNewProduct = !_isCustomNewProduct);
                      onDialogStateChanged?.call();
                    },
                    icon: Icon(
                      _isCustomNewProduct ? Icons.list_alt : Icons.edit_note_rounded,
                      size: 14,
                    ),
                    label: Text(
                      _isCustomNewProduct ? 'Pilih Katalog' : 'Input Manual',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            if (!_isCustomNewProduct && _products.isNotEmpty)
              DropdownButtonFormField<int>(
                key: ValueKey('prod_$_selectedProductId'),
                initialValue: _products.any((p) => p.id == _selectedProductId)
                    ? _selectedProductId
                    : (_products.isNotEmpty ? _products.first.id : null),
                isExpanded: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                ),
                items: _products.map((prod) {
                  return DropdownMenuItem<int>(
                    value: prod.id,
                    child: Row(
                      children: [
                        ProductThumbnailWidget(
                          fotoUrl: prod.fotoUrl,
                          namaBarang: prod.namaBarang,
                          kategori: prod.kategori,
                          size: 28,
                          borderRadius: 6,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${prod.kategori} - ${prod.namaBarang}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedProductId = val);
                    onDialogStateChanged?.call();
                  }
                },
              )
            else
              Column(
                children: [
                  TextFormField(
                    controller: _namaBarangBaruCtrl,
                    onChanged: (_) {
                      setState(() {});
                      onDialogStateChanged?.call();
                    },
                    decoration: InputDecoration(
                      hintText: 'Masukkan nama barang (contoh: Plastik Kresek 1kg)',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    validator: (v) =>
                        ((_isCustomNewProduct || _products.isEmpty) && (v == null || v.trim().isEmpty))
                            ? 'Nama barang wajib diisi'
                            : null,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('kat_baru_$_kategoriBaru'),
                          initialValue: _kategoriBaru,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Kategori',
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          items: ['Plastik', 'Sembako', 'Minuman', 'Lainnya']
                              .map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _kategoriBaru = val);
                              onDialogStateChanged?.call();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('sat_baru_$_satuanBaru'),
                          initialValue: _satuanBaru,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Satuan',
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          items: ['Pack', 'Botol', 'Pcs', 'Dus', 'Bal']
                              .map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _satuanBaru = val);
                              onDialogStateChanged?.call();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),

            const SizedBox(height: 16),

            // Jenis Pengajuan * (Radio: Tambah Stok, Kurang Stok, Retur Barang)
            const Row(
              children: [
                Text(
                  'Jenis Pengajuan ',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Text('*', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _buildJenisRadioOption(
                  JenisPengajuanStok.tambah,
                  'Tambah Stok',
                  onDialogStateChanged: onDialogStateChanged,
                ),
                _buildJenisRadioOption(
                  JenisPengajuanStok.kurang,
                  'Kurang Stok',
                  onDialogStateChanged: onDialogStateChanged,
                ),
                _buildJenisRadioOption(
                  JenisPengajuanStok.retur,
                  'Retur Barang',
                  onDialogStateChanged: onDialogStateChanged,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Jumlah * (Input + Satuan Pack di kanan)
            const Row(
              children: [
                Text(
                  'Jumlah ',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Text('*', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _qtyCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      hintText: '5',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.horizontal(left: Radius.circular(10)),
                        borderSide: BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.horizontal(left: Radius.circular(10)),
                        borderSide: BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Jumlah wajib diisi';
                      if ((int.tryParse(v.trim()) ?? 0) <= 0) return 'Minimal 1';
                      return null;
                    },
                  ),
                ),
                Container(
                  height: 47,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Text(
                    selectedProd.satuan,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Alasan *
            const Row(
              children: [
                Text(
                  'Alasan ',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Text('*', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _alasanCtrl,
              maxLines: 3,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Stok plastik di toko hampir habis, mohon untuk ditambahkan.',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Alasan pengajuan wajib diisi' : null,
            ),

            const SizedBox(height: 20),

            // Tombol "Kirim Pengajuan"
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isSubmitting
                    ? null
                    : () => _submitStockRequest(closeDialogOnSuccess: isInsideDialog),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded, size: 17, color: Colors.white),
                label: Text(
                  _isSubmitting ? 'Mengirim Pengajuan...' : 'Kirim Pengajuan',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJenisRadioOption(
    JenisPengajuanStok value,
    String label, {
    VoidCallback? onDialogStateChanged,
  }) {
    final bool selected = _selectedJenis == value;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        setState(() => _selectedJenis = value);
        onDialogStateChanged?.call();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: selected ? const Color(0xFF1D4ED8) : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? const Color(0xFF0F172A) : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // KARTU KANAN: PREVIEW BARANG + "STOK SAAT INI (DI SALES)" + "INFO"
  // ============================================================
  Widget _buildStokSaatIniPreviewCard(ProductItem selectedProd) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gambar & Nama Barang
          Row(
            children: [
              ProductThumbnailWidget(
                fotoUrl: selectedProd.fotoUrl,
                namaBarang: selectedProd.namaBarang,
                kategori: selectedProd.kategori,
                size: 64,
                borderRadius: 12,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedProd.kategori,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      selectedProd.namaBarang,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF1D4ED8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Kotak "Stok Saat Ini (di Sales)" = 2 Pack
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Stok Saat Ini (di Sales)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${selectedProd.stokSales}',
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E3A8A),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  selectedProd.satuan,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Kotak "Info"
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDBEAFE)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_rounded, size: 17, color: Color(0xFF1D4ED8)),
                    SizedBox(width: 6),
                    Text(
                      'Info',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Setelah pengajuan disetujui oleh admin/owner, barang akan dikirim sesuai jadwal dan stok akan diperbarui pada sistem.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF1E3A8A),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
