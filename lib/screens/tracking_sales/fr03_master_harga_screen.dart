import 'package:flutter/material.dart';
import '../../constants.dart';

class FR03MasterHargaScreen extends StatefulWidget {
  const FR03MasterHargaScreen({Key? key}) : super(key: key);

  @override
  State<FR03MasterHargaScreen> createState() => _FR03MasterHargaScreenState();
}

class _FR03MasterHargaScreenState extends State<FR03MasterHargaScreen> {
  // Data dummy (State)
  final List<Map<String, dynamic>> _produkList = [
    {'nama': 'Produk 1', 'harga': 15000},
    {'nama': 'Produk 2', 'harga': 30000},
    {'nama': 'Produk 3', 'harga': 45000},
    {'nama': 'Produk 4', 'harga': 60000},
    {'nama': 'Produk 5', 'harga': 75000},
  ];

  // Menampilkan modal dialog untuk mengubah harga
  void _tampilkanDialogUbahHarga(int index) {
    final TextEditingController _hargaController = TextEditingController(
      text: _produkList[index]['harga'].toString(),
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(
            'Ubah Harga - ${_produkList[index]['nama']}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _hargaController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Harga Baru (Rp)',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                if (_hargaController.text.isNotEmpty) {
                  setState(() {
                    _produkList[index]['harga'] = int.tryParse(_hargaController.text) ?? 0;
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Simpan', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, // Menghindari crash pada Flutter Web karena On-Screen Keyboard
      appBar: AppBar(
        title: const Text('Master Harga Produk', style: TextStyle(color: kTextColor)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: kTextColor),
      ),
      body: _produkList.isEmpty
          ? const Center(child: Text('Data harga produk kosong'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _produkList.length,
              itemBuilder: (context, index) {
                final item = _produkList[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: kPrimaryLightColor,
                          child: Icon(Icons.monetization_on, color: kPrimaryColor),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item['nama']?.toString() ?? 'Produk Tanpa Nama', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text(
                                'Rp ${item['harga'] ?? 0}',
                                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 80, // Tambahkan explicit width agar tidak infinite
                          height: 35,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimaryColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: EdgeInsets.zero, // Hapus padding horizontal agar tidak over-constraint
                            ),
                            onPressed: () => _tampilkanDialogUbahHarga(index),
                            child: const Text('Ubah', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
