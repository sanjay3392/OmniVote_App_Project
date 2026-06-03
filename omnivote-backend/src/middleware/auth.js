const jwt = require('jsonwebtoken');
const User = require('../models/User');
const Admin = require('../models/Admin');

const authenticateUser = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ success: false, message: 'Authorization token required' });
    }

    const token = authHeader.substring(7);
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    const user = await User.findById(decoded.userId);
    if (!user) return res.status(401).json({ success: false, message: 'User not found' });
    if (!user.isActive) return res.status(403).json({ success: false, message: 'Account deactivated' });
    if (user.isBanned) return res.status(403).json({ success: false, message: `Account banned: ${user.banReason}` });

    req.user = user;
    next();
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({ success: false, message: 'Token expired' });
    }
    return res.status(401).json({ success: false, message: 'Invalid token' });
  }
};

const authenticateAdmin = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ success: false, message: 'Admin token required' });
    }

    const token = authHeader.substring(7);
    const decoded = jwt.verify(token, process.env.ADMIN_JWT_SECRET || process.env.JWT_SECRET);

    const admin = await Admin.findById(decoded.adminId);
    if (!admin) return res.status(401).json({ success: false, message: 'Admin not found' });
    if (!admin.isActive) return res.status(403).json({ success: false, message: 'Admin account deactivated' });

    req.admin = admin;
    next();
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({ success: false, message: 'Admin token expired' });
    }
    return res.status(401).json({ success: false, message: 'Invalid admin token' });
  }
};

const requirePermission = (permission) => {
  return (req, res, next) => {
    if (!req.admin) return res.status(401).json({ success: false, message: 'Unauthorized' });
    if (req.admin.role === 'super_admin') return next();
    if (!req.admin.permissions[permission]) {
      return res.status(403).json({ success: false, message: 'Insufficient permissions' });
    }
    next();
  };
};

module.exports = { authenticateUser, authenticateAdmin, requirePermission };
