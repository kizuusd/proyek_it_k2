import 'package:flutter/material.dart';
import '../../constants.dart';
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

  @override
  Widget build(BuildContext context) {
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
      backgroundColor: const Color(0xFFF5F6F9), // Warna background abu-abu terang standar template
      appBar: AppBar(
        title: const Text('Dashboard Sales', style: TextStyle(color: kTextColor, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kTextColor),
          onPressed: () {
            // Kembali ke halaman login
            Navigator.pushReplacementNamed(context, '/login');
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Banner Profil
            Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: kPrimaryGradientColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: kPrimaryColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5)),
                ],
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 40, color: kPrimaryColor),
                  ),
                  const SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Halo, Dimas!', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      SizedBox(height: 5),
                      Text('Selamat bekerja hari ini.', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ],
              ),
            ),
            
            // Text Kategori Menu
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Menu Navigasi FR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextColor)),
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
                          BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 5),
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
                            child: Icon(menuItems[index]['icon'], color: kPrimaryColor, size: 28),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            menuItems[index]['title'],
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kTextColor),
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
