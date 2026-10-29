import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../constants.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/user_avatar.dart';
import 'fr02_master_barang_screen.dart';
import 'fr03_master_harga_screen.dart';
import 'fr04_jadwal_rute_screen.dart';
import 'fr05_pendapatan_screen.dart';
import 'fr06_monitoring_posisi_screen.dart';
import 'fr08_absensi_screen.dart';
import 'fr09_pengajuan_izin_screen.dart';
import 'fr10_pengajuan_barang_screen.dart';
import 'fr11_profil_screen.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({Key? key}) : super(key: key);

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _hasRedirected = false;

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Konfirmasi Keluar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari sesi akun ini?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal', style: TextStyle(color: kSecondaryColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              await authProvider.logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              }
            },
            child: const Text('Keluar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    // 1. Cek Sesi: Tampilkan indikator saat sistem sedang memvalidasi sesi
    if (authProvider.isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F6F9),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: kPrimaryColor),
              SizedBox(height: 16),
              Text(
                'Memverifikasi sesi login...',
                style: TextStyle(color: kSecondaryColor, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    // 2. Proteksi Akses: User belum login TIDAK BISA masuk ke Dashboard
    if (!authProvider.isAuthenticated || authProvider.currentUser == null) {
      if (!_hasRedirected) {
        _hasRedirected = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
          }
        });
      }

      return Scaffold(
        backgroundColor: const Color(0xFFF5F6F9),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_person_rounded,
                      size: 64,
                      color: Colors.redAccent,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Akses Dashboard Dibatasi',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: kTextColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Anda belum masuk ke sistem. Silakan login terlebih dahulu untuk mengakses menu dashboard dan data operasional CV Maju Bersama.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: kSecondaryColor),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/login',
                          (route) => false,
                        );
                      },
                      icon: const Icon(Icons.login, color: Colors.white),
                      label: const Text(
                        'Masuk ke Akun (Login)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final user = authProvider.currentUser;

    final userName = user?.name.isNotEmpty == true ? user!.name : 'Sales Aktif';
    final userRole = user?.roleDisplayTitle ?? 'Sales Lapangan';

    Color roleBadgeColor;
    Color rolePrimaryColor;
    Color roleLightColor;
    LinearGradient roleGradient;
    if (user?.isSuperAdmin == true) {
      roleBadgeColor = const Color(0xFF581C87);
      rolePrimaryColor = const Color(0xFF6B21A8);
      roleLightColor = const Color(0xFFF3E8FF);
      roleGradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF6B21A8), Color(0xFF4C1D95)],
      );
    } else if (user?.isAdmin == true) {
      roleBadgeColor = Colors.blue.shade800;
      rolePrimaryColor = const Color(0xFF1D4ED8);
      roleLightColor = const Color(0xFFEFF6FF);
      roleGradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1D4ED8), Color(0xFF1E3A8A)],
      );
    } else {
      roleBadgeColor = const Color(0xFF065F46);
      rolePrimaryColor = const Color(0xFF047857);
      roleLightColor = const Color(0xFFECFDF5);
      roleGradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF047857), Color(0xFF065F46)],
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF5F6F9),
      // 3. Sidebar Menu (Drawer) yang memuat seluruh menu utama aplikasi
      drawer: const AppDrawer(currentRoute: 'dashboard'),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: kTextColor),
          tooltip: 'Menu',
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text(
          'Dashboard Sales',
          style: TextStyle(color: kTextColor, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.person_outline, color: rolePrimaryColor),
            tooltip: 'Profil Saya',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FR11ProfilScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Logout',
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner Profil Dinamis dari AuthProvider
              Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: roleGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: rolePrimaryColor.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Avatar (Sesuai Foto Profil Login Gmail / Akun)
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: UserAvatar(
                            photoUrl: user?.photoUrl,
                            name: userName,
                            radius: 30,
                            backgroundColor: Colors.white,
                            textColor: rolePrimaryColor,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Halo, $userName!',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              // Role Badge & Google Link Status
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: roleBadgeColor.withValues(alpha: 0.85),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.white54),
                                    ),
                                    child: Text(
                                      userRole,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (user?.googleId != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.white54),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SvgPicture.asset('assets/icons/google-icon.svg', width: 12, height: 12),
                                          const SizedBox(width: 4),
                                          const Text(
                                            'Google Terhubung',
                                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user?.email ?? 'CV Maju Bersama',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              if (user?.isSales == true && user?.googleId == null) ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    children: [
                      SvgPicture.asset('assets/icons/google-icon.svg', width: 28, height: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tautkan Akun Google Anda',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: kTextColor),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Masuk cepat di lapangan tanpa perlu ketik kata sandi.',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryColor,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const FR11ProfilScreen()),
                          );
                        },
                        child: const Text('Tautkan', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                const SizedBox(height: 8),
              ],

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  'Ringkasan Kinerja Hari Ini',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: kTextColor,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final int cols = constraints.maxWidth >= 680 ? 4 : 2;
                    final double itemWidth =
                        (constraints.maxWidth - ((cols - 1) * 12)) / cols;
                    final double aspect = (itemWidth / 108).clamp(1.15, 1.85);

                    return GridView.count(
                      crossAxisCount: cols,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: aspect,
                      children: [
                        _buildKpiCard(
                          icon: Icons.account_balance_wallet,
                          iconBgColor: Colors.blue.shade50,
                          iconColor: Colors.blue.shade700,
                          title: 'Pendapatan Minggu Ini',
                          value: 'Rp 15.450.000',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const FR05PendapatanScreen()),
                            );
                          },
                        ),
                        _buildKpiCard(
                          icon: Icons.map,
                          iconBgColor: Colors.green.shade50,
                          iconColor: Colors.green.shade700,
                          title: 'Jadwal Rute',
                          value: '5 Titik Kunjungan',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const FR04PenjadwalanRuteScreen()),
                            );
                          },
                        ),
                        _buildKpiCard(
                          icon: Icons.fingerprint,
                          iconBgColor: Colors.teal.shade50,
                          iconColor: Colors.teal.shade700,
                          title: 'Status Presensi',
                          value: 'Hadir (07:45 WIB)',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const FR08AbsensiScreen()),
                            );
                          },
                        ),
                        _buildKpiCard(
                          icon: Icons.assignment_turned_in,
                          iconBgColor: Colors.purple.shade50,
                          iconColor: Colors.purple.shade700,
                          title: 'Status Perizinan',
                          value: 'Terverifikasi',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const FR09PengajuanIzinScreen()),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 22),

              // Bagian Akses Cepat Modul Utama
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  'Akses Cepat',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: kTextColor,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    if (user?.isSuperAdmin == true || user?.isAdmin == true) ...[
                      _buildQuickActionBtn(
                        icon: Icons.inventory_2,
                        label: 'Barang',
                        accentColor: rolePrimaryColor,
                        bgColor: roleLightColor,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const FR02MasterBarangScreen()),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    _buildQuickActionBtn(
                      icon: Icons.monetization_on,
                      label: 'Harga',
                      accentColor: rolePrimaryColor,
                      bgColor: roleLightColor,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const FR03MasterHargaScreen()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildQuickActionBtn(
                      icon: Icons.my_location,
                      label: 'Monitoring',
                      accentColor: rolePrimaryColor,
                      bgColor: roleLightColor,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const FR06MonitoringPosisiScreen()),
                      ),
                    ),
                    if (user?.isSuperAdmin != true && user?.isAdmin != true) ...[
                      const SizedBox(width: 10),
                      _buildQuickActionBtn(
                        icon: Icons.add_shopping_cart,
                        label: 'Req Barang',
                        accentColor: rolePrimaryColor,
                        bgColor: roleLightColor,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const FR10PengajuanBarangScreen()),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // Kartu Pengumuman / Status Operasional
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'Info Operasional CV Maju Bersama',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: kTextColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Pastikan selalu mencatat absensi dan update titik rute kunjungan toko harian.\n'
                      '• Menu lengkap seluruh fitur aplikasi dapat diakses kapan saja melalui Sidebar Menu.\n'
                      '• Untuk bantuan teknis hubungi bagian Administrator.',
                      style: TextStyle(fontSize: 12, color: kSecondaryColor, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
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
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: kTextColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: kSecondaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionBtn({
    required IconData icon,
    required String label,
    Color accentColor = kPrimaryColor,
    Color bgColor = kPrimaryLightColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: kTextColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
