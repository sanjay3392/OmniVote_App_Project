const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const bcrypt = require('bcryptjs');
const User = require('../models/User');
const { authenticateUser } = require('../middleware/auth');

// GET /api/users/profile
router.get('/profile', authenticateUser, async (req, res) => {
  res.json({ success: true, data: { user: req.user.toPublicJSON() } });
});

// PUT /api/users/profile
router.put('/profile', authenticateUser, [
  body('name').optional().trim().isLength({ min: 2, max: 100 }),
  body('email').optional().isEmail().normalizeEmail()
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const { name, email } = req.body;
    const updates = {};

    if (name !== undefined) updates.name = name;
    if (email !== undefined) {
      const existing = await User.findOne({ email, _id: { $ne: req.user._id } });
      if (existing) {
        return res.status(409).json({ success: false, message: 'Email already in use' });
      }
      updates.email = email;
    }

    const user = await User.findByIdAndUpdate(req.user._id, updates, { new: true });
    res.json({ success: true, data: { user: user.toPublicJSON() } });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// PUT /api/users/password
router.put('/password', authenticateUser, [
  body('currentPassword').notEmpty(),
  body('newPassword').isLength({ min: 8 })
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const { currentPassword, newPassword } = req.body;
    const valid = await req.user.comparePassword(currentPassword);
    if (!valid) {
      return res.status(401).json({ success: false, message: 'Current password incorrect' });
    }

    req.user.passwordHash = await bcrypt.hash(newPassword, 12);
    await req.user.save();

    res.json({ success: true, message: 'Password updated successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// DELETE /api/users/account
router.delete('/account', authenticateUser, async (req, res) => {
  try {
    await User.findByIdAndUpdate(req.user._id, { isActive: false });
    res.json({ success: true, message: 'Account deactivated successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
