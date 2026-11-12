import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../services/monitoring_service.dart';
import '../../services/transaction_service.dart';
import 'fr04_jadwal_rute_screen.dart';
import 'fr05_pendapatan_screen.dart';
import 'fr07_keanggotaan_screen.dart';
import 'fr08_absensi_screen.dart';

class FR06MonitoringPosisiScreen extends StatefulWidget {
  const FR06MonitoringPosisiScreen({Key? key}) : super(key: key);

  @override
  State<FR06MonitoringPosisiScreen> createState() => _FR06MonitoringPosisiScreenState();
}

class _FR06MonitoringPosisiScreenState extends State<FR06MonitoringPosisiScreen> {
  MonitoringSummaryData? _summary;
  List<UserModel> _salesList = [];
  bool _isLoading = true;

  String _periodPreset = 'Semua'; // Hari Ini, 7 Hari, Bulan Ini, Semua
  int? _selectedSalesId;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  (String?, String?) _computeDateRange() {
    final now = DateTime.now();
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    switch (_periodPreset) {
      case 'Hari Ini':
        final today = fmt(now);
        return (today, today);
      case '7 Hari':
        return (fmt(now.subtract(const Duration(days: 6))), fmt(now));
      case 'Bulan Ini':
        return (fmt(DateTime(now.year, now.month, 1)), fmt(now));
      case 'Semua':
      default:
        return (null, null);
    }
  }

