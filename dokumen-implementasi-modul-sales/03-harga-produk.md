# 03 — Modul Harga Produk

## Tujuan

Mengelola harga jual produk agar Sales menggunakan harga yang berlaku dan Admin dapat menelusuri perubahan harga.

## Fitur

### Admin
- Melihat daftar harga produk.
- Menambahkan harga baru untuk produk.
- Mengubah harga dengan membuat catatan perubahan/riwayat.
- Menentukan tanggal mulai berlaku dan, bila diperlukan, tanggal berakhir.
- Melihat riwayat harga setiap produk.

### Sales
- Melihat harga produk yang sedang berlaku.
- Melihat informasi harga saat memilih produk untuk pencatatan penjualan.
- Tidak dapat mengubah harga kecuali memang diizinkan oleh aturan role project.

## Data yang disarankan

- ID harga.
- ID barang/produk.
- Nominal harga.
- Tanggal mulai berlaku.
- Tanggal akhir berlaku (opsional).
- Status harga.
- ID pengguna yang membuat perubahan.
- Waktu dibuat.

## Aturan bisnis

- Harga harus berupa angka positif dan menggunakan tipe data numerik/decimal, bukan floating point untuk perhitungan uang.
- Setiap harga harus terhubung ke satu produk.
- Tentukan satu harga aktif untuk produk pada waktu tertentu; hindari periode harga aktif yang saling tumpang tindih.
- Ketika transaksi dicatat, simpan **salinan nominal harga saat transaksi** pada detail transaksi. Jangan hanya mengambil harga terbaru dari master karena harga dapat berubah.
- Perubahan harga harus memiliki jejak audit: pengguna, waktu, harga sebelumnya, dan harga baru.

## Kriteria penerimaan

- Admin dapat membuat harga baru.
- Sales hanya melihat harga yang berlaku dan diizinkan.
- Riwayat perubahan harga dapat ditelusuri.
- Transaksi lama tetap menampilkan harga saat transaksi dibuat.
