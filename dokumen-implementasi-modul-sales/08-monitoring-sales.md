# 08 — Modul Monitoring Sales

## Tujuan

Menyediakan ringkasan aktivitas dan kinerja Sales berdasarkan data keanggotaan, absensi, jadwal, kunjungan, dan pencatatan penjualan yang sudah tersedia.

## Fitur

### Dashboard Admin/Koordinator
- Jumlah Sales aktif.
- Ringkasan kehadiran pada tanggal/periode terpilih.
- Jumlah jadwal kunjungan.
- Jumlah kunjungan selesai dan belum selesai.
- Total omzet/hasil penjualan berdasarkan catatan yang disetujui.
- Daftar aktivitas terbaru.
- Filter berdasarkan periode dan Sales.

### Dashboard Sales
- Ringkasan absensi sendiri.
- Jadwal kunjungan hari ini/berikutnya.
- Status kunjungan.
- Ringkasan catatan penjualan milik sendiri.
- Status verifikasi catatan.

## Indikator yang disarankan

- **Kehadiran:** jumlah hari hadir dibanding hari kerja terjadwal.
- **Penyelesaian kunjungan:** kunjungan selesai dibanding total kunjungan yang dijadwalkan.
- **Omzet tercatat:** jumlah nilai transaksi yang sudah disetujui pada periode terpilih.
- **Aktivitas:** jumlah kunjungan dan transaksi pada periode terpilih.

Rumus harus ditampilkan atau didokumentasikan agar angka dashboard dapat dipahami. Jangan menganggap omzet sebagai laba atau komisi.

## Aturan bisnis dan keamanan

- Dashboard mengambil data dari modul sumber, bukan menyimpan salinan angka yang dapat berbeda dari data transaksi.
- Terapkan filter hak akses: Sales hanya melihat data sendiri; Admin melihat seluruh data; Koordinator hanya melihat cakupan timnya jika aturan tersebut tersedia.
- Gunakan rentang tanggal yang konsisten dan jelaskan zona waktu.
- Data yang belum disetujui tidak boleh masuk ke total omzet disetujui.
- Jangan menampilkan lokasi real-time atau data pribadi yang tidak dibutuhkan.
- Sediakan kondisi ketika belum ada data.

## Kriteria penerimaan

- Angka ringkasan sesuai dengan data sumber.
- Filter periode dan Sales berjalan.
- Hak akses diterapkan di server.
- Dashboard menampilkan status kosong jika belum ada data.
- Data monitoring dapat ditelusuri ke absensi, jadwal, atau transaksi sumber.
