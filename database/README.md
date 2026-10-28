# Skema Basis Data MySQL: `db_proyek_it_k2`

Database ini dirancang untuk sistem **Tracking Sales CV Maju Bersama (Kelompok 2)** menggunakan RDBMS **MySQL / MariaDB**.

## 📁 File Skema & Seeder
- File SQL lengkap: [`database/db_proyek_it_k2.sql`](db_proyek_it_k2.sql)

## 🔑 Akun Default Terdaftar

| No | Nama Lengkap | Email | Password | Role | Status | Keterangan |
|---|---|---|---|---|---|---|
| 1 | Dimas Brahamsyah Santosa Putra | `owner@majubersama.com` | `password123` | `superadmin` (Owner) | Aktif | Hak akses tertinggi |
| 2 | Agung Prasetyo Wibowo | `admin@majubersama.com` | `password123` | `administrator` | Aktif | Hak akses Admin / Sekretaris |
| 3 | Muhammad Ulil Abshor | `sales@majubersama.com` | `password123` | `sales` | Aktif | Akun Sales (Tertaut Google) |
| 4 | Budi Santoso (Nonaktif) | `inactive@majubersama.com` | `password123` | `sales` | Nonaktif | Untuk pengujian akun dinonaktifkan |
| 5 | Ahmad Hidayat | `ahmad.sales@majubersama.com` | `password123` | `sales` | Aktif | Akun Sales Lapangan |

## 📊 Tabel-tabel Sistem
1. `users`: Menyimpan akun pengguna, role, status aktif, phone, Google ID, dan waktu login terakhir.
2. `pengajuan_izin`: Modul FR09 (pengajuan izin sakit, cuti, status persetujuan Admin/Owner).
3. `absensi`: Modul FR08 (pencatatan jam masuk, jam keluar, koordinat GPS, foto bukti kehadiran).
4. `master_barang`: Modul FR02 & FR03 (data produk, kategori, harga modal, harga jual, dan stok).
5. `jadwal_rute`: Modul FR04 (rencana kunjungan toko sales per hari beserta titik koordinat).

## 🛠️ Cara Impor Database
Jika ingin mengimpor ulang skema ke MySQL:
```bash
mysql -u root < database/db_proyek_it_k2.sql
# Atau di PowerShell:
Get-Content database/db_proyek_it_k2.sql | mysql -u root
```
