require('dotenv').config();
const express = require('express');
const cors    = require('cors');
const helmet  = require('helmet');
const morgan  = require('morgan');

const routes = require('./routes');
const notificationWorker = require('./jobs/notificationWorker');
const mlService = require('./services/mlService');

const app = express();

// ── Security & logging middleware ─────────────────────────────
app.use(helmet());
app.use(cors({
  origin: '*',
  methods: ['GET','POST','PUT','DELETE','PATCH'],
  allowedHeaders: ['Content-Type','Authorization'],
}));
app.use(morgan('dev'));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// ── API Routes ────────────────────────────────────────────────
app.use('/api', routes);

// ── 404 handler ───────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({ success: false, message: `Route ${req.method} ${req.path} not found` });
});

// ── Global error handler ──────────────────────────────────────
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({ success: false, message: 'Internal server error' });
});

// ── Start server ──────────────────────────────────────────────
const PORT = process.env.PORT || 5000;
// Bind to 0.0.0.0 so devices on the same network (e.g. the phone over
// USB tether / hotspot) can reach the API, not just localhost.
app.listen(PORT, '0.0.0.0', async () => {
  console.log(`\n🚀 SAPMS API running on http://0.0.0.0:${PORT} (reachable on your LAN IP)`);
  console.log(`📋 Health check: http://localhost:${PORT}/api/health`);
  console.log(`🏫 Environment: ${process.env.NODE_ENV || 'development'}`);

  const mlHealthy = await mlService.checkHealth();
  console.log(`🤖 ML microservice: ${mlHealthy ? 'connected ✅' : 'unavailable — using rule-based risk scoring ⚠️'}`);

  notificationWorker.start();
  console.log('');
});

module.exports = app;
