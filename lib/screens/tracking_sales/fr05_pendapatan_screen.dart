import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../services/inventory_service.dart';
import '../../services/stock_batch_service.dart';
import '../../services/transaction_service.dart';

class FR05PendapatanScreen extends StatefulWidget {
  const FR05PendapatanScreen({Key? key}) : super(key: key);

  @override
  State<FR05PendapatanScreen> createState() => _FR05PendapatanScreenState();
}

class _FR05PendapatanScreenState extends State<FR05PendapatanScreen> {
  List<StockBatch> _batches = [];
  List<SalesTransaction> _transactions = [];
  List<ProductItem> _products = [];
  List<UserModel> _salesList = [];
  bool _isLoading = true;

  int _activeSection = 0; // 0: Stok Opname Batch, 1: Catatan Penjualan Langsung
  String _batchOpnameFilter = 'Semua'; // Semua, Menunggu Opname, Proses Opname, Valid, Ditolak
  String _txStatusFilter = 'Semua'; // Semua, Menunggu, Disetujui, Ditolak
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
    final salesId = isManager ? null : user?.id;

    final batches = await StockBatchService.fetchBatches(salesId: salesId);
    final txs = await TransactionService.fetchTransactions(salesId: salesId);
    final prods = await InventoryService.fetchProducts(salesId: user?.id);

    List<UserModel> salesUsers = [];
    if (isManager) {
      final allUsers = await AuthService().getAllUsers();
      salesUsers = allUsers.where((u) => u.isSales).toList();
    }

