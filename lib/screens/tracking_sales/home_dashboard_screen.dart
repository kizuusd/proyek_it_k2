import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants.dart';
import '../../providers/auth_provider.dart';
import 'fr02_master_barang_screen.dart';
import 'fr03_master_harga_screen.dart';
import 'fr04_jadwal_rute_screen.dart';
import 'fr05_pendapatan_screen.dart';
import 'fr06_monitoring_posisi_screen.dart';
import 'fr07_keanggotaan_screen.dart';
import 'fr08_absensi_screen.dart';
import 'fr09_pengajuan_izin_screen.dart';
import 'fr10_pengajuan_barang_screen.dart';
import 'fr11_profil_screen.dart';

class HomeDashboardScreen extends StatelessWidget {
  const HomeDashboardScreen({Key? key}) : super(key: key);

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
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
    final user = authProvider.currentUser;

    final userName = user?.name.isNotEmpty == true ? user!.name : 'Sales Aktif';
    final userRole = user?.roleDisplayTitle ?? 'Sales Lapangan';

    Color roleBadgeColor;
    if (user?.isSuperAdmin == true) {
      roleBadgeColor = Colors.purple;
    } else if (user?.isAdmin == true) {
      roleBadgeColor = Colors.blue.shade700;
    } else {
      roleBadgeColor = Colors.teal.shade700;
    }

    final List<Map<String, dynamic>> menuItems = [
      {'title': 'Master Barang', 'icon': Icons.inventory_2, 'page': const FR02MasterBarangScreen()},
      {'title': 'Master Harga', 'icon': Icons.monetization_on, 'page': const FR03MasterHargaScreen()},
      {'title': 'Jadwal Rute', 'icon': Icons.map, 'page': const FR04PenjadwalanRuteScreen()},
      {'title': 'Pendapatan', 'icon': Icons.account_balance_wallet, 'page': const FR05PendapatanScreen()},
      {'title': 'Monitoring', 'icon': Icons.my_location, 'page': const FR06MonitoringPosisiScreen()},
      {'title': 'Keanggotaan', 'icon': Icons.people, 'page': const FR07KeanggotaanScreen()},
      {'title': 'Absensi', 'icon': Icons.fingerprint, 'page': const FR08AbsensiScreen()},
      {'title': 'Form Izin', 'icon': Icons.edit_document, 'page': const FR09PengajuanIzinScreen()},
      {'title': 'Req Barang', 'icon': Icons.add_box, 'page': const FR10PengajuanBarangScreen()},
      {'title': 'Profil', 'icon': Icons.person, 'page': const FR11ProfilScreen()},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text(
          'Dashboard Sales',
          style: TextStyle(color: kTextColor, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Logout',
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Banner Profil Dinamis dari AuthProvider
            Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: kPrimaryGradientColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: kPrimaryColor.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    backgroundImage: user?.photoUrl != null && user!.photoUrl!.isNotEmpty
                        ? NetworkImage(user.photoUrl!)
                        : null,
                    child: user?.photoUrl == null || user!.photoUrl!.isEmpty
                        ? Text(
                            userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: kPrimaryColor,
                            ),
                          )
                        : null,
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
                        // Role Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: roleBadgeColor.withOpacity(0.85),
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
            ),

            // Text Kategori Menu
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Menu Navigasi FR (Tracking Sales)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: kTextColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Grid Menu
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                itemCount: menuItems.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => menuItems[index]['page']),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: kPrimaryLightColor,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              menuItems[index]['icon'],
                              color: kPrimaryColor,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            menuItems[index]['title'],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: kTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
