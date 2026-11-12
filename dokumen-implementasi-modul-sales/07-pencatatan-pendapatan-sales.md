# 07 — Modul Pencatatan Pendapatan Sales

## Tujuan

Mencatat hasil penjualan atau pendapatan yang diperoleh Sales dan menyediakan rekap untuk kebutuhan administrasi.

## Fitur

### Sales
- Membuat catatan penjualan/pendapatan.
- Memilih produk dan mengisi jumlah.
- Melihat subtotal dan total.
- Menambahkan tanggal transaksi, pelanggan, serta catatan bila diperlukan.
- Melihat riwayat catatan miliknya.
- Melihat status verifikasi.

### Admin/Koordinator
- Melihat seluruh catatan sesuai cakupan akses.
- Memeriksa detail catatan.
- Menyetujui atau menolak catatan dengan alasan.
- Memfilter berdasarkan Sales, produk, tanggal, dan status.
- Melihat rekap total.

## Data yang disarankan

**Header transaksi**
- ID transaksi.
- Nomor transaksi unik.
- ID anggota Sales.
- Tanggal transaksi.
- Nama/ID pelanggan (opsional).
- Total transaksi.
- Status verifikasi: menunggu, disetujui, atau ditolak.
- Catatan.
- ID pemeriksa dan waktu pemeriksaan.

**Detail transaksi**
- ID transaksi detail.
- ID produk.
- Jumlah.
- Harga satuan saat transaksi.
- Subtotal.

## Aturan bisnis

- Jumlah harus lebih besar dari nol.
- Harga satuan dan total dihitung di server; jangan mempercayai total yang dikirim dari browser.
- Simpan harga saat transaksi dibuat agar riwayat tidak berubah ketika harga master diperbarui.
- Gunakan tipe data decimal untuk nilai uang.
- Catatan yang sudah disetujui tidak boleh diedit langsung. Gunakan proses koreksi/pembatalan dengan audit trail.
- Definisikan dengan jelas apakah “pendapatan” berarti omzet penjualan, komisi Sales, atau uang yang benar-benar diterima. Jangan menyamakan ketiganya tanpa aturan bisnis.
- Jika pembayaran/komisi belum termasuk ruang lingkup, tampilkan sebagai data terpisah atau tandai belum dihitung.

## Kriteria penerimaan

- Sales dapat membuat dan melihat catatan miliknya.
- Total dihitung secara konsisten di server.
- Admin/Koordinator dapat memverifikasi catatan.
- Riwayat transaksi menyimpan harga saat transaksi.
- Rekap dapat difilter berdasarkan periode dan Sales.
