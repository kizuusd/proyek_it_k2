# 04 — Modul Keanggotaan Sales

## Tujuan

Mengelola data anggota Sales, status keanggotaan, dan hubungan akun pengguna dengan profil Sales.

## Fitur

### Admin
- Melihat daftar anggota Sales.
- Menambahkan anggota Sales atau menghubungkan akun pengguna yang sudah ada.
- Mengubah data profil Sales.
- Mengaktifkan, menonaktifkan, atau menangguhkan keanggotaan.
- Melihat detail dan riwayat status anggota.

### Sales
- Melihat profil dan status keanggotaannya sendiri.
- Memperbarui informasi pribadi yang memang diizinkan.
- Tidak dapat mengubah status keanggotaan sendiri.

## Data yang disarankan

- ID anggota Sales.
- ID akun pengguna (relasi ke tabel pengguna).
- Nomor/kode Sales yang unik.
- Nama lengkap.
- Nomor telepon.
- Email (gunakan akun utama jika sudah tersedia).
- Alamat (opsional).
- Tanggal bergabung.
- Status: aktif, nonaktif, atau ditangguhkan.
- ID atasan/koordinator (opsional, hanya jika struktur organisasi mendukung).
- Waktu dibuat dan diperbarui.

## Aturan bisnis

- Satu akun pengguna tidak boleh memiliki profil Sales ganda.
- Kode Sales harus unik.
- Sales nonaktif/ditangguhkan tidak boleh membuat aktivitas baru jika kebijakan bisnis melarangnya.
- Data Sales yang sudah memiliki absensi, jadwal, atau pendapatan tidak dihapus permanen.
- Perubahan status harus mencatat siapa yang mengubah dan kapan perubahan dilakukan.

## Kriteria penerimaan

- Admin dapat mengelola anggota Sales.
- Relasi akun dan profil Sales konsisten.
- Sales hanya dapat melihat atau mengubah informasi miliknya yang diizinkan.
- Status keanggotaan memengaruhi akses sesuai aturan aplikasi.
