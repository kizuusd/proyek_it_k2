const express = require('express');
const router = express.Router();
const { pool } = require('../config/db');
const { ensureProductAndStockSchema } = require('./productRoutes');
const { resolveActor, isManagerRole } = require('./userRoutes');

let batchSchemaInitialized = false;

function isOwnerRole(user) {
  if (!user || !user.role) return false;
  const r = String(user.role).toLowerCase();
  return r === 'superadmin' || r === 'owner';
}

function formatDateYMD(val) {
  if (!val) return '';
  if (typeof val === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(val)) return val;
  const d = new Date(val);
  if (isNaN(d.getTime())) return String(val);
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

async function ensureStockBatchSchema() {
  if (batchSchemaInitialized) return;
  try {
    await ensureProductAndStockSchema();
    await pool.query(`
      CREATE TABLE IF NOT EXISTS stock_batches (
        id BIGINT(20) NOT NULL AUTO_INCREMENT,
        kode_batch VARCHAR(60) NOT NULL,
        tanggal DATE NOT NULL,
        sales_id BIGINT(20) NOT NULL,
        catatan_pengajuan TEXT DEFAULT NULL,
        status_review ENUM('menunggu','ditinjau_admin','disetujui_owner','ditolak') NOT NULL DEFAULT 'menunggu',
        reviewed_by_admin BIGINT(20) DEFAULT NULL,
        reviewed_by_admin_at DATETIME DEFAULT NULL,
        catatan_admin TEXT DEFAULT NULL,
        reviewed_by_owner BIGINT(20) DEFAULT NULL,
        reviewed_by_owner_at DATETIME DEFAULT NULL,
        catatan_owner TEXT DEFAULT NULL,
        status_opname ENUM('belum_opname','proses_opname','valid') NOT NULL DEFAULT 'belum_opname',
        opname_by BIGINT(20) DEFAULT NULL,
        opname_by_role VARCHAR(40) DEFAULT NULL,
        opname_at DATETIME DEFAULT NULL,
        catatan_opname TEXT DEFAULT NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        UNIQUE KEY idx_stock_batches_kode (kode_batch),
        KEY idx_stock_batches_sales (sales_id),
        KEY idx_stock_batches_tanggal (tanggal)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS stock_batch_items (
        id BIGINT(20) NOT NULL AUTO_INCREMENT,
        batch_id BIGINT(20) NOT NULL,
        product_id BIGINT(20) NOT NULL,
        kode_barang VARCHAR(100) NOT NULL,
        nama_barang VARCHAR(255) NOT NULL,
        kategori VARCHAR(100) DEFAULT 'Plastik',
        satuan VARCHAR(50) DEFAULT 'Pack',
        foto_url LONGTEXT DEFAULT NULL,
        harga_satuan DECIMAL(15,2) NOT NULL DEFAULT 0.00,
        qty_diambil INT(11) NOT NULL DEFAULT 1,
        qty_sisa_opname INT(11) DEFAULT NULL,
        catatan_opname VARCHAR(255) DEFAULT NULL,
        PRIMARY KEY (id),
        KEY idx_sbi_batch_id (batch_id),
        KEY idx_sbi_product_id (product_id),
        CONSTRAINT fk_sbi_batch FOREIGN KEY (batch_id) REFERENCES stock_batches (id) ON DELETE CASCADE ON UPDATE CASCADE
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);

    batchSchemaInitialized = true;
  } catch (err) {
    console.error('[ensureStockBatchSchema] Warning:', err.message);
  }
}

function formatBatchRow(row, items = []) {
  return {
    id: Number(row.id),
    kode_batch: row.kode_batch,
    tanggal: formatDateYMD(row.tanggal),
    sales_id: Number(row.sales_id),
    sales_name: row.sales_name || 'Sales Lapangan',
    sales_email: row.sales_email || '',
    catatan_pengajuan: row.catatan_pengajuan || '',
    status_review: row.status_review || 'menunggu',
    reviewed_by_admin_name: row.reviewed_by_admin_name || null,
    reviewed_by_admin_at: row.reviewed_by_admin_at
      ? new Date(row.reviewed_by_admin_at).toISOString()
      : null,
    catatan_admin: row.catatan_admin || null,
    reviewed_by_owner_name: row.reviewed_by_owner_name || null,
    reviewed_by_owner_at: row.reviewed_by_owner_at
      ? new Date(row.reviewed_by_owner_at).toISOString()
      : null,
    catatan_owner: row.catatan_owner || null,
    status_opname: row.status_opname || 'belum_opname',
    opname_by_name: row.opname_by_name || null,
    opname_by_role: row.opname_by_role || null,
    opname_at: row.opname_at ? new Date(row.opname_at).toISOString() : null,
    catatan_opname: row.catatan_opname || null,
    items: items.map((it) => ({
      id: Number(it.id),
      batch_id: Number(it.batch_id),
      product_id: Number(it.product_id),
      kode_barang: it.kode_barang || '',
      nama_barang: it.nama_barang || 'Produk',
      kategori: it.kategori || 'Plastik',
      satuan: it.satuan || 'Pack',
      foto_url: it.foto_url || 'preset:plastik',
      harga_satuan: Number(it.harga_satuan || 0),
      qty_diambil: Number(it.qty_diambil || 0),
      qty_sisa_opname: it.qty_sisa_opname != null ? Number(it.qty_sisa_opname) : null,
      catatan_opname: it.catatan_opname || null,
    })),
    created_at: row.created_at ? new Date(row.created_at).toISOString() : new Date().toISOString(),
  };
}

async function fetchFormattedBatches({ batchId = null, salesId = null, tanggal = null } = {}) {
  let query = `
    SELECT sb.*,
           s.name AS sales_name,
           s.email AS sales_email,
           adm.name AS reviewed_by_admin_name,
           own.name AS reviewed_by_owner_name,
           opn.name AS opname_by_name
    FROM stock_batches sb
    LEFT JOIN users s ON sb.sales_id = s.id
    LEFT JOIN users adm ON sb.reviewed_by_admin = adm.id
    LEFT JOIN users own ON sb.reviewed_by_owner = own.id
    LEFT JOIN users opn ON sb.opname_by = opn.id
  `;
  const conditions = [];
  const params = [];

  if (batchId) {
    conditions.push('sb.id = ?');
    params.push(Number(batchId));
  }
  if (salesId) {
    conditions.push('sb.sales_id = ?');
    params.push(Number(salesId));
  }
  if (tanggal) {
    conditions.push('sb.tanggal = ?');
    params.push(tanggal);
  }
  if (conditions.length > 0) {
    query += ' WHERE ' + conditions.join(' AND ');
  }
  query += ' ORDER BY sb.tanggal DESC, sb.id DESC';

  const [batchRows] = await pool.query(query, params);
  if (batchRows.length === 0) return [];

  const ids = batchRows.map((r) => r.id);
  const [itemRows] = await pool.query(
    'SELECT * FROM stock_batch_items WHERE batch_id IN (?) ORDER BY id ASC',
    [ids]
  );

  const byBatch = {};
  for (const it of itemRows) {
    if (!byBatch[it.batch_id]) byBatch[it.batch_id] = [];
    byBatch[it.batch_id].push(it);
  }

  return batchRows.map((r) => formatBatchRow(r, byBatch[r.id] || []));
}

// 1. GET /api/stock-batches
router.get('/', async (req, res) => {
  try {
    await ensureStockBatchSchema();
    const { sales_id, tanggal } = req.query;
    const data = await fetchFormattedBatches({
      salesId: sales_id ? Number(sales_id) : null,
      tanggal: tanggal || null,
    });
    return res.json({ status: true, count: data.length, data });
  } catch (error) {
    console.error('[GET /api/stock-batches] Error:', error);
    return res.status(500).json({ message: 'Gagal memuat data batch pengajuan: ' + error.message });
  }
});

// 2. POST /api/stock-batches
router.post('/', async (req, res) => {
  const conn = await pool.getConnection();
  try {
    await ensureStockBatchSchema();
    const { sales_id, sales_email, tanggal, catatan_pengajuan, items } = req.body;

    if (!Array.isArray(items) || items.length === 0) {
      conn.release();
      return res.status(400).json({ message: 'Minimal satu barang harus dipilih dalam batch.' });
    }

    let salesUser = null;
    if (sales_id) {
      const [uRows] = await conn.query(
        'SELECT * FROM users WHERE id = ? AND deleted_at IS NULL LIMIT 1',
        [sales_id]
      );
      if (uRows.length > 0) salesUser = uRows[0];
    }
    if (!salesUser && sales_email) {
      const [uRows] = await conn.query(
        'SELECT * FROM users WHERE LOWER(email) = ? AND deleted_at IS NULL LIMIT 1',
        [String(sales_email).trim().toLowerCase()]
      );
      if (uRows.length > 0) salesUser = uRows[0];
    }
    if (!salesUser) {
      conn.release();
      return res.status(404).json({ message: 'Akun Sales tidak ditemukan.' });
    }

    const batchDate = tanggal || new Date().toISOString().split('T')[0];

    await conn.beginTransaction();

    const [countRows] = await conn.query(
      'SELECT COUNT(*) AS cnt FROM stock_batches WHERE tanggal = ?',
      [batchDate]
    );
    const seq = Number(countRows[0]?.cnt || 0) + 1;
    const kodeBatch = `BATCH-${batchDate.replace(/-/g, '')}-${String(seq).padStart(3, '0')}`;

    const preparedItems = [];
    for (const raw of items) {
      const prodId = Number(raw.product_id);
      const qtyDiambil = Number(raw.qty_diambil ?? raw.qty ?? 0);
      if (!prodId || !Number.isInteger(qtyDiambil) || qtyDiambil <= 0) {
        await conn.rollback();
        conn.release();
        return res.status(400).json({
          message: 'Jumlah barang yang diambil harus berupa bilangan bulat lebih dari 0.',
        });
      }

      const [pRows] = await conn.query(
        'SELECT * FROM products WHERE id = ? AND deleted_at IS NULL LIMIT 1',
        [prodId]
      );
      if (pRows.length === 0) {
        await conn.rollback();
        conn.release();
        return res.status(404).json({ message: `Produk dengan ID ${prodId} tidak ditemukan.` });
      }
      const prod = pRows[0];

      const [priceRows] = await conn.query(
        `SELECT harga_jual FROM product_prices
         WHERE product_id = ? AND started_at <= NOW() AND (ended_at IS NULL OR ended_at > NOW())
         ORDER BY started_at DESC, id DESC LIMIT 1`,
        [prodId]
      );
      const unitPrice = priceRows.length > 0 ? Number(priceRows[0].harga_jual) : Number(prod.harga || 15000);

      preparedItems.push({
        product_id: prodId,
        kode_barang: prod.kode_barang || `BRG-${String(prodId).padStart(3, '0')}`,
        nama_barang: prod.nama_barang,
        kategori: prod.kategori || 'Plastik',
        satuan: prod.satuan || 'Pack',
        foto_url: prod.foto_url || 'preset:plastik',
        harga_satuan: unitPrice,
        qty_diambil: qtyDiambil,
      });
    }

    const [batchRes] = await conn.query(
      `INSERT INTO stock_batches
        (kode_batch, tanggal, sales_id, catatan_pengajuan, status_review, status_opname, created_at)
       VALUES (?, ?, ?, ?, 'menunggu', 'belum_opname', NOW())`,
      [
        kodeBatch,
        batchDate,
        salesUser.id,
        catatan_pengajuan ? String(catatan_pengajuan).trim() : 'Pengambilan barang batch harian',
      ]
    );

    const newBatchId = batchRes.insertId;
    for (const item of preparedItems) {
      await conn.query(
        `INSERT INTO stock_batch_items
          (batch_id, product_id, kode_barang, nama_barang, kategori, satuan, foto_url, harga_satuan, qty_diambil)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          newBatchId,
          item.product_id,
          item.kode_barang,
          item.nama_barang,
          item.kategori,
          item.satuan,
          item.foto_url,
          item.harga_satuan,
          item.qty_diambil,
        ]
      );
    }

    try {
      await conn.query(
        `INSERT INTO activity_logs (user_id, modul, aksi, deskripsi, ip_address)
         VALUES (?, 'FR10_PENGAJUAN_BATCH', 'CREATE', ?, ?)`,
        [
          salesUser.id,
          `Sales ${salesUser.name} mengajukan ${kodeBatch} (${preparedItems.length} barang) & otomatis masuk ke Pendapatan Sales`,
          req.ip || '127.0.0.1',
        ]
      );
    } catch (_) {}

    await conn.commit();

    const [created] = await fetchFormattedBatches({ batchId: newBatchId });
    return res.status(201).json({
      status: true,
      message: 'Batch pengajuan berhasil dikirim & otomatis masuk ke Pendapatan Sales untuk stok opname.',
      data: created,
    });
  } catch (error) {
    try {
      await conn.rollback();
    } catch (_) {}
    console.error('[POST /api/stock-batches] Error:', error);
    return res.status(500).json({ message: 'Gagal menyimpan batch pengajuan: ' + error.message });
  } finally {
    conn.release();
  }
});

