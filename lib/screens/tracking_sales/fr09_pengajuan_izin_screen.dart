import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/user_avatar.dart';
import 'home_dashboard_screen.dart';

enum StatusIzin { pending, approved, rejected }

class IzinAbsen {
  final int? dbId;
  final String id;
  final int? salesId;
  final String salesName;
  final String salesEmail;
  final String salesPhone;
  final String? salesPhotoUrl;
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
    this.dbId,
    required this.id,
    this.salesId,
    required this.salesName,
    required this.salesEmail,
    required this.salesPhone,
    this.salesPhotoUrl,
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

  static StatusIzin parseStatus(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'disetujui':
      case 'approved':
        return StatusIzin.approved;
      case 'ditolak':
      case 'rejected':
        return StatusIzin.rejected;
      default:
        return StatusIzin.pending;
    }
  }

  static String statusToApi(StatusIzin s) {
    switch (s) {
      case StatusIzin.approved:
        return 'disetujui';
      case StatusIzin.rejected:
        return 'ditolak';
      case StatusIzin.pending:
        return 'menunggu';
    }
  }

  static String formatReadableDate(String rawDate) {
    final trimmed = rawDate.trim();
    final parts = trimmed.split('-');
    if (parts.length == 3) {
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y != null && m != null && d != null && m >= 1 && m <= 12) {
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
        return '$d ${months[m - 1]} $y';
      }
    }
    return trimmed;
  }

  static String formatTimestamp(String? isoStr) {
    if (isoStr == null || isoStr.isEmpty) return 'Baru saja';
    final dt = DateTime.tryParse(isoStr)?.toLocal();
    if (dt == null) return isoStr;
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
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $hh:$mm WIB';
  }

  factory IzinAbsen.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final int? numericId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    final kodeIzin = json['kode_izin']?.toString() ??
        (numericId != null ? 'IZN-2026-${numericId.toString().padLeft(3, '0')}' : rawId?.toString() ?? 'IZN-2026-001');

    return IzinAbsen(
      dbId: numericId,
      id: kodeIzin,
      salesId: json['sales_id'] is int
          ? json['sales_id'] as int
          : int.tryParse(json['sales_id']?.toString() ?? ''),
      salesName: json['sales_name']?.toString() ?? 'Sales Lapangan',
      salesEmail: json['sales_email']?.toString() ?? '',
      salesPhone: json['sales_phone']?.toString() ?? '',
      salesPhotoUrl: json['sales_photo_url']?.toString(),
      alasan: json['kategori_izin']?.toString() ?? json['alasan_kategori']?.toString() ?? 'Izin',
      tanggalMulai: formatReadableDate(json['tanggal_mulai']?.toString() ?? ''),
      tanggalSelesai: formatReadableDate(json['tanggal_selesai']?.toString() ?? ''),
      durasiHari: int.tryParse(json['jumlah_hari']?.toString() ?? '1') ?? 1,
      deskripsi: json['alasan']?.toString() ?? json['deskripsi']?.toString() ?? '',
      tanggalPengajuan: json['tanggal_pengajuan']?.toString() ??
          formatTimestamp(json['created_at']?.toString()),
      status: parseStatus(json['status']?.toString()),
      catatanPersetujuan: json['catatan_approver']?.toString(),
      diprosesOleh: json['diproses_oleh']?.toString() ?? json['approver_name']?.toString(),
      waktuDiproses: json['approved_at'] != null
          ? DateTime.tryParse(json['approved_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': dbId,
      'kode_izin': id,
      'sales_id': salesId,
      'sales_name': salesName,
      'sales_email': salesEmail,
      'sales_phone': salesPhone,
      'sales_photo_url': salesPhotoUrl,
      'kategori_izin': alasan,
      'tanggal_mulai': tanggalMulai,
      'tanggal_selesai': tanggalSelesai,
      'jumlah_hari': durasiHari,
      'alasan': deskripsi,
      'tanggal_pengajuan': tanggalPengajuan,
      'status': statusToApi(status),
      'catatan_approver': catatanPersetujuan,
      'diproses_oleh': diprosesOleh,
      'approved_at': waktuDiproses?.toIso8601String(),
    };
  }
}

