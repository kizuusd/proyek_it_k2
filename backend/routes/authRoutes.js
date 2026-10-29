const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const { pool } = require('../config/db');

// Helper format user object agar cocok dengan UserModel Flutter
function formatUser(row) {
  return {
    id: Number(row.id),
    name: row.name,
    email: row.email,
    phone: row.phone || null,
    photo_url: row.photo_url || null,
    role: row.role,
    is_active: Boolean(row.is_active === 1 || row.is_active === true),
    google_id: row.google_id || null,
    google_email: row.google_email || null,
    device_token: row.device_token || null,
    created_by: row.created_by || null,
    last_login_at: row.last_login_at ? new Date(row.last_login_at).toISOString() : null,
  };
}

// Helper untuk menyimpan session token ke tabel user_tokens (db_tracking_sales)
async function saveUserToken(userId, token, expiresAtDate, req) {
  try {
    const deviceInfo = req.body.device_info || req.headers['user-agent'] || 'Flutter Client';
    const ipAddress = req.ip || req.connection?.remoteAddress || '127.0.0.1';
    await pool.query(
      `INSERT INTO user_tokens (user_id, token, device_info, ip_address, expires_at)
       VALUES (?, ?, ?, ?, ?)`,
      [userId, token, String(deviceInfo).substring(0, 255), String(ipAddress).substring(0, 255), expiresAtDate]
    );
  } catch (err) {
    console.warn('[user_tokens] Gagal mencatat token sesi:', err.message);
  }
}

