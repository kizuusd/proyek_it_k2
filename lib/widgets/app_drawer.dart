import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../providers/auth_provider.dart';
import '../screens/tracking_sales/fr02_master_barang_screen.dart';
import '../screens/tracking_sales/fr03_master_harga_screen.dart';
import '../screens/tracking_sales/fr04_jadwal_rute_screen.dart';
import '../screens/tracking_sales/fr05_pendapatan_screen.dart';
import '../screens/tracking_sales/fr06_monitoring_posisi_screen.dart';
import '../screens/tracking_sales/fr07_keanggotaan_screen.dart';
import '../screens/tracking_sales/fr08_absensi_screen.dart';
import '../screens/tracking_sales/fr09_pengajuan_izin_screen.dart';
import '../screens/tracking_sales/fr10_pengajuan_barang_screen.dart';
import '../screens/tracking_sales/fr11_profil_screen.dart';
import '../screens/tracking_sales/fr12_register_screen.dart';
import 'user_avatar.dart';

class AppDrawer extends StatelessWidget {
  final String currentRoute;

  const AppDrawer({
    super.key,
    this.currentRoute = 'dashboard',
  });

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.redAccent),
            SizedBox(width: 8),
            Text(
              'Konfirmasi Keluar',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
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

  void _navigateTo(BuildContext context, Widget page, String routeName) {
    Navigator.of(context).pop(); // Tutup drawer terlebih dahulu
    if (currentRoute == routeName) return;

    if (routeName == 'dashboard') {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } else if (currentRoute != 'dashboard') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => page),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => page),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    final userName = user?.name.isNotEmpty == true ? user!.name : 'Sales Aktif';
    final userRole = user?.roleDisplayTitle ?? 'Sales Lapangan';

    Color roleBadgeColor;
    Color rolePrimaryColor;
    LinearGradient roleGradient;
    if (user?.isSuperAdmin == true) {
      roleBadgeColor = const Color(0xFF581C87);
      rolePrimaryColor = const Color(0xFF6B21A8);
      roleGradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF6B21A8), Color(0xFF4C1D95)],
      );
    } else if (user?.isAdmin == true) {
      roleBadgeColor = Colors.blue.shade800;
      rolePrimaryColor = const Color(0xFF1D4ED8);
      roleGradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1D4ED8), Color(0xFF1E3A8A)],
      );
    } else {
      roleBadgeColor = const Color(0xFF065F46);
      rolePrimaryColor = const Color(0xFF047857);
      roleGradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF047857), Color(0xFF065F46)],
      );
    }

    final bool isManagerial = (user?.isSuperAdmin == true || user?.isAdmin == true);
    final String izinMenuTitle = isManagerial ? 'Daftar Izin Sales' : 'Pengajuan Izin Sales';

    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // Header Drawer dengan info Profil & Brand CV Maju Bersama
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 44, 16, 16),
            decoration: BoxDecoration(
              gradient: roleGradient,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: UserAvatar(
                        photoUrl: user?.photoUrl,
                        name: userName,
                        radius: 26,
                        backgroundColor: Colors.white,
                        textColor: rolePrimaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.business,
                                size: 14,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'CV MAJU BERSAMA',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: roleBadgeColor.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white54, width: 0.8),
                            ),
                            child: Text(
                              userRole,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  user?.email ?? 'sales@majubersama.com',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Menu Navigasi Sidebar (List Modul FR)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildSectionHeader('NAVIGASI UTAMA'),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.dashboard_rounded,
                  title: 'Dashboard Sales',
                  routeName: 'dashboard',
                  onTap: () {
                    Navigator.of(context).pop();
                    if (currentRoute != 'dashboard') {
                      Navigator.pushReplacementNamed(context, '/dashboard');
                    }
                  },
                ),

                const Divider(height: 16, indent: 16, endIndent: 16),
                _buildSectionHeader('MASTER DATA & LOGISTIK'),
                if (user?.isSuperAdmin == true || user?.isAdmin == true)
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.inventory_2_outlined,
                    title: 'Master Barang',
                    routeName: 'master_barang',
                    onTap: () => _navigateTo(
                      context,
                      const FR02MasterBarangScreen(),
                      'master_barang',
                    ),
                  ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.monetization_on_outlined,
                  title: 'Master Harga',
                  routeName: 'master_harga',
                  onTap: () => _navigateTo(
                    context,
                    const FR03MasterHargaScreen(),
                    'master_harga',
                  ),
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.alt_route_rounded,
                  title: 'Jadwal Rute',
                  routeName: 'jadwal_rute',
                  onTap: () => _navigateTo(
                    context,
                    const FR04PenjadwalanRuteScreen(),
                    'jadwal_rute',
                  ),
                ),
                if (user?.isSuperAdmin != true && user?.isAdmin != true)
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.add_shopping_cart_outlined,
                    title: 'Pengajuan Barang (Req)',
                    routeName: 'pengajuan_barang',
                    onTap: () => _navigateTo(
                      context,
                      const FR10PengajuanBarangScreen(),
                      'pengajuan_barang',
                    ),
                  ),

                const Divider(height: 16, indent: 16, endIndent: 16),
                _buildSectionHeader('OPERASIONAL SALES'),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Pendapatan Sales',
                  routeName: 'pendapatan',
                  onTap: () => _navigateTo(
                    context,
                    const FR05PendapatanScreen(),
                    'pendapatan',
                  ),
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.my_location_outlined,
                  title: 'Monitoring Posisi',
                  routeName: 'monitoring',
                  onTap: () => _navigateTo(
                    context,
                    const FR06MonitoringPosisiScreen(),
                    'monitoring',
                  ),
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.people_outline_rounded,
                  title: 'Data Keanggotaan',
                  routeName: 'keanggotaan',
                  onTap: () => _navigateTo(
                    context,
                    const FR07KeanggotaanScreen(),
                    'keanggotaan',
                  ),
                ),
                if (isManagerial) ...[
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.person_add_alt_1_rounded,
                    title: 'Daftarkan Sales Baru',
                    routeName: 'register_sales',
                    onTap: () => _navigateTo(
                      context,
                      const FR12RegisterScreen(),
                      'register_sales',
                    ),
                  ),
                ],
                _buildDrawerItem(
                  context: context,
                  icon: Icons.fingerprint_rounded,
                  title: 'Presensi & Absensi',
                  routeName: 'absensi',
                  onTap: () => _navigateTo(
                    context,
                    const FR08AbsensiScreen(),
                    'absensi',
                  ),
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.assignment_outlined,
                  title: izinMenuTitle,
                  routeName: 'pengajuan_izin',
                  onTap: () => _navigateTo(
                    context,
                    const FR09PengajuanIzinScreen(),
                    'pengajuan_izin',
                  ),
                ),

                const Divider(height: 16, indent: 16, endIndent: 16),
                _buildSectionHeader('AKUN & PENGATURAN'),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.person_outline_rounded,
                  title: 'Profil Saya',
                  routeName: 'profil',
                  onTap: () => _navigateTo(
                    context,
                    const FR11ProfilScreen(),
                    'profil',
                  ),
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.logout_rounded,
                  title: 'Keluar (Logout)',
                  routeName: 'logout',
                  iconColor: Colors.redAccent,
                  textColor: Colors.redAccent,
                  onTap: () {
                    Navigator.of(context).pop();
                    _confirmLogout(context);
                  },
                ),
              ],
            ),
          ),

          // Footer Drawer: Info Versi & Status Sistem
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'CV Maju Bersama • v1.0.0',
                    style: TextStyle(
                      fontSize: 11,
                      color: kSecondaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Text(
                  'Online',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: kSecondaryColor,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String routeName,
    Color? iconColor,
    Color? textColor,
    required VoidCallback onTap,
  }) {
    final bool isSelected = currentRoute == routeName;
    final user = context.read<AuthProvider>().currentUser;
    final Color activeColor = user?.isSuperAdmin == true
        ? const Color(0xFF6B21A8)
        : (user?.isAdmin == true ? const Color(0xFF1D4ED8) : const Color(0xFF047857));
    final Color activeBgColor = user?.isSuperAdmin == true
        ? const Color(0xFFF3E8FF)
        : (user?.isAdmin == true ? const Color(0xFFEFF6FF) : const Color(0xFFECFDF5));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: isSelected ? activeBgColor : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: ListTile(
          dense: true,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          leading: Icon(
            icon,
            size: 22,
            color: iconColor ?? (isSelected ? activeColor : const Color(0xFF4B5563)),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: textColor ?? (isSelected ? activeColor : kTextColor),
            ),
          ),
          trailing: isSelected
              ? Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: activeColor,
                    shape: BoxShape.circle,
                  ),
                )
              : null,
          onTap: onTap,
        ),
      ),
    );
  }
}
