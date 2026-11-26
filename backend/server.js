const express = require('express');
const cors = require('cors');
const { pool, database, testConnection } = require('./config/db');
const authRoutes = require('./routes/authRoutes');
const { router: userRoutes, ensureUsersSchema } = require('./routes/userRoutes');
const leaveRoutes = require('./routes/leaveRoutes');
const { router: productRoutes, ensureProductAndStockSchema } = require('./routes/productRoutes');
const stockRequestRoutes = require('./routes/stockRequestRoutes');
const { router: attendanceRoutes, ensureAttendanceSchema } = require('./routes/attendanceRoutes');
const { router: routeRoutes, ensureRouteSchema } = require('./routes/routeRoutes');
const { router: transactionRoutes, ensureTransactionSchema } = require('./routes/transactionRoutes');
const { router: monitoringRoutes } = require('./routes/monitoringRoutes');

const app = express();
const PORT = Number(process.env.PORT || 8000);
const HOST = process.env.HOST || '127.0.0.1';

// Middleware
app.use(cors());
app.use(express.json({ limit: '15mb' }));
app.use(express.urlencoded({ extended: true, limit: '15mb' }));

// Logging sederhana request
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
  next();
});

// Routes
app.get('/api/health', async (req, res) => {
  try {
    await testConnection();
    return res.json({
      status: 'OK',
      database: `MySQL (${database})`,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    return res.status(503).json({ status: 'UNAVAILABLE', message: 'MySQL tidak dapat dihubungi.' });
  }
});

app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/leaves', leaveRoutes);
app.use('/api/products', productRoutes);
app.use('/api/stock-requests', stockRequestRoutes);
app.use('/api/attendances', attendanceRoutes);
app.use('/api/routes', routeRoutes);
app.use('/api/transactions', transactionRoutes);
app.use('/api/monitoring', monitoringRoutes);

// 404 handler
app.use((req, res) => {
  res.status(404).json({ message: `Rute '${req.originalUrl}' tidak ditemukan pada backend server.` });
});

// Start Server
async function startServer() {
  if (!Number.isInteger(PORT) || PORT < 1 || PORT > 65535) {
    throw new Error('PORT harus berupa angka antara 1 dan 65535.');
  }
  await testConnection();
  await ensureUsersSchema();
  await ensureProductAndStockSchema();
  await ensureAttendanceSchema();
  await ensureRouteSchema();
  await ensureTransactionSchema();
  await new Promise((resolve, reject) => {
    const server = app.listen(PORT, HOST, resolve);
    server.once('error', reject);
  });
  console.log(`Backend siap di http://${HOST}:${PORT}/api (MySQL: ${database})`);
}

startServer().catch(async (error) => {
  const code = error.code || error.cause?.code;
  console.error('Backend gagal dimulai:', error.message);
  if (code === 'EADDRINUSE') {
    console.error(`Port ${PORT} sedang dipakai. Ubah PORT di backend/.env atau hentikan server lama.`);
  } else if (['ER_BAD_DB_ERROR', 'ER_NO_SUCH_TABLE'].includes(code)) {
    console.error('Impor database/db_tracking_sales.sql pada database baru dan periksa DB_NAME.');
  } else if (['ECONNREFUSED', 'ETIMEDOUT', 'ENOTFOUND', 'ER_ACCESS_DENIED_ERROR'].includes(code)) {
    console.error('Pastikan MySQL aktif dan pengaturan DB_* di backend/.env sesuai.');
  }
  process.exitCode = 1;
  await pool.end();
});
