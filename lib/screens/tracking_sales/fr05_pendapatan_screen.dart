import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../services/inventory_service.dart';
import '../../services/transaction_service.dart';

class FR05PendapatanScreen extends StatefulWidget {
  const FR05PendapatanScreen({Key? key}) : super(key: key);

  @override
  State<FR05PendapatanScreen> createState() => _FR05PendapatanScreenState();
}

class _FR05PendapatanScreenState extends State<FR05PendapatanScreen> {
  List<SalesTransaction> _transactions = [];
  List<ProductItem> _products = [];
  List<UserModel> _salesList = [];
  bool _isLoading = true;

  String _statusFilter = 'Semua'; // Semua, Menunggu, Disetujui, Ditolak
  int? _salesFilterId;
  int? _productFilterId;
  String? _dateFilter;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final user = context.read<AuthProvider>().currentUser;
    final isManager = user?.isManager ?? false;

    final txs = await TransactionService.fetchTransactions(
      salesId: isManager ? null : user?.id,
    );
    final prods = await InventoryService.fetchProducts(salesId: user?.id);

    List<UserModel> salesUsers = [];
    if (isManager) {
      final allUsers = await AuthService().getAllUsers();
      salesUsers = allUsers.where((u) => u.isSales).toList();
    }

    if (mounted) {
      setState(() {
        _transactions = txs;
        _products = prods;
        _salesList = salesUsers;
        _isLoading = false;
      });
    }
  }

  List<SalesTransaction> get _filteredTransactions {
    return _transactions.where((t) {
      if (_statusFilter != 'Semua' &&
          t.statusLabel.toLowerCase() != _statusFilter.toLowerCase()) {
        return false;
      }
      if (_salesFilterId != null && t.salesId != _salesFilterId) {
        return false;
      }
      if (_productFilterId != null &&
          !t.items.any((it) => it.productId == _productFilterId)) {
        return false;
      }
      if (_dateFilter != null && _dateFilter!.isNotEmpty && t.tanggal != _dateFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  void _showCreateTransactionDialog() {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    final activeProducts = _products.where((p) => p.isActive).toList();
    if (activeProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada produk aktif yang tersedia untuk transaksi.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final pelangganCtrl = TextEditingController();
    final catatanCtrl = TextEditingController();
    final tanggalCtrl = TextEditingController(text: TransactionService.todayYmd());
    final qtyCtrl = TextEditingController(text: '1');

    ProductItem selectedProd = activeProducts.first;
    final List<Map<String, dynamic>> cart = [];
    bool saving = false;

    int calcTotal() => cart.fold<int>(0, (s, e) => s + (e['subtotal'] as int));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.point_of_sale_rounded, color: kPrimaryColor),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Catat Penjualan / Pendapatan',
                  style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: kTextColor),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: tanggalCtrl,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Tanggal Transaksi',
                      prefixIcon: const Icon(Icons.calendar_today_outlined, size: 17),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: dialogCtx,
                        initialDate: DateTime.tryParse(tanggalCtrl.text) ?? DateTime.now(),
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
                  const SizedBox(height: 10),
                  TextField(
                    controller: pelangganCtrl,
                    decoration: InputDecoration(
                      labelText: 'Nama Pelanggan / Toko (Opsional)',
                      hintText: 'Contoh: Toko Sinar Makmur',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Tambah Item Produk (Harga Mengikuti Master Harga Berlaku):',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kTextColor),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    initialValue: selectedProd.id,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Pilih Produk Aktif',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: activeProducts
                        .map(
                          (p) => DropdownMenuItem<int>(
                            value: p.id,
                            child: Text(
                              '${p.namaBarang} (${p.formattedHarga}/${p.satuan})',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedProd = activeProducts.firstWhere((p) => p.id == val);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: qtyCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Jumlah (${selectedProd.satuan})',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF047857),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          final q = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                          if (q <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Jumlah harus lebih besar dari 0.'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                            return;
                          }
                          setDialogState(() {
                            final existingIdx =
                                cart.indexWhere((c) => c['product_id'] == selectedProd.id);
                            if (existingIdx != -1) {
                              final newQty = (cart[existingIdx]['qty'] as int) + q;
                              cart[existingIdx]['qty'] = newQty;
                              cart[existingIdx]['subtotal'] = newQty * selectedProd.harga;
                            } else {
                              cart.add({
                                'product_id': selectedProd.id,
                                'nama': selectedProd.namaBarang,
                                'satuan': selectedProd.satuan,
                                'harga': selectedProd.harga,
                                'qty': q,
                                'subtotal': q * selectedProd.harga,
                              });
                            }
                            qtyCtrl.text = '1';
                          });
                        },
                        icon: const Icon(Icons.add, size: 17, color: Colors.white),
                        label: const Text('Tambah', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                  if (cart.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          ...cart.asMap().entries.map((entry) {
                            final i = entry.key;
                            final it = entry.value;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${it['nama']} (${it['qty']} ${it['satuan']} × ${TransactionService.formatRp(it['harga'] as int)})',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  Text(
                                    TransactionService.formatRp(it['subtotal'] as int),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 17, color: Colors.redAccent),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => setDialogState(() => cart.removeAt(i)),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Estimasi Total:', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(
                                TransactionService.formatRp(calcTotal()),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Color(0xFF047857),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    controller: catatanCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Catatan Transaksi (Opsional)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: saving || cart.isEmpty
                  ? null
                  : () async {
                      setDialogState(() => saving = true);
                      try {
                        final nav = Navigator.of(ctx);
                        await TransactionService.createTransaction(
                          salesId: user.id ?? 3,
                          salesName: user.name,
                          isSalesActive: user.isActive && !user.isSuspended,
                          tanggal: tanggalCtrl.text.trim(),
                          namaPelanggan: pelangganCtrl.text.trim(),
                          catatan: catatanCtrl.text.trim(),
                          items: cart
                              .map((c) => {
                                    'product_id': c['product_id'] as int,
                                    'qty': c['qty'] as int,
                                  })
                              .toList(),
                        );
                        if (!mounted) return;
                        nav.pop();
                        await _loadData();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Catatan penjualan berhasil disimpan & menunggu verifikasi.'),
                            backgroundColor: Color(0xFF047857),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      } catch (e) {
                        setDialogState(() => saving = false);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(e.toString().replaceFirst('Exception: ', '')),
                            backgroundColor: Colors.redAccent,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Simpan Penjualan', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approveTransaction(SalesTransaction tx) async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null || !user.isManager) return;
    try {
      await TransactionService.verifyTransaction(
        transactionId: tx.id,
        actorId: user.id ?? 2,
        actorEmail: user.email,
        actorName: user.name,
        status: StatusVerifikasiTransaksi.disetujui,
      );
      if (!mounted) return;
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transaksi ${tx.kodeTransaksi} disetujui.'),
          backgroundColor: const Color(0xFF047857),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showRejectOrCancelDialog(SalesTransaction tx, {required bool isCancelApproved}) {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null || !user.isManager) return;
    final reasonCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            isCancelApproved ? 'Koreksi / Batalkan Transaksi' : 'Tolak Catatan Penjualan',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${tx.kodeTransaksi} • ${TransactionService.formatRp(tx.total)}',
                  style: const TextStyle(fontSize: 12.5, color: kSecondaryColor),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: reasonCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: isCancelApproved ? 'Alasan Pembatalan (Audit) *' : 'Alasan Penolakan *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Alasan wajib diisi' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.pop(ctx), child: const Text('Tutup')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => saving = true);
                      try {
                        final nav = Navigator.of(ctx);
                        if (isCancelApproved) {
                          await TransactionService.cancelApprovedTransaction(
                            transactionId: tx.id,
                            actorId: user.id ?? 2,
                            actorEmail: user.email,
                            actorName: user.name,
                            reason: reasonCtrl.text.trim(),
                          );
                        } else {
                          await TransactionService.verifyTransaction(
                            transactionId: tx.id,
                            actorId: user.id ?? 2,
                            actorEmail: user.email,
                            actorName: user.name,
                            status: StatusVerifikasiTransaksi.ditolak,
                            alasanPenolakan: reasonCtrl.text.trim(),
                          );
                        }
                        if (!mounted) return;
                        nav.pop();
                        await _loadData();
                      } catch (e) {
                        setDialogState(() => saving = false);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(e.toString().replaceFirst('Exception: ', '')),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    },
              child: Text(
                isCancelApproved ? 'Batalkan Transaksi' : 'Tolak Catatan',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailDialog(SalesTransaction tx) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          tx.kodeTransaksi,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextColor),
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Sales: ${tx.salesName}', style: const TextStyle(fontSize: 12.5)),
                Text('Pelanggan: ${tx.namaPelanggan}', style: const TextStyle(fontSize: 12.5)),
                Text('Tanggal: ${tx.tanggal}', style: const TextStyle(fontSize: 12.5)),
                Text('Status Verifikasi: ${tx.statusLabel}',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                if (tx.verifiedByName != null)
                  Text('Pemeriksa: ${tx.verifiedByName}', style: const TextStyle(fontSize: 12, color: kSecondaryColor)),
                if (tx.alasanPenolakan != null && tx.alasanPenolakan!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Keterangan Penolakan/Pembatalan: ${tx.alasanPenolakan}',
                      style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                    ),
                  ),
                const Divider(height: 18),
                const Text(
                  'Detail Item (Harga Tersimpan Saat Transaksi):',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                ...tx.items.map(
                  (it) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${it.namaBarang}\n${it.qty} ${it.satuan} × ${TransactionService.formatRp(it.hargaSatuan)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Text(
                          TransactionService.formatRp(it.subtotal),
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Omzet Penjualan', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      TransactionService.formatRp(tx.total),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF047857),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
        ],
      ),
    );
  }

  Color _statusColor(StatusVerifikasiTransaksi s) {
    switch (s) {
      case StatusVerifikasiTransaksi.disetujui:
        return const Color(0xFF047857);
      case StatusVerifikasiTransaksi.ditolak:
        return const Color(0xFFDC2626);
      case StatusVerifikasiTransaksi.menunggu:
        return const Color(0xFFD97706);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isManager = user?.isManager ?? false;
    final filtered = _filteredTransactions;

    final approvedOmzet = filtered
        .where((t) => t.statusVerifikasi == StatusVerifikasiTransaksi.disetujui)
        .fold<int>(0, (sum, t) => sum + t.total);
    final pendingCount =
        filtered.where((t) => t.statusVerifikasi == StatusVerifikasiTransaksi.menunggu).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text('Pendapatan Sales', style: TextStyle(color: kTextColor, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: kTextColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: kPrimaryColor),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Banner Omzet Penjualan Disetujui
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: kPrimaryGradientColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Omzet Penjualan (Disetujui)',
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          TransactionService.formatRp(approvedOmzet),
                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Hanya menghitung omzet penjualan yang sudah Disetujui (bukan komisi/laba). Menunggu verifikasi: $pendingCount catatan.',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (isManager) ...[
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int?>(
                            initialValue: _salesFilterId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Sales',
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            items: [
                              const DropdownMenuItem<int?>(value: null, child: Text('Semua Sales')),
                              ..._salesList.map(
                                (s) => DropdownMenuItem<int?>(
                                  value: s.id,
                                  child: Text(s.name, overflow: TextOverflow.ellipsis),
                                ),
                              ),
                            ],
                            onChanged: (v) => setState(() => _salesFilterId = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<int?>(
                            initialValue: _productFilterId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Produk',
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            items: [
                              const DropdownMenuItem<int?>(value: null, child: Text('Semua Produk')),
                              ..._products.map(
                                (p) => DropdownMenuItem<int?>(
                                  value: p.id,
                                  child: Text(p.namaBarang, overflow: TextOverflow.ellipsis),
                                ),
                              ),
                            ],
                            onChanged: (v) => setState(() => _productFilterId = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],

                  Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: ['Semua', 'Menunggu', 'Disetujui', 'Ditolak'].map((st) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  label: Text(st, style: const TextStyle(fontSize: 11.5)),
                                  selected: _statusFilter == st,
                                  onSelected: (_) => setState(() => _statusFilter = st),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.calendar_today_outlined, size: 15),
                        label: Text(_dateFilter ?? 'Tanggal', style: const TextStyle(fontSize: 11.5)),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.tryParse(_dateFilter ?? '') ?? DateTime.now(),
                            firstDate: DateTime(2024),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setState(() {
                              _dateFilter =
                                  '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                            });
                          }
                        },
                      ),
                      if (_dateFilter != null)
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() => _dateFilter = null),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Text(
                    'Daftar Catatan Penjualan (${filtered.length})',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kTextColor),
                  ),
                  const SizedBox(height: 10),

                  if (filtered.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 42, color: kSecondaryColor),
                          SizedBox(height: 8),
                          Text(
                            'Belum ada catatan penjualan pada filter ini.',
                            style: TextStyle(fontSize: 13, color: kSecondaryColor),
                          ),
                        ],
                      ),
                    )
                  else
                    ...filtered.map((tx) => _buildTransactionCard(tx, isManager)),
                ],
              ),
            ),
      floatingActionButton: !isManager
          ? FloatingActionButton.extended(
              backgroundColor: kPrimaryColor,
              onPressed: _showCreateTransactionDialog,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Catat Penjualan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  Widget _buildTransactionCard(SalesTransaction tx, bool isManager) {
    final c = _statusColor(tx.statusVerifikasi);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 1.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => _showDetailDialog(tx),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: kPrimaryLightColor,
                    child: Icon(Icons.receipt_long, color: kPrimaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tx.kodeTransaksi,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kTextColor),
                        ),
                        Text(
                          '${tx.tanggal} • ${tx.namaPelanggan}${isManager ? ' • ${tx.salesName}' : ''}',
                          style: const TextStyle(fontSize: 11.5, color: kSecondaryColor),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      tx.statusLabel,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                tx.items.map((i) => '${i.namaBarang} (${i.qty} ${i.satuan})').join(', '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: kTextColor),
              ),
              if (tx.alasanPenolakan != null && tx.alasanPenolakan!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Alasan: ${tx.alasanPenolakan}',
                  style: const TextStyle(fontSize: 11.5, color: Colors.redAccent),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    TransactionService.formatRp(tx.total),
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                      color: c,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => _showDetailDialog(tx),
                        child: const Text('Detail', style: TextStyle(fontSize: 12)),
                      ),
                      if (isManager && tx.statusVerifikasi == StatusVerifikasiTransaksi.menunggu) ...[
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF047857),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                          ),
                          onPressed: () => _approveTransaction(tx),
                          child: const Text('Setujui', style: TextStyle(fontSize: 11.5, color: Colors.white)),
                        ),
                        const SizedBox(width: 6),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                          ),
                          onPressed: () => _showRejectOrCancelDialog(tx, isCancelApproved: false),
                          child: const Text('Tolak', style: TextStyle(fontSize: 11.5)),
                        ),
                      ],
                      if (isManager && tx.statusVerifikasi == StatusVerifikasiTransaksi.disetujui)
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange.shade800,
                            side: BorderSide(color: Colors.orange.shade300),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                          ),
                          onPressed: () => _showRejectOrCancelDialog(tx, isCancelApproved: true),
                          child: const Text('Koreksi/Batal', style: TextStyle(fontSize: 11.5)),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
