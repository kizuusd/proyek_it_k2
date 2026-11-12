import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/attendance_service.dart';
import '../../services/auth_service.dart';

class FR08AbsensiScreen extends StatefulWidget {
  const FR08AbsensiScreen({Key? key}) : super(key: key);

  @override
  State<FR08AbsensiScreen> createState() => _FR08AbsensiScreenState();
}

class _FR08AbsensiScreenState extends State<FR08AbsensiScreen> {
  List<AttendanceRecord> _records = [];
  List<UserModel> _salesList = [];
  AttendanceRecord? _todayRecord;
  bool _isLoading = true;
  bool _isSubmitting = false;

  final TextEditingController _noteCtrl = TextEditingController();
  String _statusFilter = 'Semua'; // Semua, Hadir, Terlambat, Izin, Sakit, Alpa
  int? _selectedSalesFilter;
  String? _selectedDateFilter;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    final isManager = user?.isManager ?? false;

    final fetched = await AttendanceService.fetchAttendances(
      salesId: isManager ? null : user?.id,
    );
    AttendanceRecord? today;
    if (!isManager && user?.id != null) {
      today = await AttendanceService.fetchTodayAttendance(user!.id!);
    }

    List<UserModel> salesUsers = [];
    if (isManager) {
      final allUsers = await AuthService().getAllUsers();
      salesUsers = allUsers.where((u) => u.isSales).toList();
    }

