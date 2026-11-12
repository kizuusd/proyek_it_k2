# Dokumen Implementasi Fitur Sistem Sales

Dokumen ini berisi spesifikasi kebutuhan dan panduan implementasi fitur. Gunakan sebagai acuan saat mengembangkan project yang sudah ada, bukan sebagai instruksi untuk membuat project baru dari nol.

## Daftar dokumen

1. `01-profil-ubah-password.md` — penambahan input password lama pada menu Profil.
2. `02-data-barang-sales.md` — pengelolaan data barang/produk yang digunakan Sales.
3. `03-harga-produk.md` — pengelolaan harga produk.
4. `04-keanggotaan-sales.md` — data anggota dan status keanggotaan Sales.
5. `05-absensi-sales.md` — pencatatan dan rekap absensi Sales.
6. `06-penjadwalan-rute-sales.md` — penjadwalan kunjungan dan rute Sales.
7. `07-pencatatan-pendapatan-sales.md` — pencatatan pendapatan/hasil penjualan Sales.
8. `08-monitoring-sales.md` — pemantauan aktivitas dan kinerja Sales.

## Ketentuan umum implementasi

- Pelajari struktur project, framework, pola penamaan, autentikasi, dan database yang sudah digunakan sebelum mengubah kode.
- Pertahankan desain UI, komponen, dan pola coding yang sudah ada. Jangan membuat duplikasi halaman, tabel, atau fungsi yang sebenarnya sudah tersedia.
- Gunakan autentikasi dan otorisasi dari project. Setiap endpoint harus memeriksa hak akses di sisi server, bukan hanya menyembunyikan tombol di UI.
- Validasi seluruh input di sisi server. Validasi di sisi tampilan hanya untuk membantu pengguna.
- Gunakan relasi dan foreign key agar data Sales, barang, harga, jadwal, absensi, dan pendapatan saling terhubung.
- Simpan waktu secara konsisten. Tampilkan tanggal dan jam sesuai zona waktu aplikasi.
- Sediakan status kosong, loading, pesan berhasil, dan pesan gagal pada halaman yang memerlukan pemuatan data.
- Gunakan transaksi database untuk proses yang mengubah beberapa tabel sekaligus.
- Jangan menghapus data transaksi secara permanen tanpa kebutuhan dan persetujuan yang jelas. Utamakan status nonaktif atau soft delete jika sesuai pola project.
- Jangan menampilkan password, hash password, atau informasi sensitif pada log maupun respons API.

## Peran pengguna (acuan awal)

Sesuaikan dengan role yang benar-benar sudah ada pada project.

- **Admin:** mengelola master data, harga, anggota Sales, jadwal, dan melihat seluruh laporan/monitoring.
- **Sales:** melihat data yang diizinkan, melihat jadwal sendiri, mengisi absensi, dan mencatat hasil penjualan/pendapatan sendiri.
- **Supervisor/Koordinator (jika tersedia):** memantau Sales yang berada di bawah tanggung jawabnya dan melakukan verifikasi sesuai aturan bisnis.

Jangan menambahkan role baru sebelum memeriksa kebutuhan dan struktur role pada project.

## Kriteria selesai umum

Fitur dinyatakan selesai jika halaman dapat digunakan, data tersimpan dan tampil kembali dari database, validasi berjalan, hak akses diterapkan, relasi data benar, serta pengujian berhasil dilakukan pada skenario normal dan gagal.
