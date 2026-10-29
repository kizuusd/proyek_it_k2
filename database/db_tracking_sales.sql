-- ========================================================
-- Database: db_tracking_sales
-- Proyek: Tracking Sales CV Maju Bersama (Kelompok 2)
-- RDBMS: MySQL / MariaDB
-- ========================================================

CREATE DATABASE IF NOT EXISTS `db_tracking_sales`
CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE `db_tracking_sales`;

SET FOREIGN_KEY_CHECKS = 0;

-- --------------------------------------------------------
-- Tabel: activity_logs
-- --------------------------------------------------------
DROP TABLE IF EXISTS `activity_logs`;
CREATE TABLE `activity_logs` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `user_id` bigint(20) DEFAULT NULL COMMENT 'FK ke users (opsional/system)',
  `modul` varchar(255) NOT NULL COMMENT 'Modul terkait',
  `aksi` varchar(255) NOT NULL COMMENT 'CREATE, UPDATE, DELETE, LOGIN',
  `deskripsi` text DEFAULT NULL COMMENT 'Deskripsi perubahan data',
  `ip_address` varchar(255) DEFAULT NULL COMMENT 'IP pengakses',
  `user_agent` varchar(255) DEFAULT NULL COMMENT 'Browser/Mobile OS agent',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp() COMMENT 'Waktu eksekusi',
  PRIMARY KEY (`id`),
  KEY `fk_logs_user_id_idx` (`user_id`),
  CONSTRAINT `fk_logs_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Audit trail pencatatan aktivitas untuk keamanan & integritas data - NFR03';

-- --------------------------------------------------------
-- Tabel: attendances
-- --------------------------------------------------------
DROP TABLE IF EXISTS `attendances`;
CREATE TABLE `attendances` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `sales_id` bigint(20) NOT NULL COMMENT 'FK ke sales user',
  `tanggal` date NOT NULL COMMENT 'Tanggal presensi',
  `checkin_at` datetime DEFAULT NULL COMMENT 'Waktu jam masuk',
  `checkin_lat` decimal(10,7) DEFAULT NULL COMMENT 'Latitude lokasi check-in',
  `checkin_lng` decimal(10,7) DEFAULT NULL COMMENT 'Longitude lokasi check-in',
  `checkin_foto_url` varchar(255) DEFAULT NULL COMMENT 'Bukti selfie saat masuk',
  `checkout_at` datetime DEFAULT NULL COMMENT 'Waktu jam pulang',
  `checkout_lat` decimal(10,7) DEFAULT NULL COMMENT 'Latitude checkout',
  `checkout_lng` decimal(10,7) DEFAULT NULL COMMENT 'Longitude checkout',
  `checkout_foto_url` varchar(255) DEFAULT NULL COMMENT 'Bukti foto pulang',
  `durasi_kerja` int(11) DEFAULT NULL COMMENT 'Total menit kerja',
  `status` enum('hadir','alfa','izin','terlambat') NOT NULL DEFAULT 'alfa' COMMENT 'Status kehadiran',
  `catatan_admin` text DEFAULT NULL COMMENT 'Keterangan tambahan dari admin',
  `validated_by` bigint(20) DEFAULT NULL COMMENT 'Admin yang memverifikasi',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp() COMMENT 'Dibuat',
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'Diperbarui',
  PRIMARY KEY (`id`),
  KEY `fk_attendances_sales_id_idx` (`sales_id`),
  KEY `fk_attendances_validated_by_idx` (`validated_by`),
  CONSTRAINT `fk_attendances_sales_id` FOREIGN KEY (`sales_id`) REFERENCES `users` (`id`) ON UPDATE CASCADE,
  CONSTRAINT `fk_attendances_validated_by` FOREIGN KEY (`validated_by`) REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Pencatatan absensi harian sales dengan validasi GPS & foto selfie - FR08';

-- --------------------------------------------------------
-- Tabel: customers
-- --------------------------------------------------------
DROP TABLE IF EXISTS `customers`;
CREATE TABLE `customers` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `kode_toko` varchar(255) NOT NULL COMMENT 'Kode unik toko/outlet',
  `nama_toko` varchar(255) NOT NULL COMMENT 'Nama warung/toko',
  `pemilik` varchar(255) DEFAULT NULL COMMENT 'Nama kontak pemilik',
  `no_telp` varchar(255) DEFAULT NULL COMMENT 'Nomor HP toko',
  `alamat` text NOT NULL COMMENT 'Alamat lengkap fisik',
  `kota` varchar(255) NOT NULL COMMENT 'Kabupaten / Kota',
  `kecamatan` varchar(255) DEFAULT NULL COMMENT 'Kecamatan',
  `latitude` decimal(10,7) DEFAULT NULL COMMENT 'Titik koordinat latitude',
  `longitude` decimal(10,7) DEFAULT NULL COMMENT 'Titik koordinat longitude',
  `foto_toko_url` varchar(255) DEFAULT NULL COMMENT 'Foto plang / depan toko',
  `is_active` tinyint(4) NOT NULL DEFAULT 1 COMMENT 'Status aktif',
  `created_by` bigint(20) NOT NULL COMMENT 'Admin pendaftar toko',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp() COMMENT 'Didaftarkan',
  PRIMARY KEY (`id`),
  KEY `fk_customers_created_by_idx` (`created_by`),
  CONSTRAINT `fk_customers_created_by` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Master pelanggan / toko / warung kanvas tujuan sales lapangan - FR04';

-- --------------------------------------------------------
-- Tabel: income_summaries
-- --------------------------------------------------------
DROP TABLE IF EXISTS `income_summaries`;
CREATE TABLE `income_summaries` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `sales_id` bigint(20) NOT NULL COMMENT 'Sales bersangkutan',
  `jenis_periode` enum('harian','mingguan','bulanan') NOT NULL DEFAULT 'harian' COMMENT 'Periode rekap',
  `periode_mulai` date NOT NULL COMMENT 'Awal rentang tanggal',
  `periode_selesai` date NOT NULL COMMENT 'Akhir rentang tanggal',
  `total_kunjungan` int(11) NOT NULL DEFAULT 0 COMMENT 'Jumlah outlet didatangi',
  `total_transaksi` int(11) NOT NULL DEFAULT 0 COMMENT 'Jumlah faktur penjualan',
  `total_pendapatan` decimal(15,2) NOT NULL DEFAULT 0.00 COMMENT 'Total omset/pendapatan bersih',
  `catatan` text DEFAULT NULL COMMENT 'Catatan pencatatan',
  `generated_by` bigint(20) NOT NULL COMMENT 'Admin pembuat rekap',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp() COMMENT 'Dibuat pada',
  PRIMARY KEY (`id`),
  KEY `fk_income_sales_id_idx` (`sales_id`),
  KEY `fk_income_generated_by_idx` (`generated_by`),
  CONSTRAINT `fk_income_generated_by` FOREIGN KEY (`generated_by`) REFERENCES `users` (`id`) ON UPDATE CASCADE,
  CONSTRAINT `fk_income_sales_id` FOREIGN KEY (`sales_id`) REFERENCES `users` (`id`) ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Pencatatan & agregasi pendapatan sales harian, mingguan, bulanan - FR05';

-- --------------------------------------------------------
-- Tabel: leave_requests
-- --------------------------------------------------------
DROP TABLE IF EXISTS `leave_requests`;
CREATE TABLE `leave_requests` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `sales_id` bigint(20) NOT NULL COMMENT 'Sales yang mengajukan',
  `jenis_izin` enum('sakit','izin','cuti') NOT NULL DEFAULT 'izin' COMMENT 'Jenis permohonan',
  `kategori_izin` varchar(100) DEFAULT NULL COMMENT 'Label kategori izin lengkap',
  `tanggal_mulai` date NOT NULL COMMENT 'Awal tanggal izin',
  `tanggal_selesai` date NOT NULL COMMENT 'Akhir tanggal izin',
  `jumlah_hari` int(11) NOT NULL DEFAULT 1 COMMENT 'Durasi hari izin',
  `alasan` text NOT NULL COMMENT 'Alasan ketidakhadiran',
  `lampiran_url` longtext DEFAULT NULL COMMENT 'Foto surat dokter/surat digital',
  `status` enum('menunggu','disetujui','ditolak') NOT NULL DEFAULT 'menunggu' COMMENT 'Status persetujuan',
  `catatan_approver` text DEFAULT NULL COMMENT 'Catatan dari admin/owner',
  `approved_by` bigint(20) DEFAULT NULL COMMENT 'Admin penindaklanjut',
  `approved_at` datetime DEFAULT NULL COMMENT 'Waktu persetujuan',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp() COMMENT 'Diajukan pada',
  PRIMARY KEY (`id`),
  KEY `fk_leave_sales_id_idx` (`sales_id`),
  KEY `fk_leave_approved_by_idx` (`approved_by`),
  CONSTRAINT `fk_leave_approved_by` FOREIGN KEY (`approved_by`) REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_leave_sales_id` FOREIGN KEY (`sales_id`) REFERENCES `users` (`id`) ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Pengajuan surat izin digital sales tidak masuk kerja - FR09';