  Future<void> _loadSummary() async {
    setState(() => _isLoading = true);
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    if (user.isManager && _salesList.isEmpty) {
      final users = await AuthService().getAllUsers();
      _salesList = users.where((u) => u.isSales).toList();
    }

    final (startDate, endDate) = _computeDateRange();
    final data = await MonitoringService.loadSummary(
      currentUser: user,
      startDate: startDate,
      endDate: endDate,
      filterSalesId: user.isManager ? _selectedSalesId : user.id,
    );

    if (mounted) {
      setState(() {
        _summary = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isManager = user?.isManager ?? false;
    final s = _summary;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: Text(
          isManager ? 'Monitoring Kinerja Sales' : 'Ringkasan Kinerja Saya',
          style: const TextStyle(color: kTextColor, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: kTextColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: kPrimaryColor),
            tooltip: 'Segarkan Data',
            onPressed: _loadSummary,
          ),
        ],
      ),
      body: _isLoading || s == null
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : RefreshIndicator(
              onRefresh: _loadSummary,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Filter Bar (Periode & Sales untuk Admin/Owner)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Filter Monitoring',
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: kTextColor),
                            ),
                            Text(
                              'Zona: ${s.timezone}',
                              style: const TextStyle(fontSize: 11, color: kSecondaryColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: ['Hari Ini', '7 Hari', 'Bulan Ini', 'Semua'].map((p) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  label: Text(p, style: const TextStyle(fontSize: 11.5)),
                                  selected: _periodPreset == p,
                                  onSelected: (_) {
                                    setState(() => _periodPreset = p);
                                    _loadSummary();
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        if (isManager && _salesList.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          DropdownButtonFormField<int?>(
                            initialValue: _selectedSalesId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Filter per Anggota Sales',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            items: [
                              const DropdownMenuItem<int?>(value: null, child: Text('Semua Sales')),
                              ..._salesList.map(
                                (u) => DropdownMenuItem<int?>(
                                  value: u.id,
                                  child: Text('${u.name} (${u.displayKodeSales})', overflow: TextOverflow.ellipsis),
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              setState(() => _selectedSalesId = val);
                              _loadSummary();
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (s.isCompletelyEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.analytics_outlined, size: 46, color: kSecondaryColor),
                          SizedBox(height: 10),
                          Text(
                            'Belum ada data aktivitas pada periode yang dipilih.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: kTextColor),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Data akan muncul otomatis saat ada pencatatan absensi, jadwal kunjungan, atau transaksi penjualan.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: kSecondaryColor),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    // Grid KPI Sumber
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.22,
                      children: [
                        if (isManager)
                          _kpiTile(
                            title: 'Sales Aktif',
                            value: '${s.activeSalesCount} Orang',
                            sub: 'Ketuk untuk kelola anggota',
                            icon: Icons.people_alt_rounded,
                            color: const Color(0xFF6B21A8),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const FR07KeanggotaanScreen()),
                            ),
                          ),
                        _kpiTile(
                          title: 'Kehadiran',
                          value: '${s.totalPresentDays}/${s.totalAttendanceCount}',
                          sub: 'Hadir ${s.hadirCount} • Terlambat ${s.terlambatCount} (${s.attendanceRate.toStringAsFixed(0)}%)',
                          icon: Icons.fingerprint_rounded,
                          color: const Color(0xFF047857),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const FR08AbsensiScreen()),
                          ),
                        ),
                        _kpiTile(
                          title: 'Kunjungan Selesai',
                          value: '${s.completedRoutes}/${s.totalRoutes}',
                          sub: 'Belum: ${s.pendingRoutes + s.inProgressRoutes} (${s.routeCompletionRate.toStringAsFixed(0)}%)',
                          icon: Icons.alt_route_rounded,
                          color: const Color(0xFF1D4ED8),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const FR04PenjadwalanRuteScreen()),
                          ),
                        ),
                        _kpiTile(
                          title: 'Omzet Disetujui',
                          value: TransactionService.formatRp(s.approvedOmzet),
                          sub: 'Disetujui: ${s.approvedTxCount} • Menunggu: ${s.pendingTxCount}',
                          icon: Icons.account_balance_wallet_rounded,
                          color: const Color(0xFFD97706),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const FR05PendapatanScreen()),
                          ),
                        ),
                        if (!isManager)
                          _kpiTile(
                            title: 'Verifikasi Penjualan',
                            value: '${s.approvedTxCount} Disetujui',
                            sub: 'Menunggu: ${s.pendingTxCount} • Ditolak: ${s.rejectedTxCount}',
                            icon: Icons.verified_outlined,
                            color: const Color(0xFF0D9488),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const FR05PendapatanScreen()),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Rumus Indikator (Transparansi Perhitungan)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, size: 17, color: Color(0xFF1D4ED8)),
                              SizedBox(width: 6),
                              Text(
                                'Definisi & Rumus Indikator Dashboard',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                              ),
                            ],
                          ),
                          SizedBox(height: 6),
                          Text(
                            '• Kehadiran = (Hadir + Terlambat) ÷ Total catatan absensi pada periode.\n'
                            '• Penyelesaian Kunjungan = Jadwal berstatus Selesai ÷ Total jadwal kunjungan.\n'
                            '• Omzet Tercatat = Total transaksi berstatus Disetujui (transaksi Menunggu/Ditolak tidak dihitung, bukan komisi/laba).',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF1E3A8A), height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Aktivitas Terbaru
                    const Text(
                      'Aktivitas Terbaru (Dari Modul Sumber)',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kTextColor),
                    ),
                    const SizedBox(height: 10),
                    if (s.recentActivities.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          'Belum ada aktivitas terbaru.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: kSecondaryColor, fontSize: 13),
                        ),
                      )
                    else
                      ...s.recentActivities.map(
                        (act) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: kPrimaryLightColor,
                              child: Icon(Icons.bolt_rounded, color: kPrimaryColor, size: 20),
                            ),
                            title: Text(
                              act.deskripsi,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${act.modul} • ${act.userName} • ${act.tanggal}',
                              style: const TextStyle(fontSize: 11, color: kSecondaryColor),
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _kpiTile({
    required String title,
    required String value,
    required String sub,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const Spacer(),
                const Icon(Icons.arrow_forward_ios, size: 12, color: kSecondaryColor),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextColor),
                ),
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: kSecondaryColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
