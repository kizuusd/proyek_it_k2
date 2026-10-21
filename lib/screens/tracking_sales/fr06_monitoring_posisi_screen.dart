import 'package:flutter/material.dart';
import '../../constants.dart';

class FR06MonitoringPosisiScreen extends StatelessWidget {
  const FR06MonitoringPosisiScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoring Posisi', style: TextStyle(color: kTextColor)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: kTextColor),
      ),
      body: Stack(
        children: [
          // Placeholder for Google Maps
          Container(
            color: Colors.grey[300],
            width: double.infinity,
            height: double.infinity,
            child: const Center(
              child: Text(
                'Google Maps Placeholder',
                style: TextStyle(fontSize: 24, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 4,
              child: const Padding(
                padding: EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundImage: NetworkImage('https://via.placeholder.com/150'), // Dummy Avatar
                        ),
                        SizedBox(width: 15),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Dimas Brahamsyah', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            Text('Sales Lapangan - Aktif', style: TextStyle(color: Colors.green)),
                          ],
                        ),
                      ],
                    ),
                    Divider(height: 30, thickness: 1),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Lokasi Terakhir:', style: TextStyle(color: kSecondaryColor)),
                        Text('Jl. Sudirman No. 12', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Update Waktu:', style: TextStyle(color: kSecondaryColor)),
                        Text('Baru saja', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
