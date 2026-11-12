# 02 — Modul Data Barang untuk Sales

## Tujuan

Menyediakan data barang/produk yang dapat digunakan dalam aktivitas Sales, seperti melihat katalog produk dan memilih barang saat mencatat transaksi atau hasil penjualan.

> Interpretasi istilah: permintaan “data bareng sales” ditafsirkan sebagai **data barang Sales**. Jika yang dimaksud adalah data lain, nama dan ruang lingkup modul perlu disesuaikan.

## Fitur

### Admin
- Melihat daftar barang.
- Menambah barang.
- Mengubah informasi barang.
- Mengaktifkan atau menonaktifkan barang.
- Mencari dan memfilter barang berdasarkan nama, kode, kategori, atau status.

### Sales
- Melihat daftar barang yang aktif dan boleh ditawarkan.
- Melihat detail barang, kode, kategori, deskripsi, dan harga yang berlaku.
- Memilih barang saat membuat catatan penjualan, jika fitur transaksi tersedia.

## Data yang disarankan

- ID barang.
- Kode barang unik.
- Nama barang.
- Kategori (opsional).
- Deskripsi (opsional).
- Satuan.
- Foto/gambar (opsional).
- Status aktif/nonaktif.
- Waktu dibuat dan diperbarui.

Harga sebaiknya dikelola melalui modul Harga Produk agar perubahan harga memiliki riwayat dan tidak menimpa data master barang.

## Aturan bisnis

- Kode barang harus unik.
- Barang nonaktif tidak dapat dipilih untuk transaksi baru.
- Data barang yang sudah digunakan pada transaksi tidak dihapus permanen.
- Perubahan nama atau deskripsi barang tidak boleh mengubah catatan transaksi historis.
- Jika stok tidak termasuk ruang lingkup project, jangan menambahkan perhitungan stok secara otomatis.

## Kriteria penerimaan

- Admin dapat melakukan CRUD sesuai hak akses.
- Sales hanya dapat melihat barang yang aktif.
- Pencarian dan filter berjalan.
- Barang yang sudah dipakai dalam transaksi tetap dapat ditampilkan pada riwayat.
