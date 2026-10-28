# Backend REST API Node.js & MySQL (Tracking Sales CV Maju Bersama)

Backend ini dibangun menggunakan **Node.js (Express)** dan terhubung langsung ke basis data **MySQL / MariaDB (`db_proyek_it_k2`)**.

## 📌 Fitur Backend
1. **Autentikasi Email & Password (`POST /api/auth/login`)**:
   - Mendukung enkripsi password `bcrypt` dan plaintext dev (`password123`).
   - Validasi hak akses (`superadmin`/`owner`, `administrator`/`admin`, `sales`).
   - Pengecekan status akun aktif (`is_active = 1`).
2. **Autentikasi Google (Gmail) (`POST /api/auth/google-login`)**:
   - Sinkronisasi `google_id` dan `photo_url`.
   - **Aturan Keamanan**: Sales tidak bisa mendaftar mandiri via Google; akun yang belum terdaftar akan ditolak dengan pesan instruksi.
3. **Registrasi Akun Sales Manajerial (`POST /api/auth/register-sales`)**:
   - Khusus dapat dipanggil oleh Admin atau Owner (`manager_id`).
   - Mencegah duplikasi email.
4. **Manajemen Pengguna (`/api/users`)**:
   - `GET /api/users`: Daftar seluruh anggota tim.
   - `POST /api/users/link-google`: Menautkan akun Google dari profil.
   - `POST /api/users/unlink-google`: Memutuskan tautan akun Google.
   - `POST /api/users/change-password`: Memperbarui kata sandi pengguna.

---

## 🚀 Cara Menjalankan Backend
Pastikan MySQL (misal dari Laragon/XAMPP) sudah berjalan di port `3306`.

```bash
# 1. Pindah ke direktori backend
cd backend

# 2. Instal dependensi (hanya saat pertama kali)
npm install

# 3. Jalankan server backend
npm start
# atau mode development auto-reload
npm run dev
```

Server akan aktif di:
- **Desktop/Lokal**: `http://localhost:8000`
- **Android Emulator**: `http://10.0.2.2:8000`

---

## 🗄️ Konfigurasi Database
File konfigurasi database terdapat di `backend/config/db.js`.
Secara default menggunakan:
- Host: `127.0.0.1`
- Port: `3306`
- User: `root`
- Password: `(kosong)`
- Database: `db_proyek_it_k2`
