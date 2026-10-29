const express = require('express');
const router = express.Router();
const { pool } = require('../config/db');

let schemaInitialized = false;

async function ensureProductAndStockSchema() {
  if (schemaInitialized) return;
  try {
    // 1. Pastikan kolom kategori & foto_url LONGTEXT ada di tabel products
    const [prodCols] = await pool.query('SHOW COLUMNS FROM products');
    const colNames = prodCols.map((c) => c.Field);
    if (!colNames.includes('kategori')) {
      await pool.query(
        "ALTER TABLE products ADD COLUMN kategori VARCHAR(100) NOT NULL DEFAULT 'Plastik' AFTER nama_barang"
      );
    }
    await pool.query('ALTER TABLE products MODIFY COLUMN foto_url LONGTEXT DEFAULT NULL');

    // 2. Pastikan tabel stock_requests mendukung pengajuan barang baru maupun katalog
    await pool.query('ALTER TABLE stock_requests MODIFY COLUMN product_id BIGINT(20) DEFAULT NULL');
    const [reqCols] = await pool.query('SHOW COLUMNS FROM stock_requests');
    const reqColNames = reqCols.map((c) => c.Field);
    if (!reqColNames.includes('kode_barang_custom')) {
      await pool.query(
        'ALTER TABLE stock_requests ADD COLUMN kode_barang_custom VARCHAR(100) DEFAULT NULL AFTER product_id'
      );
    }
    if (!reqColNames.includes('nama_barang_custom')) {
      await pool.query(
        'ALTER TABLE stock_requests ADD COLUMN nama_barang_custom VARCHAR(255) DEFAULT NULL AFTER kode_barang_custom'
      );
    }
    if (!reqColNames.includes('kategori_custom')) {
      await pool.query(
        "ALTER TABLE stock_requests ADD COLUMN kategori_custom VARCHAR(100) DEFAULT 'Plastik' AFTER nama_barang_custom"
      );
    }
    if (!reqColNames.includes('satuan_custom')) {
      await pool.query(
        "ALTER TABLE stock_requests ADD COLUMN satuan_custom VARCHAR(50) DEFAULT 'Pack' AFTER kategori_custom"
      );
    }
    if (!reqColNames.includes('foto_url_custom')) {
      await pool.query(
        'ALTER TABLE stock_requests ADD COLUMN foto_url_custom LONGTEXT DEFAULT NULL AFTER satuan_custom'
      );
    }

    schemaInitialized = true;
  } catch (err) {
    console.error('[ensureProductAndStockSchema] Warning:', err.message);
  }
}

function inferCategory(row) {
  if (row.kategori && String(row.kategori).trim() !== '') {
    return String(row.kategori).trim();
  }
  const lower = String(row.nama_barang || '').toLowerCase();
  if (lower.includes('plastik') || lower.includes('kresek') || lower.includes('pp')) {
    return 'Plastik';
  }
  if (lower.includes('minyak') || lower.includes('gula') || lower.includes('tepung')) {
    return 'Sembako';
  }
  return 'Plastik';
}

function formatProductRow(row) {
  const stokGudang = Number(row.stok_gudang || 0);
  const isActive = row.is_active === 1 || row.is_active === true || row.is_active === '1';
  let statusLabel = 'Nonaktif';
  if (isActive) {
    statusLabel = stokGudang > 0 ? 'Aktif' : 'Habis';
  }

  return {
    id: Number(row.id),
    kode_barang: row.kode_barang || `BRG-${String(row.id).padStart(3, '0')}`,
    nama_barang: row.nama_barang || '',
    kategori: inferCategory(row),
    deskripsi: row.deskripsi || '',
    satuan: row.satuan || 'Pack',
    stok_gudang: stokGudang,
    stok_sales: row.stok_sales != null ? Number(row.stok_sales) : 0,
    foto_url: row.foto_url || null,
    is_active: isActive,
    status_label: statusLabel,
    created_by: row.created_by ? Number(row.created_by) : 1,
    creator_name: row.creator_name || 'User',
    created_at: row.created_at ? new Date(row.created_at).toISOString() : new Date().toISOString(),
    updated_at: row.updated_at ? new Date(row.updated_at).toISOString() : new Date().toISOString(),
  };
}

