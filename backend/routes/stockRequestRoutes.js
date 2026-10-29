const express = require('express');
const router = express.Router();
const { pool } = require('../config/db');
const { ensureProductAndStockSchema } = require('./productRoutes');

function formatApproverDisplay(name, role) {
  if (!name && !role) return null;
  let roleLabel = '';
  if (role === 'superadmin' || role === 'owner') {
    roleLabel = 'Superadmin (Owner)';
  } else if (role === 'administrator' || role === 'admin') {
    roleLabel = 'Administrator';
  } else if (role) {
    roleLabel = role;
  }
  if (name && roleLabel) return `${name} • ${roleLabel}`;
  return name || roleLabel;
}

function formatStockRequestRow(row) {
  const createdYear = row.created_at ? new Date(row.created_at).getFullYear() : 2026;
  const kodePengajuan = `REQ-${createdYear}-${String(row.id).padStart(3, '0')}`;

  const namaBarang = row.nama_barang || row.nama_barang_custom || '';
  const kodeBarang = row.kode_barang || row.kode_barang_custom || `BRG-${String(row.id).padStart(3, '0')}`;
  const kategori = row.kategori || row.kategori_custom || 'Plastik';
  const satuan = row.satuan || row.satuan_custom || 'Pack';
  const fotoUrl = row.foto_url || row.foto_url_custom || 'preset:plastik';

  return {
    id: Number(row.id),
    kode_pengajuan: kodePengajuan,
    sales_id: Number(row.sales_id),
    sales_name: row.sales_name || 'Sales',
    sales_email: row.sales_email || '',
    sales_phone: row.sales_phone || '',
    sales_photo_url: row.sales_photo_url || null,
    product_id: row.product_id ? Number(row.product_id) : null,
    kode_barang: kodeBarang,
    nama_barang: namaBarang,
    kategori: kategori,
    satuan: satuan,
    foto_url: fotoUrl,
    stok_gudang: row.stok_gudang != null ? Number(row.stok_gudang) : 0,
    stok_sales: row.stok_sales != null ? Number(row.stok_sales) : 0,
    jenis: row.jenis || 'tambah',
    qty_diajukan: Number(row.qty_diajukan || 1),
    qty_disetujui: row.qty_disetujui != null ? Number(row.qty_disetujui) : null,
    alasan: row.alasan || '',
    status: row.status || 'menunggu',
    catatan_admin: row.catatan_admin || null,
    approved_by: row.approved_by ? Number(row.approved_by) : null,
    approver_name: row.approver_name || null,
    approver_role: row.approver_role || null,
    diproses_oleh: formatApproverDisplay(row.approver_name, row.approver_role),
    approved_at: row.approved_at ? new Date(row.approved_at).toISOString() : null,
    created_at: row.created_at ? new Date(row.created_at).toISOString() : new Date().toISOString(),
  };
}

const BASE_SELECT_QUERY = `
  SELECT sr.*,
         u.name AS sales_name,
         u.email AS sales_email,
         u.phone AS sales_phone,
         u.photo_url AS sales_photo_url,
         p.kode_barang AS kode_barang,
         p.nama_barang AS nama_barang,
         p.kategori AS kategori,
         p.satuan AS satuan,
         p.foto_url AS foto_url,
         p.stok_gudang AS stok_gudang,
         COALESCE(
           (SELECT si.stok_sisa
            FROM sales_inventory si
            WHERE si.product_id = sr.product_id AND si.sales_id = sr.sales_id
            ORDER BY si.updated_at DESC, si.id DESC
            LIMIT 1),
           0
         ) AS stok_sales,
         a.name AS approver_name,
         a.role AS approver_role
  FROM stock_requests sr
  JOIN users u ON sr.sales_id = u.id
  LEFT JOIN products p ON sr.product_id = p.id
  LEFT JOIN users a ON sr.approved_by = a.id
`;

