import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/user_avatar.dart';
import 'fr12_register_screen.dart';

class FR07KeanggotaanScreen extends StatefulWidget {
  const FR07KeanggotaanScreen({Key? key}) : super(key: key);

  @override
  State<FR07KeanggotaanScreen> createState() => _FR07KeanggotaanScreenState();
}

class _FR07KeanggotaanScreenState extends State<FR07KeanggotaanScreen> {
  List<UserModel> _users = [];
  bool _isLoading = true;
  final TextEditingController _searchCtrl = TextEditingController();
  String _statusFilter = 'Semua'; // Semua, Aktif, Nonaktif, Ditangguhkan
  String _roleFilter = 'Semua'; // Semua, Sales, Manajemen

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final list = await authProvider.getAllUsers();
      if (mounted) {
        setState(() {
          _users = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<UserModel> get _filteredUsers {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _users.where((u) {
      if (q.isNotEmpty) {
        final matchName = u.name.toLowerCase().contains(q);
        final matchEmail = u.email.toLowerCase().contains(q);
        final matchKode = u.displayKodeSales.toLowerCase().contains(q);
        if (!matchName && !matchEmail && !matchKode) return false;
      }
      if (_statusFilter != 'Semua') {
        if (u.membershipStatusLabel.toLowerCase() != _statusFilter.toLowerCase()) {
          return false;
        }
      }
      if (_roleFilter == 'Sales' && !u.isSales) return false;
      if (_roleFilter == 'Manajemen' && !u.isManager) return false;
      return true;
    }).toList();
  }

  Color _statusBg(UserModel u) {
    switch (u.membershipStatus.toLowerCase()) {
      case 'ditangguhkan':
        return Colors.orange.shade50;
      case 'nonaktif':
        return Colors.red.shade50;
      case 'aktif':
      default:
        return u.isActive ? Colors.green.shade50 : Colors.red.shade50;
    }
  }

  Color _statusBorder(UserModel u) {
    switch (u.membershipStatus.toLowerCase()) {
      case 'ditangguhkan':
        return Colors.orange.shade200;
      case 'nonaktif':
        return Colors.red.shade200;
      case 'aktif':
      default:
        return u.isActive ? Colors.green.shade200 : Colors.red.shade200;
    }
  }

  Color _statusFg(UserModel u) {
    switch (u.membershipStatus.toLowerCase()) {
      case 'ditangguhkan':
        return Colors.orange.shade800;
      case 'nonaktif':
        return Colors.red.shade700;
      case 'aktif':
      default:
        return u.isActive ? Colors.green.shade700 : Colors.red.shade700;
    }
  }

  // ============================================================
  // DIALOG EDIT PROFIL ANGGOTA (ADMIN/OWNER ATAU PROFIL PRIBADI SALES)
  // ============================================================
  void _showEditMemberDialog(UserModel member, {required bool isManager}) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: member.name);
    final phoneCtrl = TextEditingController(text: member.phone ?? '');
    final alamatCtrl = TextEditingController(text: member.alamat ?? '');
    final kodeCtrl = TextEditingController(text: member.kodeSales ?? member.displayKodeSales);
    final tglCtrl = TextEditingController(text: member.tanggalBergabung ?? '');
    int? selectedCoordId = member.koordinatorId;
    bool saving = false;

    final managers = _users.where((u) => u.isManager && u.id != null).toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              const Icon(Icons.edit_note_rounded, color: kPrimaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isManager ? 'Edit Data Anggota Sales' : 'Perbarui Informasi Pribadi',
                  style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: kTextColor),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 420,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isManager && member.isSales) ...[
                      TextFormField(
                        controller: kodeCtrl,
                        decoration: InputDecoration(
                          labelText: 'Kode Sales Unik',
                          hintText: 'SLS-001',
                          prefixIcon: const Icon(Icons.qr_code_2_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Kode Sales wajib diisi' : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nama Lengkap',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Nomor Telepon / WA',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: alamatCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Alamat',
                        prefixIcon: const Icon(Icons.home_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    if (isManager && member.isSales) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: tglCtrl,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Tanggal Bergabung (YYYY-MM-DD)',
                          prefixIcon: const Icon(Icons.calendar_today_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onTap: () async {
                          final init = DateTime.tryParse(tglCtrl.text) ?? DateTime.now();
                          final picked = await showDatePicker(
                            context: dialogCtx,
                            initialDate: init,
                            firstDate: DateTime(2015),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              tglCtrl.text =
                                  '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                            });
                          }
                        },
                      ),
                      if (managers.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int?>(
                          initialValue: managers.any((m) => m.id == selectedCoordId) ? selectedCoordId : null,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Atasan / Koordinator (Opsional)',
                            prefixIcon: const Icon(Icons.supervisor_account_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: [
                            const DropdownMenuItem<int?>(value: null, child: Text('Tidak ditentukan')),
                            ...managers.map(
                              (m) => DropdownMenuItem<int?>(
                                value: m.id,
                                child: Text(m.name, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                          ],
                          onChanged: (val) => setDialogState(() => selectedCoordId = val),
                        ),
                      ],
                    ],
                  ],
                ),
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
              onPressed: saving || member.id == null
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => saving = true);
                      final nav = Navigator.of(ctx);
                      final messenger = ScaffoldMessenger.of(context);
                      final authProvider = context.read<AuthProvider>();
                      final ok = await authProvider.updateMemberProfile(
                        targetUserId: member.id!,
                        name: nameCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        alamat: alamatCtrl.text.trim(),
                        kodeSales: isManager && member.isSales ? kodeCtrl.text.trim() : null,
                        tanggalBergabung:
                            isManager && member.isSales && tglCtrl.text.isNotEmpty ? tglCtrl.text.trim() : null,
                        koordinatorId: isManager && member.isSales ? selectedCoordId : null,
                      );
                      if (!mounted) return;
                      if (ok) {
                        nav.pop();
                        await _loadUsers();
                        if (!mounted) return;
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Profil anggota berhasil diperbarui.'),
                            backgroundColor: Color(0xFF047857),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      } else {
                        setDialogState(() => saving = false);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(authProvider.errorMessage ?? 'Gagal memperbarui profil.'),
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
                  : const Text('Simpan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DIALOG UBAH STATUS KEANGGOTAAN (AKTIF / NONAKTIF / DITANGGUHKAN)
  // ============================================================
  void _showChangeStatusDialog(UserModel member) {
    String selectedStatus = member.membershipStatus.toLowerCase();
    if (!['aktif', 'nonaktif', 'ditangguhkan'].contains(selectedStatus)) {
      selectedStatus = member.isActive ? 'aktif' : 'nonaktif';
    }
    final reasonCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              const Icon(Icons.manage_accounts_rounded, color: kPrimaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ubah Status: ${member.name}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextColor),
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Status keanggotaan memengaruhi hak akses login dan aktivitas operasional Sales.',
                  style: TextStyle(fontSize: 12, color: kSecondaryColor),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedStatus,
                  decoration: InputDecoration(
                    labelText: 'Status Keanggotaan',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'aktif', child: Text('Aktif')),
                    DropdownMenuItem(value: 'nonaktif', child: Text('Nonaktif')),
                    DropdownMenuItem(value: 'ditangguhkan', child: Text('Ditangguhkan (Suspend)')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedStatus = v);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: reasonCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Alasan / Catatan Perubahan *',
                    hintText: 'Contoh: Evaluasi kinerja / kontrak selesai / aktif kembali',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Alasan perubahan wajib diisi' : null,
                ),
              ],
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
              onPressed: saving || member.id == null
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => saving = true);
                      final nav = Navigator.of(ctx);
                      final messenger = ScaffoldMessenger.of(context);
                      final authProvider = context.read<AuthProvider>();
                      final ok = await authProvider.updateMembershipStatus(
                        targetUserId: member.id!,
                        membershipStatus: selectedStatus,
                        reason: reasonCtrl.text.trim(),
                      );
                      if (!mounted) return;
                      if (ok) {
                        nav.pop();
                        await _loadUsers();
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Status keanggotaan ${member.name} diubah menjadi $selectedStatus.'),
                            backgroundColor: const Color(0xFF047857),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      } else {
                        setDialogState(() => saving = false);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(authProvider.errorMessage ?? 'Gagal mengubah status keanggotaan.'),
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
                  : const Text('Simpan Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DIALOG DETAIL & RIWAYAT STATUS ANGGOTA
  // ============================================================
  Future<void> _showMemberDetailDialog(UserModel member) async {
    final authProvider = context.read<AuthProvider>();
    final history = member.id != null
        ? await authProvider.getMembershipStatusHistory(member.id!)
        : <MembershipStatusLog>[];
    if (!mounted) return;

    String fmtDateTime(DateTime dt) {
      final d = dt.toLocal();
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            UserAvatar(photoUrl: member.photoUrl, name: member.name, radius: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextColor),
                  ),
                  Text(
                    '${member.roleDisplayTitle} • ${member.displayKodeSales}',
                    style: const TextStyle(fontSize: 11.5, color: kSecondaryColor),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(),
                _detailLine('Email', member.email),
                _detailLine('Telepon', member.phone ?? '-'),
                _detailLine('Alamat', member.alamat ?? '-'),
                _detailLine('Tanggal Bergabung', member.tanggalBergabung ?? '-'),
                _detailLine('Koordinator', member.koordinatorName ?? '-'),
                _detailLine('Status Keanggotaan', member.membershipStatusLabel),
                const SizedBox(height: 12),
                const Text(
                  'Riwayat Perubahan Status',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: kTextColor),
                ),
                const SizedBox(height: 6),
                if (history.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'Belum ada riwayat perubahan status.',
                      style: TextStyle(fontSize: 12, color: kSecondaryColor),
                    ),
                  )
                else
                  ...history.map(
                    (h) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
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
                            '${h.oldStatus} → ${h.newStatus}',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: kTextColor),
                          ),
                          if (h.reason.isNotEmpty)
                            Text(h.reason, style: const TextStyle(fontSize: 12, color: kTextColor)),
                          const SizedBox(height: 2),
                          Text(
                            'Oleh: ${h.changedByName} • ${fmtDateTime(h.createdAt)}',
                            style: const TextStyle(fontSize: 10.5, color: kSecondaryColor),
                          ),
                        ],
                      ),
                    ),
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

  Widget _detailLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(fontSize: 12, color: kSecondaryColor)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: kTextColor)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.currentUser;
    final bool isManager = currentUser != null && currentUser.isManager;

    final salesUsers = _users.where((u) => u.isSales).toList();
    final activeSalesCount = salesUsers.where((u) => u.membershipStatus == 'aktif' && u.isActive).length;
    final nonActiveCount = salesUsers.where((u) => u.membershipStatus == 'nonaktif' || !u.isActive).length;
    final suspendedCount = salesUsers.where((u) => u.membershipStatus == 'ditangguhkan').length;
    final filtered = _filteredUsers;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text(
          'Kelola Keanggotaan',
          style: TextStyle(color: kTextColor, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: kTextColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: kPrimaryColor),
            tooltip: 'Segarkan Data',
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : RefreshIndicator(
              onRefresh: _loadUsers,
              color: kPrimaryColor,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Info Banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: isManager ? Colors.blue.shade50 : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isManager ? Colors.blue.shade200 : Colors.amber.shade200,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          isManager ? Icons.verified_user_outlined : Icons.info_outline,
                          color: isManager ? Colors.blue.shade700 : Colors.amber.shade800,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isManager
                                ? 'Anda memiliki hak manajerial (${currentUser.roleDisplayTitle}). Anda dapat mendaftarkan, mengubah profil, serta mengaktifkan/menonaktifkan/menangguhkan anggota Sales.'
                                : 'Anda dapat melihat status keanggotaan dan memperbarui informasi pribadi Anda. Perubahan status keanggotaan hanya dapat dilakukan oleh Admin/Owner.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isManager ? Colors.blue.shade900 : Colors.amber.shade900,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Kartu Keanggotaan Pribadi untuk Sales
                  if (currentUser != null && !isManager) ...[
                    _buildMyMembershipCard(currentUser),
                    const SizedBox(height: 14),
                  ],

                  // Summary Statistik Keanggotaan Sales
                  Row(
                    children: [
                      _buildMiniStat('Sales Aktif', '$activeSalesCount', Colors.green.shade700, Colors.green.shade50),
                      const SizedBox(width: 8),
                      _buildMiniStat('Nonaktif', '$nonActiveCount', Colors.red.shade700, Colors.red.shade50),
                      const SizedBox(width: 8),
                      _buildMiniStat('Ditangguhkan', '$suspendedCount', Colors.orange.shade800, Colors.orange.shade50),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Search & Filter Status
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Cari nama, email, atau kode sales...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ...['Semua', 'Aktif', 'Nonaktif', 'Ditangguhkan'].map((s) {
                          final selected = _statusFilter == s;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(s, style: const TextStyle(fontSize: 11.5)),
                              selected: selected,
                              onSelected: (_) => setState(() => _statusFilter = s),
                            ),
                          );
                        }),
                        const SizedBox(width: 8),
                        ...['Semua', 'Sales', 'Manajemen'].map((r) {
                          final selected = _roleFilter == r;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Text('Role: $r', style: const TextStyle(fontSize: 11.5)),
                              selected: selected,
                              onSelected: (_) => setState(() => _roleFilter = r),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Header List
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Daftar Anggota Tim (${filtered.length})',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: kTextColor,
                        ),
                      ),
                      Text(
                        'CV Maju Bersama',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (filtered.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      alignment: Alignment.center,
                      child: const Text(
                        'Tidak ada anggota yang sesuai dengan filter.',
                        style: TextStyle(color: kSecondaryColor, fontSize: 13),
                      ),
                    )
                  else
                    ...filtered.map((user) => _buildUserCard(user, isManager, currentUser)),
                ],
              ),
            ),
      // Tombol Daftarkan Sales Baru HANYA untuk Admin & Owner
      floatingActionButton: isManager
          ? FloatingActionButton.extended(
              backgroundColor: kPrimaryColor,
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FR12RegisterScreen()),
                );
                if (result == true) {
                  _loadUsers();
                }
              },
              icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
              label: const Text(
                'Daftarkan Sales Baru',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }

  Widget _buildMyMembershipCard(UserModel user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.badge_rounded, color: Color(0xFF047857)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Keanggotaan Saya',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kTextColor),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusBg(user),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _statusBorder(user)),
                ),
                child: Text(
                  user.membershipStatusLabel,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _statusFg(user)),
                ),
              ),
            ],
          ),
          const Divider(height: 18),
          _detailLine('Kode Sales', user.displayKodeSales),
          _detailLine('Nama', user.name),
          _detailLine('Telepon', user.phone ?? '-'),
          _detailLine('Alamat', user.alamat ?? '-'),
          _detailLine('Bergabung', user.tanggalBergabung ?? '-'),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.edit_outlined, size: 17),
              label: const Text('Edit Informasi Pribadi'),
              onPressed: () => _showEditMemberDialog(user, isManager: false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String count, Color fg, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: fg.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(count, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: fg)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(UserModel user, bool isManager, UserModel? currentUser) {
    Color badgeColor;
    if (user.isSuperAdmin) {
      badgeColor = Colors.purple;
    } else if (user.isAdmin) {
      badgeColor = Colors.blue.shade700;
    } else {
      badgeColor = Colors.teal.shade700;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showMemberDetailDialog(user),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              UserAvatar(
                photoUrl: user.photoUrl,
                name: user.name,
                radius: 26,
                backgroundColor: badgeColor.withValues(alpha: 0.15),
                textColor: badgeColor,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: kTextColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _statusBg(user),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _statusBorder(user)),
                          ),
                          child: Text(
                            user.membershipStatusLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _statusFg(user),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            user.roleDisplayTitle,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: badgeColor,
                            ),
                          ),
                        ),
                        if (user.isSales)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              user.displayKodeSales,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ),
                        if (user.googleId != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.g_mobiledata_rounded, size: 14, color: Colors.blue),
                                Text('Gmail', style: TextStyle(fontSize: 9.5, color: Colors.black87)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isManager)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: kSecondaryColor),
                  onSelected: (val) {
                    if (val == 'detail') {
                      _showMemberDetailDialog(user);
                    } else if (val == 'edit') {
                      _showEditMemberDialog(user, isManager: true);
                    } else if (val == 'status') {
                      _showChangeStatusDialog(user);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'detail',
                      child: Row(
                        children: [
                          Icon(Icons.history_edu_outlined, size: 18, color: kPrimaryColor),
                          SizedBox(width: 8),
                          Text('Detail & Riwayat Status'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18, color: Color(0xFF1D4ED8)),
                          SizedBox(width: 8),
                          Text('Edit Data Anggota'),
                        ],
                      ),
                    ),
                    if (currentUser?.id != user.id)
                      const PopupMenuItem(
                        value: 'status',
                        child: Row(
                          children: [
                            Icon(Icons.manage_accounts_outlined, size: 18, color: Colors.orange),
                            SizedBox(width: 8),
                            Text('Ubah Status Keanggotaan'),
                          ],
                        ),
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
