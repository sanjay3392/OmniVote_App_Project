const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const adminSchema = new mongoose.Schema({
  username: {
    type: String,
    required: true,
    unique: true,
    trim: true
  },
  email: {
    type: String,
    required: true,
    unique: true,
    lowercase: true
  },
  passwordHash: {
    type: String,
    required: true
  },
  role: {
    type: String,
    enum: ['super_admin', 'admin', 'moderator', 'viewer'],
    default: 'admin'
  },
  permissions: {
    manageElections: { type: Boolean, default: true },
    manageUsers: { type: Boolean, default: true },
    viewAnalytics: { type: Boolean, default: true },
    manageAdmins: { type: Boolean, default: false },
    systemSettings: { type: Boolean, default: false }
  },
  isActive: {
    type: Boolean,
    default: true
  },
  lastLogin: Date,
  twoFactorEnabled: {
    type: Boolean,
    default: false
  },
  createdAt: {
    type: Date,
    default: Date.now
  },
  updatedAt: {
    type: Date,
    default: Date.now
  }
});

adminSchema.pre('save', async function(next) {
  this.updatedAt = new Date();
  if (this.isModified('passwordHash') && !this.passwordHash.startsWith('$2')) {
    this.passwordHash = await bcrypt.hash(this.passwordHash, 12);
  }
  next();
});

adminSchema.methods.comparePassword = async function(password) {
  return bcrypt.compare(password, this.passwordHash);
};

adminSchema.methods.toPublicJSON = function() {
  return {
    id: this._id,
    username: this.username,
    email: this.email,
    role: this.role,
    permissions: this.permissions,
    isActive: this.isActive,
    lastLogin: this.lastLogin,
    createdAt: this.createdAt
  };
};

module.exports = mongoose.model('Admin', adminSchema);
