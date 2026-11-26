import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/inventory_service.dart';
import '../../services/stock_batch_service.dart';
import '../../services/transaction_service.dart';
import '../../widgets/user_avatar.dart';
import 'fr05_pendapatan_screen.dart';
import 'fr11_profil_screen.dart';
import 'home_dashboard_screen.dart';

class FR10PengajuanBarangScreen extends StatefulWidget {
  const FR10PengajuanBarangScreen({Key? key}) : super(key: key);

  @override
  State<FR10PengajuanBarangScreen> createState() =>
      _FR10PengajuanBarangScreenState();
}

class _FR10PengajuanBarangScreenState extends State<FR10PengajuanBarangScreen> {
  List<ProductItem> _products = [];
  List<StockBatch> _batches = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  String _selectedStatusFilter = 'Semua';
  String? _selectedDateFilter;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    final user = context.read<AuthProvider>().currentUser;
    final isManager = user?.isManager ?? false;
    final salesId = isManager ? null : user?.id;

    final cachedProds = await InventoryService.loadCachedProducts();
    final cachedBatches = await StockBatchService.loadCached(salesId: salesId);

    if (mounted) {
      setState(() {
        _products = cachedProds;
        _batches = cachedBatches;
        _isLoading = StockBatchService.isTestEnv ? false : true;
      });
    }

    if (StockBatchService.isTestEnv) return;

