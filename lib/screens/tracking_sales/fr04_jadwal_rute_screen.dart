import 'package:flutter/material.dart';
import '../../constants.dart';

class FR04PenjadwalanRuteScreen extends StatelessWidget {
  const FR04PenjadwalanRuteScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Penjadwalan Rute', style: TextStyle(color: kTextColor)),
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
              leading: const Icon(Icons.location_on, color: kPrimaryColor, size: 40),
              title: Text('Toko Sinar Makmur ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Senin, 14 September 2026\nJl. Merdeka No. 45'),
              isThreeLine: true,
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: kSecondaryColor),
                onPressed: () {},
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kPrimaryColor,
        onPressed: () {},
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Tambah Rute', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
