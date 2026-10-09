import 'package:flutter/material.dart';
import '../../constants.dart';

class FR11ProfilScreen extends StatelessWidget {
  const FR11ProfilScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Pribadi', style: TextStyle(color: kTextColor)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: kTextColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Center(
              child: CircleAvatar(
                radius: 60,
                backgroundImage: NetworkImage('https://via.placeholder.com/150'), // Dummy Avatar
              ),
            ),
            const SizedBox(height: 20),
            const Text('Dimas Brahamsyah', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const Text('Sales Lapangan', style: TextStyle(color: kSecondaryColor, fontSize: 16)),
            const SizedBox(height: 40),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: kPrimaryLightColor, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.email, color: kPrimaryColor),
              ),
              title: const Text('Email'),
              subtitle: const Text('dimas@majubersama.com'),
            ),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: kPrimaryLightColor, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.phone, color: kPrimaryColor),
              ),
              title: const Text('Nomor HP'),
              subtitle: const Text('+62 812 3456 7890'),
            ),
            const Divider(),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () {},
                child: const Text('Edit Profil', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () {},
                child: const Text('Logout', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
