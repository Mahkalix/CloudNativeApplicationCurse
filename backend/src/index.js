const express = require('express');
const cors = require('cors');
const os = require('node:os');
require('dotenv').config();

const userRoutes = require('./routes/userRoutes');
const subscriptionRoutes = require('./routes/subscriptionRoutes');
const classRoutes = require('./routes/classRoutes');
const bookingRoutes = require('./routes/bookingRoutes');
const dashboardRoutes = require('./routes/dashboardRoutes');
const authRoutes = require('./routes/authRoutes');

const app = express();
const PORT = process.env.PORT || 3000;
const INSTANCE_ID = process.env.INSTANCE_ID || os.hostname();

// Structured logging middleware
app.use((req, res, next) => {
  const start = process.hrtime.bigint();
  res.on('finish', () => {
    const durationNs = Number(process.hrtime.bigint() - start);
    const durationMs = Math.round(durationNs / 1e6);
    const log = {
      timestamp: new Date().toISOString(),
      level: 'info',
      hostname: os.hostname(),
      instance: INSTANCE_ID,
      method: req.method,
      path: req.originalUrl,
      status: res.statusCode,
      duration_ms: durationMs,
    };
    try {
      console.log(JSON.stringify(log));
    } catch {
      // Fallback to plain log if JSON serialization fails
      console.log(log);
    }
  });
  next();
});

// Middleware
app.use(cors({
  origin: process.env.FRONTEND_URL || 'http://localhost:8080',
  credentials: true
}));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Routes
app.use('/api/users', userRoutes);
app.use('/api/subscriptions', subscriptionRoutes);
app.use('/api/classes', classRoutes);
app.use('/api/bookings', bookingRoutes);
app.use('/api/dashboard', dashboardRoutes);
app.use('/api/auth', authRoutes);

// Health check
app.get(['/health', '/api/health'], (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

// Whoami endpoint for load-balancer testing
app.get(['/whoami', '/api/whoami'], (req, res) => {
  res.json({
    hostname: os.hostname(),
    instanceId: process.env.INSTANCE_ID || os.hostname(),
    timestamp: new Date().toISOString()
  });
});

// Error handling middleware
app.use((err, req, res, _next) => {
  const errorLog = {
    timestamp: new Date().toISOString(),
    level: 'error',
    hostname: os.hostname(),
    instance: INSTANCE_ID,
    message: process.env.NODE_ENV === 'development' ? err.message : 'Internal server error',
    stack: process.env.NODE_ENV === 'development' ? err.stack : undefined,
  };
  try {
    console.error(JSON.stringify(errorLog));
  } catch {
    console.error(errorLog);
  }
  res.status(500).json({
    error: 'Something went wrong!',
    message: process.env.NODE_ENV === 'development' ? err.message : 'Internal server error'
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
});