    if (mounted) {
      setState(() {
        _batches = batches;
        _transactions = txs;
        _products = prods;
        _salesList = salesUsers;
        _isLoading = false;
      });
    }
  }

  List<StockBatch> get _filteredBatches {
    return _batches.where((b) {
      if (_salesFilterId != null && b.salesId != _salesFilterId) return false;
      if (_productFilterId != null &&
          !b.items.any((it) => it.productId == _productFilterId)) {
        return false;
      }
      if (_dateFilter != null &&
          _dateFilter!.isNotEmpty &&
          b.tanggal != _dateFilter) {
        return false;
      }
      switch (_batchOpnameFilter) {
        case 'Menunggu Opname':
          return !b.isRejected && b.statusOpname == StatusOpnameBatch.belumOpname;
        case 'Proses Opname':
          return !b.isRejected && b.statusOpname == StatusOpnameBatch.prosesOpname;
        case 'Valid':
          return !b.isRejected && b.statusOpname == StatusOpnameBatch.valid;
        case 'Ditolak':
          return b.isRejected;
        default:
          return true;
      }
    }).toList();
  }

  List<SalesTransaction> get _filteredTransactions {
    return _transactions.where((t) {
      if (_txStatusFilter != 'Semua' &&
          t.statusLabel.toLowerCase() != _txStatusFilter.toLowerCase()) {
        return false;
      }
      if (_salesFilterId != null && t.salesId != _salesFilterId) {
        return false;
      }
      if (_productFilterId != null &&
          !t.items.any((it) => it.productId == _productFilterId)) {
        return false;
      }
      if (_dateFilter != null &&
          _dateFilter!.isNotEmpty &&
          t.tanggal != _dateFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  void _showBatchOpnameDialog(StockBatch batch) {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null || !user.isManager) return;

    final Map<int, TextEditingController> sisaCtrls = {
      for (final it in batch.items)
        it.id: TextEditingController(
          text: (it.qtySisaOpname ?? 0).toString(),
        ),
    };
    final Map<int, TextEditingController> itemNoteCtrls = {
      for (final it in batch.items)
        it.id: TextEditingController(text: it.catatanOpname ?? ''),
    };
    final batchNoteCtrl = TextEditingController(text: batch.catatanOpname ?? '');
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          int previewTotalPendapatan = 0;
          int previewTotalTerjual = 0;

          for (final it in batch.items) {
            final rawSisa = int.tryParse(sisaCtrls[it.id]!.text.trim());
            if (rawSisa != null && rawSisa >= 0 && rawSisa <= it.qtyDiambil) {
              final terjual = it.qtyDiambil - rawSisa;
              previewTotalTerjual += terjual;
              previewTotalPendapatan += terjual * it.hargaSatuan;
            }
          }

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                const Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF047857)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stok Opname ${batch.kodeBatch}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold, color: kTextColor),
                      ),
                      Text(
                        'Bersama ${user.isSuperAdmin ? 'Owner' : 'Administrator'} (${user.name})',
                        style: const TextStyle(fontSize: 11.5, color: kSecondaryColor),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: saving ? null : () => Navigator.pop(ctx),
                ),
              ],
            ),
            content: Form(
              key: formKey,
              child: SizedBox(
                width: 540,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          'Sales: ${batch.salesName} • Tanggal: ${StockBatchService.formatShortDate(batch.tanggal)}\nStatus Tinjauan: ${batch.reviewStatusLabel}',
                          style: const TextStyle(fontSize: 12, color: kTextColor),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Masukkan Sisa Stok Fisik per Barang:',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ...batch.items.map((it) {
                        final sisaParsed = int.tryParse(sisaCtrls[it.id]!.text.trim());
                        final validRange = sisaParsed != null &&
                            sisaParsed >= 0 &&
                            sisaParsed <= it.qtyDiambil;
                        final terjual = validRange ? it.qtyDiambil - sisaParsed : 0;
                        final sub = terjual * it.hargaSatuan;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      it.namaBarang,
                                      style: const TextStyle(
                                          fontSize: 13.5, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Text(
                                    'Diambil: ${it.qtyDiambil} ${it.satuan}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1D4ED8),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                'Harga Satuan: ${TransactionService.formatRp(it.hargaSatuan)} / ${it.satuan}',
                                style: const TextStyle(
                                    fontSize: 11.5, color: kSecondaryColor),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      controller: sisaCtrls[it.id],
                                      keyboardType: TextInputType.number,
                                      onChanged: (_) => setDialogState(() {}),
                                      decoration: InputDecoration(
                                        labelText: 'Sisa Fisik (${it.satuan})',
                                        contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 10),
                                        border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8)),
                                      ),
                                      validator: (v) {
                                        final val = int.tryParse(v?.trim() ?? '');
                                        if (val == null || val < 0 || val > it.qtyDiambil) {
                                          return '0..${it.qtyDiambil}';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    flex: 3,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Terjual: $terjual ${it.satuan}',
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF065F46),
                                            ),
                                          ),
                                          Text(
                                            TransactionService.formatRp(sub),
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF047857),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: itemNoteCtrls[it.id],
                                decoration: InputDecoration(
                                  hintText: 'Catatan item opname (opsional)',
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      TextField(
                        controller: batchNoteCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Catatan Hasil Stok Opname Batch',
                          hintText:
                              'Contoh: Sisa fisik cocok dengan stok di mobil kanvas.',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Terjual ($previewTotalTerjual unit):',
                              style: const TextStyle(
                                  fontSize: 12.5, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              TransactionService.formatRp(previewTotalPendapatan),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF047857),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => saving = true);
                        try {
                          final nav = Navigator.of(ctx);
                          await StockBatchService.submitBatchOpname(
                            batchId: batch.id,
                            actor: user,
                            sisaByItemId: {
                              for (final it in batch.items)
                                it.id: int.parse(sisaCtrls[it.id]!.text.trim()),
                            },
                            catatanByItemId: {
                              for (final it in batch.items)
                                it.id: itemNoteCtrls[it.id]!.text.trim(),
                            },
                            catatanOpname: batchNoteCtrl.text.trim(),
                            finalize: false,
                          );
                          if (!mounted) return;
                          nav.pop();
                          await _loadData();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Draft stok opname ${batch.kodeBatch} disimpan.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } catch (e) {
                          setDialogState(() => saving = false);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.toString().replaceFirst('Exception: ', '')),
                              backgroundColor: kDangerColor,
                            ),
                          );
                        }
                      },
                child: const Text('Simpan Draft'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF15803D),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: saving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => saving = true);
                        try {
                          final nav = Navigator.of(ctx);
                          final updated = await StockBatchService.submitBatchOpname(
                            batchId: batch.id,
                            actor: user,
                            sisaByItemId: {
                              for (final it in batch.items)
                                it.id: int.parse(sisaCtrls[it.id]!.text.trim()),
                            },
                            catatanByItemId: {
                              for (final it in batch.items)
                                it.id: itemNoteCtrls[it.id]!.text.trim(),
                            },
                            catatanOpname: batchNoteCtrl.text.trim(),
                            finalize: true,
                          );
                          if (!mounted) return;
                          nav.pop();
                          await _loadData();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${updated.kodeBatch} selesai opname & dinyatakan VALID (${TransactionService.formatRp(updated.totalPendapatan)})!',
                              ),
                              backgroundColor: const Color(0xFF15803D),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } catch (e) {
                          setDialogState(() => saving = false);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.toString().replaceFirst('Exception: ', '')),
                              backgroundColor: kDangerColor,
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.verified_rounded, size: 17, color: Colors.white),
                label: const Text(
                  'Selesaikan & Validasi Batch',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showBatchDetailDialog(StockBatch batch) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          batch.kodeBatch,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Sales: ${batch.salesName}', style: const TextStyle(fontSize: 12.5)),
                Text('Tanggal Batch: ${StockBatchService.formatShortDate(batch.tanggal)}',
                    style: const TextStyle(fontSize: 12.5)),
                Text('Status Tinjauan: ${batch.reviewStatusLabel}',
                    style: const TextStyle(fontSize: 12.5)),
                Text(
                  'Status Opname: ${batch.opnameStatusLabel}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: batch.isValid ? const Color(0xFF15803D) : kTextColor,
                  ),
                ),
                if (batch.opnameByName != null)
                  Text(
                    'Pelaksana Opname: ${batch.opnameByName} (${batch.opnameByRole ?? 'Manager'})',
                    style: const TextStyle(fontSize: 12, color: kSecondaryColor),
                  ),
                const Divider(height: 18),
                const Text(
                  'Rincian Stok Opname Per Barang:',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...batch.items.map(
                  (it) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${it.namaBarang}\nDiambil: ${it.qtyDiambil} • Sisa: ${it.qtySisaOpname ?? '-'} • Terjual: ${it.qtySisaOpname != null ? it.qtyTerjual : '-'} (${TransactionService.formatRp(it.hargaSatuan)})',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Text(
                          it.qtySisaOpname != null
                              ? TransactionService.formatRp(it.pendapatanItem)
                              : 'Menunggu',
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Pendapatan Batch',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      TransactionService.formatRp(batch.totalPendapatan),
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
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
                  style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.bold,
                      color: kTextColor),
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
                      prefixIcon:
                          const Icon(Icons.calendar_today_outlined, size: 17),
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
                  const SizedBox(height: 10),
                  TextField(
                    controller: pelangganCtrl,
                    decoration: InputDecoration(
                      labelText: 'Nama Pelanggan / Toko (Opsional)',
                      hintText: 'Contoh: Toko Sinar Makmur',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: selectedProd.id,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Pilih Produk Aktif',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
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
                          selectedProd =
                              activeProducts.firstWhere((p) => p.id == val);
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
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF047857),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          final q = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                          if (q <= 0) return;
                          setDialogState(() {
                            final existingIdx = cart.indexWhere(
                                (c) => c['product_id'] == selectedProd.id);
                            if (existingIdx != -1) {
                              final newQty = (cart[existingIdx]['qty'] as int) + q;
                              cart[existingIdx]['qty'] = newQty;
                              cart[existingIdx]['subtotal'] =
                                  newQty * selectedProd.harga;
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
                        label: const Text('Tambah',
                            style: TextStyle(color: Colors.white)),
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
                            return Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${it['nama']} (${it['qty']} ${it['satuan']})',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                Text(
                                  TransactionService.formatRp(it['subtotal'] as int),
                                  style: const TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 17, color: Colors.redAccent),
                                  onPressed: () =>
                                      setDialogState(() => cart.removeAt(i)),
                                ),
                              ],
                            );
                          }),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Estimasi Total:',
                                  style: TextStyle(fontWeight: FontWeight.bold)),
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
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
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
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
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
              child: const Text('Simpan Penjualan',
                  style: TextStyle(color: Colors.white)),
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

  void _showRejectOrCancelDialog(SalesTransaction tx,
      {required bool isCancelApproved}) {
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
            isCancelApproved
                ? 'Koreksi / Batalkan Transaksi'
                : 'Tolak Catatan Penjualan',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: reasonCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Alasan *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Alasan wajib diisi' : null,
            ),
          ),
          actions: [
            TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Tutup')),
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
                      }
                    },
              child: Text(
                isCancelApproved ? 'Batalkan' : 'Tolak',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTransactionDetailDialog(SalesTransaction tx) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(tx.kodeTransaksi,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sales: ${tx.salesName}'),
              Text('Pelanggan: ${tx.namaPelanggan}'),
              Text('Tanggal: ${tx.tanggal}'),
              Text('Status: ${tx.statusLabel}'),
              const Divider(),
              ...tx.items.map(
                (it) => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${it.namaBarang} (${it.qty} ${it.satuan})'),
                    Text(TransactionService.formatRp(it.subtotal)),
                  ],
                ),
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(TransactionService.formatRp(tx.total),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
        ],
      ),
    );
  }

  Color _txStatusColor(StatusVerifikasiTransaksi s) {
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
    final filteredBatches = _filteredBatches;
    final filteredTxs = _filteredTransactions;

    final validBatchOmzet = filteredBatches
        .where((b) => b.isValid)
        .fold<int>(0, (sum, b) => sum + b.totalPendapatan);
    final approvedTxOmzet = filteredTxs
        .where((t) => t.statusVerifikasi == StatusVerifikasiTransaksi.disetujui)
        .fold<int>(0, (sum, t) => sum + t.total);
    final totalApprovedOmzet = validBatchOmzet + approvedTxOmzet;

    final pendingOpnameCount = filteredBatches
        .where((b) => !b.isRejected && !b.isValid)
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text('Pendapatan Sales',
            style: TextStyle(color: kTextColor, fontWeight: FontWeight.bold)),
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
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          TransactionService.formatRp(totalApprovedOmzet),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Batch Opname Valid: ${TransactionService.formatRp(validBatchOmzet)} • Transaksi Langsung: ${TransactionService.formatRp(approvedTxOmzet)} • Menunggu Opname: $pendingOpnameCount batch.',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _sectionTabButton(
                          label: 'Stok Opname Batch (${filteredBatches.length})',
                          selected: _activeSection == 0,
                          onTap: () => setState(() => _activeSection = 0),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _sectionTabButton(
                          label: 'Penjualan Langsung (${filteredTxs.length})',
                          selected: _activeSection == 1,
                          onTap: () => setState(() => _activeSection = 1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            items: [
                              const DropdownMenuItem<int?>(
                                  value: null, child: Text('Semua Sales')),
                              ..._salesList.map(
                                (s) => DropdownMenuItem<int?>(
                                  value: s.id,
                                  child: Text(s.name,
                                      overflow: TextOverflow.ellipsis),
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
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            items: [
                              const DropdownMenuItem<int?>(
                                  value: null, child: Text('Semua Produk')),
                              ..._products.map(
                                (p) => DropdownMenuItem<int?>(
                                  value: p.id,
                                  child: Text(p.namaBarang,
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ),
                            ],
                            onChanged: (v) =>
                                setState(() => _productFilterId = v),
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
                            children: (_activeSection == 0
                                    ? [
                                        'Semua',
                                        'Menunggu Opname',
                                        'Proses Opname',
                                        'Valid',
                                        'Ditolak',
                                      ]
                                    : [
                                        'Semua',
                                        'Menunggu',
                                        'Disetujui',
                                        'Ditolak',
                                      ])
                                .map((st) {
                              final selected = _activeSection == 0
                                  ? _batchOpnameFilter == st
                                  : _txStatusFilter == st;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  label: Text(st,
                                      style: const TextStyle(fontSize: 11.5)),
                                  selected: selected,
                                  onSelected: (_) => setState(() {
                                    if (_activeSection == 0) {
                                      _batchOpnameFilter = st;
                                    } else {
                                      _txStatusFilter = st;
                                    }
                                  }),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        icon:
                            const Icon(Icons.calendar_today_outlined, size: 15),
                        label: Text(_dateFilter ?? 'Tanggal',
                            style: const TextStyle(fontSize: 11.5)),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.tryParse(_dateFilter ?? '') ??
                                DateTime.now(),
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
                  if (_activeSection == 0) ...[
                    Text(
                      'Batch Stok Opname Harian (${filteredBatches.length})',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: kTextColor),
                    ),
                    const SizedBox(height: 10),
                    if (filteredBatches.isEmpty)
                      _emptyBox('Belum ada batch pengajuan pada filter ini.')
                    else
                      ...filteredBatches
                          .map((b) => _buildBatchOpnameCard(b, isManager)),
                  ] else ...[
                    Text(
                      'Daftar Catatan Penjualan (${filteredTxs.length})',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: kTextColor),
                    ),
                    const SizedBox(height: 10),
                    if (filteredTxs.isEmpty)
                      _emptyBox('Belum ada catatan penjualan pada filter ini.')
                    else
                      ...filteredTxs
                          .map((tx) => _buildTransactionCard(tx, isManager)),
                  ],
                ],
              ),
            ),
      floatingActionButton: !isManager
          ? FloatingActionButton.extended(
              backgroundColor: kPrimaryColor,
              onPressed: _showCreateTransactionDialog,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Catat Penjualan',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  Widget _sectionTabButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? kPrimaryColor : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? kPrimaryColor : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: selected ? Colors.white : kTextColor,
          ),
        ),
      ),
    );
  }

  Widget _emptyBox(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.receipt_long_outlined,
              size: 42, color: kSecondaryColor),
          const SizedBox(height: 8),
          Text(message,
              style: const TextStyle(fontSize: 13, color: kSecondaryColor)),
        ],
      ),
    );
  }

  Widget _buildBatchOpnameCard(StockBatch batch, bool isManager) {
    final opnameColor = batch.isRejected
        ? const Color(0xFFDC2626)
        : batch.isValid
            ? const Color(0xFF15803D)
            : batch.statusOpname == StatusOpnameBatch.prosesOpname
                ? const Color(0xFF0369A1)
                : const Color(0xFFD97706);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: batch.isValid
              ? const Color(0xFF86EFAC)
              : const Color(0xFFE2E8F0),
        ),
      ),
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: opnameColor.withValues(alpha: 0.12),
                  child: Icon(
                    batch.isValid
                        ? Icons.verified_rounded
                        : Icons.inventory_rounded,
                    color: opnameColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        batch.kodeBatch,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: kTextColor),
                      ),
                      Text(
                        '${StockBatchService.formatShortDate(batch.tanggal)} • ${batch.salesName} • ${batch.reviewStatusLabel}',
                        style: const TextStyle(
                            fontSize: 11.5, color: kSecondaryColor),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: batch.isValid
                        ? const Color(0xFF15803D)
                        : opnameColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    batch.isValid ? 'VALID' : batch.opnameStatusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: batch.isValid ? Colors.white : opnameColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: batch.items.map((it) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            it.namaBarang,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          it.qtySisaOpname != null
                              ? 'Ambil ${it.qtyDiambil} | Sisa ${it.qtySisaOpname} | Terjual ${it.qtyTerjual}'
                              : 'Diambil: ${it.qtyDiambil} ${it.satuan}',
                          style: const TextStyle(
                              fontSize: 11.5, color: kSecondaryColor),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            if (batch.isValid && batch.opnameByName != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Opname selesai bersama ${batch.opnameByRole ?? 'Manager'} (${batch.opnameByName}) • Batch Valid',
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF15803D)),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      batch.isValid
                          ? 'Pendapatan Valid:'
                          : 'Estimasi Nilai Batch:',
                      style:
                          const TextStyle(fontSize: 11, color: kSecondaryColor),
                    ),
                    Text(
                      TransactionService.formatRp(batch.isValid
                          ? batch.totalPendapatan
                          : batch.totalEstimasiNilai),
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: opnameColor,
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                      ),
                      onPressed: () => _showBatchDetailDialog(batch),
                      child:
                          const Text('Detail', style: TextStyle(fontSize: 12)),
                    ),
                    if (isManager && !batch.isRejected && !batch.isValid)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF047857),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _showBatchOpnameDialog(batch),
                        icon: const Icon(Icons.fact_check_outlined,
                            size: 15, color: Colors.white),
                        label: const Text(
                          'Stok Opname Batch',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(SalesTransaction tx, bool isManager) {
    final c = _txStatusColor(tx.statusVerifikasi);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 1.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => _showTransactionDetailDialog(tx),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: kPrimaryLightColor,
                    child:
                        Icon(Icons.receipt_long, color: kPrimaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tx.kodeTransaksi,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: kTextColor),
                        ),
                        Text(
                          '${tx.tanggal} • ${tx.namaPelanggan}${isManager ? ' • ${tx.salesName}' : ''}',
                          style: const TextStyle(
                              fontSize: 11.5, color: kSecondaryColor),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      tx.statusLabel,
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold, color: c),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                tx.items
                    .map((i) => '${i.namaBarang} (${i.qty} ${i.satuan})')
                    .join(', '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: kTextColor),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    TransactionService.formatRp(tx.total),
                    style: TextStyle(
                        fontSize: 15.5, fontWeight: FontWeight.bold, color: c),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => _showTransactionDetailDialog(tx),
                        child:
                            const Text('Detail', style: TextStyle(fontSize: 12)),
                      ),
                      if (isManager &&
                          tx.statusVerifikasi ==
                              StatusVerifikasiTransaksi.menunggu) ...[
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF047857),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                          ),
                          onPressed: () => _approveTransaction(tx),
                          child: const Text('Setujui',
                              style: TextStyle(
                                  fontSize: 11.5, color: Colors.white)),
                        ),
                        const SizedBox(width: 6),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                          ),
                          onPressed: () => _showRejectOrCancelDialog(tx,
                              isCancelApproved: false),
                          child: const Text('Tolak',
                              style: TextStyle(fontSize: 11.5)),
                        ),
                      ],
                      if (isManager &&
                          tx.statusVerifikasi ==
                              StatusVerifikasiTransaksi.disetujui)
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange.shade800,
                            side: BorderSide(color: Colors.orange.shade300),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                          ),
                          onPressed: () => _showRejectOrCancelDialog(tx,
                              isCancelApproved: true),
                          child: const Text('Koreksi/Batal',
                              style: TextStyle(fontSize: 11.5)),
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