// Helper untuk mencatat audit log ke tabel activity_logs (db_tracking_sales)
async function logActivity(userId, modul, aksi, deskripsi, req) {
  try {
    const ipAddress = req.ip || req.connection?.remoteAddress || '127.0.0.1';
    const userAgent = req.headers['user-agent'] || 'Flutter Client';
    await pool.query(
      `INSERT INTO activity_logs (user_id, modul, aksi, deskripsi, ip_address, user_agent)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [userId, modul, aksi, deskripsi, String(ipAddress).substring(0, 255), String(userAgent).substring(0, 255)]
    );
  } catch (err) {
    console.warn('[activity_logs] Gagal mencatat log aktivitas:', err.message);
  }
}

// --------------------------------------------------------
// 1. POST /api/auth/login
// --------------------------------------------------------
router.post('/login', async (req, res) => {
  try {
    const { email, password, device_token } = req.body;
    if (!email || !password) {
      return res.status(400).json({ message: 'Email dan password wajib diisi.' });
    }

    const cleanEmail = email.trim().toLowerCase();
    const [rows] = await pool.query(
      'SELECT * FROM users WHERE LOWER(email) = ? AND deleted_at IS NULL LIMIT 1',
      [cleanEmail]
    );

    if (rows.length === 0) {
      return res.status(401).json({ message: 'Email tidak terdaftar dalam sistem.' });
    }

    const user = rows[0];

    // Verifikasi password (bcrypt atau plaintext dev 'password123')
    let isValidPassword = false;
    const storedPassword = user.password || '';
    if (
      storedPassword.startsWith('$2y$') ||
      storedPassword.startsWith('$2a$') ||
      storedPassword.startsWith('$2b$')
    ) {
      const normalizedHash = storedPassword.replace(/^\$2y\$/, '$2a$');
      isValidPassword = await bcrypt.compare(password, normalizedHash);
    }
    if (!isValidPassword && (password === storedPassword || password === 'password123')) {
      isValidPassword = true;
    }

    if (!isValidPassword) {
      return res.status(401).json({ message: 'Password yang Anda masukkan salah.' });
    }

    // Validasi status akun (is_active)
    if (user.is_active !== 1 && user.is_active !== true) {
      return res.status(403).json({ message: 'Akun Anda dinonaktifkan. Hubungi Administrator.' });
    }

    // Update last_login_at (dan device_token jika dikirim)
    if (device_token) {
      await pool.query(
        'UPDATE users SET last_login_at = NOW(), device_token = ? WHERE id = ?',
        [device_token, user.id]
      );
    } else {
      await pool.query('UPDATE users SET last_login_at = NOW() WHERE id = ?', [user.id]);
    }

    const token = `jwt_mysql_token_${user.id}_${crypto.randomBytes(16).toString('hex')}`;
    const expiresAtDate = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
    const expiresAt = expiresAtDate.toISOString();

    // Simpan ke tabel user_tokens & activity_logs di db_tracking_sales
    await saveUserToken(user.id, token, expiresAtDate, req);
    await logActivity(user.id, 'AUTH', 'LOGIN', `Login email berhasil (${user.email})`, req);

    return res.json({
      token,
      expires_at: expiresAt,
      user: formatUser({ ...user, last_login_at: new Date() }),
    });
  } catch (error) {
    console.error('Error saat login:', error);
    return res.status(500).json({ message: 'Terjadi kesalahan pada server: ' + error.message });
  }
});

// --------------------------------------------------------
// 2. POST /api/auth/google-login
// --------------------------------------------------------
router.post('/google-login', async (req, res) => {
  try {
    const { email, google_id, photo_url, device_token } = req.body;
    console.log(`[google-login] Menerima request: email=${email}, google_id=${google_id}`);
    if (!email && !google_id) {
      return res.status(400).json({ message: 'Email Google wajib diisi.' });
    }

    const cleanEmail = email ? email.trim().toLowerCase() : '';
    const gid = google_id && String(google_id).trim().length > 0 ? String(google_id).trim() : null;

    let user = null;

    // Prioritas 1: Cari berdasarkan google_email yang tertaut
    if (cleanEmail) {
      const [byGoogleEmail] = await pool.query(
        'SELECT * FROM users WHERE LOWER(google_email) = ? AND deleted_at IS NULL LIMIT 1',
        [cleanEmail]
      );
      if (byGoogleEmail.length > 0) {
        user = byGoogleEmail[0];
        console.log(`[google-login] Ditemukan via google_email: ${user.email} (id=${user.id})`);
      }
    }

    // Prioritas 2: Cari berdasarkan email utama akun (jika email akun sama dengan Gmail)
    if (!user && cleanEmail) {
      const [byEmail] = await pool.query(
        'SELECT * FROM users WHERE LOWER(email) = ? AND deleted_at IS NULL LIMIT 1',
        [cleanEmail]
      );
      if (byEmail.length > 0) {
        user = byEmail[0];
        console.log(`[google-login] Ditemukan via email akun: ${user.email} (id=${user.id})`);
      }
    }

    // Prioritas 3: Cari berdasarkan google_id unik
    if (!user && gid) {
      const [byGid] = await pool.query(
        'SELECT * FROM users WHERE google_id = ? AND deleted_at IS NULL LIMIT 1',
        [gid]
      );
      if (byGid.length > 0) {
        user = byGid[0];
        console.log(`[google-login] Ditemukan via google_id: ${user.email} (id=${user.id})`);
      }
    }

    // Jika tidak ditemukan dalam sistem
    if (!user) {
      console.warn(`[google-login] Akun Google ${cleanEmail} (gid=${gid}) belum terdaftar.`);
      return res.status(403).json({
        message: `Akun Google (${cleanEmail}) belum terdaftar dalam sistem. Khusus akun Sales, pendaftaran hanya dapat dilakukan oleh Admin atau Owner.`,
      });
    }

    // Cek keaktifan akun
    if (user.is_active !== 1 && user.is_active !== true) {
      return res.status(403).json({ message: 'Akun Anda dinonaktifkan. Hubungi Administrator.' });
    }

    const finalGoogleId = gid || user.google_id || `google_oauth_${user.id}`;
    const finalGoogleEmail = user.google_email || (cleanEmail || user.email);
    const hasCustomPhoto =
      user.photo_url &&
      (user.photo_url.startsWith('data:image') ||
        user.photo_url.startsWith('assets/'));
    const cleanExistingPhoto =
      user.photo_url && user.photo_url.startsWith('preset:') ? null : user.photo_url;
    const finalPhoto = hasCustomPhoto ? user.photo_url : (photo_url || cleanExistingPhoto);
    const finalDeviceToken = device_token || user.device_token || null;

    await pool.query(
      'UPDATE users SET google_id = ?, google_email = ?, photo_url = ?, device_token = ?, last_login_at = NOW() WHERE id = ?',
      [finalGoogleId, finalGoogleEmail, finalPhoto, finalDeviceToken, user.id]
    );

    const token = `google_mysql_token_${user.id}_${crypto.randomBytes(16).toString('hex')}`;
    const expiresAtDate = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
    const expiresAt = expiresAtDate.toISOString();

    // Simpan ke tabel user_tokens & activity_logs di db_tracking_sales
    await saveUserToken(user.id, token, expiresAtDate, req);
    await logActivity(
      user.id,
      'AUTH',
      'LOGIN',
      `Login Google OAuth berhasil (${finalGoogleEmail})`,
      req
    );

    console.log(`[google-login] SUKSES login user: id=${user.id}, nama=${user.name}, role=${user.role}`);
    return res.json({
      token,
      expires_at: expiresAt,
      user: formatUser({
        ...user,
        google_id: finalGoogleId,
        google_email: finalGoogleEmail,
        photo_url: finalPhoto,
        device_token: finalDeviceToken,
        last_login_at: new Date(),
      }),
    });
  } catch (error) {
    console.error('Error saat login Google:', error);
    return res.status(500).json({ message: 'Terjadi kesalahan pada server: ' + error.message });
  }
});

// --------------------------------------------------------
// 3. POST /api/auth/register-sales (Khusus Admin / Owner)
// --------------------------------------------------------
router.post('/register-sales', async (req, res) => {
  try {
    const { manager_id, name, email, password, phone, link_google } = req.body;

    // Validasi manajer
    if (!manager_id) {
      return res.status(403).json({
        message: 'Akses ditolak: Pendaftaran hanya dapat dilakukan oleh Admin atau Owner.',
      });
    }

    const [mgrRows] = await pool.query(
      'SELECT * FROM users WHERE id = ? AND deleted_at IS NULL LIMIT 1',
      [manager_id]
    );
    if (mgrRows.length === 0) {
      return res.status(403).json({ message: 'Data manajer pendaftar tidak valid.' });
    }

    const manager = mgrRows[0];
    const roleLower = (manager.role || '').toLowerCase();
    const isManager = ['superadmin', 'owner', 'administrator', 'admin'].includes(roleLower);

    if (!isManager) {
      return res.status(403).json({
        message: 'Akses ditolak: Hanya Admin dan Owner yang memiliki izin untuk mendaftarkan akun Sales baru.',
      });
    }

    if (!name || !email || !password) {
      return res.status(400).json({ message: 'Nama, email, dan password wajib diisi.' });
    }

    const cleanEmail = email.trim().toLowerCase();
    const [existRows] = await pool.query(
      'SELECT id FROM users WHERE LOWER(email) = ? AND deleted_at IS NULL LIMIT 1',
      [cleanEmail]
    );
    if (existRows.length > 0) {
      return res.status(409).json({ message: `Email "${cleanEmail}" sudah terdaftar dalam sistem.` });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const googleId = link_google ? `google_oauth_${crypto.randomBytes(6).toString('hex')}` : null;
    const googleEmail = link_google ? cleanEmail : null;

    // Pada db_tracking_sales, kolom created_by bertipe bigint(20) FK ke users(id)
    const [insertResult] = await pool.query(
      `INSERT INTO users (name, email, password, phone, role, is_active, google_id, google_email, created_by)
       VALUES (?, ?, ?, ?, 'sales', 1, ?, ?, ?)`,
      [
        name.trim(),
        cleanEmail,
        hashedPassword,
        phone ? phone.trim() : null,
        googleId,
        googleEmail,
        manager.id,
      ]
    );

    const newId = insertResult.insertId;
    const [newUserRows] = await pool.query('SELECT * FROM users WHERE id = ?', [newId]);

    await logActivity(
      manager.id,
      'USERS',
      'CREATE',
      `Mendaftarkan akun Sales baru: ${name.trim()} (${cleanEmail})`,
      req
    );

    return res.status(201).json({
      message: 'Akun Sales berhasil didaftarkan ke database MySQL (db_tracking_sales).',
      user: formatUser(newUserRows[0]),
    });
  } catch (error) {
    console.error('Error saat registrasi sales:', error);
    return res.status(500).json({ message: 'Terjadi kesalahan pada server: ' + error.message });
  }
});

// --------------------------------------------------------
// 4. POST /api/auth/logout (Cabut token sesi di user_tokens)
// --------------------------------------------------------
router.post('/logout', async (req, res) => {
  try {
    const authHeader = req.headers.authorization || '';
    const bearerToken = authHeader.startsWith('Bearer ') ? authHeader.slice(7).trim() : null;
    const token = req.body?.token || bearerToken;

    if (token) {
      const [tokenRows] = await pool.query(
        'SELECT user_id FROM user_tokens WHERE token = ? LIMIT 1',
        [token]
      );
      await pool.query(
        'UPDATE user_tokens SET revoked_at = NOW() WHERE token = ? AND revoked_at IS NULL',
        [token]
      );
      if (tokenRows.length > 0) {
        await logActivity(tokenRows[0].user_id, 'AUTH', 'LOGOUT', 'Pengguna keluar (logout)', req);
      }
    }

    return res.json({ status: true, message: 'Sesi berhasil diakhiri.' });
  } catch (error) {
    console.error('Error saat logout:', error);
    return res.status(500).json({ message: 'Terjadi kesalahan pada server: ' + error.message });
  }
});

module.exports = router;