// --------------------------------------------------------
// 1. GET /api/products
//    Ambil daftar semua produk katalog + stok di sales
// --------------------------------------------------------
router.get('/', async (req, res) => {
  try {
    await ensureProductAndStockSchema();
    const salesId = Number(req.query.sales_id) || 3;

    const [rows] = await pool.query(
      `SELECT p.*,
              u.name AS creator_name,
              COALESCE(
                (SELECT si.stok_sisa
                 FROM sales_inventory si
                 WHERE si.product_id = p.id AND si.sales_id = ?
                 ORDER BY si.updated_at DESC, si.id DESC
                 LIMIT 1),
                0
              ) AS stok_sales
       FROM products p
       LEFT JOIN users u ON p.created_by = u.id
       WHERE p.deleted_at IS NULL
       ORDER BY p.id ASC`,
      [salesId]
    );

    return res.json({
      status: true,
      count: rows.length,
      data: rows.map(formatProductRow),
    });
  } catch (error) {
    console.error('[GET /api/products] Error:', error);
    return res.status(500).json({
      message: 'Gagal memuat data katalog produk: ' + error.message,
    });
  }
});

// --------------------------------------------------------
// 2. POST /api/products
//    Sales / Admin / Owner menambahkan barang baru ke katalog
// --------------------------------------------------------
router.post('/', async (req, res) => {
  try {
    await ensureProductAndStockSchema();
    const {
      kode_barang,
      nama_barang,
      kategori,
      deskripsi,
      satuan,
      stok_gudang,
      stok_sales,
      foto_url,
      is_active,
      created_by,
      sales_id,
    } = req.body;

    if (!nama_barang || String(nama_barang).trim() === '') {
      return res.status(400).json({ message: 'Nama barang wajib diisi.' });
    }

    const finalKode =
      kode_barang && String(kode_barang).trim() !== ''
        ? String(kode_barang).trim().toUpperCase()
        : `BRG-${String(Date.now()).slice(-3)}`;

    // Cek duplikasi kode_barang pada produk aktif
    const [dupRows] = await pool.query(
      'SELECT id FROM products WHERE UPPER(kode_barang) = ? AND deleted_at IS NULL LIMIT 1',
      [finalKode]
    );
    if (dupRows.length > 0) {
      return res.status(409).json({
        message: `Kode barang '${finalKode}' sudah digunakan oleh produk lain.`,
      });
    }

    const finalKategori =
      kategori && String(kategori).trim() !== '' ? String(kategori).trim() : 'Plastik';
    const finalSatuan =
      satuan && String(satuan).trim() !== '' ? String(satuan).trim() : 'Pack';
    const finalStokGudang = Math.max(0, Number(stok_gudang) || 0);
    const finalStokSales = Math.max(0, Number(stok_sales) || 0);
    const activeVal = is_active === false || is_active === 0 || is_active === '0' ? 0 : 1;
    const creatorId = Number(created_by) || 1;

    const [insertResult] = await pool.query(
      `INSERT INTO products
        (kode_barang, nama_barang, kategori, deskripsi, satuan, stok_gudang, foto_url, is_active, created_by, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())`,
      [
        finalKode,
        String(nama_barang).trim(),
        finalKategori,
        deskripsi ? String(deskripsi).trim() : null,
        finalSatuan,
        finalStokGudang,
        foto_url || 'preset:plastik',
        activeVal,
        creatorId,
      ]
    );

    const newProductId = insertResult.insertId;

    // Jika ditambahkan oleh Sales atau disertai stok_sales awal, catat ke sales_inventory
    const targetSalesId = Number(sales_id) || creatorId;
    if (finalStokSales > 0 && targetSalesId) {
      try {
        await pool.query(
          `INSERT INTO sales_inventory (sales_id, product_id, stok_awal, stok_terjual, stok_sisa, tanggal)
           VALUES (?, ?, ?, 0, ?, CURDATE())`,
          [targetSalesId, newProductId, finalStokSales, finalStokSales]
        );
      } catch (_) {}
    }

    // Catat ke activity_logs
    try {
      await pool.query(
        `INSERT INTO activity_logs (user_id, modul, aksi, deskripsi, ip_address)
         VALUES (?, 'FR02_MASTER_BARANG', 'CREATE', ?, ?)`,
        [
          creatorId,
          `Menambahkan produk baru: [${finalKode}] ${nama_barang} (Stok Gudang: ${finalStokGudang} ${finalSatuan})`,
          req.ip || '127.0.0.1',
        ]
      );
    } catch (_) {}

    const [createdRows] = await pool.query(
      `SELECT p.*, u.name AS creator_name, ? AS stok_sales
       FROM products p
       LEFT JOIN users u ON p.created_by = u.id
       WHERE p.id = ? LIMIT 1`,
      [finalStokSales, newProductId]
    );

    return res.status(201).json({
      status: true,
      message: 'Produk berhasil ditambahkan.',
      data: formatProductRow(createdRows[0]),
    });
  } catch (error) {
    console.error('[POST /api/products] Error:', error);
    return res.status(500).json({
      message: 'Gagal menyimpan produk baru: ' + error.message,
    });
  }
});