    if (mounted) {
      setState(() {
        _records = fetched;
        _todayRecord = today;
        _salesList = salesUsers;
        _isLoading = false;
      });
    }
  }

  List<AttendanceRecord> get _filteredRecords {
    return _records.where((r) {
      if (_statusFilter != 'Semua' &&
          r.statusLabel.toLowerCase() != _statusFilter.toLowerCase()) {
        return false;
      }
      if (_selectedSalesFilter != null && r.salesId != _selectedSalesFilter) {
        return false;
      }
      if (_selectedDateFilter != null &&
          _selectedDateFilter!.isNotEmpty &&
          r.tanggal != _selectedDateFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _handleCheckIn() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null || user.id == null) return;

    setState(() => _isSubmitting = true);
    try {
      final record = await AttendanceService.checkIn(
        salesId: user.id!,
        salesName: user.name,
        salesEmail: user.email,
        isActiveAccount: user.isActive && !user.isSuspended,
        catatan: _noteCtrl.text.trim(),
      );
      _noteCtrl.clear();
      if (!mounted) return;
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Check-in berhasil pada ${record.checkinTime ?? '-'} WIB (${record.statusLabel}).',
          ),
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
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleCheckOut() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null || user.id == null) return;

    setState(() => _isSubmitting = true);
    try {
      final record = await AttendanceService.checkOut(
        salesId: user.id!,
        salesEmail: user.email,
      );
      if (!mounted) return;
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Check-out berhasil pada ${record.checkoutTime ?? '-'} WIB (Durasi: ${record.formattedDurasi}).',
          ),
          backgroundColor: const Color(0xFF1D4ED8),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showCorrectionDialog(AttendanceRecord record) {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null || !user.isManager) return;

    final formKey = GlobalKey<FormState>();
    String selectedStatus = ['hadir', 'terlambat', 'izin', 'sakit', 'alfa'].contains(record.status)
        ? record.status
        : 'hadir';
    final inCtrl = TextEditingController(text: record.checkinTime ?? '');
    final outCtrl = TextEditingController(text: record.checkoutTime ?? '');
    final reasonCtrl = TextEditingController();
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              const Icon(Icons.edit_calendar_rounded, color: kPrimaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Koreksi Absensi: ${record.salesName}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextColor),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tanggal: ${record.tanggal}',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: kSecondaryColor),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    decoration: InputDecoration(
                      labelText: 'Status Kehadiran',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'hadir', child: Text('Hadir')),
                      DropdownMenuItem(value: 'terlambat', child: Text('Terlambat')),
                      DropdownMenuItem(value: 'izin', child: Text('Izin')),
                      DropdownMenuItem(value: 'sakit', child: Text('Sakit')),
                      DropdownMenuItem(value: 'alfa', child: Text('Alpa')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selectedStatus = v);
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: inCtrl,
                          decoration: InputDecoration(
                            labelText: 'Jam Check-In',
                            hintText: '08:00',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: outCtrl,
                          decoration: InputDecoration(
                            labelText: 'Jam Check-Out',
                            hintText: '17:00',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: reasonCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Alasan Koreksi *',
                      hintText: 'Misal: Sales lupa menekan check-out saat pulang',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Alasan koreksi wajib diisi' : null,
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
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => saving = true);
                      try {
                        final nav = Navigator.of(ctx);
                        await AttendanceService.correctAttendance(
                          attendanceId: record.id,
                          actorId: user.id ?? 2,
                          actorEmail: user.email,
                          actorName: user.name,
                          status: selectedStatus,
                          checkinTime: inCtrl.text.trim(),
                          checkoutTime: outCtrl.text.trim(),
                          reason: reasonCtrl.text.trim(),
                        );
                        if (!mounted) return;
                        nav.pop();
                        await _loadData();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Koreksi absensi disimpan ke audit trail.'),
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
                  : const Text('Simpan Koreksi', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCorrectionHistoryDialog(AttendanceRecord record) async {
    final logs = await AttendanceService.fetchCorrections(record.id);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.history_rounded, color: kPrimaryColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Jejak Koreksi (${record.tanggal})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextColor),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: logs.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Belum ada riwayat koreksi untuk catatan absensi ini.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: kSecondaryColor, fontSize: 13),
                  ),
                )
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 340),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final c = logs[i];
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Status: ${c.oldStatus} → ${c.newStatus}',
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Masuk: ${c.oldCheckinTime ?? '-'} → ${c.newCheckinTime ?? '-'} | Pulang: ${c.oldCheckoutTime ?? '-'} → ${c.newCheckoutTime ?? '-'}',
                              style: const TextStyle(fontSize: 11.5, color: kSecondaryColor),
                            ),
                            const SizedBox(height: 4),
                            Text('Alasan: ${c.reason}', style: const TextStyle(fontSize: 12)),
                            const SizedBox(height: 2),
                            Text(
                              'Korektor: ${c.correctedByName}',
                              style: const TextStyle(fontSize: 10.5, color: kSecondaryColor),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'hadir':
        return const Color(0xFF047857);
      case 'terlambat':
        return const Color(0xFFD97706);
      case 'izin':
      case 'sakit':
        return const Color(0xFF1D4ED8);
      case 'alfa':
      default:
        return const Color(0xFFDC2626);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    final isManager = user?.isManager ?? false;
    final filtered = _filteredRecords;

    final hadirCount = _records.where((r) => r.status == 'hadir').length;
    final lateCount = _records.where((r) => r.status == 'terlambat').length;
    final izinCount = _records.where((r) => r.status == 'izin' || r.status == 'sakit').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: Text(
          isManager ? 'Rekap Absensi Sales' : 'Absensi Sales',
          style: const TextStyle(color: kTextColor, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: kTextColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: kPrimaryColor),
            tooltip: 'Segarkan',
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
                  if (!isManager) ...[
                    _buildSalesCheckInOutCard(),
                    const SizedBox(height: 16),
                  ] else ...[
                    _buildAdminSummaryAndFilters(hadirCount, lateCount, izinCount),
                    const SizedBox(height: 16),
                  ],

                  // Filter Status Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['Semua', 'Hadir', 'Terlambat', 'Izin', 'Sakit', 'Alpa'].map((st) {
                        final selected = _statusFilter == st;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(st, style: const TextStyle(fontSize: 11.5)),
                            selected: selected,
                            onSelected: (_) => setState(() => _statusFilter = st),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    isManager
                        ? 'Daftar Kehadiran Sales (${filtered.length})'
                        : 'Riwayat Absensi Saya (${filtered.length})',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: kTextColor,
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (filtered.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.event_busy_outlined, size: 42, color: kSecondaryColor),
                          SizedBox(height: 8),
                          Text(
                            'Belum ada data absensi pada filter ini.',
                            style: TextStyle(fontSize: 13, color: kSecondaryColor),
                          ),
                        ],
                      ),
                    )
                  else
                    ...filtered.map((rec) => _buildAttendanceCard(rec, isManager)),
                ],
              ),
            ),
    );
  }

  Widget _buildSalesCheckInOutCard() {
    final hasCheckedIn = _todayRecord?.checkinAt != null;
    final hasCheckedOut = _todayRecord?.checkoutAt != null;
    final todayStr = AttendanceService.todayYmd();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.fingerprint_rounded, color: Color(0xFF047857), size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status Absensi Hari Ini',
                      style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: kTextColor),
                    ),
                    Text(
                      'Tanggal: $todayStr • Waktu Server (WIB)',
                      style: const TextStyle(fontSize: 11.5, color: kSecondaryColor),
                    ),
                  ],
                ),
              ),
              if (_todayRecord != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(_todayRecord!.status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _todayRecord!.statusLabel,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: _statusColor(_todayRecord!.status),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Check-In', style: TextStyle(fontSize: 11, color: kSecondaryColor)),
                      const SizedBox(height: 2),
                      Text(
                        hasCheckedIn ? '${_todayRecord!.checkinTime ?? '-'} WIB' : 'Belum Check-In',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kTextColor),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Check-Out', style: TextStyle(fontSize: 11, color: kSecondaryColor)),
                      const SizedBox(height: 2),
                      Text(
                        hasCheckedOut ? '${_todayRecord!.checkoutTime ?? '-'} WIB' : 'Belum Check-Out',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kTextColor),
                      ),
                    ],
                  ),
                ),
                if (hasCheckedOut) ...[
                  Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Durasi', style: TextStyle(fontSize: 11, color: kSecondaryColor)),
                      const SizedBox(height: 2),
                      Text(
                        _todayRecord!.formattedDurasi,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF047857),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (!hasCheckedIn) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                labelText: 'Catatan Kehadiran (Opsional)',
                hintText: 'Misal: Mulai kanvas area Surabaya Barat',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF047857),
                    disabledBackgroundColor: Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: (_isSubmitting || hasCheckedIn) ? null : _handleCheckIn,
                  icon: const Icon(Icons.login_rounded, color: Colors.white, size: 18),
                  label: Text(
                    hasCheckedIn ? 'Sudah Check-In' : 'Check-In',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    disabledBackgroundColor: Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: (_isSubmitting || !hasCheckedIn || hasCheckedOut) ? null : _handleCheckOut,
                  icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 18),
                  label: Text(
                    hasCheckedOut ? 'Sudah Check-Out' : 'Check-Out',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdminSummaryAndFilters(int hadir, int terlambat, int izin) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _statChip('Hadir', '$hadir', const Color(0xFF047857), const Color(0xFFECFDF5)),
              const SizedBox(width: 8),
              _statChip('Terlambat', '$terlambat', const Color(0xFFD97706), const Color(0xFFFFFBEB)),
              const SizedBox(width: 8),
              _statChip('Izin/Sakit', '$izin', const Color(0xFF1D4ED8), const Color(0xFFEFF6FF)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int?>(
                  initialValue: _selectedSalesFilter,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Filter Sales',
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
                  onChanged: (v) => setState(() => _selectedSalesFilter = v),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                label: Text(
                  _selectedDateFilter ?? 'Tanggal',
                  style: const TextStyle(fontSize: 12),
                ),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.tryParse(_selectedDateFilter ?? '') ?? DateTime.now(),
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
                  tooltip: 'Reset tanggal',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _selectedDateFilter = null),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String val, Color fg, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(val, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: fg)),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceCard(AttendanceRecord rec, bool isManager) {
    final c = _statusColor(rec.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                        isManager ? rec.salesName : rec.tanggal,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: kTextColor),
                      ),
                      if (isManager)
                        Text(
                          rec.tanggal,
                          style: const TextStyle(fontSize: 12, color: kSecondaryColor),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    rec.statusLabel,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.login_rounded, size: 15, color: Color(0xFF047857)),
                const SizedBox(width: 4),
                Text('Masuk: ${rec.checkinTime ?? '-'}', style: const TextStyle(fontSize: 12.5)),
                const SizedBox(width: 14),
                const Icon(Icons.logout_rounded, size: 15, color: Color(0xFFDC2626)),
                const SizedBox(width: 4),
                Text('Pulang: ${rec.checkoutTime ?? '-'}', style: const TextStyle(fontSize: 12.5)),
                const Spacer(),
                Text(
                  rec.formattedDurasi,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kPrimaryColor),
                ),
              ],
            ),
            if (rec.catatanAdmin != null && rec.catatanAdmin!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Catatan: ${rec.catatanAdmin}',
                style: const TextStyle(fontSize: 11.5, color: kSecondaryColor),
              ),
            ],
            if (isManager || rec.correctionsCount > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (rec.correctionsCount > 0)
                    TextButton.icon(
                      onPressed: () => _showCorrectionHistoryDialog(rec),
                      icon: const Icon(Icons.history_rounded, size: 16),
                      label: Text('Riwayat (${rec.correctionsCount})', style: const TextStyle(fontSize: 12)),
                    ),
                  if (isManager)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _showCorrectionDialog(rec),
                      icon: const Icon(Icons.edit_outlined, size: 15),
                      label: const Text('Koreksi', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
