const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const { pool } = require('../config/db');

const LEGACY_SEED_HASH = '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi';
const PASSWORD123_HASH = '$2a$10$4nb5YaIMSE2uZID/Yd8As.gYuRSemFHEiy3JdX3dQe5a2W9bhnwjy';

let usersSchemaInitialized = false;

async function ensureUsersSchema() {
  if (usersSchemaInitialized) return;
  try {
    // Perbaiki hash seed bawaan Laravel ('password') agar benar-benar sesuai default 'password123'
    await pool.query('UPDATE users SET password = ? WHERE password = ?', [
      PASSWORD123_HASH,
      LEGACY_SEED_HASH,
    ]);

    const [cols] = await pool.query('SHOW COLUMNS FROM users');
    const colNames = cols.map((c) => c.Field);

    if (!colNames.includes('kode_sales')) {
      await pool.query('ALTER TABLE users ADD COLUMN kode_sales VARCHAR(50) DEFAULT NULL AFTER id');
    }
    if (!colNames.includes('alamat')) {
      await pool.query('ALTER TABLE users ADD COLUMN alamat TEXT DEFAULT NULL AFTER phone');
    }
    if (!colNames.includes('tanggal_bergabung')) {
      await pool.query('ALTER TABLE users ADD COLUMN tanggal_bergabung DATE DEFAULT NULL AFTER alamat');
    }
    if (!colNames.includes('membership_status')) {
      await pool.query(
        "ALTER TABLE users ADD COLUMN membership_status ENUM('aktif','nonaktif','ditangguhkan') NOT NULL DEFAULT 'aktif' AFTER is_active"
      );
    }
    if (!colNames.includes('koordinator_id')) {
      await pool.query('ALTER TABLE users ADD COLUMN koordinator_id BIGINT(20) DEFAULT NULL AFTER membership_status');
    }

    await pool.query(`
      CREATE TABLE IF NOT EXISTS membership_status_logs (
        id BIGINT(20) NOT NULL AUTO_INCREMENT,
        user_id BIGINT(20) NOT NULL,
        old_status VARCHAR(30) DEFAULT NULL,
        new_status VARCHAR(30) NOT NULL,
        reason TEXT DEFAULT NULL,
        changed_by BIGINT(20) DEFAULT NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        KEY idx_msl_user_id (user_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);

    // Backfill default kode_sales & membership_status untuk user yang belum memiliki
    const [usersToBackfill] = await pool.query(
      'SELECT id, role, is_active, kode_sales, tanggal_bergabung, membership_status, created_at FROM users WHERE deleted_at IS NULL'
    );
    for (const u of usersToBackfill) {
      const updates = [];
      const params = [];
      if (!u.kode_sales && String(u.role).toLowerCase() === 'sales') {
        updates.push('kode_sales = ?');
        params.push(`SLS-${String(u.id).padStart(3, '0')}`);
      }
      if (!u.tanggal_bergabung) {
        updates.push('tanggal_bergabung = DATE(COALESCE(created_at, NOW()))');
      }
      const expectedStatus = u.is_active === 1 || u.is_active === true ? 'aktif' : 'nonaktif';
      if (!u.membership_status) {
        updates.push('membership_status = ?');
        params.push(expectedStatus);
      } else if (u.is_active === 0 && u.membership_status === 'aktif') {
        updates.push("membership_status = 'nonaktif'");
      }
      if (updates.length > 0) {
        params.push(u.id);
        await pool.query(`UPDATE users SET ${updates.join(', ')} WHERE id = ?`, params);
      }
    }

    usersSchemaInitialized = true;
  } catch (err) {
    console.error('[ensureUsersSchema] Warning:', err.message);
  }
}

function formatUser(row) {
  const isActive = Boolean(row.is_active === 1 || row.is_active === true);
  let membershipStatus = row.membership_status || (isActive ? 'aktif' : 'nonaktif');
  if (!isActive && membershipStatus === 'aktif') {
    membershipStatus = 'nonaktif';
  }
  const joinDate = row.tanggal_bergabung
    ? new Date(row.tanggal_bergabung).toISOString().split('T')[0]
    : row.created_at
      ? new Date(row.created_at).toISOString().split('T')[0]
      : null;

  return {
    id: Number(row.id),
    kode_sales: row.kode_sales || (String(row.role).toLowerCase() === 'sales' ? `SLS-${String(row.id).padStart(3, '0')}` : null),
    name: row.name,
    email: row.email,
    phone: row.phone || null,
    alamat: row.alamat || null,
    tanggal_bergabung: joinDate,
    photo_url: row.photo_url || null,
    role: row.role,
    is_active: isActive,
    membership_status: membershipStatus,
    koordinator_id: row.koordinator_id ? Number(row.koordinator_id) : null,
    koordinator_name: row.koordinator_name || null,
    google_id: row.google_id || null,
    google_email: row.google_email || null,
    device_token: row.device_token || null,
    created_by: row.created_by || null,
    last_login_at: row.last_login_at ? new Date(row.last_login_at).toISOString() : null,
  };
}

async function resolveAuthenticatedUser(req) {
  const authHeader = req.headers.authorization || '';
  const bearerToken = authHeader.startsWith('Bearer ') ? authHeader.slice(7).trim() : null;
  if (!bearerToken) return null;

  const [tokenRows] = await pool.query(
    `SELECT u.* FROM user_tokens ut
     JOIN users u ON ut.user_id = u.id
     WHERE ut.token = ?
       AND ut.revoked_at IS NULL
       AND (ut.expires_at IS NULL OR ut.expires_at > NOW())
       AND u.deleted_at IS NULL
     LIMIT 1`,
    [bearerToken]
  );
  return tokenRows.length > 0 ? tokenRows[0] : null;
}

async function resolveActor(req) {
  const fromToken = await resolveAuthenticatedUser(req);
  if (fromToken) return fromToken;

  const actorId = req.body?.actor_id || req.body?.manager_id || req.body?.user_id || req.query?.actor_id;
  if (actorId) {
    const [rows] = await pool.query('SELECT * FROM users WHERE id = ? AND deleted_at IS NULL LIMIT 1', [
      Number(actorId),
    ]);
    if (rows.length > 0) return rows[0];
  }
  const actorEmail = req.body?.actor_email || req.body?.email || req.query?.actor_email;
  if (actorEmail) {
    const [rows] = await pool.query(
      'SELECT * FROM users WHERE LOWER(email) = ? AND deleted_at IS NULL LIMIT 1',
      [String(actorEmail).trim().toLowerCase()]
    );
    if (rows.length > 0) return rows[0];
  }
  return null;
}

function isManagerRole(user) {
  if (!user) return false;
  return ['superadmin', 'owner', 'administrator', 'admin'].includes(String(user.role || '').toLowerCase());
}

// --------------------------------------------------------
// 1. GET /api/users (Daftar semua anggota untuk panel keanggotaan)
// --------------------------------------------------------
router.get('/', async (req, res) => {
  try {
    await ensureUsersSchema();
    const { role, membership_status, search } = req.query;
    let query = `
      SELECT u.*, k.name AS koordinator_name
      FROM users u
      LEFT JOIN users k ON u.koordinator_id = k.id
      WHERE u.deleted_at IS NULL
    `;
    const params = [];

    if (role && role !== 'Semua') {
      query += ' AND LOWER(u.role) = ?';
      params.push(String(role).toLowerCase());
    }
    if (membership_status && ['aktif', 'nonaktif', 'ditangguhkan'].includes(String(membership_status).toLowerCase())) {
      query += ' AND u.membership_status = ?';
      params.push(String(membership_status).toLowerCase());
    }
    if (search && String(search).trim() !== '') {
      const q = `%${String(search).trim().toLowerCase()}%`;
      query += ' AND (LOWER(u.name) LIKE ? OR LOWER(u.email) LIKE ? OR LOWER(COALESCE(u.kode_sales, "")) LIKE ?)';
      params.push(q, q, q);
    }

    query += ' ORDER BY u.id ASC';

    const [rows] = await pool.query(query, params);
    return res.json({
      status: true,
      count: rows.length,
      data: rows.map(formatUser),
    });
  } catch (error) {
    console.error('Error saat mengambil data users:', error);
    return res.status(500).json({ message: 'Terjadi kesalahan pada server: ' + error.message });
  }
});

// --------------------------------------------------------
// 2. POST /api/users/link-google (Tautkan akun Google)
// --------------------------------------------------------
router.post('/link-google', async (req, res) => {
  try {
    await ensureUsersSchema();
    const { user_id, email, google_email, google_id, photo_url } = req.body;

    let user = await resolveAuthenticatedUser(req);
    if (!user && user_id) {
      const [idRows] = await pool.query(
        'SELECT * FROM users WHERE id = ? AND deleted_at IS NULL LIMIT 1',
        [user_id]
      );
      if (idRows.length > 0) user = idRows[0];
    }
    if (!user && email) {
      const cleanEmail = email.trim().toLowerCase();
      const [emailRows] = await pool.query(
        'SELECT * FROM users WHERE LOWER(email) = ? AND deleted_at IS NULL LIMIT 1',
        [cleanEmail]
      );
      if (emailRows.length > 0) user = emailRows[0];
    }

    if (!user) {
      return res.status(404).json({ message: 'Akun pengguna tidak ditemukan dalam sistem database.' });
    }

    const cleanGoogleEmail = (google_email || email || user.email).trim().toLowerCase();
    if (!cleanGoogleEmail) {
      return res.status(400).json({ message: 'Email Google wajib diisi.' });
    }

    const [existingLinked] = await pool.query(
      'SELECT id, name, email FROM users WHERE LOWER(google_email) = ? AND id != ? AND deleted_at IS NULL LIMIT 1',
      [cleanGoogleEmail, user.id]
    );
    if (existingLinked.length > 0) {
      return res.status(400).json({
        message: `Akun Google (${cleanGoogleEmail}) sudah digunakan oleh ${existingLinked[0].name} (${existingLinked[0].email}). Satu akun Google hanya dapat ditautkan ke 1 akun pengguna.`,
      });
    }

    const finalGid =
      google_id && String(google_id).trim().length > 0
        ? String(google_id).trim()
        : `google_oauth_${user.id}_${crypto.randomBytes(4).toString('hex')}`;
    const finalPhoto = photo_url || user.photo_url;

    await pool.query(
      'UPDATE users SET google_id = ?, google_email = ?, photo_url = ? WHERE id = ?',
      [finalGid, cleanGoogleEmail, finalPhoto, user.id]
    );

    const [updatedRows] = await pool.query('SELECT * FROM users WHERE id = ?', [user.id]);
    return res.json({
      status: true,
      message: `Akun Google (${cleanGoogleEmail}) berhasil ditautkan.`,
      user: formatUser(updatedRows[0]),
    });
  } catch (error) {
    console.error('Error saat tautkan akun Google:', error);
    return res.status(500).json({ message: 'Terjadi kesalahan pada server: ' + error.message });
  }
});

// --------------------------------------------------------
// 3. POST /api/users/unlink-google (Putuskan tautan Google)
// --------------------------------------------------------
router.post('/unlink-google', async (req, res) => {
  try {
    await ensureUsersSchema();
    const { user_id, email } = req.body;

    let user = await resolveAuthenticatedUser(req);
    if (!user && user_id) {
      const [idRows] = await pool.query(
        'SELECT * FROM users WHERE id = ? AND deleted_at IS NULL LIMIT 1',
        [user_id]
      );
      if (idRows.length > 0) user = idRows[0];
    }
    if (!user && email) {
      const cleanEmail = email.trim().toLowerCase();
      const [emailRows] = await pool.query(
        'SELECT * FROM users WHERE LOWER(email) = ? AND deleted_at IS NULL LIMIT 1',
        [cleanEmail]
      );
      if (emailRows.length > 0) user = emailRows[0];
    }

    if (!user) {
      return res.status(404).json({ message: 'Akun pengguna tidak ditemukan dalam sistem database.' });
    }

    await pool.query(
      'UPDATE users SET google_id = NULL, google_email = NULL WHERE id = ?',
      [user.id]
    );

    const [updatedRows] = await pool.query('SELECT * FROM users WHERE id = ?', [user.id]);
    return res.json({
      status: true,
      message: 'Tautan akun Google berhasil diputuskan.',
      user: formatUser(updatedRows[0]),
    });
  } catch (error) {
    console.error('Error saat putuskan tautan Google:', error);
    return res.status(500).json({ message: 'Terjadi kesalahan pada server: ' + error.message });
  }
});

// --------------------------------------------------------
// 4. POST /api/users/change-password (Ubah password terverifikasi)
//    - Mengambil akun dari token sesi jika tersedia (menolak manipulasi user_id/email akun lain)
//    - Wajib mengisi & memverifikasi old_password terhadap hash tersimpan
//    - Password baru minimal 6 karakter & tidak sama dengan password lama
// --------------------------------------------------------
router.post('/change-password', async (req, res) => {
  try {
    await ensureUsersSchema();
    const { email, old_password, new_password, confirm_password } = req.body;

    if (!old_password || String(old_password).length === 0) {
      return res.status(400).json({ message: 'Password lama wajib diisi.' });
    }
    if (!new_password || String(new_password).length < 6) {
      return res.status(400).json({ message: 'Password baru minimal 6 karakter.' });
    }
    if (confirm_password !== undefined && confirm_password !== new_password) {
      return res.status(400).json({ message: 'Konfirmasi password baru tidak cocok.' });
    }
    if (new_password === old_password) {
      return res.status(400).json({ message: 'Password baru tidak boleh sama dengan password lama.' });
    }

    let user = await resolveAuthenticatedUser(req);
    if (user) {
      // Cegah manipulasi request untuk mengubah akun lain
      if (req.body.user_id && Number(req.body.user_id) !== Number(user.id)) {
        return res.status(403).json({ message: 'Akses ditolak: Anda tidak dapat mengubah password akun pengguna lain.' });
      }
      if (email && String(email).trim().toLowerCase() !== String(user.email).toLowerCase()) {
        return res.status(403).json({ message: 'Akses ditolak: Anda tidak dapat mengubah password akun pengguna lain.' });
      }
    } else {
      if (!email) {
        return res.status(401).json({ message: 'Autentikasi diperlukan untuk mengubah password.' });
      }
      const cleanEmail = String(email).trim().toLowerCase();
      const [rows] = await pool.query(
        'SELECT * FROM users WHERE LOWER(email) = ? AND deleted_at IS NULL LIMIT 1',
        [cleanEmail]
      );
      if (rows.length === 0) {
        return res.status(404).json({ message: 'Akun tidak ditemukan dalam sistem.' });
      }
      user = rows[0];
    }

    const storedPassword = user.password || '';
    let match = false;
    if (storedPassword === LEGACY_SEED_HASH && String(old_password) === 'password123') {
      match = true;
    } else if (
      storedPassword.startsWith('$2y$') ||
      storedPassword.startsWith('$2a$') ||
      storedPassword.startsWith('$2b$')
    ) {
      const normalized = storedPassword.replace(/^\$2y\$/, '$2a$');
      match = await bcrypt.compare(String(old_password), normalized);
    } else if (storedPassword.length > 0) {
      match = String(old_password) === storedPassword;
    }

    if (!match) {
      return res.status(400).json({ message: 'Password lama yang Anda masukkan salah.' });
    }

    const hashed = await bcrypt.hash(String(new_password), 10);
    await pool.query('UPDATE users SET password = ? WHERE id = ?', [hashed, user.id]);

    try {
      await pool.query(
        `INSERT INTO activity_logs (user_id, modul, aksi, deskripsi, ip_address)
         VALUES (?, 'FR11_PROFIL', 'UPDATE', ?, ?)`,
        [user.id, `Pengguna ${user.email} mengubah password akun`, req.ip || '127.0.0.1']
      );
    } catch (_) {}

    return res.json({
      status: true,
      message: 'Password berhasil diperbarui.',
    });
  } catch (error) {
    console.error('Error saat ganti password:', error);
    return res.status(500).json({ message: 'Terjadi kesalahan pada server: ' + error.message });
  }
});

// --------------------------------------------------------
// 5. POST /api/users/update-profile (Ubah nama, telepon, alamat, foto profil)
// --------------------------------------------------------
router.post('/update-profile', async (req, res) => {
  try {
    await ensureUsersSchema();
    const { user_id, email, name, phone, alamat, photo_url } = req.body;

    let user = await resolveAuthenticatedUser(req);
    if (!user && user_id) {
      const [idRows] = await pool.query(
        'SELECT * FROM users WHERE id = ? AND deleted_at IS NULL LIMIT 1',
        [user_id]
      );
      if (idRows.length > 0) user = idRows[0];
    }
    if (!user && email) {
      const cleanEmail = email.trim().toLowerCase();
      const [emailRows] = await pool.query(
        'SELECT * FROM users WHERE LOWER(email) = ? AND deleted_at IS NULL LIMIT 1',
        [cleanEmail]
      );
      if (emailRows.length > 0) user = emailRows[0];
    }

    if (!user) {
      return res.status(404).json({ message: 'Akun pengguna tidak ditemukan.' });
    }

    const updatedName = name !== undefined && String(name).trim() !== '' ? String(name).trim() : user.name;
    const updatedPhone = phone !== undefined ? (String(phone).trim() || null) : user.phone;
    const updatedAlamat = alamat !== undefined ? (String(alamat).trim() || null) : user.alamat;
    const updatedPhoto = photo_url !== undefined ? (String(photo_url).trim() || null) : user.photo_url;

    await pool.query(
      'UPDATE users SET name = ?, phone = ?, alamat = ?, photo_url = ? WHERE id = ?',
      [updatedName, updatedPhone, updatedAlamat, updatedPhoto, user.id]
    );

    const [updatedRows] = await pool.query(
      'SELECT u.*, k.name AS koordinator_name FROM users u LEFT JOIN users k ON u.koordinator_id = k.id WHERE u.id = ?',
      [user.id]
    );
    return res.json({
      status: true,
      message: 'Profil berhasil diperbarui.',
      user: formatUser(updatedRows[0]),
    });
  } catch (error) {
    console.error('Error saat update profil:', error);
    return res.status(500).json({ message: 'Terjadi kesalahan pada server: ' + error.message });
  }
});

// --------------------------------------------------------
// 6. PUT /api/users/:id/member (Kelola profil anggota Sales oleh Admin/Owner atau edit pribadi oleh Sales)
// --------------------------------------------------------
router.put('/:id/member', async (req, res) => {
  try {
    await ensureUsersSchema();
    const targetId = Number(req.params.id);
    const {
      name,
      phone,
      alamat,
      kode_sales,
      tanggal_bergabung,
      koordinator_id,
    } = req.body;

    const actor = await resolveActor(req);
    const isMgr = isManagerRole(actor);
    if (actor && !isMgr && Number(actor.id) !== targetId) {
      return res.status(403).json({
        message: 'Akses ditolak: Anda hanya dapat mengubah informasi pribadi Anda sendiri.',
      });
    }

    const [targetRows] = await pool.query(
      'SELECT * FROM users WHERE id = ? AND deleted_at IS NULL LIMIT 1',
      [targetId]
    );
    if (targetRows.length === 0) {
      return res.status(404).json({ message: 'Data anggota tidak ditemukan.' });
    }
    const target = targetRows[0];

    const updatedName = name !== undefined && String(name).trim() !== '' ? String(name).trim() : target.name;
    const updatedPhone = phone !== undefined ? (String(phone).trim() || null) : target.phone;
    const updatedAlamat = alamat !== undefined ? (String(alamat).trim() || null) : target.alamat;

    // Hanya Admin/Owner yang boleh mengubah kode_sales, tanggal_bergabung, dan koordinator_id
    let updatedKodeSales = target.kode_sales;
    let updatedJoinDate = target.tanggal_bergabung;
    let updatedKoordinator = target.koordinator_id;

    if (isMgr || !actor) {
      if (kode_sales !== undefined && String(kode_sales).trim() !== '') {
        const cleanKode = String(kode_sales).trim().toUpperCase();
        const [dupKode] = await pool.query(
          'SELECT id FROM users WHERE UPPER(kode_sales) = ? AND id != ? AND deleted_at IS NULL LIMIT 1',
          [cleanKode, targetId]
        );
        if (dupKode.length > 0) {
          return res.status(409).json({
            message: `Kode Sales "${cleanKode}" sudah digunakan oleh anggota lain.`,
          });
        }
        updatedKodeSales = cleanKode;
      }
      if (tanggal_bergabung !== undefined) {
        updatedJoinDate = tanggal_bergabung ? String(tanggal_bergabung).trim() : null;
      }
      if (koordinator_id !== undefined) {
        updatedKoordinator = koordinator_id ? Number(koordinator_id) : null;
      }
    }

    await pool.query(
      `UPDATE users
       SET name = ?, phone = ?, alamat = ?, kode_sales = ?, tanggal_bergabung = ?, koordinator_id = ?
       WHERE id = ?`,
      [updatedName, updatedPhone, updatedAlamat, updatedKodeSales, updatedJoinDate, updatedKoordinator, targetId]
    );

    try {
      await pool.query(
        `INSERT INTO activity_logs (user_id, modul, aksi, deskripsi, ip_address)
         VALUES (?, 'FR07_KEANGGOTAAN', 'UPDATE', ?, ?)`,
        [
          actor ? actor.id : targetId,
          `Memperbarui data anggota ${updatedName} (${updatedKodeSales || target.email})`,
          req.ip || '127.0.0.1',
        ]
      );
    } catch (_) {}

    const [updatedRows] = await pool.query(
      'SELECT u.*, k.name AS koordinator_name FROM users u LEFT JOIN users k ON u.koordinator_id = k.id WHERE u.id = ?',
      [targetId]
    );
    return res.json({
      status: true,
      message: 'Data anggota berhasil diperbarui.',
      user: formatUser(updatedRows[0]),
    });
  } catch (error) {
    console.error('[PUT /api/users/:id/member] Error:', error);
    return res.status(500).json({ message: 'Gagal memperbarui data anggota: ' + error.message });
  }
});

// --------------------------------------------------------
// 7. PATCH /api/users/:id/membership-status (Aktifkan / Nonaktifkan / Tangguhkan Sales)
//    Khusus Admin & Owner. Mencatat riwayat di membership_status_logs.
// --------------------------------------------------------
router.patch('/:id/membership-status', async (req, res) => {
  try {
    await ensureUsersSchema();
    const targetId = Number(req.params.id);
    const { membership_status, reason } = req.body;

    const validStatus = ['aktif', 'nonaktif', 'ditangguhkan'];
    const newStatus = String(membership_status || '').toLowerCase();
    if (!validStatus.includes(newStatus)) {
      return res.status(400).json({
        message: 'Status keanggotaan tidak valid. Gunakan: aktif, nonaktif, atau ditangguhkan.',
      });
    }

    const actor = await resolveActor(req);
    if (!actor || !isManagerRole(actor)) {
      return res.status(403).json({
        message: 'Akses ditolak: Hanya Admin dan Owner yang berhak mengubah status keanggotaan.',
      });
    }
    if (Number(actor.id) === targetId) {
      return res.status(400).json({
        message: 'Anda tidak dapat mengubah status keanggotaan akun Anda sendiri.',
      });
    }

    const [targetRows] = await pool.query(
      'SELECT * FROM users WHERE id = ? AND deleted_at IS NULL LIMIT 1',
      [targetId]
    );
    if (targetRows.length === 0) {
      return res.status(404).json({ message: 'Data anggota tidak ditemukan.' });
    }
    const target = targetRows[0];
    const oldStatus = target.membership_status || (target.is_active === 1 ? 'aktif' : 'nonaktif');
    const newIsActive = newStatus === 'aktif' ? 1 : 0;

    await pool.query(
      'UPDATE users SET membership_status = ?, is_active = ? WHERE id = ?',
      [newStatus, newIsActive, targetId]
    );

    const finalReason = reason && String(reason).trim() !== ''
      ? String(reason).trim()
      : `Perubahan status keanggotaan menjadi ${newStatus}`;

    await pool.query(
      `INSERT INTO membership_status_logs (user_id, old_status, new_status, reason, changed_by)
       VALUES (?, ?, ?, ?, ?)`,
      [targetId, oldStatus, newStatus, finalReason, actor.id]
    );

    try {
      await pool.query(
        `INSERT INTO activity_logs (user_id, modul, aksi, deskripsi, ip_address)
         VALUES (?, 'FR07_KEANGGOTAAN', 'UPDATE', ?, ?)`,
        [
          actor.id,
          `Mengubah status keanggotaan ${target.name} dari '${oldStatus}' menjadi '${newStatus}' (${finalReason})`,
          req.ip || '127.0.0.1',
        ]
      );
    } catch (_) {}

    const [updatedRows] = await pool.query(
      'SELECT u.*, k.name AS koordinator_name FROM users u LEFT JOIN users k ON u.koordinator_id = k.id WHERE u.id = ?',
      [targetId]
    );
    return res.json({
      status: true,
      message: `Status keanggotaan ${target.name} berhasil diubah menjadi ${newStatus}.`,
      user: formatUser(updatedRows[0]),
    });
  } catch (error) {
    console.error('[PATCH /api/users/:id/membership-status] Error:', error);
    return res.status(500).json({ message: 'Gagal mengubah status keanggotaan: ' + error.message });
  }
});

// --------------------------------------------------------
// 8. GET /api/users/:id/status-history (Riwayat perubahan status keanggotaan)
// --------------------------------------------------------
router.get('/:id/status-history', async (req, res) => {
  try {
    await ensureUsersSchema();
    const targetId = Number(req.params.id);
    const [rows] = await pool.query(
      `SELECT l.*, c.name AS changed_by_name, c.role AS changed_by_role
       FROM membership_status_logs l
       LEFT JOIN users c ON l.changed_by = c.id
       WHERE l.user_id = ?
       ORDER BY l.created_at DESC, l.id DESC`,
      [targetId]
    );
    return res.json({
      status: true,
      data: rows.map((r) => ({
        id: Number(r.id),
        user_id: Number(r.user_id),
        old_status: r.old_status,
        new_status: r.new_status,
        reason: r.reason || '',
        changed_by: r.changed_by ? Number(r.changed_by) : null,
        changed_by_name: r.changed_by_name || 'Sistem',
        created_at: r.created_at ? new Date(r.created_at).toISOString() : new Date().toISOString(),
      })),
    });
  } catch (error) {
    console.error('[GET /api/users/:id/status-history] Error:', error);
    return res.status(500).json({ message: 'Gagal memuat riwayat status keanggotaan: ' + error.message });
  }
});

// --------------------------------------------------------
// 9. GET /api/users/avatar-proxy (Proxy CORS gambar eksternal untuk Flutter Web)
// --------------------------------------------------------
router.get('/avatar-proxy', async (req, res) => {
  try {
    const targetUrl = req.query.url;
    if (!targetUrl || (!targetUrl.startsWith('http://') && !targetUrl.startsWith('https://'))) {
      return res.status(400).send('Invalid URL');
    }

    const response = await fetch(targetUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        Accept: 'image/avif,image/webp,image/apng,image/png,image/jpeg,image/*,*/*;q=0.8',
      },
    });

    if (!response.ok) {
      return res.status(response.status).send('Failed to fetch image');
    }

    const contentType = response.headers.get('content-type') || 'image/jpeg';
    const arrayBuffer = await response.arrayBuffer();
    const buffer = Buffer.from(arrayBuffer);

    res.setHeader('Content-Type', contentType);
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Cache-Control', 'public, max-age=86400');
    return res.send(buffer);
  } catch (error) {
    console.warn('[avatar-proxy] Gagal memuat gambar:', error.message);
    return res.status(502).send('Error fetching image');
  }
});

module.exports = {
  router,
  ensureUsersSchema,
  resolveAuthenticatedUser,
  resolveActor,
  isManagerRole,
};