// --------------------------------------------------------
// 3. PUT /api/products/:id
//    Mengubah data produk atau stok
// --------------------------------------------------------
router.put('/:id', async (req, res) => {
  try {
    await ensureProductAndStockSchema();
    const prodId = Number(req.params.id);
    const {
      kode_barang,
      nama_barang,
      kategori,
      deskripsi,
      satuan,
      stok_gudang,
      stok_sales,
      sales_id,
      foto_url,
      is_active,
      updated_by,
    } = req.body;

    const [existingRows] = await pool.query(
      'SELECT * FROM products WHERE id = ? AND deleted_at IS NULL LIMIT 1',
      [prodId]
    );
    if (existingRows.length === 0) {
      return res.status(404).json({ message: 'Data produk tidak ditemukan.' });
    }
    const existing = existingRows[0];

    const finalKode =
      kode_barang && String(kode_barang).trim() !== ''
        ? String(kode_barang).trim().toUpperCase()
        : existing.kode_barang;
    const finalNama =
      nama_barang && String(nama_barang).trim() !== ''
        ? String(nama_barang).trim()
        : existing.nama_barang;
    const finalKategori =
      kategori && String(kategori).trim() !== ''
        ? String(kategori).trim()
        : existing.kategori || 'Plastik';
    const finalDeskripsi =
      deskripsi !== undefined ? (deskripsi ? String(deskripsi).trim() : null) : existing.deskripsi;
    const finalSatuan =
      satuan && String(satuan).trim() !== '' ? String(satuan).trim() : existing.satuan;
    const finalStok =
      stok_gudang !== undefined ? Math.max(0, Number(stok_gudang) || 0) : existing.stok_gudang;
    const finalFoto = foto_url !== undefined ? foto_url : existing.foto_url;
    const finalActive =
      is_active !== undefined
        ? is_active === false || is_active === 0 || is_active === '0'
          ? 0
          : 1
        : existing.is_active;

    await pool.query(
      `UPDATE products
       SET kode_barang = ?, nama_barang = ?, kategori = ?, deskripsi = ?, satuan = ?,
           stok_gudang = ?, foto_url = ?, is_active = ?, updated_at = NOW()
       WHERE id = ?`,
      [
        finalKode,
        finalNama,
        finalKategori,
        finalDeskripsi,
        finalSatuan,
        finalStok,
        finalFoto,
        finalActive,
        prodId,
      ]
    );

    if (stok_sales !== undefined) {
      const targetSalesId = Number(sales_id) || Number(updated_by) || 3;
      const newSalesStock = Math.max(0, Number(stok_sales) || 0);
      const [invRows] = await pool.query(
        'SELECT * FROM sales_inventory WHERE sales_id = ? AND product_id = ? ORDER BY id DESC LIMIT 1',
        [targetSalesId, prodId]
      );
      if (invRows.length > 0) {
        await pool.query(
          'UPDATE sales_inventory SET stok_sisa = ?, updated_at = NOW() WHERE id = ?',
          [newSalesStock, invRows[0].id]
        );
      } else {
        await pool.query(
          'INSERT INTO sales_inventory (sales_id, product_id, stok_awal, stok_terjual, stok_sisa, tanggal) VALUES (?, ?, ?, 0, ?, CURDATE())',
          [targetSalesId, prodId, newSalesStock, newSalesStock]
        );
      }
    }

    try {
      await pool.query(
        `INSERT INTO activity_logs (user_id, modul, aksi, deskripsi, ip_address)
         VALUES (?, 'FR02_MASTER_BARANG', 'UPDATE', ?, ?)`,
        [
          Number(updated_by) || 1,
          `Memperbarui produk [${finalKode}] ${finalNama} (Stok Gudang: ${finalStok} ${finalSatuan})`,
          req.ip || '127.0.0.1',
        ]
      );
    } catch (_) {}

    const [updatedRows] = await pool.query(
      `SELECT p.*, u.name AS creator_name,
              COALESCE(
                (SELECT si.stok_sisa FROM sales_inventory si WHERE si.product_id = p.id ORDER BY si.updated_at DESC LIMIT 1),
                0
              ) AS stok_sales
       FROM products p
       LEFT JOIN users u ON p.created_by = u.id
       WHERE p.id = ? LIMIT 1`,
      [prodId]
    );

    return res.json({
      status: true,
      message: 'Data produk berhasil diperbarui.',
      data: formatProductRow(updatedRows[0]),
    });
  } catch (error) {
    console.error('[PUT /api/products/:id] Error:', error);
    return res.status(500).json({
      message: 'Gagal memperbarui produk: ' + error.message,
    });
  }
});

