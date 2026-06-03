const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const { body, validationResult } = require('express-validator');
const Admin = require('../models/Admin');
const User = require('../models/User');
const Election = require('../models/Election');
const Vote = require('../models/Vote');
const { authenticateAdmin, requirePermission } = require('../middleware/auth');

// POST /api/admin/login
router.post('/login', [
  body('username').notEmpty(),
  body('password').notEmpty()
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const { username, password } = req.body;
    const admin = await Admin.findOne({ $or: [{ username }, { email: username }] });

    if (!admin || !admin.isActive) {
      return res.status(401).json({ success: false, message: 'Invalid credentials' });
    }

    const valid = await admin.comparePassword(password);
    if (!valid) {
      return res.status(401).json({ success: false, message: 'Invalid credentials' });
    }

    admin.lastLogin = new Date();
    await admin.save();

    const token = jwt.sign(
      { adminId: admin._id, role: admin.role },
      process.env.ADMIN_JWT_SECRET || process.env.JWT_SECRET,
      { expiresIn: process.env.ADMIN_JWT_EXPIRES_IN || '24h' }
    );

    res.json({
      success: true,
      message: 'Admin login successful',
      data: { token, admin: admin.toPublicJSON() }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// All routes below require admin auth
router.use(authenticateAdmin);

// GET /api/admin/me
router.get('/me', (req, res) => {
  res.json({ success: true, data: { admin: req.admin.toPublicJSON() } });
});

// ============ DASHBOARD ============

// GET /api/admin/dashboard
router.get('/dashboard', async (req, res) => {
  try {
    const now = new Date();
    const last30days = new Date(now - 30 * 24 * 60 * 60 * 1000);
    const last7days = new Date(now - 7 * 24 * 60 * 60 * 1000);

    const [
      totalUsers, newUsers30d, newUsers7d,
      totalElections, activeElections, pendingElections, closedElections,
      totalVotes, recentVotes,
      votesByDay
    ] = await Promise.all([
      User.countDocuments({ isActive: true }),
      User.countDocuments({ createdAt: { $gte: last30days } }),
      User.countDocuments({ createdAt: { $gte: last7days } }),
      Election.countDocuments(),
      Election.countDocuments({ status: 'active' }),
      Election.countDocuments({ status: 'pending' }),
      Election.countDocuments({ status: 'closed' }),
      Vote.countDocuments({ status: { $in: ['confirmed', 'verified'] } }),
      Vote.countDocuments({ timestamp: { $gte: last7days } }),
      Vote.aggregate([
        { $match: { timestamp: { $gte: last30days } } },
        {
          $group: {
            _id: { $dateToString: { format: '%Y-%m-%d', date: '$timestamp' } },
            count: { $sum: 1 }
          }
        },
        { $sort: { _id: 1 } }
      ])
    ]);

    // Top elections by votes
    const topElections = await Election.find()
      .sort({ totalVotes: -1 })
      .limit(5)
      .select('title totalVotes status type organizationName');

    // Recent activity
    const recentActivity = await Vote.find()
      .sort({ timestamp: -1 })
      .limit(10)
      .lean();

    const enrichedActivity = await Promise.all(recentActivity.map(async (vote) => {
      const election = await Election.findById(vote.electionId).select('title').lean();
      return {
        id: vote._id,
        transactionHash: vote.transactionHash.substring(0, 16) + '...',
        election: election?.title || 'Unknown',
        timestamp: vote.timestamp,
        status: vote.status,
        network: vote.network
      };
    }));

    res.json({
      success: true,
      data: {
        stats: {
          users: { total: totalUsers, new30d: newUsers30d, new7d: newUsers7d },
          elections: { total: totalElections, active: activeElections, pending: pendingElections, closed: closedElections },
          votes: { total: totalVotes, recent7d: recentVotes }
        },
        charts: {
          votesByDay,
          topElections
        },
        recentActivity: enrichedActivity
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// ============ ELECTIONS MANAGEMENT ============

// GET /api/admin/elections
router.get('/elections', requirePermission('manageElections'), async (req, res) => {
  try {
    const { status, type, page = 1, limit = 20, search } = req.query;
    const query = {};

    if (status) query.status = status;
    if (type) query.type = type;
    if (search) query.title = { $regex: search, $options: 'i' };

    const total = await Election.countDocuments(query);
    const elections = await Election.find(query)
      .sort({ createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(Number(limit));

    res.json({
      success: true,
      data: {
        elections,
        pagination: { total, page: Number(page), pages: Math.ceil(total / limit), limit: Number(limit) }
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/admin/elections
router.post('/elections', requirePermission('manageElections'), [
  body('title').notEmpty().trim(),
  body('description').notEmpty(),
  body('organizationName').notEmpty(),
  body('type').isIn(['general', 'presidential', 'parliamentary', 'corporate', 'dao', 'referendum']),
  body('startDate').isISO8601(),
  body('endDate').isISO8601(),
  body('candidates').isArray({ min: 2 })
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const electionData = { ...req.body, createdBy: req.admin._id };
    const election = new Election(electionData);
    await election.save();

    res.status(201).json({ success: true, message: 'Election created successfully', data: { election } });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// PUT /api/admin/elections/:id
router.put('/elections/:id', requirePermission('manageElections'), async (req, res) => {
  try {
    const election = await Election.findById(req.params.id);
    if (!election) return res.status(404).json({ success: false, message: 'Election not found' });

    if (election.status === 'active' && req.body.candidates) {
      return res.status(400).json({ success: false, message: 'Cannot modify candidates in an active election' });
    }

    const allowedUpdates = ['title', 'description', 'organizationName', 'startDate', 'endDate',
      'imageUrl', 'bannerUrl', 'isPublic', 'eligibleVoters', 'settings', 'status', 'turnoutTarget'];

    allowedUpdates.forEach(field => {
      if (req.body[field] !== undefined) election[field] = req.body[field];
    });

    // Merge candidate updates WITHOUT resetting voteCount
    // This preserves live vote tallies when admin edits election details
    if (req.body.candidates) {
      const incoming = req.body.candidates;
      const existing = election.candidates;
      election.candidates = incoming.map(inc => {
        // Match by _id if provided, otherwise treat as new candidate
        const found = inc._id
          ? existing.find(e => e._id.toString() === inc._id.toString())
          : null;
        return {
          _id:         found ? found._id         : undefined,
          name:        inc.name,
          party:       inc.party        ?? found?.party,
          description: inc.description  ?? found?.description,
          imageUrl:    inc.imageUrl     ?? found?.imageUrl,
          position:    inc.position     ?? found?.position,
          bio:         inc.bio          ?? found?.bio,
          manifesto:   inc.manifesto    ?? found?.manifesto,
          // ✅ Preserve existing vote count — never reset to 0
          voteCount:   found ? found.voteCount : 0,
        };
      });
    }

    await election.save();
    res.json({ success: true, message: 'Election updated', data: { election } });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// DELETE /api/admin/elections/:id
router.delete('/elections/:id', requirePermission('manageElections'), async (req, res) => {
  try {
    const election = await Election.findById(req.params.id);
    if (!election) return res.status(404).json({ success: false, message: 'Election not found' });

    if (election.status === 'active') {
      return res.status(400).json({ success: false, message: 'Cannot delete an active election. Cancel it first.' });
    }

    // Delete the election (including any votes associated with it)
    await election.deleteOne();
    
    // Also delete all associated votes
    await Vote.deleteMany({ electionId: election._id });
    
    res.json({ success: true, message: 'Election and associated votes deleted successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }

});

// POST /api/admin/elections/:id/cancel
router.post('/elections/:id/cancel', requirePermission('manageElections'), async (req, res) => {
  try {
    const election = await Election.findByIdAndUpdate(
      req.params.id,
      { status: 'cancelled' },
      { new: true }
    );
    if (!election) return res.status(404).json({ success: false, message: 'Election not found' });
    res.json({ success: true, message: 'Election cancelled', data: { election } });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/admin/elections/:id/activate — Resume a cancelled/paused election
// Votes are preserved exactly as-is; only the status changes
router.post('/elections/:id/activate', requirePermission('manageElections'), async (req, res) => {
  try {
    const election = await Election.findById(req.params.id);
    if (!election) return res.status(404).json({ success: false, message: 'Election not found' });

    if (election.status === 'active') {
      return res.status(400).json({ success: false, message: 'Election is already active' });
    }
    if (election.status === 'closed') {
      return res.status(400).json({ success: false, message: 'Closed elections cannot be reactivated' });
    }

    const now = new Date();
    if (now > election.endDate) {
      return res.status(400).json({ success: false, message: 'Cannot reactivate — end date has passed. Update the end date first.' });
    }

    // Use updateOne with $set to bypass pre-save hook date logic
    // This guarantees status is set to active and votes are untouched
    await Election.updateOne(
      { _id: election._id },
      { $set: { status: 'active', updatedAt: new Date() } }
    );

    const updated = await Election.findById(election._id);
    res.json({ success: true, message: 'Election reactivated. All previous votes preserved.', data: { election: updated } });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/admin/elections/:id/votes
router.get('/elections/:id/votes', requirePermission('manageElections'), async (req, res) => {
  try {
    const { page = 1, limit = 50 } = req.query;
    const votes = await Vote.find({ electionId: req.params.id })
      .sort({ timestamp: -1 })
      .skip((page - 1) * limit)
      .limit(Number(limit))
      .select('-voterDIDHash'); // Don't expose hashed DIDs

    const total = await Vote.countDocuments({ electionId: req.params.id });
    res.json({
      success: true,
      data: { votes, pagination: { total, page: Number(page), pages: Math.ceil(total / limit) } }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// ============ USERS MANAGEMENT ============

// GET /api/admin/users
router.get('/users', requirePermission('manageUsers'), async (req, res) => {
  try {
    const { page = 1, limit = 20, search, status } = req.query;
    const query = {};

    if (search) {
      query.$or = [
        { name: { $regex: search, $options: 'i' } },
        { email: { $regex: search, $options: 'i' } },
        { did: { $regex: search, $options: 'i' } }
      ];
    }
    if (status === 'active') query.isActive = true;
    if (status === 'banned') query.isBanned = true;
    if (status === 'inactive') query.isActive = false;

    const total = await User.countDocuments(query);
    const users = await User.find(query)
      .sort({ createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(Number(limit))
      .select('-passwordHash -biometricPublicKey -lockUntil');

    res.json({
      success: true,
      data: {
        users,
        pagination: { total, page: Number(page), pages: Math.ceil(total / limit), limit: Number(limit) }
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/admin/users/:id
router.get('/users/:id', requirePermission('manageUsers'), async (req, res) => {
  try {
    const user = await User.findById(req.params.id).select('-passwordHash -biometricPublicKey');
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });

    // Get vote count for this user
    const blockchainService = require('../services/blockchainService');
    const voteCount = 0; // Can't count without DID hash without knowing it

    res.json({ success: true, data: { user, voteCount } });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/admin/users/:id/ban
router.post('/users/:id/ban', requirePermission('manageUsers'), async (req, res) => {
  try {
    const { reason } = req.body;
    const user = await User.findByIdAndUpdate(
      req.params.id,
      { isBanned: true, banReason: reason || 'Banned by admin', isActive: false },
      { new: true }
    );
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });
    res.json({ success: true, message: 'User banned', data: { user: user.toPublicJSON() } });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/admin/users/:id/unban
router.post('/users/:id/unban', requirePermission('manageUsers'), async (req, res) => {
  try {
    const user = await User.findByIdAndUpdate(
      req.params.id,
      { isBanned: false, banReason: null, isActive: true },
      { new: true }
    );
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });
    res.json({ success: true, message: 'User unbanned', data: { user: user.toPublicJSON() } });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/admin/users/:id/verify
router.post('/users/:id/verify', requirePermission('manageUsers'), async (req, res) => {
  try {
    const user = await User.findByIdAndUpdate(req.params.id, { isVerified: true }, { new: true });
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });
    res.json({ success: true, message: 'User verified', data: { user: user.toPublicJSON() } });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// ============ ADMIN MANAGEMENT ============

// GET /api/admin/admins
router.get('/admins', requirePermission('manageAdmins'), async (req, res) => {
  try {
    const admins = await Admin.find().select('-passwordHash');
    res.json({ success: true, data: { admins } });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/admin/admins
router.post('/admins', requirePermission('manageAdmins'), [
  body('username').notEmpty().trim(),
  body('email').isEmail(),
  body('password').isLength({ min: 8 }),
  body('role').isIn(['admin', 'moderator', 'viewer'])
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const { username, email, password, role, permissions } = req.body;

    const existing = await Admin.findOne({ $or: [{ username }, { email }] });
    if (existing) return res.status(409).json({ success: false, message: 'Username or email already exists' });

    const admin = new Admin({
      username,
      email,
      passwordHash: await bcrypt.hash(password, 12),
      role,
      permissions: permissions || {}
    });
    await admin.save();

    res.status(201).json({ success: true, message: 'Admin created', data: { admin: admin.toPublicJSON() } });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// ============ ANALYTICS ============

// GET /api/admin/analytics
router.get('/analytics', requirePermission('viewAnalytics'), async (req, res) => {
  try {
    const { days = 30 } = req.query;
    const since = new Date(Date.now() - Number(days) * 24 * 60 * 60 * 1000);

    const [
      votesByDay,
      votesByElection,
      userRegistrations,
      votesByNetwork
    ] = await Promise.all([
      Vote.aggregate([
        { $match: { timestamp: { $gte: since } } },
        { $group: { _id: { $dateToString: { format: '%Y-%m-%d', date: '$timestamp' } }, count: { $sum: 1 } } },
        { $sort: { _id: 1 } }
      ]),
      Vote.aggregate([
        { $group: { _id: '$electionId', count: { $sum: 1 } } },
        { $sort: { count: -1 } },
        { $limit: 10 },
        { $lookup: { from: 'elections', localField: '_id', foreignField: '_id', as: 'election' } },
        { $unwind: '$election' },
        { $project: { title: '$election.title', count: 1 } }
      ]),
      User.aggregate([
        { $match: { createdAt: { $gte: since } } },
        { $group: { _id: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt' } }, count: { $sum: 1 } } },
        { $sort: { _id: 1 } }
      ]),
      Vote.aggregate([
        { $group: { _id: '$network', count: { $sum: 1 } } }
      ])
    ]);

    res.json({
      success: true,
      data: { votesByDay, votesByElection, userRegistrations, votesByNetwork }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
