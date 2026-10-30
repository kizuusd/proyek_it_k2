import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../constants.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../services/inventory_service.dart';
import '../../widgets/user_avatar.dart';
import 'fr11_profil_screen.dart';
import 'home_dashboard_screen.dart';

class FR02MasterBarangScreen extends StatefulWidget {
  const FR02MasterBarangScreen({Key? key}) : super(key: key);

  @override
  State<FR02MasterBarangScreen> createState() => _FR02MasterBarangScreenState();
}

class _FR02MasterBarangScreenState extends State<FR02MasterBarangScreen> {
  List<ProductItem> _products = InventoryService.defaultProducts();
  List<StockRequestItem> _requests = InventoryService.defaultStockRequests();
  bool _isLoading = false;
  bool _isSaving = false;

  // Filter & Pencarian Tabel Manajemen Produk
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedKategoriFilter = 'Semua';
  String _selectedStatusFilter = 'Semua';

  // Panel Form Tambah / Edit Barang (Hanya tampil melalui Pop-up Modal)
  ProductItem? _editingProduct;
  final _formKey = GlobalKey<FormState>();
  final _dialogFormKey = GlobalKey<FormState>();
  final TextEditingController _kodeBarangCtrl = TextEditingController(text: 'BRG-001');
  final TextEditingController _namaBarangCtrl = TextEditingController();
  final TextEditingController _deskripsiCtrl = TextEditingController();
  final TextEditingController _stokGudangCtrl = TextEditingController();
  String _formSatuan = 'Pack';
  String _formKategori = 'Plastik';
  String _formFotoUrl = 'preset:plastik';
  bool _formIsActive = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _kodeBarangCtrl.dispose();
    _namaBarangCtrl.dispose();
    _deskripsiCtrl.dispose();
    _stokGudangCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final cachedProds = await InventoryService.loadCachedProducts();
    final cachedReqs = await InventoryService.loadCachedRequests();
      if (mounted) {
        setState(() {
          _products = cachedProds;
          _requests = cachedReqs;
          if (_editingProduct == null) {
            _kodeBarangCtrl.text =
                'BRG-${(_products.length + 1).toString().padLeft(3, '0')}';
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
            if (_editingProduct == null) {
              _kodeBarangCtrl.text =
                  'BRG-${(_products.length + 1).toString().padLeft(3, '0')}';
            }
          });
        }
      } catch (_) {
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }

    void _prepareFormForNewProduct() {
      final nextNum = _products.length + 1;
      final suggestedCode = 'BRG-${nextNum.toString().padLeft(3, '0')}';
      setState(() {
        _editingProduct = null;
        _kodeBarangCtrl.text = suggestedCode;
        _namaBarangCtrl.clear();
        _deskripsiCtrl.clear();
        _stokGudangCtrl.clear();
        _formSatuan = 'Pack';
        _formKategori = 'Plastik';
        _formFotoUrl = 'preset:plastik';
        _formIsActive = true;
      });
    }

  void _prepareFormForEditProduct(ProductItem item) {
    setState(() {
      _editingProduct = item;
      _kodeBarangCtrl.text = item.kodeBarang;
      _namaBarangCtrl.text = item.namaBarang;
      _deskripsiCtrl.text = item.deskripsi;
      _stokGudangCtrl.text = item.stokGudang.toString();
      _formSatuan = ['Pack', 'Botol', 'Pcs', 'Dus', 'Karton', 'Box', 'Kg'].contains(item.satuan)
          ? item.satuan
          : 'Pack';
      _formKategori = ['Plastik', 'Sembako', 'Minuman', 'Lainnya'].contains(item.kategori)
          ? item.kategori
          : 'Plastik';
      _formFotoUrl = item.fotoUrl ?? 'preset:plastik';
      _formIsActive = item.isActive;
    });
  }