-- --------------------------------------------------------
-- Tabel: location_tracks
-- --------------------------------------------------------
DROP TABLE IF EXISTS `location_tracks`;
CREATE TABLE `location_tracks` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `sales_id` bigint(20) NOT NULL COMMENT 'Sales yang sedang dilacak',
  `latitude` decimal(10,7) NOT NULL COMMENT 'Garis lintang lokasi',
  `longitude` decimal(10,7) NOT NULL COMMENT 'Garis bujur lokasi',
  `accuracy` decimal(10,2) DEFAULT NULL COMMENT 'Akurasi GPS (meter)',
  `speed` decimal(10,2) DEFAULT NULL COMMENT 'Kecepatan gerak (km/h)',
  `is_mock_location` tinyint(4) NOT NULL DEFAULT 0 COMMENT 'Deteksi Fake GPS / mock provider',
  `recorded_at` datetime NOT NULL COMMENT 'Waktu sampel koordinat HP',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp() COMMENT 'Diterima di server',
  PRIMARY KEY (`id`),
  KEY `fk_location_sales_id_idx` (`sales_id`),
  CONSTRAINT `fk_location_sales_id` FOREIGN KEY (`sales_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Telemetri tracking koordinat GPS posisi sales secara real time - FR06, NFR02';

-- --------------------------------------------------------
-- Tabel: notifications
-- --------------------------------------------------------
DROP TABLE IF EXISTS `notifications`;
CREATE TABLE `notifications` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `user_id` bigint(20) NOT NULL COMMENT 'Penerima notifikasi',
  `judul` varchar(255) NOT NULL COMMENT 'Judul pesan notifikasi',
  `pesan` text NOT NULL COMMENT 'Isi pesan',
  `jenis` enum('info','approval','peringatan','sistem') NOT NULL DEFAULT 'info' COMMENT 'Kategori',
  `referensi_id` bigint(20) DEFAULT NULL COMMENT 'ID data terkait',
  `referensi_tipe` varchar(255) DEFAULT NULL COMMENT 'Nama tabel referensi',
  `is_read` tinyint(4) NOT NULL DEFAULT 0 COMMENT '0 = Belum dibaca, 1 = Sudah',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp() COMMENT 'Waktu pengiriman',
  PRIMARY KEY (`id`),
  KEY `fk_notif_user_id_idx` (`user_id`),
  CONSTRAINT `fk_notif_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Push notifikasi mobile untuk approval pengajuan & rute baru - FR04, FR09, FR10';

-- --------------------------------------------------------
-- Tabel: product_prices
-- --------------------------------------------------------
DROP TABLE IF EXISTS `product_prices`;
CREATE TABLE `product_prices` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `product_id` bigint(20) NOT NULL COMMENT 'Produk terkait',
  `harga_jual` decimal(15,2) NOT NULL COMMENT 'Harga jual ke toko',
  `harga_beli` decimal(15,2) NOT NULL DEFAULT 0.00 COMMENT 'Harga modal / HPP',
  `keterangan` varchar(255) DEFAULT NULL COMMENT 'Alasan perubahan harga',
  `started_at` datetime NOT NULL COMMENT 'Mulai berlaku efektif',
  `ended_at` datetime DEFAULT NULL COMMENT 'Akhir berlaku (NULL jika aktif saat ini)',
  `created_by` bigint(20) NOT NULL COMMENT 'Superadmin yang mengubah',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp() COMMENT 'Dicatat',
  PRIMARY KEY (`id`),
  KEY `fk_prices_prod_id_idx` (`product_id`),
  KEY `fk_prices_superadmin_id_idx` (`created_by`),
  CONSTRAINT `fk_prices_prod_id` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_prices_superadmin_id` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Pencatatan & riwayat histori harga produk oleh Superadmin - FR03';

-- --------------------------------------------------------
-- Tabel: products
-- --------------------------------------------------------
DROP TABLE IF EXISTS `products`;
CREATE TABLE `products` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `kode_barang` varchar(255) NOT NULL COMMENT 'SKU / kode unik produk',
  `nama_barang` varchar(255) NOT NULL COMMENT 'Nama barang dagangan',
  `kategori` varchar(100) NOT NULL DEFAULT 'Plastik' COMMENT 'Kategori barang (Plastik, Sembako, dll)',
  `deskripsi` text DEFAULT NULL COMMENT 'Spesifikasi produk',
  `satuan` varchar(255) NOT NULL DEFAULT 'Pcs' COMMENT 'Pcs, Dus, Pack, Karton',
  `stok_gudang` int(11) NOT NULL DEFAULT 0 COMMENT 'Stok fisik di gudang pusat',
  `foto_url` longtext DEFAULT NULL COMMENT 'Foto produk (URL / Base64 / Preset)',
  `is_active` tinyint(4) NOT NULL DEFAULT 1 COMMENT 'Status dijual atau diskontinu',
  `created_by` bigint(20) NOT NULL COMMENT 'Admin pembuat',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp() COMMENT 'Dibuat',
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'Diperbarui',
  `deleted_at` timestamp NULL DEFAULT NULL COMMENT 'Soft delete',
  PRIMARY KEY (`id`),
  KEY `fk_products_created_by_idx` (`created_by`),
  CONSTRAINT `fk_products_created_by` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Master katalog produk dagangan CV Maju Bersama - FR02';

-- --------------------------------------------------------
-- Tabel: sales_inventory
-- --------------------------------------------------------
DROP TABLE IF EXISTS `sales_inventory`;
CREATE TABLE `sales_inventory` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `sales_id` bigint(20) NOT NULL COMMENT 'Sales pemegang stok',
  `product_id` bigint(20) NOT NULL COMMENT 'Produk yang dibawa',
  `stok_awal` int(11) NOT NULL DEFAULT 0 COMMENT 'Stok awal muat pagi hari',
  `stok_terjual` int(11) NOT NULL DEFAULT 0 COMMENT 'Akumulasi terjual hari ini',
  `stok_sisa` int(11) NOT NULL DEFAULT 0 COMMENT 'Sisa stok fisik di kanvas',
  `tanggal` date NOT NULL COMMENT 'Tanggal operasional',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp() COMMENT 'Tercatat',
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'Diperbarui',
  PRIMARY KEY (`id`),
  KEY `fk_inv_sales_id_idx` (`sales_id`),
  KEY `fk_inv_product_id_idx` (`product_id`),
  CONSTRAINT `fk_inv_product_id` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON UPDATE CASCADE,
  CONSTRAINT `fk_inv_sales_id` FOREIGN KEY (`sales_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Stok fisik barang yang dibawa sales pada mobil/motor kanvas - FR02';

-- --------------------------------------------------------
-- Tabel: sales_routes
-- --------------------------------------------------------
DROP TABLE IF EXISTS `sales_routes`;
CREATE TABLE `sales_routes` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `sales_id` bigint(20) NOT NULL COMMENT 'Sales yang ditugaskan',
  `customer_id` bigint(20) NOT NULL COMMENT 'Toko sasaran kunjungan',
  `tanggal` date NOT NULL COMMENT 'Tanggal rencana kunjungan',
  `urutan` int(11) NOT NULL DEFAULT 1 COMMENT 'Nomor urut destinasi (1,2,3..)',
  `catatan` text DEFAULT NULL COMMENT 'Instruksi khusus rute',
  `status` enum('dijadwalkan','selesai','dilewati','dibatalkan') NOT NULL DEFAULT 'dijadwalkan' COMMENT 'Status progres rute',
  `created_by` bigint(20) NOT NULL COMMENT 'Admin perencana',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp() COMMENT 'Dibuat',
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'Diperbarui',
  PRIMARY KEY (`id`),
  KEY `fk_routes_sales_id_idx` (`sales_id`),
  KEY `fk_routes_customer_id_idx` (`customer_id`),
  KEY `fk_routes_created_by_idx` (`created_by`),
  CONSTRAINT `fk_routes_created_by` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON UPDATE CASCADE,
  CONSTRAINT `fk_routes_customer_id` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON UPDATE CASCADE,
  CONSTRAINT `fk_routes_sales_id` FOREIGN KEY (`sales_id`) REFERENCES `users` (`id`) ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Penjadwalan rute kunjungan sales mingguan oleh Admin - FR04';

-- --------------------------------------------------------
-- Tabel: stock_requests
-- --------------------------------------------------------
DROP TABLE IF EXISTS `stock_requests`;
CREATE TABLE `stock_requests` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `sales_id` bigint(20) NOT NULL COMMENT 'Sales pemohon',
  `product_id` bigint(20) DEFAULT NULL COMMENT 'Produk yang diajukan (NULL jika barang baru)',
  `kode_barang_custom` varchar(100) DEFAULT NULL COMMENT 'Kode barang usulan/referensi',
  `nama_barang_custom` varchar(255) DEFAULT NULL COMMENT 'Nama barang yang diajukan',
  `kategori_custom` varchar(100) DEFAULT 'Plastik' COMMENT 'Kategori barang',
  `satuan_custom` varchar(50) DEFAULT 'Pack' COMMENT 'Satuan barang',
  `foto_url_custom` longtext DEFAULT NULL COMMENT 'Foto produk referensi',
  `jenis` enum('tambah','kurang','retur') NOT NULL DEFAULT 'tambah' COMMENT 'Aksi stok',
  `qty_diajukan` int(11) NOT NULL COMMENT 'Jumlah yang diminta',
  `qty_disetujui` int(11) DEFAULT NULL COMMENT 'Jumlah realisasi approval',
  `alasan` text NOT NULL COMMENT 'Alasan penambahan/retur',
  `status` enum('menunggu','disetujui','ditolak') NOT NULL DEFAULT 'menunggu' COMMENT 'Status permohonan',
  `catatan_admin` text DEFAULT NULL COMMENT 'Alasan penolakan / feedback',
  `approved_by` bigint(20) DEFAULT NULL COMMENT 'Admin validator',
  `approved_at` datetime DEFAULT NULL COMMENT 'Waktu persetujuan',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp() COMMENT 'Diajukan',
  PRIMARY KEY (`id`),
  KEY `fk_stock_req_sales_id_idx` (`sales_id`),
  KEY `fk_stock_req_prod_id_idx` (`product_id`),
  KEY `fk_stock_req_admin_id_idx` (`approved_by`),
  CONSTRAINT `fk_stock_req_admin_id` FOREIGN KEY (`approved_by`) REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_stock_req_prod_id` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_stock_req_sales_id` FOREIGN KEY (`sales_id`) REFERENCES `users` (`id`) ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Pengajuan penambahan/pengurangan/retur barang sales ke admin - FR10';

-- --------------------------------------------------------
-- Tabel: transaction_items
-- --------------------------------------------------------
DROP TABLE IF EXISTS `transaction_items`;
CREATE TABLE `transaction_items` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `transaction_id` bigint(20) NOT NULL COMMENT 'Header transaksi',
  `product_id` bigint(20) NOT NULL COMMENT 'Produk yang dibeli',
  `harga_satuan` decimal(15,2) NOT NULL COMMENT 'Harga per unit saat transaksi',
  `qty` int(11) NOT NULL DEFAULT 1 COMMENT 'Jumlah unit barang',
  `diskon_item` decimal(15,2) NOT NULL DEFAULT 0.00 COMMENT 'Potongan per item',
  `subtotal` decimal(15,2) NOT NULL COMMENT 'Subtotal baris item',
  `catatan` varchar(255) DEFAULT NULL COMMENT 'Catatan per item',
  PRIMARY KEY (`id`),
  KEY `fk_items_trx_id_idx` (`transaction_id`),
  KEY `fk_items_product_id_idx` (`product_id`),
  CONSTRAINT `fk_items_product_id` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON UPDATE CASCADE,
  CONSTRAINT `fk_items_trx_id` FOREIGN KEY (`transaction_id`) REFERENCES `transactions` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Rincian barang & kuantiti produk yang terjual per transaksi - FR02, FR05';

-- --------------------------------------------------------
-- Tabel: transactions
-- --------------------------------------------------------
DROP TABLE IF EXISTS `transactions`;
CREATE TABLE `transactions` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `kode_transaksi` varchar(255) NOT NULL COMMENT 'Nomor invoice penjualan',
  `visit_id` bigint(20) DEFAULT NULL COMMENT 'Kunjungan saat transaksi berlangsung',
  `sales_id` bigint(20) NOT NULL COMMENT 'Sales penanggung jawab',
  `customer_id` bigint(20) NOT NULL COMMENT 'Toko pembeli produk',
  `tanggal` date NOT NULL COMMENT 'Tanggal transaksi',
  `subtotal` decimal(15,2) NOT NULL DEFAULT 0.00 COMMENT 'Total kotor sebelum diskon',
  `diskon` decimal(15,2) NOT NULL DEFAULT 0.00 COMMENT 'Diskon faktur',
  `total` decimal(15,2) NOT NULL DEFAULT 0.00 COMMENT 'Total bersih yang harus dibayar',
  `metode_bayar` enum('tunai','transfer','tempo') NOT NULL DEFAULT 'tunai' COMMENT 'Metode pembayaran',
  `status_bayar` enum('lunas','belum_lunas','sebagian') NOT NULL DEFAULT 'lunas' COMMENT 'Status pelunasan faktur',
  `catatan` text DEFAULT NULL COMMENT 'Catatan pembayaran / tempo',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp() COMMENT 'Tercatat',
  PRIMARY KEY (`id`),
  KEY `fk_trx_visit_id_idx` (`visit_id`),
  KEY `fk_trx_sales_id_idx` (`sales_id`),
  KEY `fk_trx_customer_id_idx` (`customer_id`),
  CONSTRAINT `fk_trx_customer_id` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON UPDATE CASCADE,
  CONSTRAINT `fk_trx_sales_id` FOREIGN KEY (`sales_id`) REFERENCES `users` (`id`) ON UPDATE CASCADE,
  CONSTRAINT `fk_trx_visit_id` FOREIGN KEY (`visit_id`) REFERENCES `visit_logs` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Faktur transaksi penjualan produk oleh sales di toko - FR05';

-- --------------------------------------------------------
-- Tabel: user_tokens
-- --------------------------------------------------------
DROP TABLE IF EXISTS `user_tokens`;
CREATE TABLE `user_tokens` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `user_id` bigint(20) NOT NULL COMMENT 'FK ke tabel users',
  `token` varchar(255) NOT NULL COMMENT 'Hash token otentikasi',
  `device_info` varchar(255) DEFAULT NULL COMMENT 'Model HP/Browser pengguna',
  `ip_address` varchar(255) DEFAULT NULL COMMENT 'Alamat IP client',
  `expires_at` datetime DEFAULT NULL COMMENT 'Waktu token kedaluwarsa',
  `revoked_at` datetime DEFAULT NULL COMMENT 'Waktu token dicabut',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp() COMMENT 'Waktu dibuat',
  PRIMARY KEY (`id`),
  KEY `fk_tokens_user_id_idx` (`user_id`),
  CONSTRAINT `fk_tokens_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Token otentikasi session mobile/web API (Bearer token) - FR01';

-- --------------------------------------------------------
-- Tabel: users
-- --------------------------------------------------------
DROP TABLE IF EXISTS `users`;
CREATE TABLE `users` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `name` varchar(255) NOT NULL COMMENT 'Nama lengkap user',
  `email` varchar(255) NOT NULL COMMENT 'Email unik untuk login',
  `password` varchar(255) DEFAULT NULL COMMENT 'Hashed password',
  `phone` varchar(255) DEFAULT NULL COMMENT 'Nomor telepon/WA',
  `photo_url` longtext DEFAULT NULL COMMENT 'URL atau Base64 foto profil',
  `role` enum('superadmin','owner','administrator','admin','sales') NOT NULL DEFAULT 'sales' COMMENT 'Hak akses peran sistem',
  `is_active` tinyint(4) NOT NULL DEFAULT 1 COMMENT 'Status akun aktif/nonaktif',
  `google_id` varchar(255) DEFAULT NULL COMMENT 'ID OAuth Google untuk login GMAIL',
  `google_email` varchar(255) DEFAULT NULL COMMENT 'Email akun Google (Gmail) yang ditautkan',
  `device_token` varchar(255) DEFAULT NULL COMMENT 'Token FCM untuk push notifikasi mobile',
  `last_login_at` datetime DEFAULT NULL COMMENT 'Waktu login terakhir',
  `created_by` bigint(20) DEFAULT NULL COMMENT 'ID superadmin pembuat akun',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp() COMMENT 'Waktu registrasi',
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'Waktu pembaruan',
  `deleted_at` timestamp NULL DEFAULT NULL COMMENT 'Soft delete',
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_users_email` (`email`),
  KEY `fk_users_created_by_idx` (`created_by`),
  KEY `idx_users_google_id` (`google_id`),
  KEY `idx_users_google_email` (`google_email`),
  CONSTRAINT `fk_users_created_by` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Master akun semua stakeholder (Superadmin, Administrator, Sales) - FR01, FR07, FR11';

-- --------------------------------------------------------
-- Tabel: visit_logs
-- --------------------------------------------------------
DROP TABLE IF EXISTS `visit_logs`;
CREATE TABLE `visit_logs` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT 'PK',
  `route_id` bigint(20) DEFAULT NULL COMMENT 'Relasi jadwal rute jika terencana',
  `sales_id` bigint(20) NOT NULL COMMENT 'Sales yang hadir di toko',
  `customer_id` bigint(20) NOT NULL COMMENT 'Toko yang dikunjungi',
  `tanggal_kunjungan` date NOT NULL COMMENT 'Tanggal kunjungan fisik',
  `checkin_at` datetime NOT NULL COMMENT 'Timestamp jam tiba di toko',
  `checkin_lat` decimal(10,7) NOT NULL COMMENT 'Latitude sales saat checkin',
  `checkin_lng` decimal(10,7) NOT NULL COMMENT 'Longitude sales saat checkin',
  `checkin_foto_url` varchar(255) NOT NULL COMMENT 'Foto selfie bersama pemilik toko',
  `checkout_at` datetime DEFAULT NULL COMMENT 'Timestamp jam selesai',
  `catatan` text DEFAULT NULL COMMENT 'Hasil survei / obrolan penjualan',
  `status` enum('valid','anomali_jarak','diluar_jadwal') NOT NULL DEFAULT 'valid' COMMENT 'Integritas geofencing',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp() COMMENT 'Dibuat',
  PRIMARY KEY (`id`),
  KEY `fk_visit_route_id_idx` (`route_id`),
  KEY `fk_visit_sales_id_idx` (`sales_id`),
  KEY `fk_visit_customer_id_idx` (`customer_id`),
  CONSTRAINT `fk_visit_customer_id` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`) ON UPDATE CASCADE,
  CONSTRAINT `fk_visit_route_id` FOREIGN KEY (`route_id`) REFERENCES `sales_routes` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_visit_sales_id` FOREIGN KEY (`sales_id`) REFERENCES `users` (`id`) ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Log check-in & check-out kunjungan nyata sales di outlet - FR04, FR06';

-- --------------------------------------------------------
-- Data Akun Pengguna (Owner/Superadmin, Administrator, Sales)
-- Password default: password123
-- --------------------------------------------------------
INSERT INTO `users` (`id`, `name`, `email`, `password`, `phone`, `photo_url`, `role`, `is_active`, `google_id`, `google_email`, `created_by`, `last_login_at`) VALUES
(1, 'Dimas Brahamsyah Santosa Putra', 'owner@majubersama.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', '081234567890', 'https://ui-avatars.com/api/?name=Dimas+Brahamsyah&background=0D8ABC&color=fff', 'superadmin', 1, NULL, NULL, NULL, NOW()),
(2, 'Agung Prasetyo Wibowo', 'admin@majubersama.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', '081234567891', 'https://ui-avatars.com/api/?name=Agung+Prasetyo&background=2E7D32&color=fff', 'administrator', 1, NULL, NULL, 1, NOW()),
(3, 'Muhammad Ulil Abshor', 'sales@majubersama.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', '081234567892', 'https://ui-avatars.com/api/?name=Ulil+Abshor&background=E65100&color=fff', 'sales', 1, 'real_gid_999', 'sales.google@gmail.com', 2, NOW()),
(4, 'Budi Santoso (Nonaktif)', 'inactive@majubersama.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', '081234567899', NULL, 'sales', 0, NULL, NULL, 2, NULL),
(5, 'Ahmad Hidayat', 'ahmad.sales@majubersama.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', '081298765432', NULL, 'sales', 1, 'gid_ahmad_real_123', 'ahmad.personal@gmail.com', 1, NOW()),
(6, 'hjuhihisd', 'setyoagung450@gmail.com', '$2a$10$0QmVHZX5vHzvRsXVLM8XIew0AGPvoYiFpJ0lDSvpTUsN9MfEXAYK.', '9449399839', 'https://lh3.googleusercontent.com/a/ACg8ocJkXxa2Ol2zJ_zZcsnBWlXuY9PbEQ52_MCCinARYvV4Gm3Gq00=s100', 'sales', 1, '101600273800804324536', 'setyoagung450@gmail.com', 2, NOW());

SET FOREIGN_KEY_CHECKS = 1;