    try {
      final fetchedProds = await InventoryService.fetchProducts(salesId: user?.id);
      final fetchedBatches = await StockBatchService.fetchBatches(salesId: salesId);
      if (mounted) {
        setState(() {
          _products = fetchedProds;
          _batches = fetchedBatches;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<StockBatch> get _filteredBatches {
    return _batches.where((b) {
      if (_selectedDateFilter != null &&
          _selectedDateFilter!.isNotEmpty &&
          b.tanggal != _selectedDateFilter) {
        return false;
      }
      switch (_selectedStatusFilter) {
        case 'Menunggu':
          return b.statusReview == StatusReviewBatch.menunggu;
        case 'Ditinjau Admin':
          return b.statusReview == StatusReviewBatch.ditinjauAdmin;
        case 'Disetujui Owner':
          return b.statusReview == StatusReviewBatch.disetujuiOwner;
        case 'Ditolak':
          return b.statusReview == StatusReviewBatch.ditolak;
        default:
          return true;
      }
    }).toList();
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

  void _openCreateBatchModal() {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    final activeProducts = _products.where((p) => p.isActive).toList();
    if (activeProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Belum ada barang aktif di katalog untuk diajukan.'),
          backgroundColor: kDangerColor,
        ),
      );
      return;
    }

    final tanggalCtrl = TextEditingController(text: StockBatchService.todayYmd());
    final qtyCtrl = TextEditingController(text: '10');
    final catatanCtrl = TextEditingController();

    ProductItem selectedProd = activeProducts.first;
    final List<Map<String, dynamic>> batchCart = [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final totalUnit =
              batchCart.fold<int>(0, (sum, it) => sum + (it['qty_diambil'] as int));

          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.inventory_2_rounded,
                                color: Color(0xFF047857)),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ajukan Batch Barang Harian',
                                  style: TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.bold,
                                    color: kTextColor,
                                  ),
                                ),
                                Text(
                                  'Daftar barang diambil dalam 1 batch per hari',
                                  style: TextStyle(fontSize: 12, color: kSecondaryColor),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: _isSubmitting ? null : () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const Divider(height: 22),
                      TextField(
                        controller: tanggalCtrl,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Tanggal Batch Harian *',
                          prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: dialogCtx,
                            initialDate:
                                DateTime.tryParse(tanggalCtrl.text) ?? DateTime.now(),
                            firstDate: DateTime(2024),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              tanggalCtrl.text =
                                  '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Tambah Barang ke Dalam Batch:',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: kTextColor),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        initialValue: selectedProd.id,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Pilih Barang',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        items: activeProducts
                            .map(
                              (p) => DropdownMenuItem<int>(
                                value: p.id,
                                child: Text(
                                  '${p.namaBarang} (${p.satuan} • ${p.formattedHarga})',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedProd =
                                  activeProducts.firstWhere((p) => p.id == val);
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: qtyCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Qty Diambil (${selectedProd.satuan})',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF047857),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 15),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                              if (qty <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Jumlah barang diambil minimal 1.'),
                                    backgroundColor: kDangerColor,
                                  ),
                                );
                                return;
                              }
                              setDialogState(() {
                                final existingIdx = batchCart.indexWhere(
                                    (c) => c['product_id'] == selectedProd.id);
                                if (existingIdx != -1) {
                                  batchCart[existingIdx]['qty_diambil'] =
                                      (batchCart[existingIdx]['qty_diambil'] as int) +
                                          qty;
                                } else {
                                  batchCart.add({
                                    'product_id': selectedProd.id,
                                    'nama_barang': selectedProd.namaBarang,
                                    'satuan': selectedProd.satuan,
                                    'harga': selectedProd.harga,
                                    'foto_url': selectedProd.fotoUrl,
                                    'kategori': selectedProd.kategori,
                                    'qty_diambil': qty,
                                  });
                                }
                                qtyCtrl.text = '1';
                              });
                            },
                            icon: const Icon(Icons.add, size: 18, color: Colors.white),
                            label: const Text(
                              'Tambah Item',
                              style: TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (batchCart.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Text(
                            'Belum ada barang di daftar batch. Pilih barang & klik "Tambah Item".',
                            style: TextStyle(fontSize: 12, color: kSecondaryColor),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Barang dalam Batch (${batchCart.length} jenis)',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: kTextColor,
                                    ),
                                  ),
                                  Text(
                                    'Total: $totalUnit unit',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF047857),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 14),
                              ...batchCart.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final item = entry.value;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      ProductThumbnailWidget(
                                        fotoUrl: item['foto_url'] as String?,
                                        namaBarang: item['nama_barang'] as String,
                                        kategori: item['kategori'] as String,
                                        size: 32,
                                        borderRadius: 6,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${item['nama_barang']} • ${item['qty_diambil']} ${item['satuan']}',
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline,
                                            size: 18, color: kDangerColor),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => setDialogState(
                                            () => batchCart.removeAt(idx)),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: catatanCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Catatan Batch (Opsional)',
                          hintText: 'Contoh: Muatan kanvas rute pasar pagi',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline,
                                size: 17, color: Color(0xFF1D4ED8)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Batch ini akan ditinjau oleh Admin & Owner, dan langsung otomatis masuk ke halaman Pendapatan Sales untuk stok opname per batch.',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF1E3A8A),
                                    height: 1.35),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF047857),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _isSubmitting || batchCart.isEmpty
                              ? null
                              : () async {
                                  setDialogState(() => _isSubmitting = true);
                                  setState(() => _isSubmitting = true);
                                  try {
                                    final nav = Navigator.of(ctx);
                                    final created =
                                        await StockBatchService.createDailyBatch(
                                      salesUser: user,
                                      tanggal: tanggalCtrl.text.trim(),
                                      catatanPengajuan: catatanCtrl.text.trim(),
                                      items: batchCart
                                          .map((c) => {
                                                'product_id': c['product_id'] as int,
                                                'qty_diambil': c['qty_diambil'] as int,
                                              })
                                          .toList(),
                                    );
                                    if (!mounted) return;
                                    nav.pop();
                                    await _loadAllData();
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '${created.kodeBatch} (${created.totalJenisBarang} barang) dikirim & otomatis masuk ke Pendapatan Sales!',
                                        ),
                                        backgroundColor: const Color(0xFF047857),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  } catch (e) {
                                    setDialogState(() => _isSubmitting = false);
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(e
                                            .toString()
                                            .replaceFirst('Exception: ', '')),
                                        backgroundColor: kDangerColor,
                                      ),
                                    );
                                  } finally {
                                    if (mounted) setState(() => _isSubmitting = false);
                                  }
                                },
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.send_rounded, size: 17),
                          label: Text(
                            _isSubmitting
                                ? 'Mengirim Batch...'
                                : 'Kirim Batch Pengajuan',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleReviewAction(
    StockBatch batch,
    StatusReviewBatch nextStatus, {
    String? prefilledNote,
  }) async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null || !user.isManager) return;

    final noteCtrl = TextEditingController(text: prefilledNote ?? '');
    final formKey = GlobalKey<FormState>();
    final isReject = nextStatus == StatusReviewBatch.ditolak;
    final isOwnerApprove = nextStatus == StatusReviewBatch.disetujuiOwner;

    final titleText = isReject
        ? 'Tolak Batch Pengajuan'
        : isOwnerApprove
            ? 'Tinjauan & Persetujuan Owner'
            : 'Tinjauan Admin (Teruskan ke Owner)';

    final confirmText = isReject
        ? 'Tolak Batch'
        : isOwnerApprove
            ? 'Setujui Batch (Owner)'
            : 'Simpan Tinjauan Admin';

    final confirmColor = isReject
        ? const Color(0xFFDC2626)
        : isOwnerApprove
            ? const Color(0xFF15803D)
            : const Color(0xFF1D4ED8);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          titleText,
          style: const TextStyle(
              fontSize: 16.5, fontWeight: FontWeight.bold, color: kTextColor),
        ),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${batch.kodeBatch} • ${StockBatchService.formatShortDate(batch.tanggal)} • ${batch.salesName}',
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: kSecondaryColor),
                ),
                const SizedBox(height: 8),
                Text(
                  'Total ${batch.totalJenisBarang} barang (${batch.totalQtyDiambil} unit diambil)',
                  style: const TextStyle(fontSize: 12.5, color: kTextColor),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: noteCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: isReject
                        ? 'Alasan Penolakan *'
                        : 'Catatan Tinjauan (Opsional)',
                    hintText: isReject
                        ? 'Contoh: Jumlah muatan melebihi kapasitas / stok gudang kosong'
                        : 'Tambahkan catatan pemeriksaan...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (v) {
                    if (isReject && (v == null || v.trim().isEmpty)) {
                      return 'Alasan penolakan wajib diisi';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final nav = Navigator.of(ctx);
              try {
                await StockBatchService.reviewBatch(
                  batchId: batch.id,
                  actor: user,
                  nextStatus: nextStatus,
                  note: noteCtrl.text.trim(),
                );
                if (!mounted) return;
                nav.pop();
                await _loadAllData();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isReject
                          ? '${batch.kodeBatch} ditolak.'
                          : isOwnerApprove
                              ? '${batch.kodeBatch} disetujui Owner & siap stok opname di Pendapatan Sales.'
                              : '${batch.kodeBatch} ditinjau Admin & diteruskan ke Owner.',
                    ),
                    backgroundColor: confirmColor,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(e.toString().replaceFirst('Exception: ', '')),
                    backgroundColor: kDangerColor,
                  ),
                );
              }
            },
            child: Text(
              confirmText,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showBatchDetailDialog(StockBatch batch, UserModel? user) {
    final isManager = user?.isManager ?? false;
    final isOwner = user?.isSuperAdmin ?? false;
    final isAdminOnly = (user?.isAdmin ?? false) && !isOwner;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.layers_rounded, color: Color(0xFF1D4ED8)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Detail ${batch.kodeBatch}',
                style: const TextStyle(
                    fontSize: 16.5, fontWeight: FontWeight.bold, color: kTextColor),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildReviewBadge(batch.statusReview),
                    _buildOpnameBadge(batch),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Tanggal Batch: ${StockBatchService.formatShortDate(batch.tanggal)} (${batch.tanggal})',
                    style: const TextStyle(fontSize: 12.5)),
                Text('Sales: ${batch.salesName}',
                    style: const TextStyle(fontSize: 12.5)),
                if (batch.catatanPengajuan.isNotEmpty)
                  Text('Catatan: ${batch.catatanPengajuan}',
                      style: const TextStyle(fontSize: 12.5, color: kSecondaryColor)),
                const Divider(height: 20),
                const Text(
                  'Daftar Barang Diambil dalam Batch:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...batch.items.map(
                  (it) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        ProductThumbnailWidget(
                          fotoUrl: it.fotoUrl,
                          namaBarang: it.namaBarang,
                          kategori: it.kategori,
                          size: 38,
                          borderRadius: 8,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                it.namaBarang,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${it.kodeBarang} • Harga: ${TransactionService.formatRp(it.hargaSatuan)}/${it.satuan}',
                                style: const TextStyle(
                                    fontSize: 11.5, color: kSecondaryColor),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${it.qtyDiambil} ${it.satuan}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1D4ED8),
                              ),
                            ),
                            if (it.qtySisaOpname != null)
                              Text(
                                'Sisa: ${it.qtySisaOpname} • Terjual: ${it.qtyTerjual}',
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xFF047857)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (batch.reviewedByAdminName != null ||
                    batch.reviewedByOwnerName != null ||
                    batch.opnameByName != null) ...[
                  const Divider(height: 20),
                  const Text(
                    'Jejak Tinjauan & Stok Opname:',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  if (batch.reviewedByAdminName != null)
                    _buildTrailTile(
                      icon: Icons.fact_check_outlined,
                      color: const Color(0xFF1D4ED8),
                      title: 'Admin: ${batch.reviewedByAdminName}',
                      subtitle: batch.catatanAdmin ?? '-',
                    ),
                  if (batch.reviewedByOwnerName != null)
                    _buildTrailTile(
                      icon: Icons.verified_user_outlined,
                      color: batch.isRejected
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF15803D),
                      title: 'Owner: ${batch.reviewedByOwnerName}',
                      subtitle: batch.catatanOwner ?? '-',
                    ),
                  if (batch.opnameByName != null)
                    _buildTrailTile(
                      icon: Icons.assignment_turned_in_outlined,
                      color: const Color(0xFF047857),
                      title:
                          'Stok Opname (${batch.opnameByRole ?? 'Manager'}): ${batch.opnameByName}',
                      subtitle:
                          '${batch.catatanOpname ?? '-'} • Pendapatan: ${TransactionService.formatRp(batch.totalPendapatan)}',
                    ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
          if (isManager && !batch.isRejected)
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FR05PendapatanScreen()),
                );
              },
              icon: const Icon(Icons.point_of_sale_rounded, size: 16),
              label: const Text('Buka Stok Opname (FR05)'),
            ),
          if (isAdminOnly && batch.statusReview == StatusReviewBatch.menunggu)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D4ED8)),
              onPressed: () {
                Navigator.pop(ctx);
                _handleReviewAction(batch, StatusReviewBatch.ditinjauAdmin);
              },
              child: const Text('Tinjau Admin',
                  style: TextStyle(color: Colors.white)),
            ),
          if (isOwner &&
              (batch.statusReview == StatusReviewBatch.menunggu ||
                  batch.statusReview == StatusReviewBatch.ditinjauAdmin))
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF15803D)),
              onPressed: () {
                Navigator.pop(ctx);
                _handleReviewAction(batch, StatusReviewBatch.disetujuiOwner);
              },
              child: const Text('Setujui (Owner)',
                  style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  Widget _buildTrailTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(fontSize: 11.5, color: kTextColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isManager = user?.isManager ?? false;
    final roleColor = _rolePrimaryColor(user);
    final filtered = _filteredBatches;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: kTextColor),
          tooltip: 'Kembali ke Dashboard',
          onPressed: _backToDashboard,
        ),
        title: Text(
          isManager
              ? 'Tinjauan Pengajuan Barang (Batch)'
              : 'Pengajuan Barang Sales (Batch)',
          style: const TextStyle(
            color: kTextColor,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: 'Muat Ulang',
            onPressed: _isLoading ? null : _loadAllData,
            icon: const Icon(Icons.refresh_rounded, color: kTextColor),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FR11ProfilScreen()),
              ),
              child: UserAvatar(
                photoUrl: user?.photoUrl,
                name: user?.name ?? 'User',
                radius: 17,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : RefreshIndicator(
              onRefresh: _loadAllData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildProfileBanner(user, isManager),
                  const SizedBox(height: 14),
                  _buildStatsGrid(),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    color: _roleLightColor(user),
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  child: Icon(
                                    isManager
                                        ? Icons.fact_check_outlined
                                        : Icons.inventory_2_outlined,
                                    color: roleColor,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isManager
                                          ? 'Daftar Batch Pengajuan Sales'
                                          : 'Batch Pengajuan Harian Saya',
                                      style: const TextStyle(
                                        fontSize: 16.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const Text(
                                      'Otomatis masuk ke Pendapatan Sales untuk Stok Opname',
                                      style: TextStyle(
                                          fontSize: 11.5, color: kSecondaryColor),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (!isManager)
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: roleColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 11),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: _openCreateBatchModal,
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text(
                                  'Ajukan Batch Barang',
                                  style: TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    'Semua',
                                    'Menunggu',
                                    'Ditinjau Admin',
                                    'Disetujui Owner',
                                    'Ditolak',
                                  ].map((tab) {
                                    final active = _selectedStatusFilter == tab;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ChoiceChip(
                                        label: Text(tab,
                                            style: const TextStyle(fontSize: 12)),
                                        selected: active,
                                        onSelected: (_) => setState(
                                            () => _selectedStatusFilter = tab),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.calendar_today_outlined,
                                  size: 15),
                              label: Text(
                                _selectedDateFilter ?? 'Tanggal',
                                style: const TextStyle(fontSize: 11.5),
                              ),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      DateTime.tryParse(_selectedDateFilter ?? '') ??
                                          DateTime.now(),
                                  firstDate: DateTime(2024),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) {
                                  setState(() {
                                    _selectedDateFilter =
                                        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                                  });
                                }
                              },
                            ),
                            if (_selectedDateFilter != null)
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () =>
                                    setState(() => _selectedDateFilter = null),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (filtered.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.inbox_outlined,
                                      size: 42, color: kSecondaryColor),
                                  SizedBox(height: 8),
                                  Text(
                                    'Belum ada batch pengajuan barang pada filter ini.',
                                    style: TextStyle(
                                        fontSize: 13, color: kSecondaryColor),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ...filtered.map((b) => _buildBatchCard(b, user)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileBanner(UserModel? user, bool isManager) {
    final userName = (user?.name.isNotEmpty == true) ? user!.name : 'User';
    final userEmail =
        (user?.email.isNotEmpty == true) ? user!.email : 'CV Maju Bersama';
    final roleTitle = user?.roleDisplayTitle ?? 'Sales Lapangan';
    final profileLabel = _profileLabelForRole(user);
    final roleColor = _rolePrimaryColor(user);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        gradient: _roleGradient(user),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          UserAvatar(
            photoUrl: user?.photoUrl,
            name: userName,
            radius: 23,
            backgroundColor: Colors.white,
            textColor: roleColor,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                Text(
                  '$roleTitle • $userEmail',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: Colors.white70),
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
            child: Text(
              profileLabel,
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final total = _batches.length;
    final menunggu =
        _batches.where((b) => b.statusReview == StatusReviewBatch.menunggu).length;
    final ditinjauAdmin = _batches
        .where((b) => b.statusReview == StatusReviewBatch.ditinjauAdmin)
        .length;
    final disetujuiOwner = _batches
        .where((b) => b.statusReview == StatusReviewBatch.disetujuiOwner)
        .length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          _statCard('Total Batch', '$total', Icons.layers_rounded,
              const Color(0xFF1D4ED8), const Color(0xFFEFF6FF)),
          _statCard('Menunggu', '$menunggu', Icons.hourglass_top_rounded,
              const Color(0xFFD97706), const Color(0xFFFFFBEB)),
          _statCard('Ditinjau Admin', '$ditinjauAdmin', Icons.fact_check_rounded,
              const Color(0xFF2563EB), const Color(0xFFDBEAFE)),
          _statCard('Disetujui Owner', '$disetujuiOwner', Icons.verified_rounded,
              const Color(0xFF15803D), const Color(0xFFDCFCE7)),
        ];
        if (constraints.maxWidth < 640) {
          return GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.2,
            children: cards,
          );
        }
        return Row(
          children: cards
              .map((c) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: c,
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _statCard(String title, String count, IconData icon, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration:
                BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500)),
                Text(count,
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchCard(StockBatch batch, UserModel? user) {
    final isManager = user?.isManager ?? false;
    final isOwner = user?.isSuperAdmin ?? false;
    final isAdminOnly = (user?.isAdmin ?? false) && !isOwner;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: batch.isValid
              ? const Color(0xFF86EFAC)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      batch.kodeBatch,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${StockBatchService.formatShortDate(batch.tanggal)} • ${batch.salesName}',
                      style: const TextStyle(fontSize: 12, color: kSecondaryColor),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildReviewBadge(batch.statusReview),
                  const SizedBox(height: 4),
                  _buildOpnameBadge(batch),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: batch.items
                .map(
                  (it) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      '${it.namaBarang} (${it.qtyDiambil} ${it.satuan})',
                      style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: kTextColor),
                    ),
                  ),
                )
                .toList(),
          ),
          if (batch.catatanPengajuan.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Catatan: ${batch.catatanPengajuan}',
              style: const TextStyle(fontSize: 11.5, color: kSecondaryColor),
            ),
          ],
          if (!batch.isRejected) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: batch.isValid
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    batch.isValid
                        ? Icons.verified_rounded
                        : Icons.sync_alt_rounded,
                    size: 15,
                    color: batch.isValid
                        ? const Color(0xFF15803D)
                        : const Color(0xFF1D4ED8),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      batch.isValid
                          ? 'Batch VALID • Stok opname selesai bersama ${batch.opnameByRole ?? 'Manager'} (${TransactionService.formatRp(batch.totalPendapatan)})'
                          : 'Otomatis masuk ke Pendapatan Sales (${batch.opnameStatusLabel})',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: batch.isValid
                            ? const Color(0xFF15803D)
                            : const Color(0xFF1D4ED8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${batch.totalJenisBarang} jenis • ${batch.totalQtyDiambil} unit diambil',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF334155)),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _showBatchDetailDialog(batch, user),
                    child: const Text('Detail', style: TextStyle(fontSize: 12)),
                  ),
                  if (isAdminOnly &&
                      batch.statusReview == StatusReviewBatch.menunggu) ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D4ED8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _handleReviewAction(
                          batch, StatusReviewBatch.ditinjauAdmin),
                      icon: const Icon(Icons.fact_check_outlined,
                          size: 15, color: Colors.white),
                      label: const Text('Tinjau Admin',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () =>
                          _handleReviewAction(batch, StatusReviewBatch.ditolak),
                      child: const Text('Tolak', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                  if (isOwner &&
                      (batch.statusReview == StatusReviewBatch.menunggu ||
                          batch.statusReview ==
                              StatusReviewBatch.ditinjauAdmin)) ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF15803D),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _handleReviewAction(
                          batch, StatusReviewBatch.disetujuiOwner),
                      icon: const Icon(Icons.verified_outlined,
                          size: 15, color: Colors.white),
                      label: const Text('Setujui Owner',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () =>
                          _handleReviewAction(batch, StatusReviewBatch.ditolak),
                      child: const Text('Tolak', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                  if (!isManager &&
                      batch.statusReview == StatusReviewBatch.menunggu &&
                      batch.statusOpname == StatusOpnameBatch.belumOpname)
                    IconButton(
                      tooltip: 'Batalkan / Hapus Batch',
                      icon: const Icon(Icons.delete_outline,
                          size: 19, color: Colors.redAccent),
                      onPressed: () async {
                        await StockBatchService.deleteBatch(batch.id);
                        await _loadAllData();
                      },
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewBadge(StatusReviewBatch status) {
    Color bg;
    Color fg;
    switch (status) {
      case StatusReviewBatch.menunggu:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        break;
      case StatusReviewBatch.ditinjauAdmin:
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1D4ED8);
        break;
      case StatusReviewBatch.disetujuiOwner:
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        break;
      case StatusReviewBatch.ditolak:
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(
        batchLabelReview(status),
        style:
            TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  String batchLabelReview(StatusReviewBatch s) {
    switch (s) {
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

  Widget _buildOpnameBadge(StockBatch batch) {
    if (batch.isRejected) {
      return const SizedBox.shrink();
    }
    Color bg;
    Color fg;
    switch (batch.statusOpname) {
      case StatusOpnameBatch.belumOpname:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
        break;
      case StatusOpnameBatch.prosesOpname:
        bg = const Color(0xFFE0F2FE);
        fg = const Color(0xFF0369A1);
        break;
      case StatusOpnameBatch.valid:
        bg = const Color(0xFF15803D);
        fg = Colors.white;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(
        batch.isValid ? 'VALID' : batch.opnameStatusLabel,
        style:
            TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}
