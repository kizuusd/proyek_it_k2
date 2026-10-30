import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants.dart';

// ─────────────────────────────────────────────
// Model: Satu baris item pengajuan barang
// ─────────────────────────────────────────────
class _ItemPengajuan {
  String namaBarang;
  int qty;
  String satuan;
  String keterangan;

  _ItemPengajuan({
    required this.namaBarang,
    this.qty = 1,
    this.satuan = 'Box',
    this.keterangan = '',
  });

  _ItemPengajuan copyWith({
    String? namaBarang,
    int? qty,
    String? satuan,
    String? keterangan,
  }) {
    return _ItemPengajuan(
      namaBarang: namaBarang ?? this.namaBarang,
      qty: qty ?? this.qty,
      satuan: satuan ?? this.satuan,
      keterangan: keterangan ?? this.keterangan,
    );
  }
}

// ─────────────────────────────────────────────
// Main Screen
// ─────────────────────────────────────────────
class FR10PengajuanBarangScreen extends StatefulWidget {
  const FR10PengajuanBarangScreen({Key? key}) : super(key: key);

  @override
  State<FR10PengajuanBarangScreen> createState() =>
      _FR10PengajuanBarangScreenState();
}

class _FR10PengajuanBarangScreenState
    extends State<FR10PengajuanBarangScreen> with TickerProviderStateMixin {
  // ── Data ─────────────────────────────────
  final List<_ItemPengajuan> _items = [];
  DateTime? _tanggalPengambilan;
  final TextEditingController _catatanController = TextEditingController();
  bool _isSubmitting = false;

  // ── Animasi ───────────────────────────────
  late AnimationController _headerAnim;
  late Animation<double> _headerFade;

  // ── Konstanta pilihan barang ──────────────
  static const List<String> _daftarBarang = [
    'Produk A (Minuman)',
    'Produk B (Snack)',
    'Produk C (Sembako)',
    'Produk D (Kosmetik)',
    'Produk E (Elektronik)',
    'Produk F (Deterjen)',
  ];
  static const List<String> _daftarSatuan = [
    'Box',
    'Karton',
    'Lusin',
    'Pcs',
    'Kg',
    'Liter',
  ];

  @override
  void initState() {
    super.initState();
    _headerAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _headerFade = CurvedAnimation(parent: _headerAnim, curve: Curves.easeOut);
    _headerAnim.forward();
    _items.add(_ItemPengajuan(namaBarang: _daftarBarang.first));
  }

  @override
  void dispose() {
    _headerAnim.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────
  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Belum dipilih';
    final bulan = [
      '',
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${dt.day} ${bulan[dt.month]} ${dt.year}';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggalPengambilan ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      helpText: 'PILIH TANGGAL PENGAMBILAN',
      cancelText: 'Batal',
      confirmText: 'Pilih',
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(
              primary: kPrimaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: kTextColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _tanggalPengambilan = picked);
    }
  }

  void _tambahItem() {
    setState(() {
      _items.add(_ItemPengajuan(namaBarang: _daftarBarang.first));
    });
  }

  void _hapusItem(int index) {
    if (_items.length == 1) {
      _showSnack('Minimal harus ada 1 item pengajuan.', isError: true);
      return;
    }
    setState(() => _items.removeAt(index));
  }

  void _tambahQty(int index) {
    setState(
        () => _items[index] = _items[index].copyWith(qty: _items[index].qty + 1));
  }

  void _kurangiQty(int index) {
    if (_items[index].qty <= 1) return;
    setState(
        () => _items[index] = _items[index].copyWith(qty: _items[index].qty - 1));
  }

  bool _validasi() {
    if (_tanggalPengambilan == null) {
      _showSnack('Harap pilih tanggal pengambilan barang.', isError: true);
      return false;
    }
    for (int i = 0; i < _items.length; i++) {
      if (_items[i].qty <= 0) {
        _showSnack('Qty item ke-${i + 1} tidak valid.', isError: true);
        return false;
      }
    }
    return true;
  }

  Future<void> _kirimPengajuan() async {
    if (!_validasi()) return;
    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    _showSuksesDialog();
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
                color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: isError ? kDangerColor : kSuccessColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuksesDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: kSuccessColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.check_circle, color: kSuccessColor, size: 50),
              ),
              const SizedBox(height: 20),
              const Text(
                'Pengajuan Terkirim!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: kTextColor,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Pengajuan barang Anda telah dikirim ke Administrator dan sedang menunggu persetujuan.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: kSubtitleColor, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: kWarningColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.schedule, color: kWarningColor, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Tanggal Ambil: ${_formatDate(_tanggalPengambilan)}',
                      style: const TextStyle(
                        color: kWarningColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Kembali ke Dashboard',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _headerFade,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeaderBanner()),
            SliverToBoxAdapter(child: _buildTanggalPengambilan()),
            SliverToBoxAdapter(
                child: _buildSectionTitle('Daftar Barang yang Diajukan')),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _buildItemCard(i),
                childCount: _items.length,
              ),
            ),
            SliverToBoxAdapter(child: _buildTambahItemButton()),
            SliverToBoxAdapter(child: _buildRingkasan()),
            SliverToBoxAdapter(child: _buildCatatan()),
            SliverToBoxAdapter(child: _buildSubmitButton()),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  // Widgets Komponen
  // ──────────────────────────────────────────

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text(
        'Pengajuan Barang',
        style: TextStyle(
            color: kTextColor, fontWeight: FontWeight.bold, fontSize: 18),
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      iconTheme: const IconThemeData(color: kTextColor),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFE5E7EB), height: 1),
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: kPrimaryGradientColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: kPrimaryColor.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.inventory_2_rounded,
                color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Form Pengajuan Barang',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Ajukan kebutuhan stok barang kepada Administrator untuk diproses.',
                  style:
                      TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTanggalPengambilan() {
    final bool sudahPilih = _tanggalPengambilan != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Tanggal Pengambilan Barang', withPadding: false),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _pickDate,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      sudahPilih ? kAccentColor : const Color(0xFFE5E7EB),
                  width: sudahPilih ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: sudahPilih
                          ? kAccentColor.withValues(alpha: 0.1)
                          : kPrimaryLightColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.calendar_month_rounded,
                      color: sudahPilih ? kAccentColor : kPrimaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sudahPilih
                              ? 'Tanggal Pengambilan'
                              : 'Pilih Tanggal Pengambilan',
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                sudahPilih ? kAccentColor : kSubtitleColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(_tanggalPengambilan),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: sudahPilih ? kTextColor : kSubtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: sudahPilih ? kAccentColor : kSubtitleColor,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, {bool withPadding = true}) {
    return Padding(
      padding: withPadding
          ? const EdgeInsets.fromLTRB(16, 20, 16, 0)
          : EdgeInsets.zero,
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: kAccentColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: kTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(int index) {
    final item = _items[index];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header kartu item ─────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    kPrimaryColor.withValues(alpha: 0.06),
                    kAccentColor.withValues(alpha: 0.04),
                  ],
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: kAccentColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Item Barang',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: kTextColor,
                        fontSize: 14),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _hapusItem(index),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: kDangerColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.delete_outline_rounded,
                          color: kDangerColor, size: 18),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Nama Barang ────────────
                  const Text('Nama Barang',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: kSubtitleColor)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: const Color(0xFFE5E7EB)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: item.namaBarang,
                        isExpanded: true,
                        icon: const Icon(Icons.expand_more_rounded,
                            color: kPrimaryColor),
                        style: const TextStyle(
                            color: kTextColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _items[index] =
                                  _items[index].copyWith(namaBarang: val);
                            });
                          }
                        },
                        items: _daftarBarang
                            .map((e) => DropdownMenuItem(
                                value: e,
                                child: Text(e,
                                    style: const TextStyle(fontSize: 13))))
                            .toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Qty & Satuan ────────────────────
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Jumlah (Qty)',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: kSubtitleColor)),
                            const SizedBox(height: 6),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: const Color(0xFFE5E7EB)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  _buildQtyButton(
                                    icon: Icons.remove_rounded,
                                    color: item.qty <= 1
                                        ? Colors.grey.shade300
                                        : kDangerColor.withValues(alpha: 0.8),
                                    onTap: () => _kurangiQty(index),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () =>
                                          _showQtyInputDialog(index),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                        alignment: Alignment.center,
                                        child: Text(
                                          '${item.qty}',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: kTextColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  _buildQtyButton(
                                    icon: Icons.add_rounded,
                                    color: kSuccessColor,
                                    onTap: () => _tambahQty(index),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Satuan',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: kSubtitleColor)),
                            const SizedBox(height: 6),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: const Color(0xFFE5E7EB)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: item.satuan,
                                  isExpanded: true,
                                  icon: const Icon(Icons.expand_more_rounded,
                                      color: kPrimaryColor, size: 18),
                                  style: const TextStyle(
                                      color: kTextColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _items[index] = _items[index]
                                            .copyWith(satuan: val);
                                      });
                                    }
                                  },
                                  items: _daftarSatuan
                                      .map((e) => DropdownMenuItem(
                                          value: e, child: Text(e)))
                                      .toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── Keterangan ─────────────────────
                  const Text('Keterangan (Opsional)',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: kSubtitleColor)),
                  const SizedBox(height: 6),
                  TextFormField(
                    initialValue: item.keterangan,
                    decoration: InputDecoration(
                      hintText: 'Mis: Untuk Toko Makmur Jaya',
                      hintStyle: TextStyle(
                          color: Colors.grey.shade400, fontSize: 13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: kAccentColor, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                    onChanged: (val) {
                      _items[index] =
                          _items[index].copyWith(keterangan: val);
                    },
                    style: const TextStyle(
                        fontSize: 13, color: kTextColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQtyButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 46,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  void _showQtyInputDialog(int index) {
    final ctrl =
        TextEditingController(text: '${_items[index].qty}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Masukkan Jumlah',
            style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: kAccentColor, width: 2),
            ),
          ),
          style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: kTextColor),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal',
                style: TextStyle(color: kSubtitleColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final val = int.tryParse(ctrl.text) ?? 1;
              setState(() => _items[index] = _items[index]
                  .copyWith(qty: val < 1 ? 1 : val));
              Navigator.pop(ctx);
            },
            child: const Text('Simpan',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildTambahItemButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: GestureDetector(
        onTap: _tambahItem,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: kAccentColor.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.07),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: kAccentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add_rounded,
                    color: kAccentColor, size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'Tambah Item Barang',
                style: TextStyle(
                  color: kAccentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRingkasan() {
    final totalQty = _items.fold<int>(0, (sum, e) => sum + e.qty);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: kPrimaryColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: kPrimaryColor.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            const Row(
              children: [
                Icon(Icons.summarize_rounded,
                    color: kPrimaryColor, size: 20),
                SizedBox(width: 8),
                Text('Ringkasan Pengajuan',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: kTextColor,
                        fontSize: 14)),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _buildRingkasanRow(
                'Jumlah Item', '${_items.length} jenis'),
            const SizedBox(height: 6),
            _buildRingkasanRow('Total Qty', '$totalQty unit'),
            const SizedBox(height: 6),
            _buildRingkasanRow(
              'Tanggal Ambil',
              _formatDate(_tanggalPengambilan),
              valueColor: _tanggalPengambilan != null
                  ? kSuccessColor
                  : kDangerColor,
            ),
            const SizedBox(height: 6),
            _buildRingkasanRow(
              'Tujuan Pengajuan',
              'Administrator',
              valueColor: kAccentColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRingkasanRow(String label, String value,
      {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                color: kSubtitleColor, fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? kTextColor,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildCatatan() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Catatan ke Administrator',
              withPadding: false),
          const SizedBox(height: 10),
          TextFormField(
            controller: _catatanController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText:
                  'Tuliskan catatan atau keperluan khusus untuk administrator...',
              hintStyle: TextStyle(
                  color: Colors.grey.shade400, fontSize: 13),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: kAccentColor, width: 2),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
            style: const TextStyle(
                fontSize: 13, color: kTextColor, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: _isSubmitting ? null : kPrimaryGradientColor,
          color: _isSubmitting ? Colors.grey.shade300 : null,
          borderRadius: BorderRadius.circular(18),
          boxShadow: _isSubmitting
              ? []
              : [
                  BoxShadow(
                    color: kPrimaryColor.withValues(alpha: 0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isSubmitting ? null : _kirimPengajuan,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _isSubmitting
                    ? [
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white),
                        ),
                        const SizedBox(width: 14),
                        const Text('Mengirim Pengajuan...',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                      ]
                    : [
                        const Icon(Icons.send_rounded,
                            color: Colors.white, size: 22),
                        const SizedBox(width: 12),
                        const Text(
                          'Kirim ke Administrator',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
