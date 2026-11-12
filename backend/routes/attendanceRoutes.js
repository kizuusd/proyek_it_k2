const express = require('express');
const router = express.Router();
const { pool } = require('../config/db');
const { resolveActor, isManagerRole } = require('./userRoutes');

let attendanceSchemaInitialized = false;

async function ensureAttendanceSchema() {
  if (attendanceSchemaInitialized) return;
  try {
    await pool.query(
      "ALTER TABLE attendances MODIFY COLUMN status ENUM('hadir','terlambat','izin','sakit','alfa') NOT NULL DEFAULT 'alfa'"
    );
    await pool.query(`
      CREATE TABLE IF NOT EXISTS attendance_corrections (
        id BIGINT(20) NOT NULL AUTO_INCREMENT,
        attendance_id BIGINT(20) NOT NULL,
        old_status VARCHAR(30) DEFAULT NULL,
        new_status VARCHAR(30) NOT NULL,
        old_checkin_at DATETIME DEFAULT NULL,
        new_checkin_at DATETIME DEFAULT NULL,
        old_checkout_at DATETIME DEFAULT NULL,
        new_checkout_at DATETIME DEFAULT NULL,
        reason TEXT NOT NULL,
        corrected_by BIGINT(20) DEFAULT NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        KEY idx_att_corr_att_id (attendance_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
    attendanceSchemaInitialized = true;
  } catch (err) {
    console.error('[ensureAttendanceSchema] Warning:', err.message);
  }
}

function formatTimeHHMM(val) {
  if (!val) return null;
  const d = new Date(val);
  if (isNaN(d.getTime())) return null;
  const hh = String(d.getHours()).padStart(2, '0');
  const mm = String(d.getMinutes()).padStart(2, '0');
  return `${hh}:${mm}`;
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

function formatAttendanceRow(row) {
  return {
    id: Number(row.id),
    sales_id: Number(row.sales_id),
    sales_name: row.sales_name || 'Sales Lapangan',
    tanggal: formatDateYMD(row.tanggal),
    checkin_at: row.checkin_at ? new Date(row.checkin_at).toISOString() : null,
    checkin_time: formatTimeHHMM(row.checkin_at),
    checkout_at: row.checkout_at ? new Date(row.checkout_at).toISOString() : null,
    checkout_time: formatTimeHHMM(row.checkout_at),
    durasi_kerja: row.durasi_kerja != null ? Number(row.durasi_kerja) : null,
    status: row.status || 'alfa',
    catatan_admin: row.catatan_admin || null,
    corrections_count: row.corrections_count != null ? Number(row.corrections_count) : 0,
    created_at: row.created_at ? new Date(row.created_at).toISOString() : null,
  };
}

// --------------------------------------------------------
// 1. GET /api/attendances
//    Query params: sales_id, tanggal, start_date, end_date, status, search
// --------------------------------------------------------
router.get('/', async (req, res) => {
  try {
    await ensureAttendanceSchema();
    const { sales_id, tanggal, start_date, end_date, status, search } = req.query;

    let query = `
      SELECT a.*,
             u.name AS sales_name,
             (SELECT COUNT(*) FROM attendance_corrections ac WHERE ac.attendance_id = a.id) AS corrections_count
      FROM attendances a
      JOIN users u ON a.sales_id = u.id
    `;
    const params = [];
    const conditions = [];

    if (sales_id) {
      conditions.push('a.sales_id = ?');
      params.push(Number(sales_id));
    }
    if (tanggal) {
      conditions.push('a.tanggal = ?');
      params.push(tanggal);
    }
    if (start_date) {
      conditions.push('a.tanggal >= ?');
      params.push(start_date);
    }
    if (end_date) {
      conditions.push('a.tanggal <= ?');
      params.push(end_date);
    }
    if (status && ['hadir', 'terlambat', 'izin', 'sakit', 'alfa'].includes(String(status).toLowerCase())) {
      conditions.push('a.status = ?');
      params.push(String(status).toLowerCase());
    }
    if (search && String(search).trim() !== '') {
      conditions.push('LOWER(u.name) LIKE ?');
      params.push(`%${String(search).trim().toLowerCase()}%`);
    }

    if (conditions.length > 0) {
      query += ' WHERE ' + conditions.join(' AND ');
    }

    query += ' ORDER BY a.tanggal DESC, a.id DESC';

    const [rows] = await pool.query(query, params);
    return res.json({
      status: true,
      count: rows.length,
      data: rows.map(formatAttendanceRow),
    });
  } catch (error) {
    console.error('[GET /api/attendances] Error:', error);
    return res.status(500).json({
      message: 'Gagal memuat data absensi: ' + error.message,
    });
  }
});

// --------------------------------------------------------
// 2. GET /api/attendances/today/:sales_id
// --------------------------------------------------------
router.get('/today/:sales_id', async (req, res) => {
  try {
    await ensureAttendanceSchema();
    const salesId = Number(req.params.sales_id);
    if (!salesId || isNaN(salesId)) {
      return res.status(400).json({ message: 'sales_id tidak valid.' });
    }

    const [rows] = await pool.query(
      `SELECT a.*, u.name AS sales_name,
              (SELECT COUNT(*) FROM attendance_corrections ac WHERE ac.attendance_id = a.id) AS corrections_count
       FROM attendances a
       JOIN users u ON a.sales_id = u.id
       WHERE a.sales_id = ? AND a.tanggal = CURDATE()
       LIMIT 1`,
      [salesId]
    );

    if (rows.length === 0) {
      return res.json({
        status: true,
        data: null,
        message: 'Belum ada absensi hari ini.',
      });
    }

    return res.json({
      status: true,
      data: formatAttendanceRow(rows[0]),
    });
  } catch (error) {
    console.error('[GET /api/attendances/today/:sales_id] Error:', error);
    return res.status(500).json({
      message: 'Gagal memuat status absensi hari ini: ' + error.message,
    });
  }
});

// --------------------------------------------------------
// 3. POST /api/attendances/checkin
//    Validasi: akun Sales harus aktif, satu record per tanggal per sales
// --------------------------------------------------------
router.post('/checkin', async (req, res) => {
  try {
    await ensureAttendanceSchema();
    const { sales_id, sales_email, catatan } = req.body;

    let salesUser = null;
    if (sales_id) {
      const [uRows] = await pool.query(
        'SELECT * FROM users WHERE id = ? AND deleted_at IS NULL LIMIT 1',
        [Number(sales_id)]
      );
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
      return res.status(404).json({ message: 'Data akun Sales tidak ditemukan.' });
    }

    if (salesUser.is_active !== 1 && salesUser.is_active !== true) {
      return res.status(403).json({
        message: 'Akun Sales sedang nonaktif atau ditangguhkan sehingga tidak dapat melakukan absensi.',
      });
    }

    const [existingRows] = await pool.query(
      'SELECT * FROM attendances WHERE sales_id = ? AND tanggal = CURDATE() LIMIT 1',
      [salesUser.id]
    );

    if (existingRows.length > 0) {
      return res.status(409).json({
        message: 'Anda sudah melakukan check-in hari ini. Satu record per hari per sales.',
        data: formatAttendanceRow({ ...existingRows[0], sales_name: salesUser.name }),
      });
    }

    // Tentukan status hadir vs terlambat berdasarkan waktu server (batas masuk 08:30)
    const [timeInfo] = await pool.query(
      'SELECT HOUR(NOW()) AS hr, MINUTE(NOW()) AS mn'
    );
    const hr = Number(timeInfo[0].hr);
    const mn = Number(timeInfo[0].mn);
    const statusMasuk = hr > 8 || (hr === 8 && mn > 30) ? 'terlambat' : 'hadir';

    const [insertResult] = await pool.query(
      `INSERT INTO attendances (sales_id, tanggal, checkin_at, status, catatan_admin, created_at, updated_at)
       VALUES (?, CURDATE(), NOW(), ?, ?, NOW(), NOW())`,
      [salesUser.id, statusMasuk, catatan ? String(catatan).trim() : null]
    );

    try {
      await pool.query(
        `INSERT INTO activity_logs (user_id, modul, aksi, deskripsi, ip_address)
         VALUES (?, 'FR08_ABSENSI', 'CREATE', ?, ?)`,
        [
          salesUser.id,
          `Sales ${salesUser.name} melakukan check-in (${statusMasuk})`,
          req.ip || '127.0.0.1',
        ]
      );
    } catch (_) {}

    const [createdRows] = await pool.query(
      `SELECT a.*, u.name AS sales_name, 0 AS corrections_count
       FROM attendances a
       JOIN users u ON a.sales_id = u.id
       WHERE a.id = ? LIMIT 1`,
      [insertResult.insertId]
    );

    return res.status(201).json({
      status: true,
      message: `Check-in berhasil (${statusMasuk})! Selamat bekerja, ${salesUser.name}.`,
      data: formatAttendanceRow(createdRows[0]),
    });
  } catch (error) {
    console.error('[POST /api/attendances/checkin] Error:', error);
    return res.status(500).json({
      message: 'Gagal melakukan check-in: ' + error.message,
    });
  }
});

// --------------------------------------------------------
// 4. POST /api/attendances/checkout
// --------------------------------------------------------
router.post('/checkout', async (req, res) => {
  try {
    await ensureAttendanceSchema();
    const { sales_id, sales_email } = req.body;

    let salesUser = null;
    if (sales_id) {
      const [uRows] = await pool.query(
        'SELECT * FROM users WHERE id = ? AND deleted_at IS NULL LIMIT 1',
        [Number(sales_id)]
      );
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
      return res.status(404).json({ message: 'Data akun Sales tidak ditemukan.' });
    }

    const [existingRows] = await pool.query(
      'SELECT * FROM attendances WHERE sales_id = ? AND tanggal = CURDATE() LIMIT 1',
      [salesUser.id]
    );

    if (existingRows.length === 0) {
      return res.status(400).json({
        message: 'Anda belum melakukan check-in hari ini. Silakan check-in terlebih dahulu.',
      });
    }

    const record = existingRows[0];

    if (!record.checkin_at) {
      return res.status(400).json({ message: 'Data check-in tidak valid. Silakan hubungi admin.' });
    }

    if (record.checkout_at) {
      return res.status(409).json({
        message: 'Anda sudah melakukan check-out hari ini.',
        data: formatAttendanceRow({ ...record, sales_name: salesUser.name }),
      });
    }

    const [timeRow] = await pool.query(
      'SELECT NOW() AS now_time, TIMESTAMPDIFF(MINUTE, ?, NOW()) AS durasi FROM dual',
      [record.checkin_at]
    );
    const durasimenit = Number(timeRow[0].durasi);

    if (durasimenit < 0) {
      return res.status(400).json({ message: 'Waktu check-out tidak boleh lebih awal dari check-in.' });
    }

    await pool.query(
      `UPDATE attendances SET checkout_at = NOW(), durasi_kerja = ?, updated_at = NOW() WHERE id = ?`,
      [durasimenit, record.id]
    );

    try {
      await pool.query(
        `INSERT INTO activity_logs (user_id, modul, aksi, deskripsi, ip_address)
         VALUES (?, 'FR08_ABSENSI', 'UPDATE', ?, ?)`,
        [
          salesUser.id,
          `Sales ${salesUser.name} melakukan check-out. Durasi kerja: ${durasimenit} menit.`,
          req.ip || '127.0.0.1',
        ]
      );
    } catch (_) {}

    const [updatedRows] = await pool.query(
      `SELECT a.*, u.name AS sales_name,
              (SELECT COUNT(*) FROM attendance_corrections ac WHERE ac.attendance_id = a.id) AS corrections_count
       FROM attendances a
       JOIN users u ON a.sales_id = u.id
       WHERE a.id = ? LIMIT 1`,
      [record.id]
    );

    return res.json({
      status: true,
      message: `Check-out berhasil! Total kerja: ${durasimenit} menit. Terima kasih, ${salesUser.name}.`,
      data: formatAttendanceRow(updatedRows[0]),
    });
  } catch (error) {
    console.error('[POST /api/attendances/checkout] Error:', error);
    return res.status(500).json({
      message: 'Gagal melakukan check-out: ' + error.message,
    });
  }
});

// --------------------------------------------------------
// 5. PUT /api/attendances/:id/correct
//    Koreksi absensi oleh Admin/Owner dengan alasan dan jejak perubahan
// --------------------------------------------------------
router.put('/:id/correct', async (req, res) => {
  const conn = await pool.getConnection();
  try {
    await ensureAttendanceSchema();
    const attId = Number(req.params.id);
    const { status, checkin_time, checkout_time, reason } = req.body;

    if (!reason || String(reason).trim() === '') {
      conn.release();
      return res.status(400).json({ message: 'Alasan koreksi absensi wajib diisi.' });
    }

    const validStatuses = ['hadir', 'terlambat', 'izin', 'sakit', 'alfa'];
    const newStatus = String(status || '').toLowerCase();
    if (!validStatuses.includes(newStatus)) {
      conn.release();
      return res.status(400).json({ message: 'Status absensi tidak valid.' });
    }

    const actor = await resolveActor(req);
    if (!actor || !isManagerRole(actor)) {
      conn.release();
      return res.status(403).json({
        message: 'Akses ditolak: Hanya Admin dan Owner yang berhak melakukan koreksi absensi.',
      });
    }

    const [existingRows] = await conn.query('SELECT * FROM attendances WHERE id = ? LIMIT 1', [attId]);
    if (existingRows.length === 0) {
      conn.release();
      return res.status(404).json({ message: 'Data absensi tidak ditemukan.' });
    }
    const existing = existingRows[0];
    const dateStr = formatDateYMD(existing.tanggal);

    let newCheckinAt = existing.checkin_at;
    if (checkin_time !== undefined) {
      if (checkin_time === null || String(checkin_time).trim() === '') {
        newCheckinAt = null;
      } else {
        newCheckinAt = new Date(`${dateStr}T${String(checkin_time).trim()}:00`);
        if (isNaN(newCheckinAt.getTime())) {
          conn.release();
          return res.status(400).json({ message: 'Format jam check-in tidak valid (gunakan HH:mm).' });
        }
      }
    }

    let newCheckoutAt = existing.checkout_at;
    if (checkout_time !== undefined) {
      if (checkout_time === null || String(checkout_time).trim() === '') {
        newCheckoutAt = null;
      } else {
        newCheckoutAt = new Date(`${dateStr}T${String(checkout_time).trim()}:00`);
        if (isNaN(newCheckoutAt.getTime())) {
          conn.release();
          return res.status(400).json({ message: 'Format jam check-out tidak valid (gunakan HH:mm).' });
        }
      }
    }

    if (newCheckinAt && newCheckoutAt && new Date(newCheckoutAt) < new Date(newCheckinAt)) {
      conn.release();
      return res.status(400).json({
        message: 'Waktu check-out tidak boleh lebih awal dari waktu check-in.',
      });
    }

    let newDurasi = existing.durasi_kerja;
    if (newCheckinAt && newCheckoutAt) {
      newDurasi = Math.round((new Date(newCheckoutAt) - new Date(newCheckinAt)) / 60000);
    } else if (!newCheckoutAt) {
      newDurasi = null;
    }

    await conn.beginTransaction();

    await conn.query(
      `INSERT INTO attendance_corrections
        (attendance_id, old_status, new_status, old_checkin_at, new_checkin_at, old_checkout_at, new_checkout_at, reason, corrected_by)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        attId,
        existing.status,
        newStatus,
        existing.checkin_at,
        newCheckinAt,
        existing.checkout_at,
        newCheckoutAt,
        String(reason).trim(),
        actor.id,
      ]
    );

    await conn.query(
      `UPDATE attendances
       SET status = ?, checkin_at = ?, checkout_at = ?, durasi_kerja = ?, catatan_admin = ?, validated_by = ?, updated_at = NOW()
       WHERE id = ?`,
      [newStatus, newCheckinAt, newCheckoutAt, newDurasi, String(reason).trim(), actor.id, attId]
    );

    try {
      await conn.query(
        `INSERT INTO activity_logs (user_id, modul, aksi, deskripsi, ip_address)
         VALUES (?, 'FR08_ABSENSI', 'UPDATE', ?, ?)`,
        [
          actor.id,
          `Koreksi absensi #${attId}: status '${existing.status}' -> '${newStatus}' (${String(reason).trim()})`,
          req.ip || '127.0.0.1',
        ]
      );
    } catch (_) {}

    await conn.commit();

    const [updatedRows] = await pool.query(
      `SELECT a.*, u.name AS sales_name,
              (SELECT COUNT(*) FROM attendance_corrections ac WHERE ac.attendance_id = a.id) AS corrections_count
       FROM attendances a
       JOIN users u ON a.sales_id = u.id
       WHERE a.id = ? LIMIT 1`,
      [attId]
    );

    return res.json({
      status: true,
      message: 'Koreksi absensi berhasil disimpan dengan jejak audit.',
      data: formatAttendanceRow(updatedRows[0]),
    });
  } catch (error) {
    try {
      await conn.rollback();
    } catch (_) {}
    console.error('[PUT /api/attendances/:id/correct] Error:', error);
    return res.status(500).json({ message: 'Gagal mengoreksi absensi: ' + error.message });
  } finally {
    conn.release();
  }
});

