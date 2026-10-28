const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const { pool } = require('../config/db');

// Helper format user object agar cocok dengan UserModel Flutter
function formatUser(row) {
  return {
    id: row.id,
    name: row.name,
    email: row.email,
    phone: row.phone || null,
    photo_url: row.photo_url || null,
    role: row.role,
    is_active: Boolean(row.is_active === 1 || row.is_active === true),
    google_id: row.google_id || null,
    google_email: row.google_email || null,
    created_by: row.created_by || null,
    last_login_at: row.last_login_at ? new Date(row.last_login_at).toISOString() : null,
  };
}

// --------------------------------------------------------
// 1. POST /api/auth/login
// --------------------------------------------------------
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ message: 'Email dan password wajib diisi.' });
    }

    const cleanEmail = email.trim().toLowerCase();
    const [rows] = await pool.query(
      'SELECT * FROM users WHERE LOWER(email) = ? LIMIT 1',
      [cleanEmail]
    );

    if (rows.length === 0) {
      return res.status(401).json({ message: 'Email tidak terdaftar dalam sistem.' });
    }

    const user = rows[0];

    // Verifikasi password (bcrypt atau plaintext dev 'password123')
    let isValidPassword = false;
    if (user.password.startsWith('$2y$') || user.password.startsWith('$2a$') || user.password.startsWith('$2b$')) {
      const normalizedHash = user.password.replace(/^\$2y\$/, '$2a$');
      isValidPassword = await bcrypt.compare(password, normalizedHash);
    }
    if (!isValidPassword && (password === user.password || password === 'password123')) {
      isValidPassword = true;
    }

    if (!isValidPassword) {
      return res.status(401).json({ message: 'Password yang Anda masukkan salah.' });
    }

    // Validasi status akun (is_active)
    if (user.is_active !== 1 && user.is_active !== true) {
      return res.status(403).json({ message: 'Akun Anda dinonaktifkan. Hubungi Administrator.' });
    }

    // Update last_login_at
    await pool.query('UPDATE users SET last_login_at = NOW() WHERE id = ?', [user.id]);

    const token = `jwt_mysql_token_${user.id}_${crypto.randomBytes(16).toString('hex')}`;
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();

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
    const { email, google_id, photo_url } = req.body;
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
        'SELECT * FROM users WHERE LOWER(google_email) = ? LIMIT 1',
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
        'SELECT * FROM users WHERE LOWER(email) = ? LIMIT 1',
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
        'SELECT * FROM users WHERE google_id = ? LIMIT 1',
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
    const finalPhoto = photo_url || user.photo_url;

    await pool.query(
      'UPDATE users SET google_id = ?, google_email = ?, photo_url = ?, last_login_at = NOW() WHERE id = ?',
      [finalGoogleId, finalGoogleEmail, finalPhoto, user.id]
    );

    const token = `google_mysql_token_${user.id}_${crypto.randomBytes(16).toString('hex')}`;
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();

    console.log(`[google-login] SUKSES login user: id=${user.id}, nama=${user.name}, role=${user.role}`);
    return res.json({
      token,
      expires_at: expiresAt,
      user: formatUser({
        ...user,
        google_id: finalGoogleId,
        google_email: finalGoogleEmail,
        photo_url: finalPhoto,
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

    const [mgrRows] = await pool.query('SELECT * FROM users WHERE id = ? LIMIT 1', [manager_id]);
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
    const [existRows] = await pool.query('SELECT id FROM users WHERE LOWER(email) = ? LIMIT 1', [cleanEmail]);
    if (existRows.length > 0) {
      return res.status(409).json({ message: `Email "${cleanEmail}" sudah terdaftar dalam sistem.` });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const googleId = link_google ? `google_oauth_${crypto.randomBytes(6).toString('hex')}` : null;

    const [insertResult] = await pool.query(
      `INSERT INTO users (name, email, password, phone, role, is_active, google_id, created_by)
       VALUES (?, ?, ?, ?, 'sales', 1, ?, ?)`,
      [name.trim(), cleanEmail, hashedPassword, phone ? phone.trim() : null, googleId, manager.name]
    );

    const newId = insertResult.insertId;
    const [newUserRows] = await pool.query('SELECT * FROM users WHERE id = ?', [newId]);

    return res.status(201).json({
      message: 'Akun Sales berhasil didaftarkan ke database MySQL.',
      user: formatUser(newUserRows[0]),
    });
  } catch (error) {
    console.error('Error saat registrasi sales:', error);
    return res.status(500).json({ message: 'Terjadi kesalahan pada server: ' + error.message });
  }
});

module.exports = router;
