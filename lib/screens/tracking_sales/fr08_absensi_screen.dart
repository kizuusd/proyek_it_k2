import 'package:flutter/material.dart';
import '../../constants.dart';

class FR08AbsensiScreen extends StatelessWidget {
  const FR08AbsensiScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Absensi Sales', style: TextStyle(color: kTextColor)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: kTextColor),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kSecondaryColor.withOpacity(0.5)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.camera_alt, size: 60, color: kSecondaryColor),
                  SizedBox(height: 10),
                  Text('Kamera Utama (Selfie Kehadiran)', style: TextStyle(color: kSecondaryColor)),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.location_on, color: kPrimaryColor),
                SizedBox(width: 8),
                Text('Lokasi: Jl. Jend. Sudirman, Jakarta', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 40),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: () {},
                    child: const Text('Clock-In', style: TextStyle(fontSize: 18, color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: () {},
                    child: const Text('Clock-Out', style: TextStyle(fontSize: 18, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
