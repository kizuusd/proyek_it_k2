# 01 — Perbaikan Menu Profil: Input Password Lama

## Tujuan

Menambahkan kolom **Password Lama** pada formulir ubah password di menu Profil. Saat ini kolom tersebut belum tersedia sehingga proses pengujian ubah password belum dapat dilakukan dengan verifikasi password saat ini.

## Perubahan tampilan

Pada menu **Profil → Ubah Password**, tampilkan tiga input:

1. Password Lama
2. Password Baru
3. Konfirmasi Password Baru

Semua input bertipe password dan memiliki opsi tampil/sembunyikan password jika komponen project mendukungnya.

## Aturan proses

1. Pengguna harus login.
2. Pengguna mengisi password lama, password baru, dan konfirmasi password baru.
3. Sistem mengambil akun berdasarkan pengguna yang sedang login. Jangan menerima `user_id` dari form untuk menentukan akun yang akan diubah.
4. Sistem memverifikasi password lama terhadap hash password yang tersimpan menggunakan mekanisme hashing bawaan framework.
5. Jika password lama salah, batalkan proses dan tampilkan pesan yang jelas.
6. Jika password lama benar, validasi password baru dan kecocokan konfirmasi.
7. Simpan password baru dalam bentuk hash, bukan teks biasa.
8. Setelah berhasil, tampilkan notifikasi sukses. Kebijakan logout ulang atau mempertahankan sesi mengikuti mekanisme keamanan project.

## Validasi

- Password lama wajib diisi.
- Password baru wajib diisi dan memenuhi kebijakan minimal password project.
- Konfirmasi password wajib sama dengan password baru.
- Password baru sebaiknya tidak sama dengan password lama.
- Jangan mengirim atau menampilkan hash password ke frontend.

## Kriteria penerimaan

- Kolom Password Lama muncul pada menu Profil.
- Password lama yang salah ditolak dan password tidak berubah.
- Password lama yang benar dengan konfirmasi yang sesuai berhasil mengubah password.
- Konfirmasi yang tidak cocok ditolak.
- Password baru tersimpan sebagai hash.
- Pengguna lain tidak dapat mengubah password akun yang bukan miliknya melalui manipulasi request.

## Pengujian

| Skenario | Hasil yang diharapkan |
|---|---|
| Password lama kosong | Validasi gagal |
| Password lama salah | Ditolak, data tidak berubah |
| Password baru kosong | Validasi gagal |
| Konfirmasi berbeda | Validasi gagal |
| Password lama benar dan data valid | Password berhasil diperbarui |
| Mengirim ID akun lain | Tidak dapat mengubah akun lain |
