# 06 — Modul Penjadwalan Rute Sales

## Tujuan

Membantu Admin/Koordinator menyusun jadwal kunjungan Sales dan membantu Sales melihat urutan kunjungan yang harus dilakukan.

## Fitur

### Admin/Koordinator
- Membuat jadwal kunjungan.
- Menentukan Sales yang bertugas.
- Menentukan tanggal, waktu, tujuan/lokasi, dan urutan kunjungan.
- Mengubah atau membatalkan jadwal dengan alasan.
- Melihat jadwal per Sales dan per tanggal.

### Sales
- Melihat jadwal miliknya.
- Melihat detail tujuan, alamat, waktu, dan catatan kunjungan.
- Memperbarui status kunjungan: belum dikunjungi, dalam perjalanan (opsional), selesai, atau batal.
- Menambahkan catatan hasil kunjungan.

## Data yang disarankan

- ID jadwal.
- ID anggota Sales.
- Tanggal kunjungan.
- Waktu mulai dan waktu selesai/rentang waktu.
- Nama pelanggan/tujuan.
- Alamat tujuan.
- Latitude dan longitude (opsional).
- Nomor urutan kunjungan.
- Catatan.
- Status jadwal/kunjungan.
- ID pembuat dan waktu perubahan.

## Aturan bisnis

- Jadwal harus terhubung ke anggota Sales yang aktif.
- Waktu selesai harus setelah waktu mulai.
- Cegah bentrok jadwal Sales pada waktu yang sama, kecuali aturan shift memperbolehkan.
- Urutan kunjungan harus dapat diubah oleh pihak yang berwenang.
- Perubahan jadwal setelah dipublikasikan harus dapat diketahui oleh Sales.
- Peta/rute otomatis dan pelacakan GPS real-time bukan bagian wajib kecuali diminta sebagai ruang lingkup terpisah.

## Kriteria penerimaan

- Admin/Koordinator dapat membuat dan mengelola jadwal.
- Sales hanya melihat jadwal sendiri.
- Sistem memvalidasi bentrok jadwal.
- Status dan catatan kunjungan tersimpan serta dapat dilihat kembali.
