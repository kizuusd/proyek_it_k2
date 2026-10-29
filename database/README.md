# Skema Basis Data MySQL: `db_tracking_sales`

Database ini dirancang untuk sistem **Tracking Sales CV Maju Bersama (Kelompok 2)** menggunakan RDBMS **MySQL / MariaDB**.

## 📁 File Skema & Seeder
- File SQL lengkap: [`database/db_tracking_sales.sql`](db_tracking_sales.sql)

## 🔑 Akun Default Terdaftar (`users`)

| No | Nama Lengkap | Email | Password | Role | Status | Google Email Tertaut | Keterangan |
|---|---|---|---|---|---|---|---|
| 1 | Dimas Brahamsyah Santosa Putra | `owner@majubersama.com` | `password123` | `superadmin` (Owner) | Aktif | - | Hak akses tertinggi |
| 2 | Agung Prasetyo Wibowo | `admin@majubersama.com` | `password123` | `administrator` | Aktif | - | Hak akses Admin / Sekretaris |
| 3 | Muhammad Ulil Abshor | `sales@majubersama.com` | `password123` | `sales` | Aktif | `sales.google@gmail.com` | Akun Sales (Tertaut Google) |
| 4 | Budi Santoso (Nonaktif) | `inactive@majubersama.com` | `password123` | `sales` | Nonaktif | - | Untuk pengujian akun dinonaktifkan |
| 5 | Ahmad Hidayat | `ahmad.sales@majubersama.com` | `password123` | `sales` | Aktif | `ahmad.personal@gmail.com` | Akun Sales Lapangan |

## 📊 Tabel-tabel Sistem (`db_tracking_sales`)
1. `users`: Master akun semua stakeholder (`superadmin`, `administrator`, `sales`) dengan dukungan login Email/Password dan Google OAuth (`google_id`, `google_email`), `device_token`, `last_login_at`, `created_by` (FK ke `users.id`), dan soft-delete (`deleted_at`).
2. `user_tokens`: Menyimpan token sesi autentikasi Bearer (`user_id`, `token`, `device_info`, `ip_address`, `expires_at`, `revoked_at`).
3. `activity_logs`: Audit trail pencatatan aktivitas login, registrasi, dan perubahan data.
4. `attendances`: Pencatatan absensi harian sales dengan validasi GPS & foto selfie (FR08).
5. `leave_requests`: Pengajuan izin/cuti sales dan persetujuan admin (FR09).
6. `products` & `product_prices`: Master barang dan riwayat harga jual/beli (FR02 & FR03).
7. `sales_inventory` & `stock_requests`: Stok barang bawaan sales dan pengajuan tambah/kurang/retur stok (FR10).
8. `customers`, `sales_routes`, `visit_logs`, `location_tracks`: Pelanggan/toko, jadwal rute kunjungan, log kunjungan, dan pelacakan GPS (FR04 & FR06).
9. `transactions`, `transaction_items`, `income_summaries`: Transaksi penjualan dan rekap pendapatan (FR05).
10. `notifications`: Notifikasi sistem dan persetujuan.

## 🛠️ Cara Impor Database
Jika ingin mengimpor ulang skema ke MySQL:
```bash
mysql -u root < database/db_tracking_sales.sql
# Atau di PowerShell:
Get-Content database/db_tracking_sales.sql | mysql -u root
```
