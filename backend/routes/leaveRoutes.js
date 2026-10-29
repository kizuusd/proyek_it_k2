const express = require('express');
const router = express.Router();
const { pool } = require('../config/db');

function mapKategoriToJenisEnum(kategori) {
  if (!kategori) return 'izin';
  const lower = String(kategori).toLowerCase();
  if (lower.includes('sakit')) return 'sakit';
  if (lower.includes('cuti')) return 'cuti';
  return 'izin';
}

function mapJenisEnumToKategori(jenis, kategori) {
  if (kategori && String(kategori).trim() !== '') return String(kategori).trim();
  if (jenis === 'sakit') return 'Sakit';
  if (jenis === 'cuti') return 'Cuti Tahunan';
  return 'Izin Urusan Keluarga';
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

function formatLeaveRow(row) {
  const createdYear = row.created_at ? new Date(row.created_at).getFullYear() : 2026;
  const kodeIzin = `IZN-${createdYear}-${String(row.id).padStart(3, '0')}`;
  return {
    id: Number(row.id),
    kode_izin: kodeIzin,
    sales_id: Number(row.sales_id),
    sales_name: row.sales_name || 'Sales Lapangan',
    sales_email: row.sales_email || '',
    sales_phone: row.sales_phone || '',
    sales_photo_url: row.sales_photo_url || null,
    jenis_izin: row.jenis_izin,
    kategori_izin: mapJenisEnumToKategori(row.jenis_izin, row.kategori_izin),
    tanggal_mulai: formatDateYMD(row.tanggal_mulai),
    tanggal_selesai: formatDateYMD(row.tanggal_selesai),
    jumlah_hari: Number(row.jumlah_hari || 1),
    alasan: row.alasan || '',
    lampiran_url: row.lampiran_url || null,
    status: row.status || 'menunggu',
    catatan_approver: row.catatan_approver || null,
    approved_by: row.approved_by ? Number(row.approved_by) : null,
    approver_name: row.approver_name || null,
    approver_role: row.approver_role || null,
    diproses_oleh: formatApproverDisplay(row.approver_name, row.approver_role),
    approved_at: row.approved_at ? new Date(row.approved_at).toISOString() : null,
    created_at: row.created_at ? new Date(row.created_at).toISOString() : new Date().toISOString(),
  };
}

// --------------------------------------------------------
// 1. GET /api/leaves
//    Ambil daftar pengajuan izin (semua untuk Admin/Owner, atau filter per sales)
// --------------------------------------------------------
router.get('/', async (req, res) => {
  try {
    const { sales_id, sales_email } = req.query;
    let query = `
      SELECT lr.*,
             u.name AS sales_name,
             u.email AS sales_email,
             u.phone AS sales_phone,
             u.photo_url AS sales_photo_url,
             a.name AS approver_name,
             a.role AS approver_role
      FROM leave_requests lr
      JOIN users u ON lr.sales_id = u.id
      LEFT JOIN users a ON lr.approved_by = a.id
    `;
    const params = [];

    if (sales_id) {
      query += ' WHERE lr.sales_id = ?';
      params.push(sales_id);
    } else if (sales_email) {
      query += ' WHERE LOWER(u.email) = ?';
      params.push(String(sales_email).trim().toLowerCase());
    }

    query += ' ORDER BY lr.created_at DESC, lr.id DESC';

    const [rows] = await pool.query(query, params);
    return res.json({
      status: true,
      count: rows.length,
      data: rows.map(formatLeaveRow),
    });
  } catch (error) {
    console.error('[GET /api/leaves] Error:', error);
    return res.status(500).json({
      message: 'Gagal memuat data pengajuan izin: ' + error.message,
    });
  }
});

// --------------------------------------------------------
// 2. POST /api/leaves
//    Sales mengajukan permohonan izin baru
// --------------------------------------------------------
router.post('/', async (req, res) => {
  try {
    const {
      sales_id,
      sales_email,
      kategori_izin,
      jenis_izin,
      tanggal_mulai,
      tanggal_selesai,
      jumlah_hari,
      alasan,
      lampiran_url,
    } = req.body;

    if (!alasan || String(alasan).trim() === '') {
      return res.status(400).json({ message: 'Deskripsi / alasan ketidakhadiran wajib diisi.' });
    }
    if (!tanggal_mulai || !tanggal_selesai) {
      return res.status(400).json({ message: 'Tanggal mulai dan tanggal selesai izin wajib diisi.' });
    }

    // Cari user sales
    let salesUser = null;
    if (sales_id) {
      const [uRows] = await pool.query('SELECT * FROM users WHERE id = ? AND deleted_at IS NULL LIMIT 1', [sales_id]);
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
      return res.status(404).json({ message: 'Data akun Sales tidak ditemukan di dalam database.' });
    }

    const finalKategori = kategori_izin || mapJenisEnumToKategori(jenis_izin, null);
    const finalJenis = mapKategoriToJenisEnum(finalKategori || jenis_izin);
    const durasi = Math.max(1, Number(jumlah_hari) || 1);

    const [insertResult] = await pool.query(
      `INSERT INTO leave_requests
        (sales_id, jenis_izin, kategori_izin, tanggal_mulai, tanggal_selesai, jumlah_hari, alasan, lampiran_url, status, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'menunggu', NOW())`,
      [
        salesUser.id,
        finalJenis,
        finalKategori,
        tanggal_mulai,
        tanggal_selesai,
        durasi,
        String(alasan).trim(),
        lampiran_url || null,
      ]
    );

    // Catat ke activity_logs
    try {
      await pool.query(
        `INSERT INTO activity_logs (user_id, modul, aksi, deskripsi, ip_address)
         VALUES (?, 'FR09_PENGAJUAN_IZIN', 'CREATE', ?, ?)`,
        [
          salesUser.id,
          `Sales ${salesUser.name} mengajukan izin (${finalKategori}) untuk tanggal ${tanggal_mulai} s/d ${tanggal_selesai}`,
          req.ip || '127.0.0.1',
        ]
      );
    } catch (_) {}

    const [createdRows] = await pool.query(
      `SELECT lr.*,
              u.name AS sales_name,
              u.email AS sales_email,
              u.phone AS sales_phone,
              u.photo_url AS sales_photo_url,
              a.name AS approver_name,
              a.role AS approver_role
       FROM leave_requests lr
       JOIN users u ON lr.sales_id = u.id
       LEFT JOIN users a ON lr.approved_by = a.id
       WHERE lr.id = ? LIMIT 1`,
      [insertResult.insertId]
    );

    return res.status(201).json({
      status: true,
      message: 'Pengajuan izin berhasil dikirim dan menunggu persetujuan Admin/Owner.',
      data: formatLeaveRow(createdRows[0]),
    });
  } catch (error) {
    console.error('[POST /api/leaves] Error:', error);
    return res.status(500).json({
      message: 'Gagal menyimpan pengajuan izin: ' + error.message,
    });
  }
});

// --------------------------------------------------------
// 3. PUT /api/leaves/:id/status
//    Admin atau Owner menyetujui (disetujui), menolak (ditolak), atau merevisi (menunggu) izin
// --------------------------------------------------------
router.put('/:id/status', async (req, res) => {
  try {
    const leaveId = Number(req.params.id);
    const { status, catatan_approver, reviewer_id, reviewer_email } = req.body;

    if (!['menunggu', 'disetujui', 'ditolak'].includes(status)) {
      return res.status(400).json({ message: 'Status persetujuan tidak valid.' });
    }

    // Cek keberadaan data izin
    const [existingRows] = await pool.query('SELECT * FROM leave_requests WHERE id = ? LIMIT 1', [leaveId]);
    if (existingRows.length === 0) {
      return res.status(404).json({ message: 'Data pengajuan izin tidak ditemukan.' });
    }
    const leaveItem = existingRows[0];

    // Cari user reviewer (Admin / Owner)
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

    // Validasi hanya Admin / Owner yang boleh memproses izin
    if (reviewer) {
      const validRoles = ['superadmin', 'owner', 'administrator', 'admin'];
      if (!validRoles.includes(String(reviewer.role).toLowerCase())) {
        return res.status(403).json({
          message: 'Akses ditolak: Hanya Admin dan Owner yang berhak menyetujui atau menolak pengajuan izin.',
        });
      }
    }

    if (status === 'menunggu') {
      await pool.query(
        `UPDATE leave_requests
         SET status = 'menunggu', catatan_approver = NULL, approved_by = NULL, approved_at = NULL
         WHERE id = ?`,
        [leaveId]
      );
    } else {
      const defaultNote =
        status === 'disetujui'
          ? 'Pengajuan izin telah disetujui secara resmi.'
          : 'Pengajuan izin ditolak oleh manajemen.';
      const finalNote =
        catatan_approver && String(catatan_approver).trim() !== ''
          ? String(catatan_approver).trim()
          : defaultNote;
      const approverId = reviewer ? reviewer.id : null;

      await pool.query(
        `UPDATE leave_requests
         SET status = ?, catatan_approver = ?, approved_by = ?, approved_at = NOW()
         WHERE id = ?`,
        [status, finalNote, approverId, leaveId]
      );

      // Kirim notifikasi ke tabel notifications untuk sales bersangkutan
      try {
        const judulNotif =
          status === 'disetujui' ? 'Pengajuan Izin Disetujui' : 'Pengajuan Izin Ditolak';
        await pool.query(
          `INSERT INTO notifications (user_id, judul, pesan, jenis, referensi_id, referensi_tipe, is_read)
           VALUES (?, ?, ?, 'approval', ?, 'leave_requests', 0)`,
          [leaveItem.sales_id, judulNotif, finalNote, leaveId]
        );
      } catch (_) {}

      // Catat ke activity_logs
      try {
        await pool.query(
          `INSERT INTO activity_logs (user_id, modul, aksi, deskripsi, ip_address)
           VALUES (?, 'FR09_PENGAJUAN_IZIN', 'UPDATE', ?, ?)`,
          [
            approverId,
            `Memperbarui status izin ID #${leaveId} menjadi '${status.toUpperCase()}': ${finalNote}`,
            req.ip || '127.0.0.1',
          ]
        );
      } catch (_) {}
    }

    const [updatedRows] = await pool.query(
      `SELECT lr.*,
              u.name AS sales_name,
              u.email AS sales_email,
              u.phone AS sales_phone,
              u.photo_url AS sales_photo_url,
              a.name AS approver_name,
              a.role AS approver_role
       FROM leave_requests lr
       JOIN users u ON lr.sales_id = u.id
       LEFT JOIN users a ON lr.approved_by = a.id
       WHERE lr.id = ? LIMIT 1`,
      [leaveId]
    );

    return res.json({
      status: true,
      message: `Status pengajuan izin berhasil diperbarui menjadi ${status}.`,
      data: formatLeaveRow(updatedRows[0]),
    });
  } catch (error) {
    console.error('[PUT /api/leaves/:id/status] Error:', error);
    return res.status(500).json({
      message: 'Gagal memperbarui status pengajuan izin: ' + error.message,
    });
  }
});

module.exports = router;
