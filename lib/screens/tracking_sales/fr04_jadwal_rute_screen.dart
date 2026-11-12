import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../services/route_service.dart';

class FR04PenjadwalanRuteScreen extends StatefulWidget {
  const FR04PenjadwalanRuteScreen({Key? key}) : super(key: key);

  @override
  State<FR04PenjadwalanRuteScreen> createState() => _FR04PenjadwalanRuteScreenState();
}

class _FR04PenjadwalanRuteScreenState extends State<FR04PenjadwalanRuteScreen> {
  List<RouteScheduleItem> _routes = [];
  List<UserModel> _salesList = [];
  bool _isLoading = true;
  int? _salesFilterId;
  String? _dateFilter;
  String _statusFilter = 'Semua';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final user = context.read<AuthProvider>().currentUser;
    final isManager = user?.isManager ?? false;

    final fetchedRoutes = await RouteService.fetchRoutes(
      salesId: isManager ? null : user?.id,
    );

    List<UserModel> salesUsers = [];
    if (isManager) {
      final allUsers = await AuthService().getAllUsers();
      salesUsers = allUsers.where((u) => u.isSales).toList();
    }

    if (mounted) {
      setState(() {
        _routes = fetchedRoutes;
        _salesList = salesUsers;
        _isLoading = false;
      });
    }
  }

  List<RouteScheduleItem> get _filteredRoutes {
    return _routes.where((r) {
      if (_salesFilterId != null && r.salesId != _salesFilterId) return false;
      if (_dateFilter != null && _dateFilter!.isNotEmpty && r.tanggal != _dateFilter) return false;
      if (_statusFilter != 'Semua' &&
          r.statusLabel.toLowerCase() != _statusFilter.toLowerCase()) {
        return false;
      }
      return true;
    }).toList();
  }

  void _showRouteFormDialog({RouteScheduleItem? editing}) {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null || !user.isManager) return;

    final activeSales = _salesList.where((s) => s.isActive && !s.isSuspended).toList();
    if (activeSales.isEmpty && editing == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada Sales aktif yang tersedia untuk dijadwalkan.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    int selectedSalesId = editing?.salesId ?? activeSales.first.id ?? 3;
    final tanggalCtrl = TextEditingController(text: editing?.tanggal ?? RouteService.todayYmd());
    final startCtrl = TextEditingController(text: editing?.waktuMulai ?? '09:00');
    final endCtrl = TextEditingController(text: editing?.waktuSelesai ?? '10:00');
    final tujuanCtrl = TextEditingController(text: editing?.namaTujuan ?? '');
    final alamatCtrl = TextEditingController(text: editing?.alamatTujuan ?? '');
    final urutanCtrl = TextEditingController(text: (editing?.urutan ?? 1).toString());
    final catatanCtrl = TextEditingController(text: editing?.catatan ?? '');
    final alasanUbahCtrl = TextEditingController();
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              const Icon(Icons.alt_route_rounded, color: kPrimaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  editing == null ? 'Buat Jadwal Kunjungan' : 'Edit Jadwal Kunjungan',
                  style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: kTextColor),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 440,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: activeSales.any((s) => s.id == selectedSalesId)
                          ? selectedSalesId
                          : (activeSales.isNotEmpty ? activeSales.first.id : null),
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Sales Bertugas (Aktif) *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: activeSales
                          .map(
                            (s) => DropdownMenuItem<int>(
                              value: s.id,
                              child: Text('${s.name} (${s.displayKodeSales})', overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setDialogState(() => selectedSalesId = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: tanggalCtrl,
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: 'Tanggal *',
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
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: urutanCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Urutan *',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            validator: (v) {
                              final n = int.tryParse(v ?? '');
                              if (n == null || n < 1) return 'Min 1';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: startCtrl,
                            decoration: InputDecoration(
                              labelText: 'Jam Mulai *',
                              hintText: '09:00',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            validator: (v) => (v == null || !RegExp(r'^\d{2}:\d{2}$').hasMatch(v.trim()))
                                ? 'HH:mm'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: endCtrl,
                            decoration: InputDecoration(
                              labelText: 'Jam Selesai *',
                              hintText: '10:00',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            validator: (v) => (v == null || !RegExp(r'^\d{2}:\d{2}$').hasMatch(v.trim()))
                                ? 'HH:mm'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: tujuanCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nama Pelanggan / Tujuan *',
                        hintText: 'Toko Sinar Makmur',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Nama tujuan wajib diisi' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: alamatCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Alamat Tujuan *',
                        hintText: 'Jl. Merdeka No. 45',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Alamat tujuan wajib diisi' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: catatanCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Catatan Kunjungan (Opsional)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    if (editing != null) ...[
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: alasanUbahCtrl,
                        decoration: InputDecoration(
                          labelText: 'Alasan Perubahan Jadwal (Opsional)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
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
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => saving = true);
                      final salesObj = _salesList.firstWhere(
                        (s) => s.id == selectedSalesId,
                        orElse: () => activeSales.first,
                      );
                      try {
                        final nav = Navigator.of(ctx);
                        if (editing == null) {
                          await RouteService.createRoute(
                            actorId: user.id ?? 2,
                            actorEmail: user.email,
                            salesId: selectedSalesId,
                            salesName: salesObj.name,
                            isSalesActive: salesObj.isActive && !salesObj.isSuspended,
                            tanggal: tanggalCtrl.text.trim(),
                            waktuMulai: startCtrl.text.trim(),
                            waktuSelesai: endCtrl.text.trim(),
                            namaTujuan: tujuanCtrl.text.trim(),
                            alamatTujuan: alamatCtrl.text.trim(),
                            urutan: int.tryParse(urutanCtrl.text.trim()) ?? 1,
                            catatan: catatanCtrl.text.trim(),
                          );
                        } else {
                          await RouteService.updateRoute(
                            routeId: editing.id,
                            actorId: user.id ?? 2,
                            actorEmail: user.email,
                            salesId: selectedSalesId,
                            salesName: salesObj.name,
                            tanggal: tanggalCtrl.text.trim(),
                            waktuMulai: startCtrl.text.trim(),
                            waktuSelesai: endCtrl.text.trim(),
                            namaTujuan: tujuanCtrl.text.trim(),
                            alamatTujuan: alamatCtrl.text.trim(),
                            urutan: int.tryParse(urutanCtrl.text.trim()) ?? 1,
                            catatan: catatanCtrl.text.trim(),
                            status: editing.status,
                            alasanPerubahan: alasanUbahCtrl.text.trim(),
                          );
                        }
                        if (!mounted) return;
                        nav.pop();
                        await _loadData();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              editing == null
                                  ? 'Jadwal kunjungan berhasil dibuat.'
                                  : 'Jadwal kunjungan berhasil diperbarui.',
                            ),
                            backgroundColor: const Color(0xFF047857),
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
                  : const Text('Simpan Jadwal', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelRouteDialog(RouteScheduleItem item) {
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
          title: const Text('Batalkan Jadwal Kunjungan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: reasonCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Alasan Pembatalan *',
                hintText: 'Contoh: Toko sedang tutup / jadwal dialihkan',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Alasan pembatalan wajib diisi' : null,
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
                        await RouteService.updateRoute(
                          routeId: item.id,
                          actorId: user.id ?? 2,
                          actorEmail: user.email,
                          salesId: item.salesId,
                          salesName: item.salesName,
                          tanggal: item.tanggal,
                          waktuMulai: item.waktuMulai,
                          waktuSelesai: item.waktuSelesai,
                          namaTujuan: item.namaTujuan,
                          alamatTujuan: item.alamatTujuan,
                          urutan: item.urutan,
                          catatan: item.catatan,
                          status: StatusKunjungan.dibatalkan,
                          alasanPerubahan: reasonCtrl.text.trim(),
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
              child: const Text('Batalkan Jadwal', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showUpdateVisitStatusDialog(RouteScheduleItem item) {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    StatusKunjungan selectedStatus = item.status;
    final hasilCtrl = TextEditingController(text: item.catatanHasil);
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            'Update Kunjungan: ${item.namaTujuan}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextColor),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<StatusKunjungan>(
                initialValue: selectedStatus,
                decoration: InputDecoration(
                  labelText: 'Status Kunjungan',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: const [
                  DropdownMenuItem(value: StatusKunjungan.belumDikunjungi, child: Text('Belum Dikunjungi')),
                  DropdownMenuItem(value: StatusKunjungan.dalamPerjalanan, child: Text('Dalam Perjalanan')),
                  DropdownMenuItem(value: StatusKunjungan.selesai, child: Text('Selesai')),
                  DropdownMenuItem(value: StatusKunjungan.dibatalkan, child: Text('Batal')),
                ],
                onChanged: (v) {
                  if (v != null) setDialogState(() => selectedStatus = v);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: hasilCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Catatan Hasil Kunjungan',
                  hintText: 'Contoh: Pemilik toko memesan 5 pack plastik',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.pop(ctx), child: const Text('Tutup')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF047857)),
              onPressed: saving
                  ? null
                  : () async {
                      setDialogState(() => saving = true);
                      try {
                        final nav = Navigator.of(ctx);
                        await RouteService.updateVisitStatus(
                          routeId: item.id,
                          actorId: user.id ?? item.salesId,
                          actorEmail: user.email,
                          status: selectedStatus,
                          catatanHasil: hasilCtrl.text.trim(),
                        );
                        if (!mounted) return;
                        nav.pop();
                        await _loadData();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Status & catatan kunjungan berhasil disimpan.'),
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
                          ),
                        );
                      }
                    },
              child: const Text('Simpan', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(StatusKunjungan s) {
    switch (s) {
      case StatusKunjungan.selesai:
        return const Color(0xFF047857);
      case StatusKunjungan.dalamPerjalanan:
        return const Color(0xFF1D4ED8);
      case StatusKunjungan.dibatalkan:
        return const Color(0xFFDC2626);
      case StatusKunjungan.belumDikunjungi:
        return const Color(0xFFD97706);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isManager = user?.isManager ?? false;
    final filtered = _filteredRoutes;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text('Penjadwalan Rute', style: TextStyle(color: kTextColor, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: kTextColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: kPrimaryColor),
            tooltip: 'Muat Ulang',
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
                  if (isManager) ...[
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int?>(
                            initialValue: _salesFilterId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Filter Sales',
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
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.calendar_today_outlined, size: 16),
                          label: Text(_dateFilter ?? 'Semua Tanggal', style: const TextStyle(fontSize: 12)),
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
                    const SizedBox(height: 10),
                  ],

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['Semua', 'Belum Dikunjungi', 'Dalam Perjalanan', 'Selesai', 'Batal'].map((st) {
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
                  const SizedBox(height: 14),

                  if (filtered.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.route_outlined, size: 42, color: kSecondaryColor),
                          SizedBox(height: 8),
                          Text(
                            'Belum ada jadwal kunjungan pada filter ini.',
                            style: TextStyle(fontSize: 13, color: kSecondaryColor),
                          ),
                        ],
                      ),
                    )
                  else
                    ...filtered.map((item) => _buildRouteCard(item, isManager)),
                ],
              ),
            ),
      floatingActionButton: isManager
          ? FloatingActionButton.extended(
              backgroundColor: kPrimaryColor,
              onPressed: () => _showRouteFormDialog(),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Tambah Rute', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  Widget _buildRouteCard(RouteScheduleItem item, bool isManager) {
    final c = _statusColor(item.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: kPrimaryColor.withValues(alpha: 0.12),
                  child: Text(
                    '#${item.urutan}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: kPrimaryColor),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.namaTujuan,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kTextColor),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.tanggal} • ${item.waktuMulai} - ${item.waktuSelesai} WIB',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kPrimaryColor),
                      ),
                      if (isManager)
                        Text(
                          'Sales: ${item.salesName}',
                          style: const TextStyle(fontSize: 12, color: kSecondaryColor),
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
                    item.statusLabel,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: kSecondaryColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(item.alamatTujuan, style: const TextStyle(fontSize: 12.5, color: kTextColor)),
                ),
              ],
            ),
            if (item.catatan.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Instruksi: ${item.catatan}', style: const TextStyle(fontSize: 12, color: kSecondaryColor)),
            ],
            if (item.catatanHasil.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Hasil Kunjungan: ${item.catatanHasil}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF166534)),
                ),
              ),
            ],
            if (item.alasanPerubahan.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Alasan Perubahan/Batal: ${item.alasanPerubahan}',
                style: const TextStyle(fontSize: 11.5, color: Colors.redAccent),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isManager) ...[
                  TextButton.icon(
                    onPressed: () => _showRouteFormDialog(editing: item),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Ubah', style: TextStyle(fontSize: 12)),
                  ),
                  if (item.status != StatusKunjungan.dibatalkan)
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                      onPressed: () => _showCancelRouteDialog(item),
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: const Text('Batalkan', style: TextStyle(fontSize: 12)),
                    ),
                ] else ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF047857),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _showUpdateVisitStatusDialog(item),
                    icon: const Icon(Icons.update_rounded, size: 16, color: Colors.white),
                    label: const Text('Update Status Kunjungan', style: TextStyle(fontSize: 12, color: Colors.white)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