// --------------------------------------------------------
// 1. GET /api/stock-requests
//    Ambil semua pengajuan stok (Admin/Owner melihat semua, Sales bisa filter)
// --------------------------------------------------------
router.get('/', async (req, res) => {
  try {
    await ensureProductAndStockSchema();
    const { sales_id, sales_email, status } = req.query;
    const conditions = [];
    const params = [];

    if (sales_id) {
      conditions.push('sr.sales_id = ?');
      params.push(sales_id);
    } else if (sales_email) {
      conditions.push('LOWER(u.email) = ?');
      params.push(String(sales_email).trim().toLowerCase());
    }

    if (status && ['menunggu', 'disetujui', 'ditolak'].includes(String(status).toLowerCase())) {
      conditions.push('sr.status = ?');
      params.push(String(status).toLowerCase());
    }

    let query = BASE_SELECT_QUERY;
    if (conditions.length > 0) {
      query += ' WHERE ' + conditions.join(' AND ');
    }
    query += ' ORDER BY sr.created_at DESC, sr.id DESC';

    const [rows] = await pool.query(query, params);
    return res.json({
      status: true,
      count: rows.length,
      data: rows.map(formatStockRequestRow),
    });
  } catch (error) {
    console.error('[GET /api/stock-requests] Error:', error);
    return res.status(500).json({
      message: 'Gagal memuat data pengajuan stok: ' + error.message,
    });
  }
});

// --------------------------------------------------------
// 2. POST /api/stock-requests
//    Sales mengajukan kebutuhan barang (dicatat di stock_requests dengan status menunggu)
// --------------------------------------------------------
router.post('/', async (req, res) => {
  try {
    await ensureProductAndStockSchema();
    const {
      sales_id,
      sales_email,
      product_id,
      kode_barang_custom,
      nama_barang_custom,
      kategori_custom,
      satuan_custom,
      foto_url_custom,
      jenis,
      qty_diajukan,
      alasan,
    } = req.body;

    if (!alasan || String(alasan).trim() === '') {
      return res.status(400).json({ message: 'Alasan pengajuan barang wajib diisi.' });
    }

    const qty = Math.max(1, Number(qty_diajukan) || 1);
    const validJenis = ['tambah', 'kurang', 'retur'].includes(String(jenis || '').toLowerCase())
      ? String(jenis).toLowerCase()
      : 'tambah';

    // Cari user sales
    let salesUser = null;
    if (sales_id) {
      const [uRows] = await pool.query('SELECT * FROM users WHERE id = ? AND deleted_at IS NULL LIMIT 1', [
        sales_id,
      ]);
      if (uRows.length > 0) salesUser = uRows[0];
    }
    if (!salesUser && sales_email) {
      const [uRows] = await pool.query(
        'SELECT * FROM users WHERE LOWER(email) = ? AND deleted_at IS NULL LIMIT 1',
        [String(sales_email).trim().toLowerCase()]
      );
      if (uRows.length > 0) salesUser = uRows[0];
    }
    if (!salesUser) {
      const [fallbackRows] = await pool.query(
        "SELECT * FROM users WHERE role = 'sales' AND deleted_at IS NULL ORDER BY id ASC LIMIT 1"
      );
      salesUser = fallbackRows[0] || { id: 3, name: 'Budi Santoso' };
    }

    // Cek produk jika product_id dikirim
    let prodRow = null;
    if (product_id) {
      const [pRows] = await pool.query('SELECT * FROM products WHERE id = ? LIMIT 1', [product_id]);
      if (pRows.length > 0) prodRow = pRows[0];
    }

    const finalKodeCustom = prodRow
      ? prodRow.kode_barang
      : kode_barang_custom || `BRG-${String(Date.now()).slice(-3)}`;
    const finalNamaCustom = prodRow
      ? prodRow.nama_barang
      : nama_barang_custom || 'Plastik Kresek 1kg';
    const finalKategoriCustom = prodRow
      ? prodRow.kategori || 'Plastik'
      : kategori_custom || 'Plastik';
    const finalSatuanCustom = prodRow ? prodRow.satuan || 'Pack' : satuan_custom || 'Pack';
    const finalFotoCustom = prodRow
      ? prodRow.foto_url || 'preset:plastik'
      : foto_url_custom || 'preset:plastik';

    const [insertResult] = await pool.query(
      `INSERT INTO stock_requests
        (sales_id, product_id, kode_barang_custom, nama_barang_custom, kategori_custom, satuan_custom, foto_url_custom, jenis, qty_diajukan, alasan, status, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'menunggu', NOW())`,
      [
        salesUser.id,
        prodRow ? prodRow.id : null,
        finalKodeCustom,
        finalNamaCustom,
        finalKategoriCustom,
        finalSatuanCustom,
        finalFotoCustom,
        validJenis,
        qty,
        String(alasan).trim(),
      ]
    );

    try {
      await pool.query(
        `INSERT INTO activity_logs (user_id, modul, aksi, deskripsi, ip_address)
         VALUES (?, 'FR10_PENGAJUAN_STOK', 'CREATE', ?, ?)`,
        [
          salesUser.id,
          `Sales ${salesUser.name} mengajukan ${validJenis} stok ${finalNamaCustom} sebanyak ${qty} ${finalSatuanCustom}`,
          req.ip || '127.0.0.1',
        ]
      );
    } catch (_) {}

    const [createdRows] = await pool.query(`${BASE_SELECT_QUERY} WHERE sr.id = ? LIMIT 1`, [
      insertResult.insertId,
    ]);

    return res.status(201).json({
      status: true,
      message: 'Pengajuan barang berhasil dikirim dan menunggu persetujuan Admin/Owner.',
      data: formatStockRequestRow(createdRows[0]),
    });
  } catch (error) {
    console.error('[POST /api/stock-requests] Error:', error);
    return res.status(500).json({
      message: 'Gagal mengirim pengajuan stok: ' + error.message,
    });
  }
});

