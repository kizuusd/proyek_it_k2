import 'package:flutter/material.dart';
import '../../constants.dart';

class FR07KeanggotaanScreen extends StatelessWidget {
  const FR07KeanggotaanScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Keanggotaan', style: TextStyle(color: kTextColor)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: kTextColor),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            elevation: 2,
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const CircleAvatar(
                radius: 25,
                backgroundImage: NetworkImage('https://via.placeholder.com/150'), // Dummy Avatar
              ),
              title: Text('Anggota ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(index % 2 == 0 ? 'Sales' : 'Administrator'),
              trailing: IconButton(
                icon: const Icon(Icons.more_vert, color: kSecondaryColor),
                onPressed: () {},
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kPrimaryColor,
        onPressed: () {},
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Tambah Anggota', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