class FR09PengajuanIzinScreen extends StatefulWidget {
  const FR09PengajuanIzinScreen({Key? key}) : super(key: key);

  @override
  State<FR09PengajuanIzinScreen> createState() => _FR09PengajuanIzinScreenState();
}

class _FR09PengajuanIzinScreenState extends State<FR09PengajuanIzinScreen>
    with SingleTickerProviderStateMixin {
  static const String _localCacheKey = 'leave_requests_cache_v1';

  late List<IzinAbsen> _daftarIzin;
  bool _isLoading = false;
  bool _isSubmitting = false;

  // Filter untuk tampilan Admin/Owner & Riwayat Sales
  String _filterStatus = 'Semua';
  String _salesHistoryFilter = 'Semua';

  void _backToDashboard() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeDashboardScreen()),
      );
    }
  }

  // Controller Form untuk Role Sales
  final _formKey = GlobalKey<FormState>();
  String _selectedAlasan = 'Sakit';
  DateTime _selectedStartDate = DateTime.now();
  DateTime _selectedEndDate = DateTime.now().add(const Duration(days: 1));
  late final TextEditingController _startDateCtrl;
  late final TextEditingController _endDateCtrl;
  final TextEditingController _deskripsiCtrl = TextEditingController();

  TabController? _salesTabController;

  bool get _isTestEnv {
    try {
      final bindingName = WidgetsBinding.instance.runtimeType.toString();
      if (bindingName.contains('Test')) return true;
    } catch (_) {}
    return false;
  }

  static List<IzinAbsen> _defaultInitialList() {
    return [
      IzinAbsen(
        dbId: 1,
        id: 'IZN-2026-001',
        salesId: 3,
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
        dbId: 2,
        id: 'IZN-2026-002',
        salesId: 5,
        salesName: 'Ahmad Hidayat',
        salesEmail: 'ahmad.sales@majubersama.com',
        salesPhone: '081298765432',
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
        dbId: 3,
        id: 'IZN-2026-003',
        salesId: 3,
        salesName: 'Muhammad Ulil Abshor',
        salesEmail: 'sales@majubersama.com',
        salesPhone: '081234567892',
        alasan: 'Kendala Operasional / Rute',
        tanggalMulai: '20 Okt 2026',
        tanggalSelesai: '20 Okt 2026',
        durasiHari: 1,
        deskripsi:
            'Sepeda motor inventaris mengalami kendala mesin saat menuju rute distribusi timur dan harus servis bengkel darurat.',
        tanggalPengajuan: '20 Okt 2026, 07:45 WIB',
        status: StatusIzin.approved,
        diprosesOleh: 'Agung Prasetyo Wibowo • Administrator',
        catatanPersetujuan: 'Disetujui. Surat tanda terima servis telah dikonfirmasi.',
        waktuDiproses: DateTime.now().subtract(const Duration(days: 1)),
      ),
      IzinAbsen(
        dbId: 4,
        id: 'IZN-2026-004',
        salesId: 5,
        salesName: 'Ahmad Hidayat',
        salesEmail: 'ahmad.sales@majubersama.com',
        salesPhone: '081298765432',
        alasan: 'Cuti Tahunan',
        tanggalMulai: '19 Okt 2026',
        tanggalSelesai: '20 Okt 2026',
        durasiHari: 2,
        deskripsi: 'Pengajuan cuti pribadi untuk liburan akhir pekan.',
        tanggalPengajuan: '19 Okt 2026, 06:10 WIB',
        status: StatusIzin.rejected,
        diprosesOleh: 'Dimas Brahamsyah Santosa Putra • Superadmin (Owner)',
        catatanPersetujuan:
            'Ditolak. Permohonan cuti tahunan wajib diajukan minimal H-3 sebelum tanggal pelaksanaan sesuai SOP perusahaan.',
        waktuDiproses: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _salesTabController = TabController(length: 2, vsync: this);
    _startDateCtrl = TextEditingController(text: _formatDateInput(_selectedStartDate));
    _endDateCtrl = TextEditingController(text: _formatDateInput(_selectedEndDate));
    _daftarIzin = _defaultInitialList();
    _loadDaftarIzin();
  }

  @override
  void dispose() {
    _salesTabController?.dispose();
    _startDateCtrl.dispose();
    _endDateCtrl.dispose();
    _deskripsiCtrl.dispose();
    super.dispose();
  }

  String _formatDateInput(DateTime dt) {
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

  String _formatDateIso(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  int get _calculatedDurationDays {
    final diff = _selectedEndDate.difference(_selectedStartDate).inDays + 1;
    return diff < 1 ? 1 : diff;
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _selectedStartDate : _selectedEndDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked == null || !mounted) return;

    setState(() {
      if (isStart) {
        _selectedStartDate = picked;
        _startDateCtrl.text = _formatDateInput(picked);
        if (_selectedEndDate.isBefore(_selectedStartDate)) {
          _selectedEndDate = _selectedStartDate;
          _endDateCtrl.text = _formatDateInput(_selectedEndDate);
        }
      } else {
        _selectedEndDate = picked.isBefore(_selectedStartDate) ? _selectedStartDate : picked;
        _endDateCtrl.text = _formatDateInput(_selectedEndDate);
      }
    });
  }

  // ============================================================
  // SINKRONISASI DATA IZIN DARI BACKEND MYSQL & CACHE LOKAL
  // ============================================================
  Future<void> _saveToLocalCache(List<IzinAbsen> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(list.map((e) => e.toJson()).toList());
      await prefs.setString(_localCacheKey, encoded);
    } catch (_) {}
  }

  Future<void> _loadDaftarIzin() async {
    // 1. Cek cache lokal terlebih dahulu
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString(_localCacheKey);
      if (cachedStr != null && cachedStr.isNotEmpty) {
        final decoded = jsonDecode(cachedStr) as List<dynamic>;
        final cachedList = decoded
            .map((item) => IzinAbsen.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
        if (cachedList.isNotEmpty && mounted) {
          setState(() {
            _daftarIzin = cachedList;
          });
        }
      }
    } catch (_) {}

    if (_isTestEnv) return;

    // 2. Sinkronkan profil user aktif & ambil data terbaru dari backend MySQL db_tracking_sales
    if (mounted) {
      setState(() => _isLoading = true);
      Provider.of<AuthProvider>(context, listen: false).refreshCurrentUser();
    }
    try {
      await AuthService.resolveBaseUrl();
      final response = await http
          .get(
            Uri.parse('${AuthService.activeBaseUrl}/leaves'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final dataList = body['data'] as List<dynamic>? ?? [];
        final fetched = dataList
            .map((item) => IzinAbsen.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
        if (mounted) {
          setState(() {
            _daftarIzin = fetched;
          });
        }
        await _saveToLocalCache(fetched);
      }
    } catch (_) {
      // Tetap gunakan cache lokal jika backend sedang tidak terjangkau
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // LOGIKA PENERIMAAN (APPROVE) & PENOLAKAN (REJECT) OLEH ADMIN / OWNER
  // ============================================================
  void _showStatusDecisionPopup(IzinAbsen izin) {
    final bool isApproved = izin.status == StatusIzin.approved;
    final bool isRejected = izin.status == StatusIzin.rejected;
    final Color statusColor = isApproved
        ? const Color(0xFF2E7D32)
        : (isRejected ? const Color(0xFFD32F2F) : const Color(0xFFFB8C00));
    final Color statusBgColor = isApproved
        ? const Color(0xFFE8F5E9)
        : (isRejected ? const Color(0xFFFFEBEE) : const Color(0xFFFFF3E0));
    final String statusText = isApproved
        ? 'Disetujui (Approved)'
        : (isRejected ? 'Ditolak (Rejected)' : 'Menunggu');
    final IconData statusIcon = isApproved
        ? Icons.check_circle_rounded
        : (isRejected ? Icons.cancel_rounded : Icons.hourglass_top_rounded);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
        title: Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isApproved
                    ? 'Izin Sales Disetujui'
                    : (isRejected ? 'Izin Sales Ditolak' : 'Detail Pengajuan Izin'),
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusBgColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, size: 15, color: statusColor),
                  const SizedBox(width: 6),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Nama Sales: ${izin.salesName}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kTextColor),
            ),
            const SizedBox(height: 4),
            Text(
              'Kategori: ${izin.alasan}',
              style: const TextStyle(fontSize: 13, color: kTextColor),
            ),
            const SizedBox(height: 4),
            Text(
              'Tanggal: ${izin.tanggalMulai} - ${izin.tanggalSelesai} (${izin.durasiHari} Hari)',
              style: const TextStyle(fontSize: 12.5, color: kSecondaryColor),
            ),
            if (izin.catatanPersetujuan != null && izin.catatanPersetujuan!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${izin.catatanPersetujuan!} (Oleh: ${izin.diprosesOleh ?? '-'})',
                  style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: statusColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _approveIzin(IzinAbsen izin, String reviewerTitle) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
    final reviewerDisplay = currentUser != null && currentUser.name.isNotEmpty
        ? '${currentUser.name} • $reviewerTitle'
        : reviewerTitle;

    setState(() {
      izin.status = StatusIzin.approved;
      izin.diprosesOleh = reviewerDisplay;
      izin.waktuDiproses = DateTime.now();
      izin.catatanPersetujuan = 'Pengajuan izin telah disetujui secara resmi.';
      // Otomatis pindah dari Semua/Menunggu langsung ke menu Disetujui
      _filterStatus = 'Disetujui';
    });
    await _saveToLocalCache(_daftarIzin);

    if (!_isTestEnv && izin.dbId != null) {
      try {
        final response = await http
            .put(
              Uri.parse('${AuthService.activeBaseUrl}/leaves/${izin.dbId}/status'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode({
                'status': 'disetujui',
                'catatan_approver': izin.catatanPersetujuan,
                'reviewer_id': currentUser?.id,
                'reviewer_email': currentUser?.email,
              }),
            )
            .timeout(const Duration(seconds: 6));

        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          if (body['data'] != null && mounted) {
            final updated = IzinAbsen.fromJson(Map<String, dynamic>.from(body['data']));
            setState(() {
              izin.diprosesOleh = updated.diprosesOleh ?? reviewerDisplay;
              izin.catatanPersetujuan = updated.catatanPersetujuan;
            });
            await _saveToLocalCache(_daftarIzin);
          }
        }
      } catch (_) {}
    }

    if (!mounted) return;
    _showStatusDecisionPopup(izin);
  }

  void _showRejectDialog(IzinAbsen izin, String reviewerTitle) {
    final noteCtrl = TextEditingController();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
    final reviewerDisplay = currentUser != null && currentUser.name.isNotEmpty
        ? '${currentUser.name} • $reviewerTitle'
        : reviewerTitle;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cancel, color: Colors.redAccent),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Tolak Pengajuan Izin',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextColor),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Apakah Anda yakin ingin menolak izin dari ${izin.salesName}?',
              style: const TextStyle(fontSize: 14, color: kTextColor),
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
            child: const Text('Batal', style: TextStyle(color: kSecondaryColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final rejectNote = noteCtrl.text.trim().isNotEmpty
                  ? noteCtrl.text.trim()
                  : 'Pengajuan izin ditolak oleh manajemen.';

              setState(() {
                izin.status = StatusIzin.rejected;
                izin.diprosesOleh = reviewerDisplay;
                izin.waktuDiproses = DateTime.now();
                izin.catatanPersetujuan = rejectNote;
                // Otomatis pindah dari Semua/Menunggu langsung ke menu Ditolak
                _filterStatus = 'Ditolak';
              });
              await _saveToLocalCache(_daftarIzin);

              if (!_isTestEnv && izin.dbId != null) {
                try {
                  await http
                      .put(
                        Uri.parse('${AuthService.activeBaseUrl}/leaves/${izin.dbId}/status'),
                        headers: {
                          'Content-Type': 'application/json',
                          'Accept': 'application/json',
                        },
                        body: jsonEncode({
                          'status': 'ditolak',
                          'catatan_approver': rejectNote,
                          'reviewer_id': currentUser?.id,
                          'reviewer_email': currentUser?.email,
                        }),
                      )
                      .timeout(const Duration(seconds: 6));
                } catch (_) {}
              }

              if (!mounted) return;
              _showStatusDecisionPopup(izin);
            },
            child: const Text('Tolak Izin', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _revisiIzin(IzinAbsen item) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;

    setState(() {
      item.status = StatusIzin.pending;
      item.catatanPersetujuan = null;
      item.diprosesOleh = null;
      // Otomatis pindah kembali ke menu Menunggu
      _filterStatus = 'Menunggu';
    });
    await _saveToLocalCache(_daftarIzin);

    if (!_isTestEnv && item.dbId != null) {
      try {
        await http
            .put(
              Uri.parse('${AuthService.activeBaseUrl}/leaves/${item.dbId}/status'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode({
                'status': 'menunggu',
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
        content: Text('Status izin ${item.salesName} dikembalikan ke Menunggu.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // LOGIKA KIRIM PENGAJUAN BARU OLEH SALES
  // ============================================================
  Future<void> _submitIzinSales(
    int? salesId,
    String salesName,
    String salesEmail,
    String salesPhone,
    String? salesPhotoUrl,
  ) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final startText = _startDateCtrl.text.trim();
    final endText = _endDateCtrl.text.trim();
    final deskripsiText = _deskripsiCtrl.text.trim();
    final durasi = _calculatedDurationDays;

    IzinAbsen newIzin = IzinAbsen(
      id: 'IZN-2026-${(_daftarIzin.length + 1).toString().padLeft(3, '0')}',
      salesId: salesId,
      salesName: salesName,
      salesEmail: salesEmail,
      salesPhone: salesPhone,
      salesPhotoUrl: salesPhotoUrl,
      alasan: _selectedAlasan,
      tanggalMulai: startText,
      tanggalSelesai: endText,
      durasiHari: durasi,
      deskripsi: deskripsiText,
      tanggalPengajuan: IzinAbsen.formatTimestamp(DateTime.now().toIso8601String()),
      status: StatusIzin.pending,
    );

    if (!_isTestEnv) {
      try {
        final response = await http
            .post(
              Uri.parse('${AuthService.activeBaseUrl}/leaves'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode({
                'sales_id': salesId,
                'sales_email': salesEmail,
                'kategori_izin': _selectedAlasan,
                'tanggal_mulai': _formatDateIso(_selectedStartDate),
                'tanggal_selesai': _formatDateIso(_selectedEndDate),
                'jumlah_hari': durasi,
                'alasan': deskripsiText,
              }),
            )
            .timeout(const Duration(seconds: 6));

        if (response.statusCode == 201 || response.statusCode == 200) {
          final body = jsonDecode(response.body);
          if (body['data'] != null) {
            newIzin = IzinAbsen.fromJson(Map<String, dynamic>.from(body['data']));
          }
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _daftarIzin.insert(0, newIzin);
      _deskripsiCtrl.clear();
      _isSubmitting = false;
    });

    await _saveToLocalCache(_daftarIzin);
    _salesTabController?.animateTo(1);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 10),
            Expanded(
              child: Text('Pengajuan izin Anda berhasil dikirim ke Admin & Owner!'),
            ),
          ],
        ),
        backgroundColor: Color(0xFF047857),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    // Menentukan role pengguna secara otomatis dari sesi login aktif
    final isOwner = user?.isSuperAdmin ?? false;
    final isAdmin = user?.isAdmin ?? false;
    final isManagement = isOwner || isAdmin; // Admin & Owner melihat "Daftar Izin Sales"

    final reviewerTitle = isOwner
        ? 'Superadmin (Owner)'
        : (isAdmin ? 'Administrator' : 'Manajemen');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: kTextColor),
          tooltip: 'Kembali ke Dashboard',
          onPressed: _backToDashboard,
        ),
        title: Text(
          isManagement ? 'Daftar Izin Sales' : 'Pengajuan Izin Sales',
          style: const TextStyle(color: kTextColor, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: kTextColor),
        actions: [
          IconButton(
            tooltip: 'Muat Ulang Data Izin',
            onPressed: _isLoading ? null : _loadDaftarIzin,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: kPrimaryColor),
                  )
                : const Icon(Icons.refresh_rounded, color: kTextColor),
          ),
        ],
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
        child: isManagement
            ? _buildAdminOwnerView(reviewerTitle)
            : _buildSalesView(
                user?.id,
                user?.name ?? 'Sales Lapangan',
                user?.email ?? 'sales@majubersama.com',
                user?.phone ?? '081234567892',
                user?.photoUrl,
              ),
      ),
    );
  }

  // ============================================================
  // TAMPILAN ADMIN & OWNER: "DAFTAR IZIN SALES" DENGAN APPROVE & REJECT
  // ============================================================
  Widget _buildAdminOwnerView(String reviewerTitle) {
    final filteredList = _daftarIzin.where((item) {
      // Pada menu Semua dan Menunggu, hanya tampilkan yang belum di-acc/ditolak (masih menunggu).
      // Begitu sudah di-acc atau ditolak, item langsung keluar dari Semua dan masuk ke Disetujui/Ditolak.
      if (_filterStatus == 'Semua' || _filterStatus == 'Menunggu') {
        return item.status == StatusIzin.pending;
      }
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
                color: Colors.black.withValues(alpha: 0.04),
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
                          'Hak Akses: $reviewerTitle • Penerimaan & Verifikasi Izin',
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
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
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
                    return _buildIzinCard(item, reviewerTitle, canVerify: true);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStatBadge(String label, String value, Color textColor, Color bgColor) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _filterStatus = label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: textColor.withValues(alpha: 0.3)),
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
      ),
    );
  }

  // Card Item Izin Sales
  Widget _buildIzinCard(IzinAbsen item, String reviewerTitle, {required bool canVerify}) {
    final currentUser = context.watch<AuthProvider>().currentUser;
    final isCurrentUserItem = currentUser != null &&
        ((item.salesId != null && item.salesId == currentUser.id) ||
            (item.salesEmail.isNotEmpty &&
                item.salesEmail.toLowerCase() == currentUser.email.toLowerCase()));
    final rawItemPhoto = item.salesPhotoUrl;
    final rawUserPhoto = currentUser?.photoUrl;
    final resolvedPhotoUrl = (rawItemPhoto != null &&
            rawItemPhoto.isNotEmpty &&
            !rawItemPhoto.startsWith('preset:'))
        ? rawItemPhoto
        : (isCurrentUserItem &&
                rawUserPhoto != null &&
                rawUserPhoto.isNotEmpty &&
                !rawUserPhoto.startsWith('preset:')
            ? rawUserPhoto
            : null);

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
            color: Colors.black.withValues(alpha: 0.04),
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
                UserAvatar(
                  photoUrl: resolvedPhotoUrl,
                  name: item.salesName,
                  radius: 20,
                  backgroundColor: kPrimaryLightColor,
                  textColor: kPrimaryColor,
                  fontSize: 15,
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
                    border: Border.all(color: statusColor.withValues(alpha: 0.5)),
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
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
                        '${item.tanggalMulai} - ${item.tanggalSelesai} (${item.durasiHari} Hari)',
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

            // ============================================================
            // TOMBOL PENERIMAAN (APPROVE) & PENOLAKAN (REJECT) KHUSUS ADMIN & OWNER
            // ============================================================
            if (canVerify) ...[
              const SizedBox(height: 14),
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
                    // Button Approve (Terima / Setujui)
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
                    onPressed: () => _revisiIzin(item),
                    icon: const Icon(Icons.restart_alt, size: 16),
                    label: const Text('Revisi / Ubah Keputusan', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ] else if (item.status == StatusIzin.pending) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFFB45309)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Menunggu penerimaan / verifikasi dari Admin atau Owner.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFFB45309),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
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
  Widget _buildSalesView(
    int? salesId,
    String salesName,
    String salesEmail,
    String salesPhone,
    String? salesPhotoUrl,
  ) {
    if (_salesTabController == null) return const SizedBox();

    // Filter riwayat milik sales yang sedang login (atau tampilkan semua jika cocok)
    final myIzinList = _daftarIzin.where((item) {
      if (salesId != null && item.salesId != null && item.salesId == salesId) {
        return true;
      }
      if (salesEmail.isNotEmpty &&
          item.salesEmail.toLowerCase() == salesEmail.toLowerCase()) {
        return true;
      }
      if (item.salesName.toLowerCase() == salesName.toLowerCase()) {
        return true;
      }
      return false;
    }).toList();

    final historyList = myIzinList.isNotEmpty ? myIzinList : _daftarIzin;

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
                      UserAvatar(
                        photoUrl: salesPhotoUrl,
                        name: salesName,
                        radius: 20,
                        backgroundColor: const Color(0xFF00796B),
                        textColor: Colors.white,
                        fontSize: 15,
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.teal.shade200),
                        ),
                        child: Text(
                          '$_calculatedDurationDays Hari',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00796B),
                          ),
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
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  initialValue: _selectedAlasan,
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

                // Rentang Tanggal (Responsif sesuai lebar layar)
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 340) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Tanggal Mulai', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _startDateCtrl,
                            readOnly: true,
                            onTap: () => _pickDate(isStart: true),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              prefixIcon: const Icon(Icons.calendar_today, size: 18, color: kPrimaryColor),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                          ),
                          const SizedBox(height: 12),
                          const Text('Tanggal Selesai', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _endDateCtrl,
                            readOnly: true,
                            onTap: () => _pickDate(isStart: false),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              prefixIcon: const Icon(Icons.event, size: 18, color: kPrimaryColor),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Tanggal Mulai', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _startDateCtrl,
                                readOnly: true,
                                style: const TextStyle(fontSize: 13),
                                onTap: () => _pickDate(isStart: true),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                  prefixIcon: const Icon(Icons.calendar_today, size: 17, color: kPrimaryColor),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                ),
                                validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Tanggal Selesai', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _endDateCtrl,
                                readOnly: true,
                                style: const TextStyle(fontSize: 13),
                                onTap: () => _pickDate(isStart: false),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                  prefixIcon: const Icon(Icons.event, size: 17, color: kPrimaryColor),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                ),
                                validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                const Text('Deskripsi & Keterangan Lengkap', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _deskripsiCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
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
                    onPressed: _isSubmitting
                        ? null
                        : () => _submitIzinSales(
                              salesId,
                              salesName,
                              salesEmail,
                              salesPhone,
                              salesPhotoUrl,
                            ),
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send, color: Colors.white, size: 18),
                    label: Text(
                      _isSubmitting ? 'Mengirim Pengajuan...' : 'Kirim Pengajuan Izin',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Tab 2: Riwayat Pengajuan Saya
        Column(
          children: [
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: ['Semua', 'Menunggu', 'Disetujui', 'Ditolak'].map((tab) {
                  final isSelected = _salesHistoryFilter == tab;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(tab),
                      selected: isSelected,
                      selectedColor: const Color(0xFF047857),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : kTextColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      backgroundColor: Colors.white,
                      onSelected: (_) {
                        setState(() => _salesHistoryFilter = tab);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Builder(
                builder: (context) {
                  final filteredSalesHistory = historyList.where((item) {
                    if (_salesHistoryFilter == 'Semua' || _salesHistoryFilter == 'Menunggu') {
                      return item.status == StatusIzin.pending;
                    }
                    if (_salesHistoryFilter == 'Disetujui') {
                      return item.status == StatusIzin.approved;
                    }
                    if (_salesHistoryFilter == 'Ditolak') {
                      return item.status == StatusIzin.rejected;
                    }
                    return true;
                  }).toList();

                  if (filteredSalesHistory.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history_edu_outlined, size: 48, color: kSecondaryColor),
                          SizedBox(height: 10),
                          Text(
                            'Belum ada data pengajuan izin pada kategori ini.',
                            style: TextStyle(color: kSecondaryColor, fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredSalesHistory.length,
                    itemBuilder: (context, index) {
                      final item = filteredSalesHistory[index];
                      return _buildIzinCard(item, 'Manajemen', canVerify: false);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
