require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const path = require('path');
const connectDB = require('./config/database');

const app = express();

// Connect to MongoDB
connectDB();

// Auto-seed default admin on first boot
async function seedDefaultAdmin() {
  try {
    const Admin = require('./models/Admin');
    const existing = await Admin.findOne({});
    if (!existing) {
      const admin = new Admin({
        username:     'admin',
        email:        'admin@omnivote.local',
        passwordHash: 'Admin@OmniVote2026!',
        role:         'super_admin',
        isActive:     true,
        permissions: {
          manageElections: true,
          manageUsers:     true,
          viewAnalytics:   true,
          manageAdmins:    true,
          systemSettings:  true
        }
      });
      await admin.save();
      console.log('  ✅ Default admin created: admin / Admin@OmniVote2026!');
      console.log('  ⚠️  Change this password immediately after first login!');
    }
  } catch (err) {
    console.error('  ⚠️  Could not seed default admin:', err.message);
  }
}

// Security middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc:  ["'self'"],
      connectSrc:  ["'self'"],
      styleSrc:    ["'self'", "'unsafe-inline'", "https://fonts.googleapis.com", "https://cdnjs.cloudflare.com"],
      fontSrc:     ["'self'", "https://fonts.gstatic.com", "https://cdnjs.cloudflare.com"],
      scriptSrc:   ["'self'", "'unsafe-inline'", "https://cdnjs.cloudflare.com"],
      imgSrc:      ["'self'", "data:", "https:", "blob:"],
    },
  },
}));

// CORS
app.use(cors({
  origin: process.env.FRONTEND_URL || '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: Number(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000,
  max: Number(process.env.RATE_LIMIT_MAX) || 100,
  message: { success: false, message: 'Too many requests. Please try again later.' }
});
app.use('/api/', limiter);

// Vote casting specific limiter
const voteLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 5,
  message: { success: false, message: 'Vote rate limit exceeded.' }
});
app.use('/api/votes/cast', voteLimiter);

// Logging
if (process.env.NODE_ENV !== 'test') {
  app.use(morgan('dev'));
}

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Serve admin panel static files
app.use('/admin', express.static(path.join(__dirname, '../admin')));

// API Routes

// ── Standalone setup endpoint (no auth required, safe to call repeatedly) ──
// Placed here in server.js to guarantee it runs BEFORE any auth middleware
app.get('/api/admin/setup', async (req, res) => {
  try {
    const Admin = require('./models/Admin');
    const existing = await Admin.findOne({});
    if (existing) {
      return res.json({
        success: true,
        message: 'Admin account already exists. Use the login page.',
        data: { alreadyExists: true, username: existing.username }
      });
    }
    const admin = new Admin({
      username:     'admin',
      email:        'admin@omnivote.local',
      passwordHash: 'Admin@OmniVote2026!',
      role:         'super_admin',
      isActive:     true,
      permissions: {
        manageElections: true, manageUsers: true,
        viewAnalytics:   true, manageAdmins: true, systemSettings: true
      }
    });
    await admin.save();
    res.json({
      success: true,
      message: 'Admin account created! You can now log in.',
      data: { username: 'admin', password: 'Admin@OmniVote2026!' }
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.use('/api/auth', require('./routes/auth'));
app.use('/api/elections', require('./routes/elections'));
app.use('/api/votes', require('./routes/votes'));
app.use('/api/users', require('./routes/users'));
app.use('/api/admin', require('./routes/admin'));

// Health check
app.get('/health', (req, res) => {
  res.json({
    success: true,
    message: 'OmniVote API is running',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV
  });
});

// API root
app.get('/api', (req, res) => {
  res.json({
    success: true,
    message: 'OmniVote API',
    version: '1.0.0',
    endpoints: {
      auth: '/api/auth',
      elections: '/api/elections',
      votes: '/api/votes',
      users: '/api/users',
      admin: '/api/admin'
    }
  });
});

// Admin panel redirect
app.get('/', (req, res) => {
  res.redirect('/admin');
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ success: false, message: `Route ${req.method} ${req.url} not found` });
});

// Error handler
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  res.status(err.status || 500).json({
    success: false,
    message: process.env.NODE_ENV === 'production' ? 'Internal server error' : err.message
  });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', async () => {
  await seedDefaultAdmin();
  console.log(`
  ██████╗ ███╗   ███╗███╗   ██╗██╗██╗   ██╗ ██████╗ ████████╗███████╗
 ██╔═══██╗████╗ ████║████╗  ██║██║██║   ██║██╔═══██╗╚══██╔══╝██╔════╝
 ██║   ██║██╔████╔██║██╔██╗ ██║██║██║   ██║██║   ██║   ██║   █████╗  
 ██║   ██║██║╚██╔╝██║██║╚██╗██║██║╚██╗ ██╔╝██║   ██║   ██║   ██╔══╝  
 ╚██████╔╝██║ ╚═╝ ██║██║ ╚████║██║ ╚████╔╝ ╚██████╔╝   ██║   ███████╗
  ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═══╝╚═╝  ╚═══╝   ╚═════╝    ╚═╝   ╚══════╝
                                                                         
  🚀 Server running on http://localhost:${PORT}
  📊 Admin Panel: http://localhost:${PORT}/admin
  🔌 API: http://localhost:${PORT}/api
  💚 Health: http://localhost:${PORT}/health
  `);
});

module.exports = app;