// 3. PUT /api/stock-batches/:id/review
router.put('/:id/review', async (req, res) => {
  const conn = await pool.getConnection();
  try {
    await ensureStockBatchSchema();
    const batchId = Number(req.params.id);
    const { status_review, catatan } = req.body;

    if (!['ditinjau_admin', 'disetujui_owner', 'ditolak'].includes(String(status_review || ''))) {
      conn.release();
      return res.status(400).json({ message: 'Status tinjauan batch tidak valid.' });
    }

    const actor = await resolveActor(req);
    if (!actor || !isManagerRole(actor)) {
      conn.release();
      return res.status(403).json({
        message: 'Akses ditolak: Hanya Admin dan Owner yang berhak meninjau batch pengajuan.',
      });
    }

    if (status_review === 'disetujui_owner' && !isOwnerRole(actor)) {
      conn.release();
      return res.status(403).json({
        message: 'Persetujuan final batch pengajuan harus ditinjau oleh Owner.',
      });
    }

    if (status_review === 'ditolak' && (!catatan || String(catatan).trim() === '')) {
      conn.release();
      return res.status(400).json({ message: 'Alasan penolakan batch wajib diisi.' });
    }

    const [rows] = await conn.query('SELECT * FROM stock_batches WHERE id = ? LIMIT 1', [batchId]);
    if (rows.length === 0) {
      conn.release();
      return res.status(404).json({ message: 'Batch pengajuan tidak ditemukan.' });
    }
    const existing = rows[0];
    const cleanNote = catatan ? String(catatan).trim() : '';

    await conn.beginTransaction();

    if (status_review === 'ditinjau_admin') {
      await conn.query(
        `UPDATE stock_batches
         SET status_review = 'ditinjau_admin', reviewed_by_admin = ?, reviewed_by_admin_at = NOW(), catatan_admin = ?
         WHERE id = ?`,
        [actor.id, cleanNote || 'Telah diperiksa Admin, siap ditinjau Owner.', batchId]
      );
    } else if (status_review === 'disetujui_owner') {
      await conn.query(
        `UPDATE stock_batches
         SET status_review = 'disetujui_owner', reviewed_by_owner = ?, reviewed_by_owner_at = NOW(), catatan_owner = ?
         WHERE id = ?`,
        [actor.id, cleanNote || `Ditinjau dan disetujui oleh Owner (${actor.name}).`, batchId]
      );

      if (existing.status_review !== 'disetujui_owner') {
        const [itemRows] = await conn.query('SELECT * FROM stock_batch_items WHERE batch_id = ?', [
          batchId,
        ]);
        for (const it of itemRows) {
          const [pRows] = await conn.query('SELECT stok_gudang FROM products WHERE id = ? LIMIT 1', [
            it.product_id,
          ]);
          if (pRows.length > 0) {
            const curGudang = Number(pRows[0].stok_gudang || 0);
            const nextGudang = curGudang >= it.qty_diambil ? curGudang - it.qty_diambil : curGudang;
            await conn.query('UPDATE products SET stok_gudang = ?, updated_at = NOW() WHERE id = ?', [
              nextGudang,
              it.product_id,
            ]);
          }
          const [invRows] = await conn.query(
            'SELECT * FROM sales_inventory WHERE sales_id = ? AND product_id = ? ORDER BY id DESC LIMIT 1',
            [existing.sales_id, it.product_id]
          );
          if (invRows.length > 0) {
            await conn.query(
              'UPDATE sales_inventory SET stok_awal = stok_awal + ?, stok_sisa = stok_sisa + ?, updated_at = NOW() WHERE id = ?',
              [it.qty_diambil, it.qty_diambil, invRows[0].id]
            );
          } else {
            await conn.query(
              `INSERT INTO sales_inventory (sales_id, product_id, stok_awal, stok_terjual, stok_sisa, tanggal)
               VALUES (?, ?, ?, 0, ?, ?)`,
              [existing.sales_id, it.product_id, it.qty_diambil, it.qty_diambil, existing.tanggal]
            );
          }
        }
      }
    } else if (status_review === 'ditolak') {
      if (isOwnerRole(actor)) {
        await conn.query(
          `UPDATE stock_batches
           SET status_review = 'ditolak', reviewed_by_owner = ?, reviewed_by_owner_at = NOW(), catatan_owner = ?
           WHERE id = ?`,
          [actor.id, cleanNote, batchId]
        );
      } else {
        await conn.query(
          `UPDATE stock_batches
           SET status_review = 'ditolak', reviewed_by_admin = ?, reviewed_by_admin_at = NOW(), catatan_admin = ?
           WHERE id = ?`,
          [actor.id, cleanNote, batchId]
        );
      }
    }

    try {
      await conn.query(
        `INSERT INTO notifications (user_id, judul, pesan, jenis, referensi_id, referensi_tipe, is_read)
         VALUES (?, ?, ?, 'approval', ?, 'stock_batches', 0)`,
        [
          existing.sales_id,
          `Status Batch ${existing.kode_batch}`,
          `Batch ${existing.kode_batch} berstatus: ${status_review}.`,
          batchId,
        ]
      );
      await conn.query(
        `INSERT INTO activity_logs (user_id, modul, aksi, deskripsi, ip_address)
         VALUES (?, 'FR10_PENGAJUAN_BATCH', 'UPDATE', ?, ?)`,
        [actor.id, `Tinjauan batch ${existing.kode_batch} -> ${status_review}`, req.ip || '127.0.0.1']
      );
    } catch (_) {}

    await conn.commit();
    const [updated] = await fetchFormattedBatches({ batchId });
    return res.json({
      status: true,
      message: `Tinjauan batch ${existing.kode_batch} berhasil disimpan.`,
      data: updated,
    });
  } catch (error) {
    try {
      await conn.rollback();
    } catch (_) {}
    console.error('[PUT /api/stock-batches/:id/review] Error:', error);
    return res.status(500).json({ message: 'Gagal memproses tinjauan batch: ' + error.message });
  } finally {
    conn.release();
  }
});

