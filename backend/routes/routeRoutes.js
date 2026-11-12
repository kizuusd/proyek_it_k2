const express = require('express');
const router = express.Router();
const { pool } = require('../config/db');
const { resolveActor, isManagerRole } = require('./userRoutes');

let routeSchemaInitialized = false;

async function ensureRouteSchema() {
  if (routeSchemaInitialized) return;
  try {
    await pool.query('ALTER TABLE sales_routes MODIFY COLUMN customer_id BIGINT(20) DEFAULT NULL');
    await pool.query(
      "ALTER TABLE sales_routes MODIFY COLUMN status ENUM('belum_dikunjungi','dalam_perjalanan','selesai','dibatalkan','dijadwalkan','dilewati') NOT NULL DEFAULT 'belum_dikunjungi'"
    );

    const [cols] = await pool.query('SHOW COLUMNS FROM sales_routes');
    const colNames = cols.map((c) => c.Field);
    if (!colNames.includes('waktu_mulai')) {
      await pool.query("ALTER TABLE sales_routes ADD COLUMN waktu_mulai TIME DEFAULT '09:00:00' AFTER tanggal");
    }
    if (!colNames.includes('waktu_selesai')) {
      await pool.query("ALTER TABLE sales_routes ADD COLUMN waktu_selesai TIME DEFAULT '10:00:00' AFTER waktu_mulai");
    }
    if (!colNames.includes('nama_tujuan')) {
      await pool.query('ALTER TABLE sales_routes ADD COLUMN nama_tujuan VARCHAR(255) DEFAULT NULL AFTER waktu_selesai');
    }
    if (!colNames.includes('alamat_tujuan')) {
      await pool.query('ALTER TABLE sales_routes ADD COLUMN alamat_tujuan TEXT DEFAULT NULL AFTER nama_tujuan');
    }
    if (!colNames.includes('catatan_hasil')) {
      await pool.query('ALTER TABLE sales_routes ADD COLUMN catatan_hasil TEXT DEFAULT NULL AFTER catatan');
    }
    if (!colNames.includes('alasan_perubahan')) {
      await pool.query('ALTER TABLE sales_routes ADD COLUMN alasan_perubahan TEXT DEFAULT NULL AFTER catatan_hasil');
    }
    if (!colNames.includes('updated_by')) {
      await pool.query('ALTER TABLE sales_routes ADD COLUMN updated_by BIGINT(20) DEFAULT NULL AFTER created_by');
    }

    routeSchemaInitialized = true;
  } catch (err) {
    console.error('[ensureRouteSchema] Warning:', err.message);
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

function formatTimeHHMM(val, fallback = '09:00') {
  if (!val) return fallback;
  const str = String(val);
  const m = str.match(/^(\d{2}):(\d{2})/);
  if (m) return `${m[1]}:${m[2]}`;
  return fallback;
}

function normalizeStatus(raw) {
  const s = String(raw || 'belum_dikunjungi').toLowerCase();
  if (s === 'dijadwalkan') return 'belum_dikunjungi';
  if (s === 'dilewati') return 'dibatalkan';
  return s;
}

function formatRouteRow(row) {
  return {
    id: Number(row.id),
    sales_id: Number(row.sales_id),
    sales_name: row.sales_name || 'Sales Lapangan',
    customer_id: row.customer_id ? Number(row.customer_id) : null,
    tanggal: formatDateYMD(row.tanggal),
    waktu_mulai: formatTimeHHMM(row.waktu_mulai, '09:00'),
    waktu_selesai: formatTimeHHMM(row.waktu_selesai, '10:00'),
    nama_tujuan: row.nama_tujuan || row.customer_name || 'Pelanggan',
    alamat_tujuan: row.alamat_tujuan || row.customer_address || '',
    urutan: Number(row.urutan || 1),
    catatan: row.catatan || '',
    catatan_hasil: row.catatan_hasil || '',
    alasan_perubahan: row.alasan_perubahan || '',
    status: normalizeStatus(row.status),
    created_by: row.created_by ? Number(row.created_by) : null,
    creator_name: row.creator_name || 'Admin',
    updated_by_name: row.updated_by_name || null,
    updated_at: row.updated_at ? new Date(row.updated_at).toISOString() : null,
    created_at: row.created_at ? new Date(row.created_at).toISOString() : null,
  };
}

const BASE_SELECT = `
  SELECT sr.*,
         u.name AS sales_name,
         c.nama_toko AS customer_name,
         c.alamat AS customer_address,
         cr.name AS creator_name,
         up.name AS updated_by_name
  FROM sales_routes sr
  JOIN users u ON sr.sales_id = u.id
  LEFT JOIN customers c ON sr.customer_id = c.id
  LEFT JOIN users cr ON sr.created_by = cr.id
  LEFT JOIN users up ON sr.updated_by = up.id
`;

function toMinutes(hhmm) {
  const parts = String(hhmm).split(':');
  if (parts.length < 2) return -1;
  const h = Number(parts[0]);
  const m = Number(parts[1]);
  if (isNaN(h) || isNaN(m) || h < 0 || h > 23 || m < 0 || m > 59) return -1;
  return h * 60 + m;
}

// --------------------------------------------------------
// 1. GET /api/routes
// --------------------------------------------------------
router.get('/', async (req, res) => {
  try {
    await ensureRouteSchema();
    const { sales_id, tanggal, status } = req.query;
    const conditions = [];
    const params = [];

    if (sales_id) {
      conditions.push('sr.sales_id = ?');
      params.push(Number(sales_id));
    }
    if (tanggal) {
      conditions.push('sr.tanggal = ?');
      params.push(tanggal);
    }
    if (status && status !== 'semua') {
      const normalized = normalizeStatus(status);
      if (normalized === 'belum_dikunjungi') {
        conditions.push("sr.status IN ('belum_dikunjungi','dijadwalkan')");
      } else {
        conditions.push('sr.status = ?');
        params.push(normalized);
      }
    }

    let query = BASE_SELECT;
    if (conditions.length > 0) {
      query += ' WHERE ' + conditions.join(' AND ');
    }
    query += ' ORDER BY sr.tanggal ASC, sr.urutan ASC, sr.waktu_mulai ASC, sr.id ASC';

    const [rows] = await pool.query(query, params);
    return res.json({
      status: true,
      count: rows.length,
      data: rows.map(formatRouteRow),
    });
  } catch (error) {
    console.error('[GET /api/routes] Error:', error);
    return res.status(500).json({ message: 'Gagal memuat data jadwal rute: ' + error.message });
  }
});

// --------------------------------------------------------
// 2. POST /api/routes (Buat jadwal kunjungan oleh Admin/Owner)
// --------------------------------------------------------
router.post('/', async (req, res) => {
  try {
    await ensureRouteSchema();
    const {
      sales_id,
      tanggal,
      waktu_mulai,
      waktu_selesai,
      nama_tujuan,
      alamat_tujuan,
      urutan,
      catatan,
      created_by,
    } = req.body;

    const actor = await resolveActor(req);
    if (actor && !isManagerRole(actor)) {
      return res.status(403).json({
        message: 'Akses ditolak: Hanya Admin dan Owner yang berhak membuat jadwal kunjungan.',
      });
    }

    if (!sales_id || !tanggal || !nama_tujuan || !alamat_tujuan) {
      return res.status(400).json({
        message: 'Sales, tanggal, nama tujuan/pelanggan, dan alamat wajib diisi.',
      });
    }

    const startStr = formatTimeHHMM(waktu_mulai || '09:00');
    const endStr = formatTimeHHMM(waktu_selesai || '10:00');
    const startMin = toMinutes(startStr);
    const endMin = toMinutes(endStr);

    if (startMin < 0 || endMin < 0 || endMin <= startMin) {
      return res.status(400).json({
        message: 'Waktu selesai kunjungan harus lebih akhir daripada waktu mulai.',
      });
    }

    // Pastikan Sales aktif
    const [salesRows] = await pool.query(
      'SELECT * FROM users WHERE id = ? AND deleted_at IS NULL LIMIT 1',
      [Number(sales_id)]
    );
    if (salesRows.length === 0) {
      return res.status(404).json({ message: 'Anggota Sales tidak ditemukan.' });
    }
    const salesUser = salesRows[0];
    if (salesUser.is_active !== 1 && salesUser.is_active !== true) {
      return res.status(400).json({
        message: `Sales "${salesUser.name}" sedang nonaktif/ditangguhkan dan tidak dapat dijadwalkan.`,
      });
    }

    // Validasi bentrok jadwal pada tanggal & sales yang sama (kecuali yg dibatalkan)
    const [conflicts] = await pool.query(
      `SELECT id, nama_tujuan, waktu_mulai, waktu_selesai
       FROM sales_routes
       WHERE sales_id = ?
         AND tanggal = ?
         AND status NOT IN ('dibatalkan', 'dilewati')
         AND NOT (waktu_selesai <= ? OR waktu_mulai >= ?)
       LIMIT 1`,
      [Number(sales_id), tanggal, `${startStr}:00`, `${endStr}:00`]
    );
    if (conflicts.length > 0) {
      const c = conflicts[0];
      return res.status(409).json({
        message: `Jadwal bentrok dengan kunjungan "${c.nama_tujuan}" (${formatTimeHHMM(c.waktu_mulai)} - ${formatTimeHHMM(c.waktu_selesai)}) pada tanggal yang sama.`,
      });
    }

    const creatorId = actor ? actor.id : (Number(created_by) || 2);
    const seqOrder = Math.max(1, Number(urutan) || 1);

    const [insertResult] = await pool.query(
      `INSERT INTO sales_routes
        (sales_id, customer_id, tanggal, waktu_mulai, waktu_selesai, nama_tujuan, alamat_tujuan, urutan, catatan, status, created_by, updated_by, created_at, updated_at)
       VALUES (?, NULL, ?, ?, ?, ?, ?, ?, ?, 'belum_dikunjungi', ?, ?, NOW(), NOW())`,
      [
        Number(sales_id),
        tanggal,
        `${startStr}:00`,
        `${endStr}:00`,
        String(nama_tujuan).trim(),
        String(alamat_tujuan).trim(),
        seqOrder,
        catatan ? String(catatan).trim() : null,
        creatorId,
        creatorId,
      ]
    );

    try {
      await pool.query(
        `INSERT INTO notifications (user_id, judul, pesan, jenis, referensi_id, referensi_tipe, is_read)
         VALUES (?, 'Jadwal Kunjungan Baru', ?, 'info', ?, 'sales_routes', 0)`,
        [
          Number(sales_id),
          `Anda dijadwalkan mengunjungi ${String(nama_tujuan).trim()} pada ${tanggal} pukul ${startStr} - ${endStr}.`,
          insertResult.insertId,
        ]
      );
      await pool.query(
        `INSERT INTO activity_logs (user_id, modul, aksi, deskripsi, ip_address)
         VALUES (?, 'FR04_JADWAL_RUTE', 'CREATE', ?, ?)`,
        [
          creatorId,
          `Membuat jadwal kunjungan untuk ${salesUser.name}: ${String(nama_tujuan).trim()} (${tanggal} ${startStr}-${endStr})`,
          req.ip || '127.0.0.1',
        ]
      );
    } catch (_) {}

    const [createdRows] = await pool.query(`${BASE_SELECT} WHERE sr.id = ? LIMIT 1`, [
      insertResult.insertId,
    ]);
    return res.status(201).json({
      status: true,
      message: 'Jadwal kunjungan berhasil dibuat.',
      data: formatRouteRow(createdRows[0]),
    });
  } catch (error) {
    console.error('[POST /api/routes] Error:', error);
    return res.status(500).json({ message: 'Gagal membuat jadwal kunjungan: ' + error.message });
  }
});

// --------------------------------------------------------
// 3. PUT /api/routes/:id (Ubah / batalkan jadwal dengan alasan oleh Admin/Owner)
// --------------------------------------------------------
router.put('/:id', async (req, res) => {
  try {
    await ensureRouteSchema();
    const routeId = Number(req.params.id);
    const {
      sales_id,
      tanggal,
      waktu_mulai,
      waktu_selesai,
      nama_tujuan,
      alamat_tujuan,
      urutan,
      catatan,
      status,
      alasan_perubahan,
    } = req.body;

    const actor = await resolveActor(req);
    if (actor && !isManagerRole(actor)) {
      return res.status(403).json({
        message: 'Akses ditolak: Hanya Admin dan Owner yang berhak mengubah jadwal kunjungan.',
      });
    }

    const [existingRows] = await pool.query('SELECT * FROM sales_routes WHERE id = ? LIMIT 1', [routeId]);
    if (existingRows.length === 0) {
      return res.status(404).json({ message: 'Jadwal kunjungan tidak ditemukan.' });
    }
    const existing = existingRows[0];

    const finalSalesId = sales_id ? Number(sales_id) : Number(existing.sales_id);
    const finalTanggal = tanggal || formatDateYMD(existing.tanggal);
    const startStr = formatTimeHHMM(waktu_mulai || existing.waktu_mulai, '09:00');
    const endStr = formatTimeHHMM(waktu_selesai || existing.waktu_selesai, '10:00');
    const startMin = toMinutes(startStr);
    const endMin = toMinutes(endStr);

    if (startMin < 0 || endMin < 0 || endMin <= startMin) {
      return res.status(400).json({
        message: 'Waktu selesai kunjungan harus lebih akhir daripada waktu mulai.',
      });
    }

    const finalStatus = status ? normalizeStatus(status) : normalizeStatus(existing.status);
    if (finalStatus !== 'dibatalkan') {
      const [conflicts] = await pool.query(
        `SELECT id, nama_tujuan, waktu_mulai, waktu_selesai
         FROM sales_routes
         WHERE sales_id = ?
           AND tanggal = ?
           AND id != ?
           AND status NOT IN ('dibatalkan', 'dilewati')
           AND NOT (waktu_selesai <= ? OR waktu_mulai >= ?)
         LIMIT 1`,
        [finalSalesId, finalTanggal, routeId, `${startStr}:00`, `${endStr}:00`]
      );
      if (conflicts.length > 0) {
        const c = conflicts[0];
        return res.status(409).json({
          message: `Jadwal bentrok dengan "${c.nama_tujuan}" (${formatTimeHHMM(c.waktu_mulai)} - ${formatTimeHHMM(c.waktu_selesai)}).`,
        });
      }
    }

    const finalNama = nama_tujuan !== undefined ? String(nama_tujuan).trim() : existing.nama_tujuan;
    const finalAlamat = alamat_tujuan !== undefined ? String(alamat_tujuan).trim() : existing.alamat_tujuan;
    const finalUrutan = urutan !== undefined ? Math.max(1, Number(urutan) || 1) : existing.urutan;
    const finalCatatan = catatan !== undefined ? String(catatan).trim() : existing.catatan;
    const finalReason = alasan_perubahan ? String(alasan_perubahan).trim() : existing.alasan_perubahan;
    const updaterId = actor ? actor.id : (existing.updated_by || 2);

    await pool.query(
      `UPDATE sales_routes
       SET sales_id = ?, tanggal = ?, waktu_mulai = ?, waktu_selesai = ?,
           nama_tujuan = ?, alamat_tujuan = ?, urutan = ?, catatan = ?,
           status = ?, alasan_perubahan = ?, updated_by = ?, updated_at = NOW()
       WHERE id = ?`,
      [
        finalSalesId,
        finalTanggal,
        `${startStr}:00`,
        `${endStr}:00`,
        finalNama,
        finalAlamat,
        finalUrutan,
        finalCatatan,
        finalStatus,
        finalReason,
        updaterId,
        routeId,
      ]
    );

    try {
      await pool.query(
        `INSERT INTO notifications (user_id, judul, pesan, jenis, referensi_id, referensi_tipe, is_read)
         VALUES (?, 'Perubahan Jadwal Kunjungan', ?, 'peringatan', ?, 'sales_routes', 0)`,
        [
          finalSalesId,
          `Jadwal ke ${finalNama} (${finalTanggal} ${startStr}-${endStr}) diperbarui (${finalStatus})${finalReason ? `: ${finalReason}` : '.'}`,
          routeId,
        ]
      );
      await pool.query(
        `INSERT INTO activity_logs (user_id, modul, aksi, deskripsi, ip_address)
         VALUES (?, 'FR04_JADWAL_RUTE', 'UPDATE', ?, ?)`,
        [
          updaterId,
          `Memperbarui jadwal #${routeId} (${finalNama} - ${finalStatus})${finalReason ? ` Alasan: ${finalReason}` : ''}`,
          req.ip || '127.0.0.1',
        ]
      );
    } catch (_) {}

    const [updatedRows] = await pool.query(`${BASE_SELECT} WHERE sr.id = ? LIMIT 1`, [routeId]);
    return res.json({
      status: true,
      message: 'Jadwal kunjungan berhasil diperbarui.',
      data: formatRouteRow(updatedRows[0]),
    });
  } catch (error) {
    console.error('[PUT /api/routes/:id] Error:', error);
    return res.status(500).json({ message: 'Gagal memperbarui jadwal kunjungan: ' + error.message });
  }
});

// --------------------------------------------------------
// 4. PATCH /api/routes/:id/status (Sales memperbarui status & catatan hasil kunjungan)
// --------------------------------------------------------
router.patch('/:id/status', async (req, res) => {
  try {
    await ensureRouteSchema();
    const routeId = Number(req.params.id);
    const { status, catatan_hasil } = req.body;

    const validStatuses = ['belum_dikunjungi', 'dalam_perjalanan', 'selesai', 'dibatalkan'];
    const nextStatus = normalizeStatus(status);
    if (!validStatuses.includes(nextStatus)) {
      return res.status(400).json({ message: 'Status kunjungan tidak valid.' });
    }

    const [existingRows] = await pool.query('SELECT * FROM sales_routes WHERE id = ? LIMIT 1', [routeId]);
    if (existingRows.length === 0) {
      return res.status(404).json({ message: 'Jadwal kunjungan tidak ditemukan.' });
    }
    const existing = existingRows[0];

    const actor = await resolveActor(req);
    if (actor && !isManagerRole(actor) && Number(actor.id) !== Number(existing.sales_id)) {
      return res.status(403).json({
        message: 'Akses ditolak: Anda hanya dapat memperbarui status jadwal kunjungan Anda sendiri.',
      });
    }

    const finalNote = catatan_hasil !== undefined ? String(catatan_hasil).trim() : existing.catatan_hasil;
    const updaterId = actor ? actor.id : existing.sales_id;

    await pool.query(
      `UPDATE sales_routes
       SET status = ?, catatan_hasil = ?, updated_by = ?, updated_at = NOW()
       WHERE id = ?`,
      [nextStatus, finalNote, updaterId, routeId]
    );

    try {
      await pool.query(
        `INSERT INTO activity_logs (user_id, modul, aksi, deskripsi, ip_address)
         VALUES (?, 'FR04_JADWAL_RUTE', 'UPDATE', ?, ?)`,
        [
          updaterId,
          `Status kunjungan #${routeId} (${existing.nama_tujuan}) diubah menjadi '${nextStatus}'`,
          req.ip || '127.0.0.1',
        ]
      );
    } catch (_) {}

    const [updatedRows] = await pool.query(`${BASE_SELECT} WHERE sr.id = ? LIMIT 1`, [routeId]);
    return res.json({
      status: true,
      message: `Status kunjungan diperbarui menjadi ${nextStatus}.`,
      data: formatRouteRow(updatedRows[0]),
    });
  } catch (error) {
    console.error('[PATCH /api/routes/:id/status] Error:', error);
    return res.status(500).json({ message: 'Gagal memperbarui status kunjungan: ' + error.message });
  }
});

module.exports = {
  router,
  ensureRouteSchema,
};
