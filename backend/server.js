const express = require('express');
const cors = require('cors');
const { testConnection } = require('./config/db');
const authRoutes = require('./routes/authRoutes');
const userRoutes = require('./routes/userRoutes');
const leaveRoutes = require('./routes/leaveRoutes');
const { router: productRoutes, ensureProductAndStockSchema } = require('./routes/productRoutes');
const stockRequestRoutes = require('./routes/stockRequestRoutes');

const app = express();
const PORT = process.env.PORT || 8000;

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
app.get('/api/health', (req, res) => {
  res.json({
    status: 'OK',
    message: 'Backend Node.js Tracking Sales CV Maju Bersama berjalan dengan baik.',
    database: 'MySQL (db_tracking_sales)',
    timestamp: new Date().toISOString(),
  });
});

app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/leaves', leaveRoutes);
app.use('/api/products', productRoutes);
app.use('/api/stock-requests', stockRequestRoutes);

// 404 handler
app.use((req, res) => {
  res.status(404).json({ message: `Rute '${req.originalUrl}' tidak ditemukan pada backend server.` });
});

// Start Server
async function startServer() {
  const connected = await testConnection();
  if (connected) {
    await ensureProductAndStockSchema();
  }
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 Server Node.js berjalan di http://localhost:${PORT}`);
    console.log(`📡 Base URL API: http://localhost:${PORT}/api`);
    console.log(`📱 Untuk Android Emulator gunakan: http://10.0.2.2:${PORT}/api`);
  });
}

startServer();
