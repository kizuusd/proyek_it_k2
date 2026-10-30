import 'package:flutter/material.dart';
import '../../constants.dart';

class _PengajuanIzin {
  final String id;
  final String jenisIzin;
  final String alasan;
  final DateTime tanggalMulai;
  final DateTime tanggalSelesai;
  final DateTime tanggalDibuat;
  final String deskripsi;
  final String status;

  _PengajuanIzin({
    required this.id,
    required this.jenisIzin,
    required this.alasan,
    required this.tanggalMulai,
    required this.tanggalSelesai,
    required this.tanggalDibuat,
    required this.deskripsi,
    this.status = 'Menunggu',
  });

  int get durasiHari => tanggalSelesai.difference(tanggalMulai).inDays + 1;
}

class FR09PengajuanIzinScreen extends StatefulWidget {
  const FR09PengajuanIzinScreen({Key? key}) : super(key: key);

  @override
  State<FR09PengajuanIzinScreen> createState() =>
      _FR09PengajuanIzinScreenState();
}

class _FR09PengajuanIzinScreenState extends State<FR09PengajuanIzinScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  String _jenisIzin = 'Tidak Masuk';
  String _alasan = 'Sakit';
  DateTime? _tanggalMulai;
  DateTime? _tanggalSelesai;
  final TextEditingController _deskripsiController = TextEditingController();
  bool _isSubmitting = false;
  late AnimationController _headerAnim;
  late Animation<double> _headerFade;
  final DateTime _tanggalDibuat = DateTime.now();

  final List<_PengajuanIzin> _riwayat = [
    _PengajuanIzin(
      id: 'IZN-001',
      jenisIzin: 'Tidak Masuk',
      alasan: 'Sakit',
      tanggalMulai: DateTime(2026, 10, 20),
      tanggalSelesai: DateTime(2026, 10, 21),
      tanggalDibuat: DateTime(2026, 10, 19, 9, 30),
      deskripsi: 'Demam dan tidak enak badan.',
      status: 'Disetujui',
    ),
    _PengajuanIzin(
      id: 'IZN-002',
      jenisIzin: 'Kepentingan Lain',
      alasan: 'Urusan Keluarga',
      tanggalMulai: DateTime(2026, 10, 25),
      tanggalSelesai: DateTime(2026, 10, 25),
      tanggalDibuat: DateTime(2026, 10, 24, 14, 0),
      deskripsi: 'Menghadiri acara pernikahan saudara.',
      status: 'Menunggu',
    ),
    _PengajuanIzin(
      id: 'IZN-003',
      jenisIzin: 'Tidak Masuk',
      alasan: 'Cuti Tahunan',
      tanggalMulai: DateTime(2026, 11, 3),
      tanggalSelesai: DateTime(2026, 11, 5),
      tanggalDibuat: DateTime(2026, 10, 28, 8, 15),
      deskripsi: 'Liburan akhir tahun bersama keluarga.',
      status: 'Ditolak',
    ),
  ];

  static const Map<String, List<String>> _alasanPerJenis = {
    'Tidak Masuk': [
      'Sakit',
      'Cuti Tahunan',
      'Cuti Bersama',
      'Izin Dokter',
      'Kecelakaan / Musibah',
    ],
    'Kepentingan Lain': [
      'Urusan Keluarga',
      'Acara Pernikahan / Hajatan',
      'Dinas Luar Kota',
      'Pelatihan / Training',
      'Keperluan Pribadi Mendesak',
    ],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _headerAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _headerFade =
        CurvedAnimation(parent: _headerAnim, curve: Curves.easeOut);
    _headerAnim.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _headerAnim.dispose();
    _deskripsiController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? dt, {bool withTime = false}) {
    if (dt == null) return 'Belum dipilih';
    const List<String> bulan = [
      '',
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
      'Des',
    ];
    final base = '${dt.day} ${bulan[dt.month]} ${dt.year}';
    if (!withTime) return base;
    final jam = dt.hour.toString().padLeft(2, '0');
    final menit = dt.minute.toString().padLeft(2, '0');
    return '$base, $jam:$menit';
  }

  Future<void> _pickTanggalMulai() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggalMulai ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: now.add(const Duration(days: 180)),
      helpText: 'PILIH TANGGAL MULAI IZIN',
      cancelText: 'Batal',
      confirmText: 'Pilih',
      builder: _datePickerTheme,
    );
    if (picked != null) {
      setState(() {
        _tanggalMulai = picked;
        if (_tanggalSelesai != null &&
            _tanggalSelesai!.isBefore(picked)) {
          _tanggalSelesai = picked;
        }
      });
    }
  }

  Future<void> _pickTanggalSelesai() async {
    if (_tanggalMulai == null) {
      _showSnack('Harap pilih tanggal mulai terlebih dahulu.',
          isError: true);
      return;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggalSelesai ?? _tanggalMulai!,
      firstDate: _tanggalMulai!,
      lastDate: _tanggalMulai!.add(const Duration(days: 180)),
      helpText: 'PILIH TANGGAL SELESAI IZIN',
      cancelText: 'Batal',
      confirmText: 'Pilih',
      builder: _datePickerTheme,
    );
    if (picked != null) setState(() => _tanggalSelesai = picked);
  }

  Widget _datePickerTheme(BuildContext ctx, Widget? child) {
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
  }

  bool _validasi() {
    if (_tanggalMulai == null) {
      _showSnack('Harap pilih tanggal mulai izin.', isError: true);
      return false;
    }
    if (_tanggalSelesai == null) {
      _showSnack('Harap pilih tanggal selesai izin.', isError: true);
      return false;
    }
    if (_deskripsiController.text.trim().isEmpty) {
      _showSnack('Harap isi deskripsi / keterangan izin.',
          isError: true);
      return false;
    }
    return true;
  }

  Future<void> _kirimPengajuan() async {
    if (!_validasi()) return;
    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final newEntry = _PengajuanIzin(
      id: 'IZN-${(_riwayat.length + 1).toString().padLeft(3, '0')}',
      jenisIzin: _jenisIzin,
      alasan: _alasan,
      tanggalMulai: _tanggalMulai!,
      tanggalSelesai: _tanggalSelesai!,
      tanggalDibuat: _tanggalDibuat,
      deskripsi: _deskripsiController.text.trim(),
    );
    setState(() {
      _isSubmitting = false;
      _riwayat.insert(0, newEntry);
    });
    _showSuksesDialog(newEntry);
  }

  void _resetForm() {
    setState(() {
      _jenisIzin = 'Tidak Masuk';
      _alasan = 'Sakit';
      _tanggalMulai = null;
      _tanggalSelesai = null;
      _deskripsiController.clear();
    });
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(
            isError
                ? Icons.error_outline
                : Icons.check_circle_outline,
            color: Colors.white,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(msg)),
        ]),
        backgroundColor: isError ? kDangerColor : kSuccessColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuksesDialog(_PengajuanIzin izin) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: kSuccessColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle,
                  color: kSuccessColor, size: 50),
            ),
            const SizedBox(height: 20),
            const Text(
              'Pengajuan Terkirim!',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: kTextColor),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pengajuan izin Anda telah dikirim ke Supervisor dan sedang menunggu persetujuan.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: kSubtitleColor, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kPrimaryLightColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(children: [
                _buildInfoRow(Icons.badge_outlined, 'ID Pengajuan',
                    izin.id, kAccentColor),
                const Divider(height: 16),
                _buildInfoRow(Icons.category_outlined, 'Jenis Izin',
                    izin.jenisIzin, kPrimaryColor),
                const Divider(height: 16),
                _buildInfoRow(
                  Icons.calendar_month_rounded,
                  'Durasi',
                  '${_formatDate(izin.tanggalMulai)} - ${_formatDate(izin.tanggalSelesai)} (${izin.durasiHari} hari)',
                  kWarningColor,
                ),
                const Divider(height: 16),
                _buildInfoRow(
                  Icons.access_time_rounded,
                  'Dibuat',
                  _formatDate(izin.tanggalDibuat, withTime: true),
                  kSubtitleColor,
                ),
              ]),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: kPrimaryColor),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _resetForm();
                  },
                  child: const Text('Buat Lagi',
                      style: TextStyle(
                          color: kPrimaryColor,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _tabController.animateTo(1);
                  },
                  child: const Text('Lihat Riwayat',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
      IconData icon, String label, String value, Color color) {
    return Row(children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 10,
                      color: kSubtitleColor,
                      fontWeight: FontWeight.w500)),
              Text(value,
                  style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.bold)),
            ]),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _headerFade,
        child: Column(children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: kAccentColor,
              unselectedLabelColor: kSubtitleColor,
              indicatorColor: kAccentColor,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14),
              tabs: const [
                Tab(text: 'Buat Izin'),
                Tab(text: 'Riwayat Izin'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildFormTab(), _buildRiwayatTab()],
            ),
          ),
        ]),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text(
        'Pengajuan Izin',
        style: TextStyle(
            color: kTextColor,
            fontWeight: FontWeight.bold,
            fontSize: 18),
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      iconTheme: const IconThemeData(color: kTextColor),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child:
            Container(color: const Color(0xFFE5E7EB), height: 1),
      ),
    );
  }

  Widget _buildFormTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 40),
      child: Form(
        key: _formKey,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderBanner(),
              _buildTanggalDibuat(),
              _buildSectionTitle('Jenis & Alasan Izin'),
              _buildJenisIzinSelector(),
              _buildSectionTitle('Rentang Tanggal Izin'),
              _buildRentangTanggal(),
              _buildSectionTitle('Keterangan / Deskripsi'),
              _buildDeskripsiField(),
              _buildSubmitButton(),
            ]),
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
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.assignment_late_rounded,
              color: Colors.white, size: 32),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Form Pengajuan Izin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Ajukan izin tidak masuk atau kepentingan lain kepada Supervisor untuk disetujui.',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.4),
                ),
              ]),
        ),
      ]),
    );
  }

  Widget _buildTanggalDibuat() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kWarningColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: kWarningColor.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.access_time_rounded,
            color: kWarningColor, size: 20),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
            'Tanggal Pengajuan Dibuat',
            style: TextStyle(
              fontSize: 11,
              color: kWarningColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            _formatDate(_tanggalDibuat, withTime: true),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: kTextColor,
            ),
          ),
        ]),
        const Spacer(),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: kWarningColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Otomatis',
            style: TextStyle(
                fontSize: 10,
                color: kWarningColor,
                fontWeight: FontWeight.bold),
          ),
        ),
      ]),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(children: [
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
      ]),
    );
  }

  Widget _buildJenisIzinSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              _buildJenisPill(
                label: 'Tidak Masuk',
                icon: Icons.person_off_rounded,
                isSelected: _jenisIzin == 'Tidak Masuk',
                color: kDangerColor,
                onTap: () => setState(() {
                  _jenisIzin = 'Tidak Masuk';
                  _alasan =
                      _alasanPerJenis['Tidak Masuk']!.first;
                }),
              ),
              const SizedBox(width: 12),
              _buildJenisPill(
                label: 'Kepentingan Lain',
                icon: Icons.event_note_rounded,
                isSelected: _jenisIzin == 'Kepentingan Lain',
                color: kAccentColor,
                onTap: () => setState(() {
                  _jenisIzin = 'Kepentingan Lain';
                  _alasan =
                      _alasanPerJenis['Kepentingan Lain']!.first;
                }),
              ),
            ]),
            const SizedBox(height: 14),
            const Text('Pilih Alasan',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kSubtitleColor)),
            const SizedBox(height: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                    color: const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _alasan,
                  isExpanded: true,
                  icon: const Icon(Icons.expand_more_rounded,
                      color: kPrimaryColor),
                  style: const TextStyle(
                      color: kTextColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _alasan = val);
                    }
                  },
                  items:
                      (_alasanPerJenis[_jenisIzin] ?? [])
                          .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e,
                                  style: const TextStyle(
                                      fontSize: 13))))
                          .toList(),
                ),
              ),
            ),
          ]),
    );
  }

  Widget _buildJenisPill({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? color
                  : const Color(0xFFE5E7EB),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [
                    BoxShadow(
                      color:
                          Colors.grey.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Column(children: [
            Icon(icon,
                size: 26,
                color: isSelected ? Colors.white : color),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : kTextColor,
              ),
              textAlign: TextAlign.center,
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildRentangTanggal() {
    final durasiHari =
        (_tanggalMulai != null && _tanggalSelesai != null)
            ? _tanggalSelesai!
                    .difference(_tanggalMulai!)
                    .inDays +
                1
            : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: _buildDatePickerCard(
              label: 'Tanggal Mulai',
              date: _tanggalMulai,
              icon: Icons.calendar_today_rounded,
              color: kAccentColor,
              onTap: _pickTanggalMulai,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Icon(Icons.arrow_forward_rounded,
                color: kSubtitleColor, size: 20),
          ),
          Expanded(
            child: _buildDatePickerCard(
              label: 'Tanggal Selesai',
              date: _tanggalSelesai,
              icon: Icons.event_available_rounded,
              color: kSuccessColor,
              onTap: _pickTanggalSelesai,
            ),
          ),
        ]),
        if (durasiHari > 0) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: kAccentColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.schedule_rounded,
                      size: 16, color: kAccentColor),
                  const SizedBox(width: 6),
                  Text(
                    'Total Izin: $durasiHari hari kerja',
                    style: const TextStyle(
                      fontSize: 13,
                      color: kAccentColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ]),
          ),
        ],
      ]),
    );
  }

  Widget _buildDatePickerCard({
    required String label,
    required DateTime? date,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final bool sudahPilih = date != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: sudahPilih
                ? color
                : const Color(0xFFE5E7EB),
            width: sudahPilih ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: sudahPilih
                  ? color.withValues(alpha: 0.15)
                  : Colors.grey.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon,
                    size: 18,
                    color:
                        sudahPilih ? color : kSubtitleColor),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: sudahPilih
                          ? color
                          : kSubtitleColor,
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Text(
                sudahPilih
                    ? _formatDate(date)
                    : 'Tap untuk pilih',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: sudahPilih
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: sudahPilih
                      ? kTextColor
                      : kSubtitleColor,
                ),
              ),
            ]),
      ),
    );
  }

  Widget _buildDeskripsiField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _deskripsiController,
        maxLines: 4,
        maxLength: 300,
        decoration: InputDecoration(
          hintText:
              'Jelaskan alasan izin Anda secara lengkap...',
          hintStyle: TextStyle(
              color: Colors.grey.shade400, fontSize: 13),
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
            borderSide: const BorderSide(
                color: kAccentColor, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.all(16),
        ),
        style:
            const TextStyle(fontSize: 14, color: kTextColor),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimaryColor,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18)),
            elevation: 4,
            shadowColor:
                kPrimaryColor.withValues(alpha: 0.4),
          ),
          onPressed:
              _isSubmitting ? null : _kirimPengajuan,
          child: _isSubmitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white),
                )
              : const Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Kirim Pengajuan Izin',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildRiwayatTab() {
    if (_riwayat.isEmpty) {
      return Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox_rounded,
                  size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              const Text(
                  'Belum ada riwayat pengajuan izin.',
                  style: TextStyle(
                      color: kSubtitleColor, fontSize: 14)),
            ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      itemCount: _riwayat.length,
      itemBuilder: (ctx, i) => _buildRiwayatCard(_riwayat[i]),
    );
  }

  Widget _buildRiwayatCard(_PengajuanIzin izin) {
    final statusColor = _statusColor(izin.status);
    final statusIcon = _statusIcon(izin.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              kPrimaryColor.withValues(alpha: 0.06),
              kAccentColor.withValues(alpha: 0.04),
            ]),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _jenisColor(izin.jenisIzin)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                izin.jenisIzin == 'Tidak Masuk'
                    ? Icons.person_off_rounded
                    : Icons.event_note_rounded,
                color: _jenisColor(izin.jenisIzin),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(izin.jenisIzin,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: kTextColor,
                            fontSize: 14)),
                    Text(izin.alasan,
                        style: const TextStyle(
                            color: kSubtitleColor,
                            fontSize: 12)),
                  ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(statusIcon, size: 12, color: statusColor),
                const SizedBox(width: 4),
                Text(izin.status,
                    style: TextStyle(
                        fontSize: 11,
                        color: statusColor,
                        fontWeight: FontWeight.bold)),
              ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: kAccentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(izin.id,
                        style: const TextStyle(
                            fontSize: 11,
                            color: kAccentColor,
                            fontWeight: FontWeight.bold)),
                  ),
                  const Spacer(),
                  const Icon(Icons.access_time_rounded,
                      size: 13, color: kSubtitleColor),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Dibuat: ${_formatDate(izin.tanggalDibuat, withTime: true)}',
                      style: const TextStyle(
                          fontSize: 11, color: kSubtitleColor),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kPrimaryLightColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    const Icon(Icons.date_range_rounded,
                        size: 18, color: kPrimaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_formatDate(izin.tanggalMulai)}  \u2192  ${_formatDate(izin.tanggalSelesai)}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: kPrimaryColor),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: kPrimaryColor
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${izin.durasiHari}h',
                          style: const TextStyle(
                              fontSize: 11,
                              color: kPrimaryColor,
                              fontWeight: FontWeight.bold)),
                    ),
                  ]),
                ),
                const SizedBox(height: 10),
                Text(izin.deskripsi,
                    style: const TextStyle(
                        fontSize: 13,
                        color: kSubtitleColor,
                        height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ]),
        ),
      ]),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Disetujui':
        return kSuccessColor;
      case 'Ditolak':
        return kDangerColor;
      default:
        return kWarningColor;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Disetujui':
        return Icons.check_circle_rounded;
      case 'Ditolak':
        return Icons.cancel_rounded;
      default:
        return Icons.hourglass_empty_rounded;
    }
  }

  Color _jenisColor(String jenis) =>
      jenis == 'Tidak Masuk' ? kDangerColor : kAccentColor;
}
