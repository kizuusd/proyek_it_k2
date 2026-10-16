import 'package:flutter/material.dart';
import '../../constants.dart';

class FR02MasterBarangScreen extends StatelessWidget {
  const FR02MasterBarangScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Master Barang Sales', style: TextStyle(color: kTextColor)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: kTextColor),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            elevation: 2,
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                backgroundColor: kPrimaryLightColor,
                child: const Icon(Icons.inventory, color: kPrimaryColor),
              ),
              title: Text('Produk ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Stok: ${10 * (index + 1)} Box'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () {}),
                  IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () {}),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kPrimaryColor,
        onPressed: () {},
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
