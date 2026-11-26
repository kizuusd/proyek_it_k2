# Backend REST API Node.js & MySQL (Tracking Sales CV Maju Bersama)

Backend ini dibangun menggunakan **Node.js (Express)** dan terhubung langsung ke basis data **MySQL / MariaDB (`db_tracking_sales`)**.

## 📌 Fitur Backend
1. **Autentikasi Email & Password (`POST /api/auth/login`)**:
   - Mendukung enkripsi password `bcrypt` dan plaintext dev (`password123`).
   - Validasi hak akses (`superadmin`/`owner`, `administrator`/`admin`, `sales`).
   - Pengecekan status akun aktif (`is_active = 1` dan `deleted_at IS NULL`).
   - Pencatatan otomatis token sesi ke tabel `user_tokens` dan riwayat ke `activity_logs`.
2. **Autentikasi Google (Gmail) (`POST /api/auth/google-login`)**:
   - Sinkronisasi `google_id`, `google_email`, dan `photo_url` pada tabel `users`.
   - Pencatatan otomatis token sesi ke tabel `user_tokens` dan riwayat ke `activity_logs`.
   - **Aturan Keamanan**: Sales tidak bisa mendaftar mandiri via Google; akun yang belum terdaftar akan ditolak dengan pesan instruksi.
3. **Registrasi Akun Sales Manajerial (`POST /api/auth/register-sales`)**:
   - Khusus dapat dipanggil oleh Admin atau Owner (`manager_id` tercatat di `users.created_by`).
   - Mencegah duplikasi email.
4. **Logout & Revoke Token (`POST /api/auth/logout`)**:
   - Mencabut token aktif di tabel `user_tokens` (`revoked_at = NOW()`).
5. **Manajemen Pengguna (`/api/users`)**:
   - `GET /api/users`: Daftar seluruh anggota tim.
   - `POST /api/users/link-google`: Menautkan akun Google dari profil.
   - `POST /api/users/unlink-google`: Memutuskan tautan akun Google.
   - `POST /api/users/change-password`: Memperbarui kata sandi pengguna.
   - `POST /api/users/update-profile`: Memperbarui nama, nomor telepon, dan foto profil.

---

## Menjalankan Backend

Ikuti [panduan setup proyek](../README.md) untuk mengimpor skema pada database baru dan menjalankan Android.

Dari folder ini, salin `.env.example` menjadi `.env` saat setup pertama, lalu jalankan `npm ci` dan `npm start`. Pada PowerShell Windows, gunakan `npm.cmd ci` dan `npm.cmd start` bila eksekusi skrip dibatasi. Gunakan Node.js 22 atau lebih baru.

Backend memuat `backend/.env` secara otomatis. Pengaturan dari environment shell tetap berlaku jika variabel yang sama juga ada di file. Secara default, server mendengarkan di `127.0.0.1:8000` dan menggunakan database `db_tracking_sales` di `127.0.0.1:3306`.

`GET /api/health` mengembalikan HTTP 200 saat database dapat diakses dan HTTP 503 jika koneksi terputus. Baca keluaran terminal jika koneksi atau migrasi database gagal saat startup.