// --------------------------------------------------------
// 3. PUT /api/stock-requests/:id/status
//    Admin / Owner menyetujui (disetujui), menolak (ditolak), atau mengembalikan ke menunggu.
//    Saat disetujui:
//    - Jika barang belum ada di tabel products (product_id NULL), otomatis ditambahkan ke tabel products!
//    - Memperbarui stok di sales_inventory dan stok_gudang di products!
// --------------------------------------------------------
router.put('/:id/status', async (req, res) => {
  try {
    await ensureProductAndStockSchema();
    const reqId = Number(req.params.id);
    const {
      status,
      qty_disetujui,
      tambahan_stok_gudang,
      catatan_admin,
      reviewer_id,
      reviewer_email,
    } = req.body;

    if (!['menunggu', 'disetujui', 'ditolak'].includes(status)) {
      return res.status(400).json({ message: 'Status persetujuan tidak valid.' });
    }

    const [existingRows] = await pool.query('SELECT * FROM stock_requests WHERE id = ? LIMIT 1', [
      reqId,
    ]);
    if (existingRows.length === 0) {
      return res.status(404).json({ message: 'Data pengajuan stok tidak ditemukan.' });
    }
    const reqItem = existingRows[0];

    // Cari reviewer Admin / Owner
    let reviewer = null;
    if (reviewer_id) {
      const [rRows] = await pool.query('SELECT * FROM users WHERE id = ? AND deleted_at IS NULL LIMIT 1', [
        reviewer_id,
      ]);
      if (rRows.length > 0) reviewer = rRows[0];
    }
    if (!reviewer && reviewer_email) {
      const [rRows] = await pool.query(
        'SELECT * FROM users WHERE LOWER(email) = ? AND deleted_at IS NULL LIMIT 1',
        [String(reviewer_email).trim().toLowerCase()]
      );
      if (rRows.length > 0) reviewer = rRows[0];
    }

    if (reviewer) {
      const validRoles = ['superadmin', 'owner', 'administrator', 'admin'];
      if (!validRoles.includes(String(reviewer.role).toLowerCase())) {
        return res.status(403).json({
          message: 'Akses ditolak: Hanya Admin dan Owner yang berhak memproses pengajuan stok.',
        });
      }
    }

    const approverId = reviewer ? reviewer.id : 2;

    if (status === 'menunggu') {
      await pool.query(
        `UPDATE stock_requests
         SET status = 'menunggu', qty_disetujui = NULL, catatan_admin = NULL, approved_by = NULL, approved_at = NULL
         WHERE id = ?`,
        [reqId]
      );
    } else if (status === 'ditolak') {
      const finalNote =
        catatan_admin && String(catatan_admin).trim() !== ''
          ? String(catatan_admin).trim()
          : 'Pengajuan stok ditolak oleh Admin/Owner.';
      await pool.query(
        `UPDATE stock_requests
         SET status = 'ditolak', qty_disetujui = 0, catatan_admin = ?, approved_by = ?, approved_at = NOW()
         WHERE id = ?`,
        [finalNote, approverId, reqId]
      );
    } else if (status === 'disetujui') {
      const approvedQty =
        qty_disetujui != null && Number(qty_disetujui) > 0
          ? Number(qty_disetujui)
          : Number(reqItem.qty_diajukan || 1);
      const restockWarehouseQty = Math.max(0, Number(tambahan_stok_gudang) || 0);
      const finalNote =
        catatan_admin && String(catatan_admin).trim() !== ''
          ? String(catatan_admin).trim()
          : 'Pengajuan stok disetujui dan stok barang telah diperbarui pada sistem.';

      let targetProductId = reqItem.product_id ? Number(reqItem.product_id) : null;

      // Jika produk belum ada di tabel products (pengajuan barang baru dari sales), buat di tabel products
      if (!targetProductId) {
        const namaCustom = reqItem.nama_barang_custom || 'Plastik Baru';
        const [matchProds] = await pool.query(
          'SELECT * FROM products WHERE LOWER(nama_barang) = ? AND deleted_at IS NULL LIMIT 1',
          [String(namaCustom).trim().toLowerCase()]
        );
        if (matchProds.length > 0) {
          targetProductId = Number(matchProds[0].id);
        } else {
          const newKode =
            reqItem.kode_barang_custom || `BRG-${String(Date.now()).slice(-3)}`;
          const initialWarehouseStock = Math.max(50, approvedQty + restockWarehouseQty);
          const [newProdRes] = await pool.query(
            `INSERT INTO products
              (kode_barang, nama_barang, kategori, deskripsi, satuan, stok_gudang, foto_url, is_active, created_by, created_at, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?, NOW(), NOW())`,
            [
              newKode,
              namaCustom,
              reqItem.kategori_custom || 'Plastik',
              `Produk ditambahkan dari pengajuan stok sales (${reqItem.alasan})`,
              reqItem.satuan_custom || 'Pack',
              initialWarehouseStock,
              reqItem.foto_url_custom || 'preset:plastik',
              approverId,
            ]
          );
          targetProductId = Number(newProdRes.insertId);
        }
      }

      // Hanya mutasi stok jika sebelumnya belum disetujui
      if (reqItem.status !== 'disetujui' && targetProductId) {
        // Tambah stok gudang terlebih dahulu jika Admin menambahkan restock gudang
        if (restockWarehouseQty > 0) {
          await pool.query(
            'UPDATE products SET stok_gudang = stok_gudang + ?, updated_at = NOW() WHERE id = ?',
            [restockWarehouseQty, targetProductId]
          );
        }

        // Ambil data produk terkini
        const [pRows] = await pool.query('SELECT * FROM products WHERE id = ? LIMIT 1', [
          targetProductId,
        ]);
        const currentGudang = pRows.length > 0 ? Number(pRows[0].stok_gudang || 0) : 0;

        // Ambil atau buat baris sales_inventory untuk sales_id & product_id
        const [invRows] = await pool.query(
          'SELECT * FROM sales_inventory WHERE sales_id = ? AND product_id = ? ORDER BY id DESC LIMIT 1',
          [reqItem.sales_id, targetProductId]
        );
        let currentSalesStock = invRows.length > 0 ? Number(invRows[0].stok_sisa || 0) : 2;
        let currentSalesAwal = invRows.length > 0 ? Number(invRows[0].stok_awal || 10) : 10;

        if (reqItem.jenis === 'tambah') {
          currentSalesStock += approvedQty;
          currentSalesAwal += approvedQty;
          // Jika stok gudang cukup, kurangi dari gudang; jika kurang, gudang di-restock otomatis agar siap kirim
          const nextGudang =
            currentGudang >= approvedQty ? currentGudang - approvedQty : currentGudang;
          await pool.query(
            'UPDATE products SET stok_gudang = ?, is_active = 1, updated_at = NOW() WHERE id = ?',
            [nextGudang, targetProductId]
          );
        } else if (reqItem.jenis === 'kurang') {
          currentSalesStock = Math.max(0, currentSalesStock - approvedQty);
        } else if (reqItem.jenis === 'retur') {
          currentSalesStock = Math.max(0, currentSalesStock - approvedQty);
          await pool.query(
            'UPDATE products SET stok_gudang = stok_gudang + ?, updated_at = NOW() WHERE id = ?',
            [approvedQty, targetProductId]
          );
        }

        if (invRows.length > 0) {
          await pool.query(
            'UPDATE sales_inventory SET stok_awal = ?, stok_sisa = ?, updated_at = NOW() WHERE id = ?',
            [currentSalesAwal, currentSalesStock, invRows[0].id]
          );
        } else {
          await pool.query(
            `INSERT INTO sales_inventory (sales_id, product_id, stok_awal, stok_terjual, stok_sisa, tanggal)
             VALUES (?, ?, ?, 0, ?, CURDATE())`,
            [reqItem.sales_id, targetProductId, currentSalesAwal, currentSalesStock]
          );
        }
      }

      await pool.query(
        `UPDATE stock_requests
         SET product_id = ?, status = 'disetujui', qty_disetujui = ?, catatan_admin = ?, approved_by = ?, approved_at = NOW()
         WHERE id = ?`,
        [targetProductId, approvedQty, finalNote, approverId, reqId]
      );
    }

    // Kirim notifikasi ke sales
    if (status !== 'menunggu') {
      try {
        const judulNotif =
          status === 'disetujui' ? 'Pengajuan Stok Disetujui' : 'Pengajuan Stok Ditolak';
        await pool.query(
          `INSERT INTO notifications (user_id, judul, pesan, jenis, referensi_id, referensi_tipe, is_read)
           VALUES (?, ?, ?, 'approval', ?, 'stock_requests', 0)`,
          [
            reqItem.sales_id,
            judulNotif,
            catatan_admin || `Pengajuan stok #${reqId} telah ${status}.`,
            reqId,
          ]
        );
      } catch (_) {}
    }

    const [updatedRows] = await pool.query(`${BASE_SELECT_QUERY} WHERE sr.id = ? LIMIT 1`, [reqId]);

    return res.json({
      status: true,
      message: `Status pengajuan stok berhasil diperbarui menjadi ${status}.`,
      data: formatStockRequestRow(updatedRows[0]),
    });
  } catch (error) {
    console.error('[PUT /api/stock-requests/:id/status] Error:', error);
    return res.status(500).json({
      message: 'Gagal memperbarui status pengajuan stok: ' + error.message,
    });
  }
});

// --------------------------------------------------------
// 4. DELETE /api/stock-requests/:id
//    Hapus atau batalkan pengajuan stok
// --------------------------------------------------------
router.delete('/:id', async (req, res) => {
  try {
    await ensureProductAndStockSchema();
    const reqId = Number(req.params.id);
    await pool.query('DELETE FROM stock_requests WHERE id = ?', [reqId]);
    return res.json({
      status: true,
      message: 'Data pengajuan stok berhasil dihapus.',
    });
  } catch (error) {
    console.error('[DELETE /api/stock-requests/:id] Error:', error);
    return res.status(500).json({
      message: 'Gagal menghapus pengajuan stok: ' + error.message,
    });
  }
});

module.exports = router;