// --------------------------------------------------------
// 6. GET /api/attendances/:id/corrections
//    Ambil riwayat koreksi (audit trail) untuk suatu catatan absensi
// --------------------------------------------------------
router.get('/:id/corrections', async (req, res) => {
  try {
    await ensureAttendanceSchema();
    const attId = Number(req.params.id);
    const [rows] = await pool.query(
      `SELECT ac.*, u.name AS corrected_by_name
       FROM attendance_corrections ac
       LEFT JOIN users u ON ac.corrected_by = u.id
       WHERE ac.attendance_id = ?
       ORDER BY ac.created_at DESC, ac.id DESC`,
      [attId]
    );
    return res.json({
      status: true,
      data: rows.map((r) => ({
        id: Number(r.id),
        attendance_id: Number(r.attendance_id),
        old_status: r.old_status,
        new_status: r.new_status,
        old_checkin_time: formatTimeHHMM(r.old_checkin_at),
        new_checkin_time: formatTimeHHMM(r.new_checkin_at),
        old_checkout_time: formatTimeHHMM(r.old_checkout_at),
        new_checkout_time: formatTimeHHMM(r.new_checkout_at),
        reason: r.reason,
        corrected_by_name: r.corrected_by_name || 'Admin',
        created_at: r.created_at ? new Date(r.created_at).toISOString() : null,
      })),
    });
  } catch (error) {
    console.error('[GET /api/attendances/:id/corrections] Error:', error);
    return res.status(500).json({ message: 'Gagal memuat riwayat koreksi absensi: ' + error.message });
  }
});

module.exports = {
  router,
  ensureAttendanceSchema,
};