  Future<void> _pickProductPhoto() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 75,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final base64Str = base64Encode(bytes);
        if (mounted) {
          setState(() {
            _formFotoUrl = 'data:image/jpeg;base64,$base64Str';
          });
        }
        return;
      }
    } catch (_) {}

    // Fallback pilihan ikon produk bawaan jika galeri dibatalkan / desktop
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pilih Foto / Visual Produk',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextColor),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  _buildPresetOption(ctx, 'preset:plastik', 'Plastik Kresek'),
                  _buildPresetOption(ctx, 'preset:minyak', 'Minyak Goreng'),
                  _buildPresetOption(ctx, 'preset:gula', 'Gula Pasir'),
                  _buildPresetOption(ctx, 'preset:tepung', 'Tepung Terigu'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetOption(BuildContext ctx, String presetKey, String label) {
    final isSelected = _formFotoUrl == presetKey;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() => _formFotoUrl = presetKey);
        Navigator.pop(ctx);
      },
      child: Container(
        width: 110,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            ProductThumbnailWidget(
              fotoUrl: presetKey,
              namaBarang: label,
              size: 48,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SIMPAN PRODUK BARU ATAU UPDATE PRODUK (OLEH ADMIN / OWNER / SALES)
  // ============================================================
  Future<void> _saveProduct({bool closeDialogOnSuccess = false}) async {
    final activeFormState =
        closeDialogOnSuccess ? _dialogFormKey.currentState : _formKey.currentState;
    if (activeFormState != null && !activeFormState.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
    final isManager = (currentUser?.isSuperAdmin == true || currentUser?.isAdmin == true);

    final kode = _kodeBarangCtrl.text.trim().toUpperCase();
    final nama = _namaBarangCtrl.text.trim();
    if (kode.isEmpty || nama.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kode barang dan nama barang wajib diisi.'),
          backgroundColor: kDangerColor,
        ),
      );
      return;
    }
    final deskripsi = _deskripsiCtrl.text.trim();
    final stok = int.tryParse(_stokGudangCtrl.text.trim()) ?? 0;

    setState(() => _isSaving = true);

    if (_editingProduct != null) {
      // Mode Edit Produk
      final target = _editingProduct!;
      setState(() {
        target.kodeBarang = kode;
        target.namaBarang = nama;
        target.kategori = _formKategori;
        target.deskripsi = deskripsi;
        target.satuan = _formSatuan;
        target.stokGudang = stok < 0 ? 0 : stok;
        if (!isManager && stok > 0 && target.stokSales == 0) {
          target.stokSales = stok;
        }
        target.fotoUrl = _formFotoUrl;
        target.isActive = _formIsActive;
      });
      await InventoryService.saveCachedProducts(_products);

      if (!InventoryService.isTestEnv) {
        try {
          await http
              .put(
                Uri.parse('${AuthService.activeBaseUrl}/products/${target.id}'),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
                body: jsonEncode({
                  'kode_barang': kode,
                  'nama_barang': nama,
                  'kategori': _formKategori,
                  'deskripsi': deskripsi,
                  'satuan': _formSatuan,
                  'stok_gudang': stok,
                  if (!isManager) 'stok_sales': target.stokSales,
                  if (!isManager) 'sales_id': currentUser?.id,
                  'foto_url': _formFotoUrl,
                  'is_active': _formIsActive ? 1 : 0,
                  'updated_by': currentUser?.id ?? 1,
                }),
              )
              .timeout(const Duration(seconds: 6));
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() => _isSaving = false);

      if (closeDialogOnSuccess && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Produk [$kode] "$nama" berhasil diperbarui (Stok: $stok $_formSatuan).',
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF15803D),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Mode Tambah Barang Baru
    final existingIdx = _products.indexWhere(
      (p) => p.kodeBarang.toUpperCase() == kode,
    );

    final nextId = _products.isEmpty
        ? 1
        : (_products.map((e) => e.id).reduce((a, b) => a > b ? a : b) + 1);
    final finalKode = existingIdx != -1
        ? 'BRG-${nextId.toString().padLeft(3, '0')}'
        : kode;

    ProductItem createdItem = ProductItem(
      id: nextId,
      kodeBarang: finalKode,
      namaBarang: nama,
      kategori: _formKategori,
      deskripsi: deskripsi,
      satuan: _formSatuan,
      stokGudang: stok < 0 ? 0 : stok,
      stokSales: !isManager ? (stok < 0 ? 0 : stok) : 0,
      fotoUrl: _formFotoUrl,
      isActive: _formIsActive,
    );

    if (!InventoryService.isTestEnv) {
      try {
        final response = await http
            .post(
              Uri.parse('${AuthService.activeBaseUrl}/products'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode({
                'kode_barang': finalKode,
                'nama_barang': nama,
                'kategori': _formKategori,
                'deskripsi': deskripsi,
                'satuan': _formSatuan,
                'stok_gudang': stok,
                if (!isManager) 'stok_sales': stok < 0 ? 0 : stok,
                if (!isManager) 'sales_id': currentUser?.id,
                'foto_url': _formFotoUrl,
                'is_active': _formIsActive ? 1 : 0,
                'created_by': currentUser?.id ?? 1,
              }),
            )
            .timeout(const Duration(seconds: 6));

        if (response.statusCode == 201 || response.statusCode == 200) {
          final body = jsonDecode(response.body);
          if (body['data'] != null) {
            createdItem = ProductItem.fromJson(Map<String, dynamic>.from(body['data']));
          }
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _products.add(createdItem);
      _isSaving = false;
      _kodeBarangCtrl.text = 'BRG-${(_products.length + 1).toString().padLeft(3, '0')}';
      _namaBarangCtrl.clear();
      _deskripsiCtrl.clear();
      _stokGudangCtrl.clear();
    });

    if (closeDialogOnSuccess && Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Produk baru [${createdItem.kodeBarang}] "${createdItem.namaBarang}" berhasil disimpan ke katalog!',
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1D4ED8),
        behavior: SnackBarBehavior.floating,
      ),
    );
    await InventoryService.saveCachedProducts(_products);
  }

  // ============================================================
  // DIALOG CEPAT TAMBAH STOK GUDANG / DISTRIBUSI STOK KE SALES
  // ============================================================
  void _showAddStockDialog(ProductItem item) {
    final addGudangCtrl = TextEditingController(text: '25');
    final addSalesCtrl = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.add_box_rounded, color: Color(0xFF1D4ED8)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Tambah Stok: ${item.namaBarang}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextColor),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kode: ${item.kodeBarang} • Stok Gudang Saat Ini: ${item.stokGudang} ${item.satuan} • Stok di Sales: ${item.stokSales} ${item.satuan}',
              style: const TextStyle(fontSize: 12, color: kSecondaryColor),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: addGudangCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Tambah Stok Gudang (+ ${item.satuan})',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addSalesCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Tambah / Kirim Stok ke Sales (+ ${item.satuan})',
                helperText: 'Opsional: langsung menambah stok pegangan Sales',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D4ED8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final addGudang = int.tryParse(addGudangCtrl.text.trim()) ?? 0;
              final addSales = int.tryParse(addSalesCtrl.text.trim()) ?? 0;

              setState(() {
                item.stokGudang = (item.stokGudang + addGudang).clamp(0, 999999);
                if (addSales > 0) {
                  item.stokSales = (item.stokSales + addSales).clamp(0, 999999);
                }
                if (item.stokGudang > 0) item.isActive = true;
              });
              await InventoryService.saveCachedProducts(_products);

              if (!InventoryService.isTestEnv) {
                try {
                  await http
                      .patch(
                        Uri.parse('${AuthService.activeBaseUrl}/products/${item.id}/stock'),
                        headers: {'Content-Type': 'application/json'},
                        body: jsonEncode({
                          'mode': addSales > 0 ? 'distribute_to_sales' : 'add',
                          'qty': addGudang > 0 ? addGudang : addSales,
                          'sales_id': 3,
                        }),
                      )
                      .timeout(const Duration(seconds: 5));
                } catch (_) {}
              }

              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Stok "${item.namaBarang}" berhasil diperbarui (Stok Gudang: ${item.stokGudang} ${item.satuan}, Stok Sales: ${item.stokSales} ${item.satuan}).',
                  ),
                  backgroundColor: const Color(0xFF15803D),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.save_outlined, size: 17, color: Colors.white),
            label: const Text('Simpan Stok', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProduct(ProductItem item) async {
    setState(() {
      _products.removeWhere((p) => p.id == item.id);
    });
    await InventoryService.saveCachedProducts(_products);

    if (!InventoryService.isTestEnv) {
      try {
        await http
            .delete(Uri.parse('${AuthService.activeBaseUrl}/products/${item.id}'))
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Produk "${item.namaBarang}" telah dihapus.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _exportProductData() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.download_done_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Berhasil mengekspor ${_products.length} data katalog produk (BRG-001 s/d BRG-00${_products.length}).',
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E3A5F),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openTambahBarangModal({ProductItem? productToEdit}) {
    if (productToEdit != null) {
      _prepareFormForEditProduct(productToEdit);
    } else {
      _prepareFormForNewProduct();
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: SingleChildScrollView(
              child: _buildTambahBarangFormCard(
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

    final filteredProducts = _products.where((p) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchKode = p.kodeBarang.toLowerCase().contains(q);
        final matchNama = p.namaBarang.toLowerCase().contains(q);
        if (!matchKode && !matchNama) return false;
      }
      if (_selectedKategoriFilter != 'Semua') {
        if (p.kategori.toLowerCase() != _selectedKategoriFilter.toLowerCase()) {
          return false;
        }
      }
      if (_selectedStatusFilter != 'Semua') {
        if (p.statusLabel.toLowerCase() != _selectedStatusFilter.toLowerCase()) {
          return false;
        }
      }
      return true;
    }).toList();

    final pendingRequests =
        _requests.where((r) => r.status == StatusPengajuanStok.menunggu).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: kTextColor),
          tooltip: 'Kembali ke Dashboard',
          onPressed: _backToDashboard,
        ),
        title: const Text(
          'Data Barang',
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
            tooltip: 'Muat Ulang Data Produk',
            onPressed: _isLoading ? null : _loadData,
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
              if (isManager && pendingRequests.isNotEmpty) ...[
                _buildPendingStockRequestsQuickCard(pendingRequests),
                const SizedBox(height: 14),
              ],
              _buildManajemenProdukTableCard(filteredProducts, isManager),
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
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white38),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_circle_outlined, size: 15, color: Colors.white),
                  const SizedBox(width: 5),
                  Text(
                    profileLabel,
                    style: const TextStyle(
                      fontSize: 11,
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
  // PANEL PENGAJUAN STOK SALES MENUNGGU APPROVAL (UNTUK ADMIN / OWNER)
  // ============================================================
  Future<void> _approveSalesRequestInMaster(StockRequestItem item) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
    final reviewerRole = (currentUser?.isSuperAdmin == true) ? 'Owner' : 'Admin';
    final reviewerDisplay = currentUser != null && currentUser.name.isNotEmpty
        ? '${currentUser.name} ($reviewerRole)'
        : reviewerRole;
    final finalApprovedQty = item.qtyDiajukan;
    final finalNote = 'Disetujui oleh $reviewerDisplay melalui Data Barang.';

    setState(() {
      item.status = StatusPengajuanStok.disetujui;
      item.qtyDisetujui = finalApprovedQty;
      item.catatanAdmin = finalNote;
      item.diprosesOleh = reviewerDisplay;

      final prodIdx = _products.indexWhere(
        (p) =>
            (item.productId != null && p.id == item.productId) ||
            p.namaBarang.toLowerCase() == item.namaBarang.toLowerCase(),
      );

      if (prodIdx == -1) {
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
          deskripsi: item.alasan,
          satuan: item.satuan,
          stokGudang: 50,
          stokSales: finalApprovedQty,
          fotoUrl: item.fotoUrl ?? 'preset:plastik',
          isActive: true,
        );
        _products.add(createdProd);
      } else {
        final prod = _products[prodIdx];
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
      }
    });

    await InventoryService.saveCachedProducts(_products);
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
                'status': 'disetujui',
                'qty_disetujui': finalApprovedQty,
                'tambahan_stok_gudang': 0,
                'catatan_admin': finalNote,
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
        content: Text(
          'Pengajuan "${item.namaBarang}" ($finalApprovedQty ${item.satuan}) disetujui & stok telah diperbarui.',
        ),
        backgroundColor: const Color(0xFF15803D),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _rejectSalesRequestInMaster(StockRequestItem item) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
    final reviewerRole = (currentUser?.isSuperAdmin == true) ? 'Owner' : 'Admin';
    final reviewerDisplay = currentUser != null && currentUser.name.isNotEmpty
        ? '${currentUser.name} ($reviewerRole)'
        : reviewerRole;

    setState(() {
      item.status = StatusPengajuanStok.ditolak;
      item.qtyDisetujui = 0;
      item.catatanAdmin = 'Ditolak oleh $reviewerDisplay.';
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
                'qty_disetujui': 0,
                'catatan_admin': item.catatanAdmin,
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
        content: Text('Pengajuan "${item.namaBarang}" ditolak.'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildPendingStockRequestsQuickCard(List<StockRequestItem> pendingList) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.notifications_active_outlined, color: Color(0xFFD97706)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${pendingList.length} Pengajuan Barang dari Sales Menunggu Persetujuan',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...pendingList.map(
            (req) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Wrap(
                spacing: 10,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${req.namaBarang} • ${req.jenisFullLabel} (${req.qtyDiajukan} ${req.satuan})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: kTextColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Oleh: ${req.salesName} (${req.tanggalPengajuan}) — "${req.alasan}"',
                        style: const TextStyle(fontSize: 11.5, color: kSecondaryColor),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF15803D),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _approveSalesRequestInMaster(req),
                        icon: const Icon(Icons.check_circle_outline, size: 15, color: Colors.white),
                        label: const Text(
                          'Setujui & Tambah Stok',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFB91C1C),
                          side: const BorderSide(color: Color(0xFFFECACA)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _rejectSalesRequestInMaster(req),
                        child: const Text(
                          'Tolak',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // KARTU TABEL "MANAJEMEN PRODUK" (RESPONSIVE MOBILE & DESKTOP)
  // ============================================================
  Widget _buildManajemenProdukTableCard(List<ProductItem> filteredProducts, bool isManager) {
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
              // Baris Atas: Judul "Manajemen Produk" + Tombol "+ Tambah Barang" & "Ekspor Data"
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
                          'Manajemen Produk',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: roleColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _openTambahBarangModal(),
                        icon: const Icon(Icons.add, size: 18, color: Colors.white),
                        label: const Text(
                          'Tambah Barang',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF334155),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _exportProductData,
                        icon: const Icon(Icons.download_rounded, size: 17),
                        label: const Text(
                          'Ekspor Data',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Baris Pencarian & Filter Kategori / Status (Responsif Mobile vs Tablet/Desktop)
              if (isMobile) ...[
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    style: const TextStyle(fontSize: 12.5),
                    decoration: InputDecoration(
                      hintText: 'Cari kode atau nama barang...',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Text(
                              'Kat:',
                              style: TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedKategoriFilter,
                                  isExpanded: true,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0F172A),
                                  ),
                                  items: ['Semua', 'Plastik', 'Sembako', 'Minuman', 'Lainnya']
                                      .map((e) => DropdownMenuItem(
                                            value: e,
                                            child: Text(e, overflow: TextOverflow.ellipsis),
                                          ))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _selectedKategoriFilter = val);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Text(
                              'Status:',
                              style: TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedStatusFilter,
                                  isExpanded: true,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0F172A),
                                  ),
                                  items: ['Semua', 'Aktif', 'Habis', 'Nonaktif']
                                      .map((e) => DropdownMenuItem(
                                            value: e,
                                            child: Text(e, overflow: TextOverflow.ellipsis),
                                          ))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _selectedStatusFilter = val);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ] else
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 280,
                      height: 40,
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (val) => setState(() => _searchQuery = val.trim()),
                        style: const TextStyle(fontSize: 12.5),
                        decoration: InputDecoration(
                          hintText: 'Cari kode atau nama barang...',
                          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Kategori:',
                          style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedKategoriFilter,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
                              ),
                              items: ['Semua', 'Plastik', 'Sembako', 'Minuman', 'Lainnya']
                                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedKategoriFilter = val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Status:',
                          style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedStatusFilter,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
                              ),
                              items: ['Semua', 'Aktif', 'Habis', 'Nonaktif']
                                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedStatusFilter = val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

              const SizedBox(height: 16),

              if (!isMobile) ...[
                // Header Kolom Tabel Desktop/Tablet
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
                        width: 52,
                        child: Text(
                          'Foto',
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
                          'Kode Barang',
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
                          'Nama Barang',
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
                          'Satuan',
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
                          'Stok Gudang',
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

              if (filteredProducts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Text(
                      'Tidak ada produk yang sesuai dengan filter pencarian.',
                      style: TextStyle(color: kSecondaryColor, fontSize: 13),
                    ),
                  ),
                )
              else if (isMobile)
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredProducts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = filteredProducts[index];
                    return _buildMobileProductCard(item, isManager);
                  },
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredProducts.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  itemBuilder: (context, index) {
                    final item = filteredProducts[index];
                    return _buildProductRow(item, isManager);
                  },
                ),

              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 12),

              // Footer Pagination: "Menampilkan 1 - 4 dari 4 data" + < < 1 > >
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    filteredProducts.isEmpty
                        ? 'Menampilkan 0 data'
                        : 'Menampilkan 1 - ${filteredProducts.length} dari ${_products.length} data',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildPageBtn(icon: Icons.keyboard_double_arrow_left, active: false),
                      const SizedBox(width: 4),
                      _buildPageBtn(icon: Icons.chevron_left, active: false),
                      const SizedBox(width: 4),
                      _buildPageBtn(label: '1', active: true),
                      const SizedBox(width: 4),
                      _buildPageBtn(icon: Icons.chevron_right, active: false),
                      const SizedBox(width: 4),
                      _buildPageBtn(icon: Icons.keyboard_double_arrow_right, active: false),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileProductCard(ProductItem item, bool isManager) {
    final status = item.statusLabel;
    Color badgeBg;
    Color badgeFg;
    if (status == 'Aktif') {
      badgeBg = const Color(0xFFDCFCE7);
      badgeFg = const Color(0xFF15803D);
    } else if (status == 'Habis') {
      badgeBg = const Color(0xFFFEE2E2);
      badgeFg = const Color(0xFFDC2626);
    } else {
      badgeBg = const Color(0xFFF1F5F9);
      badgeFg = const Color(0xFF64748B);
    }

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProductThumbnailWidget(
                fotoUrl: item.fotoUrl,
                namaBarang: item.namaBarang,
                kategori: item.kategori,
                size: 46,
                borderRadius: 10,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Text(
                            item.kodeBarang,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: badgeFg,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.namaBarang,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item.kategori} • Satuan: ${item.satuan}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 28,
                height: 28,
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF64748B)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onSelected: (val) {
                    if (val == 'edit') {
                      _openTambahBarangModal(productToEdit: item);
                    } else if (val == 'add_stock') {
                      _showAddStockDialog(item);
                    } else if (val == 'toggle_active') {
                      setState(() => item.isActive = !item.isActive);
                      InventoryService.saveCachedProducts(_products);
                    } else if (val == 'delete') {
                      _deleteProduct(item);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'add_stock',
                      child: Row(
                        children: [
                          Icon(Icons.add_box_outlined, size: 18, color: Color(0xFF15803D)),
                          SizedBox(width: 8),
                          Text('Tambah Stok Gudang / Sales'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18, color: Color(0xFF1D4ED8)),
                          SizedBox(width: 8),
                          Text('Edit Produk'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle_active',
                      child: Row(
                        children: [
                          Icon(
                            item.isActive ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 18,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Text(item.isActive ? 'Nonaktifkan Produk' : 'Aktifkan Produk'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                          SizedBox(width: 8),
                          Text('Hapus Produk'),
                        ],
                      ),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Stok Gudang',
                        style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.stokGudang} ${item.satuan}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 26, color: const Color(0xFFE2E8F0)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Stok di Sales',
                        style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.stokSales} ${item.satuan}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ],
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
                    onPressed: () => _openTambahBarangModal(productToEdit: item),
                    child: const Text(
                      'Edit',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductRow(ProductItem item, bool isManager) {
    final status = item.statusLabel;
    Color badgeBg;
    Color badgeFg;
    if (status == 'Aktif') {
      badgeBg = const Color(0xFFDCFCE7);
      badgeFg = const Color(0xFF15803D);
    } else if (status == 'Habis') {
      badgeBg = const Color(0xFFFEE2E2);
      badgeFg = const Color(0xFFDC2626);
    } else {
      badgeBg = const Color(0xFFF1F5F9);
      badgeFg = const Color(0xFF64748B);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          // Foto
          SizedBox(
            width: 52,
            child: Align(
              alignment: Alignment.centerLeft,
              child: ProductThumbnailWidget(
                fotoUrl: item.fotoUrl,
                namaBarang: item.namaBarang,
                kategori: item.kategori,
                size: 38,
                borderRadius: 8,
              ),
            ),
          ),

          // Kode Barang
          Expanded(
            flex: 3,
            child: Text(
              item.kodeBarang,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
          ),

          // Nama Barang
          Expanded(
            flex: 4,
            child: Text(
              item.namaBarang,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1D4ED8),
              ),
            ),
          ),

          // Satuan
          Expanded(
            flex: 2,
            child: Text(
              item.satuan,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF334155),
              ),
            ),
          ),

          // Stok Gudang
          Expanded(
            flex: 2,
            child: Text(
              '${item.stokGudang}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ),

          // Status Badge (Aktif / Habis)
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeFg,
                  ),
                ),
              ),
            ),
          ),

          // Aksi (Edit + Menu 3 Titik)
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _openTambahBarangModal(productToEdit: item),
                      child: const Text(
                        'Edit',
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
                    if (val == 'edit') {
                      _openTambahBarangModal(productToEdit: item);
                    } else if (val == 'add_stock') {
                      _showAddStockDialog(item);
                    } else if (val == 'toggle_active') {
                      setState(() => item.isActive = !item.isActive);
                      InventoryService.saveCachedProducts(_products);
                    } else if (val == 'delete') {
                      _deleteProduct(item);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'add_stock',
                      child: Row(
                        children: [
                          Icon(Icons.add_box_outlined, size: 18, color: Color(0xFF15803D)),
                          SizedBox(width: 8),
                          Text('Tambah Stok Gudang / Sales'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18, color: Color(0xFF1D4ED8)),
                          SizedBox(width: 8),
                          Text('Edit Produk'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle_active',
                      child: Row(
                        children: [
                          Icon(
                            item.isActive ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 18,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Text(item.isActive ? 'Nonaktifkan Produk' : 'Aktifkan Produk'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                          SizedBox(width: 8),
                          Text('Hapus Produk'),
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
    );
  }

  Widget _buildPageBtn({IconData? icon, String? label, required bool active}) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF1D4ED8) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: active ? const Color(0xFF1D4ED8) : const Color(0xFFE2E8F0),
        ),
      ),
      child: label != null
          ? Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: active ? Colors.white : const Color(0xFF475569),
              ),
            )
          : Icon(
              icon,
              size: 15,
              color: const Color(0xFF94A3B8),
            ),
    );
  }

  // ============================================================
  // KARTU FORM "TAMBAH BARANG" / "EDIT BARANG" (SESUAI GAMBAR KANAN BAWAH)
  // ============================================================
  Widget _buildTambahBarangFormCard({
    required bool isInsideDialog,
    VoidCallback? onDialogStateChanged,
  }) {
    final isEditing = _editingProduct != null;

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
            // Header "Tambah Barang" + Close X
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Text(
                        isEditing ? 'Edit Barang (${_editingProduct!.kodeBarang})' : 'Tambah Barang',
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      if (isEditing)
                        TextButton(
                          onPressed: _prepareFormForNewProduct,
                          child: const Text(
                            'Reset ke Baru',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF1D4ED8)),
                          ),
                        ),
                    ],
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

            // 2-Column Form Layout persis sesuai gambar (Kode Barang, Nama Barang, Deskripsi, Kategori/Satuan di kiri | Stok Gudang, Foto Produk, Status di kanan)
            LayoutBuilder(
              builder: (context, constraints) {
                final canTwoColumns = constraints.maxWidth >= 460;
                if (canTwoColumns) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildFormLeftColumn(
                          onDialogStateChanged: onDialogStateChanged,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildFormRightColumn(
                          onDialogStateChanged: onDialogStateChanged,
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFormLeftColumn(onDialogStateChanged: onDialogStateChanged),
                    const SizedBox(height: 16),
                    _buildFormRightColumn(onDialogStateChanged: onDialogStateChanged),
                  ],
                );
              },
            ),

            const SizedBox(height: 20),

            // Tombol "Simpan Produk"
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
                onPressed: _isSaving
                    ? null
                    : () => _saveProduct(closeDialogOnSuccess: isInsideDialog),
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_rounded, size: 18, color: Colors.white),
                label: Text(
                  _isSaving ? 'Menyimpan...' : 'Simpan Produk',
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

  Widget _buildFormLeftColumn({VoidCallback? onDialogStateChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Kode Barang *
        const Row(
          children: [
            Text(
              'Kode Barang ',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
            ),
            Text('*', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _kodeBarangCtrl,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'BRG-004',
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Kode barang wajib diisi' : null,
        ),

        const SizedBox(height: 14),

        // Nama Barang *
        const Row(
          children: [
            Text(
              'Nama Barang ',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
            ),
            Text('*', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _namaBarangCtrl,
          onChanged: (_) {
            setState(() {});
            onDialogStateChanged?.call();
          },
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'Plastik Kresek 1kg',
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama barang wajib diisi' : null,
        ),

        const SizedBox(height: 14),

        // Deskripsi
        const Text(
          'Deskripsi',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _deskripsiCtrl,
          maxLines: 3,
          style: const TextStyle(fontSize: 12.5),
          decoration: InputDecoration(
            hintText: 'Plastik kresek untuk kebutuhan toko.',
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
        ),

        const SizedBox(height: 14),

        // Kategori / Satuan *
        const Row(
          children: [
            Text(
              'Kategori / Satuan ',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
            ),
            Text('*', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey('satuan_$_formSatuan'),
                initialValue: _formSatuan,
                isExpanded: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                ),
                items: ['Pack', 'Botol', 'Pcs', 'Dus', 'Karton', 'Box', 'Kg']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _formSatuan = val);
                    onDialogStateChanged?.call();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey('kategori_$_formKategori'),
                initialValue: _formKategori,
                isExpanded: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                ),
                items: ['Plastik', 'Sembako', 'Minuman', 'Lainnya']
                    .map((k) => DropdownMenuItem(value: k, child: Text(k, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _formKategori = val);
                    onDialogStateChanged?.call();
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFormRightColumn({VoidCallback? onDialogStateChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stok Gudang *
        const Row(
          children: [
            Text(
              'Stok Gudang ',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
            ),
            Text('*', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _stokGudangCtrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: '50',
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Stok gudang wajib diisi';
            if (int.tryParse(v.trim()) == null) return 'Masukkan angka';
            return null;
          },
        ),

        const SizedBox(height: 14),

        // Foto Produk
        const Text(
          'Foto Produk',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            ProductThumbnailWidget(
              fotoUrl: _formFotoUrl,
              namaBarang: _namaBarangCtrl.text,
              kategori: _formKategori,
              size: 86,
              borderRadius: 12,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _pickProductPhoto,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 86),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF93C5FD),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_upload_outlined, size: 22, color: Color(0xFF1D4ED8)),
                      SizedBox(height: 4),
                      Text(
                        'Klik untuk upload foto\natau drag & drop',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF475569),
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Format: JPG, PNG (Max. 2MB)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        // Status * (Toggle Switch Aktif)
        const Row(
          children: [
            Text(
              'Status ',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
            ),
            Text('*', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Switch(
              value: _formIsActive,
              activeThumbColor: Colors.white,
              activeTrackColor: const Color(0xFF1D4ED8),
              onChanged: (val) {
                setState(() => _formIsActive = val);
                onDialogStateChanged?.call();
              },
            ),
            const SizedBox(width: 4),
            Text(
              _formIsActive ? 'Aktif' : 'Nonaktif',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
