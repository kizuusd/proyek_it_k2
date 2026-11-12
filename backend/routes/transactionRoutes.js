const express = require('express');
const router = express.Router();
const { pool } = require('../config/db');
const { resolveActor, isManagerRole } = require('./userRoutes');

let txSchemaInitialized = false;

async function ensureTransactionSchema() {
  if (txSchemaInitialized) return;
  try {
    await pool.query('ALTER TABLE transactions MODIFY COLUMN customer_id BIGINT(20) DEFAULT NULL');

    const [txCols] = await pool.query('SHOW COLUMNS FROM transactions');
    const txColNames = txCols.map((c) => c.Field);
    if (!txColNames.includes('nama_pelanggan')) {
      await pool.query('ALTER TABLE transactions ADD COLUMN nama_pelanggan VARCHAR(255) DEFAULT NULL AFTER customer_id');
    }
    if (!txColNames.includes('status_verifikasi')) {
      await pool.query(
        "ALTER TABLE transactions ADD COLUMN status_verifikasi ENUM('menunggu','disetujui','ditolak') NOT NULL DEFAULT 'menunggu' AFTER status_bayar"
      );
    }
    if (!txColNames.includes('alasan_penolakan')) {
      await pool.query('ALTER TABLE transactions ADD COLUMN alasan_penolakan TEXT DEFAULT NULL AFTER catatan');
    }
    if (!txColNames.includes('verified_by')) {
      await pool.query('ALTER TABLE transactions ADD COLUMN verified_by BIGINT(20) DEFAULT NULL AFTER alasan_penolakan');
    }
    if (!txColNames.includes('verified_at')) {
      await pool.query('ALTER TABLE transactions ADD COLUMN verified_at DATETIME DEFAULT NULL AFTER verified_by');
    }
    if (!txColNames.includes('cancelled_reason')) {
      await pool.query('ALTER TABLE transactions ADD COLUMN cancelled_reason TEXT DEFAULT NULL AFTER verified_at');
    }
    if (!txColNames.includes('cancelled_by')) {
      await pool.query('ALTER TABLE transactions ADD COLUMN cancelled_by BIGINT(20) DEFAULT NULL AFTER cancelled_reason');
    }
    if (!txColNames.includes('cancelled_at')) {
      await pool.query('ALTER TABLE transactions ADD COLUMN cancelled_at DATETIME DEFAULT NULL AFTER cancelled_by');
    }

    const [itemCols] = await pool.query('SHOW COLUMNS FROM transaction_items');
    const itemColNames = itemCols.map((c) => c.Field);
    if (!itemColNames.includes('nama_barang_snapshot')) {
      await pool.query('ALTER TABLE transaction_items ADD COLUMN nama_barang_snapshot VARCHAR(255) DEFAULT NULL AFTER product_id');
    }
    if (!itemColNames.includes('satuan_snapshot')) {
      await pool.query("ALTER TABLE transaction_items ADD COLUMN satuan_snapshot VARCHAR(50) DEFAULT 'Pack' AFTER nama_barang_snapshot");
    }

    txSchemaInitialized = true;
  } catch (err) {
    console.error('[ensureTransactionSchema] Warning:', err.message);
  }
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

function formatTransactionRow(row, items = []) {
  return {
    id: Number(row.id),
    kode_transaksi: row.kode_transaksi,
    sales_id: Number(row.sales_id),
    sales_name: row.sales_name || 'Sales Lapangan',
    customer_id: row.customer_id ? Number(row.customer_id) : null,
    nama_pelanggan: row.nama_pelanggan || row.customer_name || 'Pelanggan Umum',
    tanggal: formatDateYMD(row.tanggal),
    subtotal: Number(row.subtotal || 0),
    diskon: Number(row.diskon || 0),
    total: Number(row.total || 0),
    status_verifikasi: row.status_verifikasi || 'menunggu',
    catatan: row.catatan || '',
    alasan_penolakan: row.alasan_penolakan || null,
    verified_by: row.verified_by ? Number(row.verified_by) : null,
    verified_by_name: row.verified_by_name || null,
    verified_at: row.verified_at ? new Date(row.verified_at).toISOString() : null,
    cancelled_reason: row.cancelled_reason || null,
    cancelled_at: row.cancelled_at ? new Date(row.cancelled_at).toISOString() : null,
    created_at: row.created_at ? new Date(row.created_at).toISOString() : null,
    items,
  };
}

// --------------------------------------------------------
// 1. GET /api/transactions
//    Filter: sales_id, product_id, start_date, end_date, status_verifikasi
// --------------------------------------------------------
router.get('/', async (req, res) => {
  try {
    await ensureTransactionSchema();
    const { sales_id, product_id, start_date, end_date, status_verifikasi } = req.query;

    let query = `
      SELECT t.*,
             u.name AS sales_name,
             c.nama_toko AS customer_name,
             v.name AS verified_by_name
      FROM transactions t
      JOIN users u ON t.sales_id = u.id
      LEFT JOIN customers c ON t.customer_id = c.id
      LEFT JOIN users v ON t.verified_by = v.id
    `;
    const conditions = [];
    const params = [];

    if (sales_id) {
      conditions.push('t.sales_id = ?');
      params.push(Number(sales_id));
    }
    if (start_date) {
      conditions.push('t.tanggal >= ?');
      params.push(start_date);
    }
    if (end_date) {
      conditions.push('t.tanggal <= ?');
      params.push(end_date);
    }
    if (status_verifikasi && ['menunggu', 'disetujui', 'ditolak'].includes(String(status_verifikasi).toLowerCase())) {
      conditions.push('t.status_verifikasi = ?');
      params.push(String(status_verifikasi).toLowerCase());
    }
    if (product_id) {
      conditions.push('EXISTS (SELECT 1 FROM transaction_items ti WHERE ti.transaction_id = t.id AND ti.product_id = ?)');
      params.push(Number(product_id));
    }

    if (conditions.length > 0) {
      query += ' WHERE ' + conditions.join(' AND ');
    }
    query += ' ORDER BY t.tanggal DESC, t.id DESC';

    const [txRows] = await pool.query(query, params);

    const txIds = txRows.map((r) => r.id);
    const itemsByTx = {};
    if (txIds.length > 0) {
      const [itemRows] = await pool.query(
        `SELECT ti.*, p.kode_barang, p.nama_barang, p.satuan
         FROM transaction_items ti
         LEFT JOIN products p ON ti.product_id = p.id
         WHERE ti.transaction_id IN (?)
         ORDER BY ti.id ASC`,
        [txIds]
      );
      for (const it of itemRows) {
        if (!itemsByTx[it.transaction_id]) itemsByTx[it.transaction_id] = [];
        itemsByTx[it.transaction_id].push({
          id: Number(it.id),
          product_id: Number(it.product_id),
          kode_barang: it.kode_barang || `BRG-${String(it.product_id).padStart(3, '0')}`,
          nama_barang: it.nama_barang_snapshot || it.nama_barang || 'Produk',
          satuan: it.satuan_snapshot || it.satuan || 'Pack',
          qty: Number(it.qty || 0),
          harga_satuan: Number(it.harga_satuan || 0),
          subtotal: Number(it.subtotal || 0),
        });
      }
    }

    const formatted = txRows.map((r) => formatTransactionRow(r, itemsByTx[r.id] || []));
    const approvedOmzet = formatted
      .filter((t) => t.status_verifikasi === 'disetujui')
      .reduce((sum, t) => sum + t.total, 0);

    return res.json({
      status: true,
      count: formatted.length,
      rekap: {
        total_omzet_disetujui: approvedOmzet,
        count_menunggu: formatted.filter((t) => t.status_verifikasi === 'menunggu').length,
        count_disetujui: formatted.filter((t) => t.status_verifikasi === 'disetujui').length,
        count_ditolak: formatted.filter((t) => t.status_verifikasi === 'ditolak').length,
      },
      data: formatted,
    });
  } catch (error) {
    console.error('[GET /api/transactions] Error:', error);
    return res.status(500).json({ message: 'Gagal memuat data transaksi penjualan: ' + error.message });
  }
});

// --------------------------------------------------------
// 2. POST /api/transactions
//    Sales membuat catatan penjualan baru.
//    - Harga satuan dan total DIHITUNG DI SERVER berdasarkan harga berlaku produk.
//    - Menyimpan salinan nominal harga & nama produk pada detail transaksi.
//    - Menggunakan database transaction.
// --------------------------------------------------------
router.post('/', async (req, res) => {
  const conn = await pool.getConnection();
  try {
    await ensureTransactionSchema();
    const { sales_id, tanggal, nama_pelanggan, catatan, items } = req.body;

    if (!Array.isArray(items) || items.length === 0) {
      conn.release();
      return res.status(400).json({ message: 'Minimal satu produk harus dipilih pada transaksi.' });
    }

    const actor = await resolveActor(req);
    const targetSalesId = actor && !isManagerRole(actor) ? actor.id : Number(sales_id || actor?.id);
    if (!targetSalesId) {
      conn.release();
      return res.status(400).json({ message: 'ID Sales wajib diisi.' });
    }

    const [salesRows] = await conn.query(
      'SELECT * FROM users WHERE id = ? AND deleted_at IS NULL LIMIT 1',
      [targetSalesId]
    );
    if (salesRows.length === 0) {
      conn.release();
      return res.status(404).json({ message: 'Akun Sales tidak ditemukan.' });
    }
    const salesUser = salesRows[0];
    if (salesUser.is_active !== 1 && salesUser.is_active !== true) {
      conn.release();
      return res.status(403).json({
        message: 'Akun Sales sedang nonaktif/ditangguhkan dan tidak dapat membuat transaksi baru.',
      });
    }

    await conn.beginTransaction();

    let serverTotal = 0;
    const preparedItems = [];

    for (const rawItem of items) {
      const prodId = Number(rawItem.product_id);
      const qty = Number(rawItem.qty);
      if (!prodId || isNaN(qty) || qty <= 0 || !Number.isInteger(qty)) {
        await conn.rollback();
        conn.release();
        return res.status(400).json({
          message: 'Jumlah (qty) setiap barang harus berupa bilangan bulat lebih dari 0.',
        });
      }

      const [prodRows] = await conn.query(
        'SELECT * FROM products WHERE id = ? AND deleted_at IS NULL LIMIT 1',
        [prodId]
      );
      if (prodRows.length === 0) {
        await conn.rollback();
        conn.release();
        return res.status(404).json({ message: `Produk dengan ID ${prodId} tidak ditemukan.` });
      }
      const prod = prodRows[0];
      if (prod.is_active !== 1 && prod.is_active !== true) {
        await conn.rollback();
        conn.release();
        return res.status(400).json({
          message: `Produk "${prod.nama_barang}" sedang nonaktif dan tidak dapat dipilih untuk transaksi baru.`,
        });
      }

      // Ambil harga berlaku dari product_prices jika ada, atau fallback ke products.harga
      const [priceRows] = await conn.query(
        `SELECT harga_jual FROM product_prices
         WHERE product_id = ? AND started_at <= NOW() AND (ended_at IS NULL OR ended_at > NOW())
         ORDER BY started_at DESC, id DESC LIMIT 1`,
        [prodId]
      );
      const unitPrice = priceRows.length > 0
        ? Number(priceRows[0].harga_jual)
        : Number(prod.harga || 0);

      if (unitPrice <= 0) {
        await conn.rollback();
        conn.release();
        return res.status(400).json({
          message: `Harga jual produk "${prod.nama_barang}" belum valid.`,
        });
      }

      const lineSubtotal = Number((unitPrice * qty).toFixed(2));
      serverTotal = Number((serverTotal + lineSubtotal).toFixed(2));

      preparedItems.push({
        product_id: prodId,
        nama_barang_snapshot: prod.nama_barang,
        satuan_snapshot: prod.satuan || 'Pack',
        harga_satuan: unitPrice,
        qty,
        subtotal: lineSubtotal,
      });
    }

    const txDate = tanggal || new Date().toISOString().split('T')[0];
    const kodeTransaksi = `TRX-${txDate.replace(/-/g, '')}-${String(Date.now()).slice(-4)}`;

    const [txRes] = await conn.query(
      `INSERT INTO transactions
        (kode_transaksi, sales_id, customer_id, nama_pelanggan, tanggal, subtotal, diskon, total, metode_bayar, status_bayar, status_verifikasi, catatan, created_at)
       VALUES (?, ?, NULL, ?, ?, ?, 0, ?, 'tunai', 'lunas', 'menunggu', ?, NOW())`,
      [
        kodeTransaksi,
        targetSalesId,
        nama_pelanggan ? String(nama_pelanggan).trim() : 'Pelanggan Umum',
        txDate,
        serverTotal,
        serverTotal,
        catatan ? String(catatan).trim() : null,
      ]
    );

    const newTxId = txRes.insertId;
    for (const item of preparedItems) {
      await conn.query(
        `INSERT INTO transaction_items
          (transaction_id, product_id, nama_barang_snapshot, satuan_snapshot, harga_satuan, qty, diskon_item, subtotal)
         VALUES (?, ?, ?, ?, ?, ?, 0, ?)`,
        [
          newTxId,
          item.product_id,
          item.nama_barang_snapshot,
          item.satuan_snapshot,
          item.harga_satuan,
          item.qty,
          item.subtotal,
        ]
      );
    }

    try {
      await conn.query(
        `INSERT INTO activity_logs (user_id, modul, aksi, deskripsi, ip_address)
         VALUES (?, 'FR05_PENDAPATAN', 'CREATE', ?, ?)`,
        [
          targetSalesId,
          `Mencatat penjualan ${kodeTransaksi} senilai Rp ${serverTotal} (${preparedItems.length} item)`,
          req.ip || '127.0.0.1',
        ]
      );
    } catch (_) {}

    await conn.commit();

    const [createdRows] = await pool.query(
      `SELECT t.*, u.name AS sales_name, NULL AS customer_name, NULL AS verified_by_name
       FROM transactions t JOIN users u ON t.sales_id = u.id WHERE t.id = ? LIMIT 1`,
      [newTxId]
    );
    const [createdItems] = await pool.query(
      `SELECT ti.*, p.kode_barang, p.nama_barang, p.satuan
       FROM transaction_items ti LEFT JOIN products p ON ti.product_id = p.id
       WHERE ti.transaction_id = ?`,
      [newTxId]
    );

    return res.status(201).json({
      status: true,
      message: 'Catatan penjualan berhasil disimpan dan menunggu verifikasi Admin.',
      data: formatTransactionRow(
        createdRows[0],
        createdItems.map((it) => ({
          id: Number(it.id),
          product_id: Number(it.product_id),
          kode_barang: it.kode_barang || '',
          nama_barang: it.nama_barang_snapshot || it.nama_barang || 'Produk',
          satuan: it.satuan_snapshot || it.satuan || 'Pack',
          qty: Number(it.qty),
          harga_satuan: Number(it.harga_satuan),
          subtotal: Number(it.subtotal),
        }))
      ),
    });
  } catch (error) {
    try {
      await conn.rollback();
    } catch (_) {}
    console.error('[POST /api/transactions] Error:', error);
    return res.status(500).json({ message: 'Gagal menyimpan catatan penjualan: ' + error.message });
  } finally {
    conn.release();
  }
});

// --------------------------------------------------------
// 3. PUT /api/transactions/:id/verify
//    Admin/Owner menyetujui atau menolak catatan penjualan
//    Catatan yang sudah disetujui tidak boleh diubah langsung
// --------------------------------------------------------
router.put('/:id/verify', async (req, res) => {
  try {
    await ensureTransactionSchema();
    const txId = Number(req.params.id);
    const { status_verifikasi, alasan_penolakan } = req.body;

    if (!['disetujui', 'ditolak'].includes(String(status_verifikasi || '').toLowerCase())) {
      return res.status(400).json({ message: 'Status verifikasi harus disetujui atau ditolak.' });
    }
    const nextStatus = String(status_verifikasi).toLowerCase();

    if (nextStatus === 'ditolak' && (!alasan_penolakan || String(alasan_penolakan).trim() === '')) {
      return res.status(400).json({ message: 'Alasan penolakan wajib diisi.' });
    }

    const actor = await resolveActor(req);
    if (!actor || !isManagerRole(actor)) {
      return res.status(403).json({
        message: 'Akses ditolak: Hanya Admin dan Owner yang berhak memverifikasi catatan penjualan.',
      });
    }

    const [existingRows] = await pool.query('SELECT * FROM transactions WHERE id = ? LIMIT 1', [txId]);
    if (existingRows.length === 0) {
      return res.status(404).json({ message: 'Catatan penjualan tidak ditemukan.' });
    }
    const existing = existingRows[0];

    if (existing.status_verifikasi === 'disetujui') {
      return res.status(400).json({
        message: 'Catatan penjualan yang sudah disetujui tidak dapat diedit langsung. Gunakan proses koreksi/pembatalan.',
      });
    }

    const finalReason = nextStatus === 'ditolak' ? String(alasan_penolakan).trim() : null;

    await pool.query(
      `UPDATE transactions
       SET status_verifikasi = ?, alasan_penolakan = ?, verified_by = ?, verified_at = NOW()
       WHERE id = ?`,
      [nextStatus, finalReason, actor.id, txId]
    );

    try {
      await pool.query(
        `INSERT INTO notifications (user_id, judul, pesan, jenis, referensi_id, referensi_tipe, is_read)
         VALUES (?, ?, ?, 'approval', ?, 'transactions', 0)`,
        [
          existing.sales_id,
          nextStatus === 'disetujui' ? 'Catatan Penjualan Disetujui' : 'Catatan Penjualan Ditolak',
          nextStatus === 'disetujui'
            ? `Transaksi ${existing.kode_transaksi} senilai Rp ${existing.total} telah disetujui.`
            : `Transaksi ${existing.kode_transaksi} ditolak: ${finalReason}`,
          txId,
        ]
      );
      await pool.query(
        `INSERT INTO activity_logs (user_id, modul, aksi, deskripsi, ip_address)
         VALUES (?, 'FR05_PENDAPATAN', 'UPDATE', ?, ?)`,
        [
          actor.id,
          `Verifikasi transaksi ${existing.kode_transaksi} -> ${nextStatus}${finalReason ? ` (${finalReason})` : ''}`,
          req.ip || '127.0.0.1',
        ]
      );
    } catch (_) {}

    const [updatedRows] = await pool.query(
      `SELECT t.*, u.name AS sales_name, c.nama_toko AS customer_name, v.name AS verified_by_name
       FROM transactions t
       JOIN users u ON t.sales_id = u.id
       LEFT JOIN customers c ON t.customer_id = c.id
       LEFT JOIN users v ON t.verified_by = v.id
       WHERE t.id = ? LIMIT 1`,
      [txId]
    );
    const [itemRows] = await pool.query(
      `SELECT ti.*, p.kode_barang, p.nama_barang, p.satuan
       FROM transaction_items ti LEFT JOIN products p ON ti.product_id = p.id
       WHERE ti.transaction_id = ?`,
      [txId]
    );

    return res.json({
      status: true,
      message: `Catatan penjualan ${existing.kode_transaksi} berhasil ${nextStatus}.`,
      data: formatTransactionRow(
        updatedRows[0],
        itemRows.map((it) => ({
          id: Number(it.id),
          product_id: Number(it.product_id),
          kode_barang: it.kode_barang || '',
          nama_barang: it.nama_barang_snapshot || it.nama_barang || 'Produk',
          satuan: it.satuan_snapshot || it.satuan || 'Pack',
          qty: Number(it.qty),
          harga_satuan: Number(it.harga_satuan),
          subtotal: Number(it.subtotal),
        }))
      ),
    });
  } catch (error) {
    console.error('[PUT /api/transactions/:id/verify] Error:', error);
    return res.status(500).json({ message: 'Gagal memverifikasi transaksi: ' + error.message });
  }
});

// --------------------------------------------------------
// 4. POST /api/transactions/:id/cancel
//    Pembatalan / koreksi transaksi yang sudah disetujui dengan audit trail
// --------------------------------------------------------
router.post('/:id/cancel', async (req, res) => {
  try {
    await ensureTransactionSchema();
    const txId = Number(req.params.id);
    const { reason } = req.body;

    if (!reason || String(reason).trim() === '') {
      return res.status(400).json({ message: 'Alasan pembatalan/koreksi wajib diisi.' });
    }

    const actor = await resolveActor(req);
    if (!actor || !isManagerRole(actor)) {
      return res.status(403).json({
        message: 'Akses ditolak: Hanya Admin dan Owner yang berhak membatalkan catatan disetujui.',
      });
    }

    const [existingRows] = await pool.query('SELECT * FROM transactions WHERE id = ? LIMIT 1', [txId]);
    if (existingRows.length === 0) {
      return res.status(404).json({ message: 'Catatan penjualan tidak ditemukan.' });
    }
    const existing = existingRows[0];
    const cleanReason = String(reason).trim();

    await pool.query(
      `UPDATE transactions
       SET status_verifikasi = 'ditolak',
           alasan_penolakan = ?,
           cancelled_reason = ?,
           cancelled_by = ?,
           cancelled_at = NOW()
       WHERE id = ?`,
      [`Dibatalkan/Koreksi: ${cleanReason}`, cleanReason, actor.id, txId]
    );

    try {
      await pool.query(
        `INSERT INTO activity_logs (user_id, modul, aksi, deskripsi, ip_address)
         VALUES (?, 'FR05_PENDAPATAN', 'UPDATE', ?, ?)`,
        [
          actor.id,
          `Membatalkan transaksi disetujui ${existing.kode_transaksi}: ${cleanReason}`,
          req.ip || '127.0.0.1',
        ]
      );
    } catch (_) {}

    const [updatedRows] = await pool.query(
      `SELECT t.*, u.name AS sales_name, c.nama_toko AS customer_name, v.name AS verified_by_name
       FROM transactions t
       JOIN users u ON t.sales_id = u.id
       LEFT JOIN customers c ON t.customer_id = c.id
       LEFT JOIN users v ON t.verified_by = v.id
       WHERE t.id = ? LIMIT 1`,
      [txId]
    );
    const [itemRows] = await pool.query(
      `SELECT ti.*, p.kode_barang, p.nama_barang, p.satuan
       FROM transaction_items ti LEFT JOIN products p ON ti.product_id = p.id
       WHERE ti.transaction_id = ?`,
      [txId]
    );

    return res.json({
      status: true,
      message: `Transaksi ${existing.kode_transaksi} berhasil dibatalkan dengan jejak audit.`,
      data: formatTransactionRow(
        updatedRows[0],
        itemRows.map((it) => ({
          id: Number(it.id),
          product_id: Number(it.product_id),
          kode_barang: it.kode_barang || '',
          nama_barang: it.nama_barang_snapshot || it.nama_barang || 'Produk',
          satuan: it.satuan_snapshot || it.satuan || 'Pack',
          qty: Number(it.qty),
          harga_satuan: Number(it.harga_satuan),
          subtotal: Number(it.subtotal),
        }))
      ),
    });
  } catch (error) {
    console.error('[POST /api/transactions/:id/cancel] Error:', error);
    return res.status(500).json({ message: 'Gagal membatalkan transaksi: ' + error.message });
  }
});

module.exports = {
  router,
  ensureTransactionSchema,
};
