import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants.dart';
import '../../providers/auth_provider.dart';

enum StatusIzin { pending, approved, rejected }

class IzinAbsen {
  final String id;
  final String salesName;
  final String salesEmail;
  final String salesPhone;
  final String alasan;
  final String tanggalMulai;
  final String tanggalSelesai;
  final int durasiHari;
  final String deskripsi;
  final String tanggalPengajuan;
  StatusIzin status;
  String? catatanPersetujuan;
  String? diprosesOleh;
  DateTime? waktuDiproses;

  IzinAbsen({
    required this.id,
    required this.salesName,
    required this.salesEmail,
    required this.salesPhone,
    required this.alasan,
    required this.tanggalMulai,
    required this.tanggalSelesai,
    required this.durasiHari,
    required this.deskripsi,
    required this.tanggalPengajuan,
    this.status = StatusIzin.pending,
    this.catatanPersetujuan,
    this.diprosesOleh,
    this.waktuDiproses,
  });
}

class FR09PengajuanIzinScreen extends StatefulWidget {
  const FR09PengajuanIzinScreen({Key? key}) : super(key: key);

  @override
  State<FR09PengajuanIzinScreen> createState() => _FR09PengajuanIzinScreenState();
}

class _FR09PengajuanIzinScreenState extends State<FR09PengajuanIzinScreen>
    with SingleTickerProviderStateMixin {
  // Mock Data Daftar Izin Absen dari Sales (Untuk Admin & Owner)
  late List<IzinAbsen> _daftarIzin;

  // Filter untuk tampilan Admin/Owner
  String _filterStatus = 'Semua';

  // Controller Form untuk Role Sales
  final _formKey = GlobalKey<FormState>();
  String _selectedAlasan = 'Sakit';
  final TextEditingController _startDateCtrl = TextEditingController(text: '22 Okt 2026');
  final TextEditingController _endDateCtrl = TextEditingController(text: '23 Okt 2026');
  final TextEditingController _deskripsiCtrl = TextEditingController();

  TabController? _salesTabController;

  @override
  void initState() {
    super.initState();
    _salesTabController = TabController(length: 2, vsync: this);
    _daftarIzin = [
      IzinAbsen(
        id: 'IZN-2026-001',
        salesName: 'Muhammad Ulil Abshor',
        salesEmail: 'sales@majubersama.com',
        salesPhone: '081234567892',
        alasan: 'Sakit',
        tanggalMulai: '22 Okt 2026',
        tanggalSelesai: '23 Okt 2026',
        durasiHari: 2,
        deskripsi:
            'Mengalami demam tinggi dan flu berat setelah dinas kunjungan toko di area barat kemarin. Dokter menyarankan istirahat medis 2 hari.',
        tanggalPengajuan: '21 Okt 2026, 08:30 WIB',
        status: StatusIzin.pending,
      ),
      IzinAbsen(
        id: 'IZN-2026-002',
        salesName: 'Budi Santoso',
        salesEmail: 'budi.sales@majubersama.com',
        salesPhone: '081234567899',
        alasan: 'Izin Urusan Keluarga',
        tanggalMulai: '24 Okt 2026',
        tanggalSelesai: '25 Okt 2026',
        durasiHari: 2,
        deskripsi:
            'Menghadiri acara pernikahan saudara kandung di luar kota. Tugas monitoring outlet telah dikoordinasikan dengan tim rute cadangan.',
        tanggalPengajuan: '21 Okt 2026, 10:15 WIB',
        status: StatusIzin.pending,
      ),
      IzinAbsen(
        id: 'IZN-2026-003',
        salesName: 'Rian Pratama',
        salesEmail: 'rian.sales@majubersama.com',
        salesPhone: '081299887766',
        alasan: 'Kendala Operasional / Rute',
        tanggalMulai: '20 Okt 2026',
        tanggalSelesai: '20 Okt 2026',
        durasiHari: 1,
        deskripsi:
            'Sepeda motor inventaris mengalami kendala mesin saat menuju rute distribusi timur dan harus servis bengkel darurat.',
        tanggalPengajuan: '20 Okt 2026, 07:45 WIB',
        status: StatusIzin.approved,
        diprosesOleh: 'Administrator (Sekretaris)',
        catatanPersetujuan: 'Disetujui. Surat tanda terima servis telah dikonfirmasi.',
        waktuDiproses: DateTime.now().subtract(const Duration(days: 1)),
      ),
      IzinAbsen(
        id: 'IZN-2026-004',
        salesName: 'Dimas Hendrawan',
        salesEmail: 'hendrawan@majubersama.com',
        salesPhone: '081255443322',
        alasan: 'Cuti Tahunan',
        tanggalMulai: '19 Okt 2026',
        tanggalSelesai: '20 Okt 2026',
        durasiHari: 2,
        deskripsi: 'Pengajuan cuti pribadi untuk liburan akhir pekan.',
        tanggalPengajuan: '19 Okt 2026, 06:10 WIB',
        status: StatusIzin.rejected,
        diprosesOleh: 'Superadmin (Owner)',
        catatanPersetujuan:
            'Ditolak. Permohonan cuti tahunan wajib diajukan minimal H-3 sebelum tanggal pelaksanaan sesuai SOP perusahaan.',
        waktuDiproses: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];
  }

  @override
  void dispose() {
    _salesTabController?.dispose();
    _startDateCtrl.dispose();
    _endDateCtrl.dispose();
    _deskripsiCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // LOGIKA AKSI APPROVE & REJECT
  // ============================================================
  void _approveIzin(IzinAbsen izin, String reviewerRole) {
    setState(() {
      izin.status = StatusIzin.approved;
      izin.diprosesOleh = reviewerRole;
      izin.waktuDiproses = DateTime.now();
      izin.catatanPersetujuan = 'Pengajuan izin telah disetujui secara resmi.';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Izin ${izin.salesName} (${izin.alasan}) BERHASIL DISETUJUI (Approved)!',
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showRejectDialog(IzinAbsen izin, String reviewerRole) {
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cancel, color: Colors.redAccent),
            SizedBox(width: 8),
            Text(
              'Tolak Pengajuan Izin',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Apakah Anda yakin ingin menolak izin dari ${izin.salesName}?',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: noteCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Alasan Penolakan (Catatan)',
                hintText: 'Misal: Dokumen belum lengkap atau kuota jadwal...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                izin.status = StatusIzin.rejected;
                izin.diprosesOleh = reviewerRole;
                izin.waktuDiproses = DateTime.now();
                izin.catatanPersetujuan = noteCtrl.text.trim().isNotEmpty
                    ? noteCtrl.text.trim()
                    : 'Pengajuan izin ditolak oleh manajemen.';
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.cancel, color: Colors.white),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Izin ${izin.salesName} TELAH DITOLAK (Rejected).',
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.redAccent,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Tolak Izin', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LOGIKA KIRIM PENGAJUAN BARU OLEH SALES
  // ============================================================
  void _submitIzinSales(String salesName, String salesEmail, String salesPhone) {
    if (!_formKey.currentState!.validate()) return;

    final newIzin = IzinAbsen(
      id: 'IZN-2026-00${_daftarIzin.length + 1}',
      salesName: salesName,
      salesEmail: salesEmail,
      salesPhone: salesPhone,
      alasan: _selectedAlasan,
      tanggalMulai: _startDateCtrl.text.trim(),
      tanggalSelesai: _endDateCtrl.text.trim(),
      durasiHari: 1,
      deskripsi: _deskripsiCtrl.text.trim(),
      tanggalPengajuan: 'Hari ini, Baru saja',
      status: StatusIzin.pending,
    );

    setState(() {
      _daftarIzin.insert(0, newIzin);
      _deskripsiCtrl.clear();
    });

    _salesTabController?.animateTo(1);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pengajuan izin Anda berhasil dikirim ke Admin & Owner!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    // Menentukan role pengguna
    final isOwner = user?.isSuperAdmin ?? false;
    final isAdmin = user?.isAdmin ?? false;
    final isManagement = isOwner || isAdmin; // Admin & Owner melihat "Daftar Izin Sales"

    final reviewerTitle = isOwner
        ? 'Superadmin (Owner)'
        : (isAdmin ? 'Administrator' : 'Manajemen');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: Text(
          isManagement ? 'Daftar Izin Sales' : 'Pengajuan Izin Sales',
          style: const TextStyle(color: kTextColor, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: kTextColor),
        bottom: (!isManagement && _salesTabController != null)
            ? TabBar(
                controller: _salesTabController,
                indicatorColor: kPrimaryColor,
                labelColor: kPrimaryColor,
                unselectedLabelColor: kSecondaryColor,
                tabs: const [
                  Tab(icon: Icon(Icons.edit_document), text: 'Formulir Izin'),
                  Tab(icon: Icon(Icons.history), text: 'Riwayat Saya'),
                ],
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ============================================================
            // CHIP SELECTOR ROLE (UNTUK KEMUDAHAN TESTING DEMO ROLE)
            // ============================================================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.white,
              child: Row(
                children: [
                  const Icon(Icons.visibility, size: 16, color: kSecondaryColor),
                  const SizedBox(width: 6),
                  const Text(
                    'Mode Tampilan:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextColor),
                  ),
                  const Spacer(),
                  Wrap(
                    spacing: 6,
                    children: [
                      ChoiceChip(
                        label: const Text('Owner'),
                        selected: isOwner,
                        selectedColor: const Color(0xFF6A1B9A),
                        labelStyle: TextStyle(
                          color: isOwner ? Colors.white : kTextColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (_) => authProvider.switchRoleDemo('owner'),
                      ),
                      ChoiceChip(
                        label: const Text('Admin'),
                        selected: isAdmin,
                        selectedColor: const Color(0xFF1565C0),
                        labelStyle: TextStyle(
                          color: isAdmin ? Colors.white : kTextColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (_) => authProvider.switchRoleDemo('admin'),
                      ),
                      ChoiceChip(
                        label: const Text('Sales'),
                        selected: !isManagement,
                        selectedColor: const Color(0xFF00796B),
                        labelStyle: TextStyle(
                          color: !isManagement ? Colors.white : kTextColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (_) => authProvider.switchRoleDemo('sales'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Tampilan konten berdasarkan Role
            Expanded(
              child: isManagement
                  ? _buildAdminOwnerView(reviewerTitle)
                  : _buildSalesView(user?.name ?? 'Sales Lapangan', user?.email ?? 'sales@majubersama.com', user?.phone ?? '081234567892'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TAMPILAN ADMIN & OWNER: "DAFTAR IZIN SALES" DENGAN APPROVE & REJECT
  // ============================================================
  Widget _buildAdminOwnerView(String reviewerTitle) {
    final filteredList = _daftarIzin.where((item) {
      if (_filterStatus == 'Menunggu') return item.status == StatusIzin.pending;
      if (_filterStatus == 'Disetujui') return item.status == StatusIzin.approved;
      if (_filterStatus == 'Ditolak') return item.status == StatusIzin.rejected;
      return true;
    }).toList();

    final pendingCount = _daftarIzin.where((i) => i.status == StatusIzin.pending).length;
    final approvedCount = _daftarIzin.where((i) => i.status == StatusIzin.approved).length;
    final rejectedCount = _daftarIzin.where((i) => i.status == StatusIzin.rejected).length;

    return Column(
      children: [
        // Ringkasan Statistik Kartu
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: kPrimaryLightColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.assignment_turned_in, color: kPrimaryColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pusat Verifikasi Izin Sales',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: kTextColor,
                          ),
                        ),
                        Text(
                          'Hak Akses: $reviewerTitle • Persetujuan Absensi',
                          style: const TextStyle(fontSize: 11, color: kSecondaryColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _buildStatBadge('Menunggu', '$pendingCount', const Color(0xFFFB8C00), Colors.orange.shade50),
                  const SizedBox(width: 8),
                  _buildStatBadge('Disetujui', '$approvedCount', const Color(0xFF2E7D32), Colors.green.shade50),
                  const SizedBox(width: 8),
                  _buildStatBadge('Ditolak', '$rejectedCount', const Color(0xFFD32F2F), Colors.red.shade50),
                ],
              ),
            ],
          ),
        ),

        // Filter Chips (Semua, Menunggu, Disetujui, Ditolak)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: ['Semua', 'Menunggu', 'Disetujui', 'Ditolak'].map((tab) {
              final isSelected = _filterStatus == tab;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: FilterChip(
                  label: Text(tab),
                  selected: isSelected,
                  selectedColor: kPrimaryColor,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : kTextColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  backgroundColor: Colors.white,
                  onSelected: (val) {
                    setState(() => _filterStatus = tab);
                  },
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 8),

        // List Izin Absen dari Sales
        Expanded(
          child: filteredList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.inbox_outlined, size: 48, color: kSecondaryColor),
                      SizedBox(height: 10),
                      Text(
                        'Tidak ada data izin sales pada kategori ini.',
                        style: TextStyle(color: kSecondaryColor, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    final item = filteredList[index];
                    return _buildIzinCard(item, reviewerTitle);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStatBadge(String label, String value, Color textColor, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: textColor.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: textColor),
            ),
          ],
        ),
      ),
    );
  }

  // Card Item Izin Sales
  Widget _buildIzinCard(IzinAbsen item, String reviewerTitle) {
    Color statusColor;
    Color statusBgColor;
    String statusText;
    IconData statusIcon;

    switch (item.status) {
      case StatusIzin.pending:
        statusColor = const Color(0xFFFB8C00);
        statusBgColor = const Color(0xFFFFF3E0);
        statusText = 'Menunggu';
        statusIcon = Icons.hourglass_top;
        break;
      case StatusIzin.approved:
        statusColor = const Color(0xFF2E7D32);
        statusBgColor = const Color(0xFFE8F5E9);
        statusText = 'Disetujui (Approved)';
        statusIcon = Icons.check_circle;
        break;
      case StatusIzin.rejected:
        statusColor = const Color(0xFFD32F2F);
        statusBgColor = const Color(0xFFFFEBEE);
        statusText = 'Ditolak (Rejected)';
        statusIcon = Icons.cancel;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Baris Atas: Nama Sales & Badge Status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: kPrimaryLightColor,
                  child: Text(
                    item.salesName.isNotEmpty ? item.salesName[0].toUpperCase() : 'S',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: kPrimaryColor),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.salesName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: kTextColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ID: ${item.id} • ${item.tanggalPengajuan}',
                        style: const TextStyle(fontSize: 11, color: kSecondaryColor),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Informasi Alasan & Rentang Tanggal
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.category_outlined, size: 14, color: kPrimaryColor),
                      const SizedBox(width: 6),
                      Text(
                        item.alasan,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: kTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.date_range, size: 14, color: kPrimaryColor),
                      const SizedBox(width: 6),
                      Text(
                        '${item.tanggalMulai} - ${item.tanggalSelesai}',
                        style: const TextStyle(fontSize: 12, color: kTextColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Deskripsi dari Sales
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                item.deskripsi,
                style: const TextStyle(fontSize: 13, color: kTextColor, height: 1.4),
              ),
            ),

            // Catatan hasil verifikasi jika sudah disetujui / ditolak
            if (item.catatanPersetujuan != null && item.status != StatusIzin.pending) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(statusIcon, size: 16, color: statusColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${item.catatanPersetujuan!} (Oleh: ${item.diprosesOleh ?? reviewerTitle})',
                        style: TextStyle(
                          fontSize: 12,
                          color: statusColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),

            // ============================================================
            // TOMBOL APPROVE & REJECT
            // ============================================================
            if (item.status == StatusIzin.pending) ...[
              Row(
                children: [
                  // Button Reject (Tolak)
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFD32F2F),
                          side: const BorderSide(color: Color(0xFFD32F2F), width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => _showRejectDialog(item, reviewerTitle),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text(
                          'Reject',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Button Approve (Setujui)
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => _approveIzin(item, reviewerTitle),
                        icon: const Icon(Icons.check, color: Colors.white, size: 18),
                        label: const Text(
                          'Approve',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Opsi Ubah Keputusan jika diperlukan revisi oleh Admin/Owner
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: kPrimaryColor),
                  onPressed: () {
                    setState(() {
                      item.status = StatusIzin.pending;
                      item.catatanPersetujuan = null;
                      item.diprosesOleh = null;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Status izin ${item.salesName} dikembalikan ke Menunggu.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.restart_alt, size: 16),
                  label: const Text('Revisi / Ubah Keputusan', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TAMPILAN ROLE SALES: FORMULIR INPUT PENGAJUAN & RIWAYAT SAYA
  // ============================================================
  Widget _buildSalesView(String salesName, String salesEmail, String salesPhone) {
    if (_salesTabController == null) return const SizedBox();

    return TabBarView(
      controller: _salesTabController,
      children: [
        // Tab 1: Formulir Pengajuan Izin
        SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Banner Sales
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFF00796B),
                        radius: 18,
                        child: Icon(Icons.badge, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pengaju: $salesName',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              salesEmail,
                              style: const TextStyle(fontSize: 11, color: kSecondaryColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                const Text('Alasan Izin Absen', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  value: _selectedAlasan,
                  items: [
                    'Sakit',
                    'Cuti Tahunan',
                    'Izin Urusan Keluarga',
                    'Kendala Operasional / Rute',
                  ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedAlasan = val);
                  },
                ),
                const SizedBox(height: 16),

                // Rentang Tanggal
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Tanggal Mulai', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _startDateCtrl,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.calendar_today, size: 18, color: kPrimaryColor),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Tanggal Selesai', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _endDateCtrl,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.event, size: 18, color: kPrimaryColor),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                const Text('Deskripsi & Keterangan Lengkap', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _deskripsiCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Tuliskan alasan lengkap ketidakhadiran Anda...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Keterangan izin wajib diisi' : null,
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => _submitIzinSales(salesName, salesEmail, salesPhone),
                    icon: const Icon(Icons.send, color: Colors.white, size: 18),
                    label: const Text(
                      'Kirim Pengajuan Izin',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Tab 2: Riwayat Pengajuan Saya
        ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _daftarIzin.length,
          itemBuilder: (context, index) {
            final item = _daftarIzin[index];
            return _buildIzinCard(item, 'Manajemen');
          },
        ),
      ],
    );
  }
}
