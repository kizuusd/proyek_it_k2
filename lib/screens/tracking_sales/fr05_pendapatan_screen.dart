import 'package:flutter/material.dart';
import '../../constants.dart';

class FR05PendapatanScreen extends StatelessWidget {
  const FR05PendapatanScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pendapatan Sales', style: TextStyle(color: kTextColor)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: kTextColor),
        actions: [
          IconButton(icon: const Icon(Icons.filter_list), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: kPrimaryGradientColor,
              borderRadius: BorderRadius.circular(20),
            ),
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Total Pendapatan (Minggu Ini)', style: TextStyle(color: Colors.white, fontSize: 16)),
                SizedBox(height: 10),
                Text('Rp 15.450.000', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Daftar Transaksi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextColor)),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 6,
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: kPrimaryLightColor,
                      child: const Icon(Icons.receipt_long, color: kPrimaryColor),
                    ),
                    title: Text('INV-20260914-00${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('14 Sep 2026, 14:30'),
                    trailing: Text('+ Rp ${150 * (index + 1)}.000', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