// --------------------------------------------------------
// 4. PATCH /api/products/:id/stock
//    Menambah / mengurangi stok gudang atau stok sales
// --------------------------------------------------------
router.patch('/:id/stock', async (req, res) => {
  try {
    await ensureProductAndStockSchema();
    const prodId = Number(req.params.id);
    const { mode, qty, sales_id } = req.body;

    const [existingRows] = await pool.query(
      'SELECT * FROM products WHERE id = ? AND deleted_at IS NULL LIMIT 1',
      [prodId]
    );
    if (existingRows.length === 0) {
      return res.status(404).json({ message: 'Produk tidak ditemukan.' });
    }
    const prod = existingRows[0];
    const amount = Number(qty) || 0;

    let newWarehouseStock = Number(prod.stok_gudang || 0);
    if (mode === 'set') {
      newWarehouseStock = Math.max(0, amount);
    } else if (mode === 'subtract') {
      newWarehouseStock = Math.max(0, newWarehouseStock - amount);
    } else {
      newWarehouseStock = Math.max(0, newWarehouseStock + amount);
    }

    await pool.query('UPDATE products SET stok_gudang = ?, updated_at = NOW() WHERE id = ?', [
      newWarehouseStock,
      prodId,
    ]);

    if (sales_id && amount > 0 && mode === 'distribute_to_sales') {
      const targetSalesId = Number(sales_id);
      const [invRows] = await pool.query(
        'SELECT * FROM sales_inventory WHERE sales_id = ? AND product_id = ? ORDER BY id DESC LIMIT 1',
        [targetSalesId, prodId]
      );
      if (invRows.length > 0) {
        await pool.query(
          'UPDATE sales_inventory SET stok_awal = stok_awal + ?, stok_sisa = stok_sisa + ?, updated_at = NOW() WHERE id = ?',
          [amount, amount, invRows[0].id]
        );
      } else {
        await pool.query(
          'INSERT INTO sales_inventory (sales_id, product_id, stok_awal, stok_terjual, stok_sisa, tanggal) VALUES (?, ?, ?, 0, ?, CURDATE())',
          [targetSalesId, prodId, amount, amount]
        );
      }
    }

    const [updatedRows] = await pool.query(
      `SELECT p.*, u.name AS creator_name,
              COALESCE(
                (SELECT si.stok_sisa FROM sales_inventory si WHERE si.product_id = p.id AND si.sales_id = ? ORDER BY si.updated_at DESC LIMIT 1),
                0
              ) AS stok_sales
       FROM products p
       LEFT JOIN users u ON p.created_by = u.id
       WHERE p.id = ? LIMIT 1`,
      [Number(sales_id) || 3, prodId]
    );

    return res.json({
      status: true,
      message: 'Stok produk berhasil diperbarui.',
      data: formatProductRow(updatedRows[0]),
    });
  } catch (error) {
    console.error('[PATCH /api/products/:id/stock] Error:', error);
    return res.status(500).json({
      message: 'Gagal memperbarui stok produk: ' + error.message,
    });
  }
});

// --------------------------------------------------------
// 5. DELETE /api/products/:id
//    Soft delete produk
// --------------------------------------------------------
router.delete('/:id', async (req, res) => {
  try {
    await ensureProductAndStockSchema();
    const prodId = Number(req.params.id);
    await pool.query('UPDATE products SET deleted_at = NOW(), is_active = 0 WHERE id = ?', [prodId]);
    return res.json({
      status: true,
      message: 'Produk berhasil dihapus dari katalog.',
    });
  } catch (error) {
    console.error('[DELETE /api/products/:id] Error:', error);
    return res.status(500).json({
      message: 'Gagal menghapus produk: ' + error.message,
    });
  }
});

module.exports = {
  router,
  ensureProductAndStockSchema,
};
