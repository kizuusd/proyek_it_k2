# 05 — Modul Absensi Sales

## Tujuan

Mencatat kehadiran Sales dan menyediakan rekap absensi untuk Admin/Koordinator.

## Fitur

### Sales
- Melakukan check-in.
- Melakukan check-out.
- Melihat riwayat absensi sendiri.
- Melihat status absensi harian.

### Admin/Koordinator
- Melihat absensi seluruh Sales atau anggota dalam cakupannya.
- Memfilter berdasarkan nama Sales, tanggal, dan status.
- Melihat detail jam check-in/check-out.
- Melakukan koreksi absensi dengan alasan dan jejak perubahan, jika diizinkan.

## Data yang disarankan

- ID absensi.
- ID anggota Sales.
- Tanggal absensi.
- Waktu check-in.
- Waktu check-out.
- Status: hadir, terlambat, izin, sakit, atau alpa (sesuaikan kebijakan).
- Catatan/alasan (opsional).
- Sumber pencatatan (opsional).
- Koordinat/lokasi (opsional, hanya jika memang diperlukan dan kebijakan privasi mengizinkan).
- ID pemeriksa/korektor dan waktu koreksi (opsional).

## Aturan bisnis

- Satu Sales hanya memiliki satu catatan absensi per tanggal, kecuali project mendukung beberapa shift.
- Check-out tidak boleh lebih awal dari check-in.
- Check-in/check-out harus menggunakan waktu server sebagai acuan utama.
- Permintaan check-in ganda harus ditolak atau ditangani secara idempoten.
- Koreksi oleh Admin harus menyimpan nilai sebelum dan sesudah serta alasannya.
- Jangan mengaktifkan pelacakan lokasi tanpa kebutuhan yang jelas, pemberitahuan, dan persetujuan yang sesuai.

## Kriteria penerimaan

- Sales dapat check-in dan check-out.
- Sistem mencegah absensi ganda yang tidak valid.
- Sales hanya dapat melihat absensi sendiri.
- Admin/Koordinator dapat melihat rekap sesuai hak akses.
- Koreksi absensi tercatat dalam audit trail.
