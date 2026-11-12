const express = require('express');
const router = express.Router();
const { pool } = require('../config/db');
const { ensureUsersSchema, resolveActor, isManagerRole } = require('./userRoutes');
const { ensureAttendanceSchema } = require('./attendanceRoutes');
const { ensureRouteSchema } = require('./routeRoutes');
const { ensureTransactionSchema } = require('./transactionRoutes');

// --------------------------------------------------------
// GET /api/monitoring/summary
// Mengagregasi data langsung dari modul sumber (users, attendances, sales_routes, transactions, activity_logs)
// --------------------------------------------------------
router.get('/summary', async (req, res) => {
  try {
    await ensureUsersSchema();
    await ensureAttendanceSchema();
    await ensureRouteSchema();
    await ensureTransactionSchema();

    const { start_date, end_date, sales_id } = req.query;
    const actor = await resolveActor(req);

    // Terapkan filter hak akses: Sales hanya dapat melihat datanya sendiri
    let targetSalesId = sales_id ? Number(sales_id) : null;
    if (actor && !isManagerRole(actor)) {
      targetSalesId = Number(actor.id);
    }

    // 1. Jumlah Sales aktif
    const [salesCountRows] = await pool.query(
      "SELECT COUNT(*) AS cnt FROM users WHERE role = 'sales' AND is_active = 1 AND deleted_at IS NULL"
    );
    const activeSalesCount = Number(salesCountRows[0]?.cnt || 0);

    // 2. Ringkasan kehadiran pada periode terpilih
    let attQuery = 'SELECT status, COUNT(*) AS cnt FROM attendances WHERE 1=1';
    const attParams = [];
    if (targetSalesId) {
      attQuery += ' AND sales_id = ?';
      attParams.push(targetSalesId);
    }
    if (start_date) {
      attQuery += ' AND tanggal >= ?';
      attParams.push(start_date);
    }
    if (end_date) {
      attQuery += ' AND tanggal <= ?';
      attParams.push(end_date);
    }
    attQuery += ' GROUP BY status';
    const [attRows] = await pool.query(attQuery, attParams);

    const attMap = { hadir: 0, terlambat: 0, izin: 0, sakit: 0, alfa: 0 };
    for (const r of attRows) {
      attMap[r.status] = Number(r.cnt || 0);
    }
    const attTotal = Object.values(attMap).reduce((a, b) => a + b, 0);

    // 3. Ringkasan jadwal & penyelesaian kunjungan
    let routeQuery = 'SELECT status, COUNT(*) AS cnt FROM sales_routes WHERE 1=1';
    const routeParams = [];
    if (targetSalesId) {
      routeQuery += ' AND sales_id = ?';
      routeParams.push(targetSalesId);
    }
    if (start_date) {
      routeQuery += ' AND tanggal >= ?';
      routeParams.push(start_date);
    }
    if (end_date) {
      routeQuery += ' AND tanggal <= ?';
      routeParams.push(end_date);
    }
    routeQuery += ' GROUP BY status';
    const [routeRows] = await pool.query(routeQuery, routeParams);

    let routePending = 0;
    let routeInProgress = 0;
    let routeCompleted = 0;
    let routeCancelled = 0;
    for (const r of routeRows) {
      const cnt = Number(r.cnt || 0);
      if (r.status === 'selesai') routeCompleted += cnt;
      else if (r.status === 'dalam_perjalanan') routeInProgress += cnt;
      else if (r.status === 'dibatalkan' || r.status === 'dilewati') routeCancelled += cnt;
      else routePending += cnt;
    }
    const routeTotal = routePending + routeInProgress + routeCompleted + routeCancelled;

    // 4. Ringkasan omzet & status verifikasi transaksi (hanya status_verifikasi = 'disetujui' masuk ke omzet)
    let txQuery = 'SELECT status_verifikasi, COUNT(*) AS cnt, COALESCE(SUM(total), 0) AS sum_total FROM transactions WHERE 1=1';
    const txParams = [];
    if (targetSalesId) {
      txQuery += ' AND sales_id = ?';
      txParams.push(targetSalesId);
    }
    if (start_date) {
      txQuery += ' AND tanggal >= ?';
      txParams.push(start_date);
    }
    if (end_date) {
      txQuery += ' AND tanggal <= ?';
      txParams.push(end_date);
    }
    txQuery += ' GROUP BY status_verifikasi';
    const [txRows] = await pool.query(txQuery, txParams);

    let approvedOmzet = 0;
    let approvedTxCount = 0;
    let pendingTxCount = 0;
    let rejectedTxCount = 0;
    for (const r of txRows) {
      const cnt = Number(r.cnt || 0);
      if (r.status_verifikasi === 'disetujui') {
        approvedTxCount = cnt;
        approvedOmzet = Number(r.sum_total || 0);
      } else if (r.status_verifikasi === 'ditolak') {
        rejectedTxCount = cnt;
      } else {
        pendingTxCount += cnt;
      }
    }

    // 5. Aktivitas terbaru dari activity_logs
    let logQuery = `
      SELECT al.id, al.user_id, u.name AS user_name, al.modul, al.aksi, al.deskripsi, al.created_at
      FROM activity_logs al
      LEFT JOIN users u ON al.user_id = u.id
      WHERE 1=1
    `;
    const logParams = [];
    if (targetSalesId) {
      logQuery += ' AND al.user_id = ?';
      logParams.push(targetSalesId);
    }
    logQuery += ' ORDER BY al.created_at DESC, al.id DESC LIMIT 15';
    const [logRows] = await pool.query(logQuery, logParams);

    return res.json({
      status: true,
      timezone: 'WIB (Asia/Jakarta, UTC+7)',
      filters: {
        start_date: start_date || null,
        end_date: end_date || null,
        sales_id: targetSalesId,
      },
      data: {
        active_sales_count: activeSalesCount,
        attendance: {
          hadir: attMap.hadir,
          terlambat: attMap.terlambat,
          izin: attMap.izin,
          sakit: attMap.sakit,
          alfa: attMap.alfa,
          total: attTotal,
        },
        routes: {
          total: routeTotal,
          selesai: routeCompleted,
          dalam_perjalanan: routeInProgress,
          belum_dikunjungi: routePending,
          dibatalkan: routeCancelled,
        },
        transactions: {
          approved_omzet: approvedOmzet,
          disetujui_count: approvedTxCount,
          menunggu_count: pendingTxCount,
          ditolak_count: rejectedTxCount,
          total_count: approvedTxCount + pendingTxCount + rejectedTxCount,
        },
        recent_activities: logRows.map((r) => ({
          id: Number(r.id),
          user_id: r.user_id ? Number(r.user_id) : null,
          user_name: r.user_name || 'Sistem',
          modul: r.modul,
          aksi: r.aksi,
          deskripsi: r.deskripsi || '',
          created_at: r.created_at ? new Date(r.created_at).toISOString() : null,
        })),
        formulas: {
          kehadiran: 'Jumlah hari hadir + terlambat dibanding total catatan absensi pada periode terpilih.',
          penyelesaian_kunjungan: 'Jumlah kunjungan berstatus Selesai dibanding total jadwal kunjungan pada periode terpilih.',
          omzet_tercatat: 'Total nilai transaksi penjualan yang berstatus Disetujui (bukan komisi atau laba).',
        },
      },
    });
  } catch (error) {
    console.error('[GET /api/monitoring/summary] Error:', error);
    return res.status(500).json({ message: 'Gagal memuat ringkasan monitoring: ' + error.message });
  }
});

module.exports = {
  router,
};