// 4. PUT /api/stock-batches/:id/opname
router.put('/:id/opname', async (req, res) => {
  const conn = await pool.getConnection();
  try {
    await ensureStockBatchSchema();
    const batchId = Number(req.params.id);
    const { items, catatan_opname, finalize = true } = req.body;

    const actor = await resolveActor(req);
    if (!actor || !isManagerRole(actor)) {
      conn.release();
      return res.status(403).json({
        message: 'Stok opnam per batch harus divalidasi bersama Administrator atau Owner.',
      });
    }

    const [batchRows] = await conn.query('SELECT * FROM stock_batches WHERE id = ? LIMIT 1', [
      batchId,
    ]);
    if (batchRows.length === 0) {
      conn.release();
      return res.status(404).json({ message: 'Batch tidak ditemukan.' });
    }
    const existing = batchRows[0];
    if (existing.status_review === 'ditolak') {
      conn.release();
      return res.status(400).json({ message: 'Batch yang ditolak tidak dapat diopname.' });
    }
    if (existing.status_opname === 'valid') {
      conn.release();
      return res.status(400).json({ message: 'Batch ini sudah selesai stok opname dan berstatus Valid.' });
    }

    const [dbItems] = await conn.query('SELECT * FROM stock_batch_items WHERE batch_id = ?', [
      batchId,
    ]);
    const inputById = {};
    for (const raw of Array.isArray(items) ? items : []) {
      inputById[Number(raw.id)] = raw;
    }

    await conn.beginTransaction();

    for (const dbIt of dbItems) {
      const inp = inputById[dbIt.id];
      if (!inp || inp.qty_sisa_opname == null) {
        await conn.rollback();
        conn.release();
        return res.status(400).json({
          message: `Sisa stok opname untuk "${dbIt.nama_barang}" wajib diisi.`,
        });
      }
      const sisa = Number(inp.qty_sisa_opname);
      if (!Number.isInteger(sisa) || sisa < 0 || sisa > dbIt.qty_diambil) {
        await conn.rollback();
        conn.release();
        return res.status(400).json({
          message: `Sisa stok "${dbIt.nama_barang}" harus antara 0 dan ${dbIt.qty_diambil}.`,
        });
      }
      await conn.query(
        'UPDATE stock_batch_items SET qty_sisa_opname = ?, catatan_opname = ? WHERE id = ?',
        [sisa, inp.catatan_opname ? String(inp.catatan_opname).trim() : null, dbIt.id]
      );

      if (finalize) {
        const terjual = Math.max(0, dbIt.qty_diambil - sisa);
        await conn.query(
          `UPDATE sales_inventory
           SET stok_terjual = stok_terjual + ?, stok_sisa = GREATEST(0, stok_sisa - ?), updated_at = NOW()
           WHERE sales_id = ? AND product_id = ?`,
          [terjual, terjual, existing.sales_id, dbIt.product_id]
        );
      }
    }

    const opnameRole = isOwnerRole(actor) ? 'Owner' : 'Administrator';
    const nextOpnameStatus = finalize ? 'valid' : 'proses_opname';
    const finalOpnameNote =
      catatan_opname && String(catatan_opname).trim() !== ''
        ? String(catatan_opname).trim()
        : finalize
        ? `Stok opnam per batch selesai bersama ${opnameRole} (${actor.name}).`
        : 'Draft stok opname disimpan.';

    if (finalize && isOwnerRole(actor) && existing.status_review !== 'disetujui_owner') {
      await conn.query(
        `UPDATE stock_batches
         SET status_review = 'disetujui_owner', reviewed_by_owner = ?, reviewed_by_owner_at = NOW(),
             catatan_owner = COALESCE(catatan_owner, 'Ditinjau & divalidasi oleh Owner pada stok opname.'),
             status_opname = ?, opname_by = ?, opname_by_role = ?, opname_at = NOW(), catatan_opname = ?
         WHERE id = ?`,
        [actor.id, nextOpnameStatus, actor.id, opnameRole, finalOpnameNote, batchId]
      );
    } else {
      await conn.query(
        `UPDATE stock_batches
         SET status_opname = ?, opname_by = ?, opname_by_role = ?, opname_at = NOW(), catatan_opname = ?
         WHERE id = ?`,
        [nextOpnameStatus, actor.id, opnameRole, finalOpnameNote, batchId]
      );
    }

    try {
      await conn.query(
        `INSERT INTO activity_logs (user_id, modul, aksi, deskripsi, ip_address)
         VALUES (?, 'FR05_PENDAPATAN_OPNAME', 'UPDATE', ?, ?)`,
        [
          actor.id,
          `Stok opname batch ${existing.kode_batch} (${nextOpnameStatus}) oleh ${opnameRole} ${actor.name}`,
          req.ip || '127.0.0.1',
        ]
      );
    } catch (_) {}

    await conn.commit();

    const [updated] = await fetchFormattedBatches({ batchId });
    return res.json({
      status: true,
      message: finalize
        ? `Stok opname ${existing.kode_batch} selesai dan batch dinyatakan VALID.`
        : `Draft stok opname ${existing.kode_batch} disimpan.`,
      data: updated,
    });
  } catch (error) {
    try {
      await conn.rollback();
    } catch (_) {}
    console.error('[PUT /api/stock-batches/:id/opname] Error:', error);
    return res.status(500).json({ message: 'Gagal menyimpan stok opname batch: ' + error.message });
  } finally {
    conn.release();
  }
});

// 5. DELETE /api/stock-batches/:id
router.delete('/:id', async (req, res) => {
  try {
    await ensureStockBatchSchema();
    await pool.query('DELETE FROM stock_batches WHERE id = ?', [Number(req.params.id)]);
    return res.json({ status: true, message: 'Batch pengajuan berhasil dihapus.' });
  } catch (error) {
    console.error('[DELETE /api/stock-batches/:id] Error:', error);
    return res.status(500).json({ message: 'Gagal menghapus batch: ' + error.message });
  }
});

module.exports = {
  router,
  ensureStockBatchSchema,
};
