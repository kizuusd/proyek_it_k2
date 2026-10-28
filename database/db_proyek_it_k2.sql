-- ========================================================
-- Database: db_proyek_it_k2
-- Proyek: Tracking Sales CV Maju Bersama (Kelompok 2)
-- RDBMS: MySQL / MariaDB
-- ========================================================

CREATE DATABASE IF NOT EXISTS `db_proyek_it_k2`
CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE `db_proyek_it_k2`;

-- --------------------------------------------------------
-- 1. Tabel: users
-- Menyimpan akun pengguna (Owner, Admin, Sales)
-- --------------------------------------------------------
DROP TABLE IF EXISTS `users`;
CREATE TABLE `users` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `name` VARCHAR(150) NOT NULL,
  `email` VARCHAR(150) NOT NULL UNIQUE,
  `password` VARCHAR(255) NOT NULL,
  `phone` VARCHAR(30) DEFAULT NULL,
  `photo_url` VARCHAR(255) DEFAULT NULL,
  `role` ENUM('superadmin', 'owner', 'administrator', 'admin', 'sales') NOT NULL DEFAULT 'sales',
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `google_id` VARCHAR(150) DEFAULT NULL UNIQUE,
  `google_email` VARCHAR(150) DEFAULT NULL,
  `created_by` VARCHAR(150) DEFAULT NULL,
  `last_login_at` DATETIME DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX `idx_email` (`email`),
  INDEX `idx_role` (`role`),
  INDEX `idx_google_id` (`google_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------
-- Data Akun Bawaan (Owner, Admin, Sales)
-- Password default: password123
-- --------------------------------------------------------
INSERT INTO `users` (`id`, `name`, `email`, `password`, `phone`, `photo_url`, `role`, `is_active`, `google_id`, `created_by`, `last_login_at`) VALUES
(1, 'Dimas Brahamsyah Santosa Putra', 'owner@majubersama.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', '081234567890', 'https://ui-avatars.com/api/?name=Dimas+Brahamsyah&background=0D8ABC&color=fff', 'superadmin', 1, NULL, 'SYSTEM', NOW()),
(2, 'Agung Prasetyo Wibowo', 'admin@majubersama.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', '081234567891', 'https://ui-avatars.com/api/?name=Agung+Prasetyo&background=2E7D32&color=fff', 'administrator', 1, NULL, 'SYSTEM', NOW()),
(3, 'Muhammad Ulil Abshor', 'sales@majubersama.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', '081234567892', 'https://ui-avatars.com/api/?name=Ulil+Abshor&background=E65100&color=fff', 'sales', 1, 'google_oauth_sales_123', 'Agung Prasetyo Wibowo', NOW()),
(4, 'Budi Santoso (Nonaktif)', 'inactive@majubersama.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', '081234567899', NULL, 'sales', 0, NULL, 'Agung Prasetyo Wibowo', NULL),
(5, 'Ahmad Hidayat', 'ahmad.sales@majubersama.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', '081298765432', NULL, 'sales', 1, NULL, 'Dimas Brahamsyah Santosa Putra', NULL);

-- --------------------------------------------------------
-- 2. Tabel: pengajuan_izin (FR09)
-- --------------------------------------------------------
DROP TABLE IF EXISTS `pengajuan_izin`;
CREATE TABLE `pengajuan_izin` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `user_id` INT NOT NULL,
  `sales_name` VARCHAR(150) NOT NULL,
  `jenis_izin` ENUM('Sakit', 'Cuti Tahunan', 'Keperluan Keluarga', 'Lainnya') NOT NULL,
  `tanggal_mulai` DATE NOT NULL,
  `tanggal_selesai` DATE NOT NULL,
  `alasan` TEXT NOT NULL,
  `status` ENUM('Menunggu', 'Disetujui', 'Ditolak') NOT NULL DEFAULT 'Menunggu',
  `approved_by` VARCHAR(150) DEFAULT NULL,
  `approved_at` DATETIME DEFAULT NULL,
  `catatan_admin` TEXT DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `pengajuan_izin` (`user_id`, `sales_name`, `jenis_izin`, `tanggal_mulai`, `tanggal_selesai`, `alasan`, `status`, `approved_by`, `approved_at`, `catatan_admin`) VALUES
(3, 'Muhammad Ulil Abshor', 'Sakit', CURDATE(), CURDATE(), 'Demam dan flu berat, istirahat dokter 1 hari', 'Menunggu', NULL, NULL, NULL);

-- --------------------------------------------------------
-- 3. Tabel: absensi (FR08)
-- --------------------------------------------------------
DROP TABLE IF EXISTS `absensi`;
CREATE TABLE `absensi` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `user_id` INT NOT NULL,
  `tanggal` DATE NOT NULL,
  `jam_masuk` TIME DEFAULT NULL,
  `jam_keluar` TIME DEFAULT NULL,
  `latitude` DECIMAL(10, 8) DEFAULT NULL,
  `longitude` DECIMAL(11, 8) DEFAULT NULL,
  `lokasi` VARCHAR(255) DEFAULT NULL,
  `status` ENUM('Hadir', 'Izin', 'Terlambat') NOT NULL DEFAULT 'Hadir',
  `foto_bukti` VARCHAR(255) DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------
-- 4. Tabel: master_barang (FR02 & FR03)
-- --------------------------------------------------------
DROP TABLE IF EXISTS `master_barang`;
CREATE TABLE `master_barang` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `kode_barang` VARCHAR(50) NOT NULL UNIQUE,
  `nama_barang` VARCHAR(150) NOT NULL,
  `kategori` VARCHAR(100) NOT NULL,
  `harga_modal` DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
  `harga_jual` DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
  `stok` INT NOT NULL DEFAULT 0,
  `satuan` VARCHAR(20) NOT NULL DEFAULT 'Pcs',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `master_barang` (`kode_barang`, `nama_barang`, `kategori`, `harga_modal`, `harga_jual`, `stok`, `satuan`) VALUES
('BRG-001', 'Kopi Robusta 250gr', 'Minuman', 18000.00, 25000.00, 120, 'Pcs'),
('BRG-002', 'Teh Celup Melati Box', 'Minuman', 8000.00, 12000.00, 85, 'Box'),
('BRG-003', 'Minyak Goreng 1L', 'Sembako', 14000.00, 17500.00, 200, 'Pouch');

-- --------------------------------------------------------
-- 5. Tabel: jadwal_rute (FR04)
-- --------------------------------------------------------
DROP TABLE IF EXISTS `jadwal_rute`;
CREATE TABLE `jadwal_rute` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `user_id` INT NOT NULL,
  `hari` VARCHAR(20) NOT NULL,
  `nama_toko` VARCHAR(150) NOT NULL,
  `alamat` TEXT NOT NULL,
  `latitude` DECIMAL(10, 8) DEFAULT NULL,
  `longitude` DECIMAL(11, 8) DEFAULT NULL,
  `status_kunjungan` ENUM('Belum Dikunjungi', 'Selesai', 'Dibatalkan') NOT NULL DEFAULT 'Belum Dikunjungi',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `jadwal_rute` (`user_id`, `hari`, `nama_toko`, `alamat`, `status_kunjungan`) VALUES
(3, 'Senin', 'Toko Berkah Sejahtera', 'Jl. Sudirman No. 45, Semarang', 'Belum Dikunjungi'),
(3, 'Senin', 'Warung Madura Barokah', 'Jl. Pemuda No. 12, Semarang', 'Belum Dikunjungi');
