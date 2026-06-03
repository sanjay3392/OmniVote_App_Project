const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userSchema = new mongoose.Schema({
  did: {
    type: String,
    required: true,
    unique: true,
    index: true
  },
  publicKey: {
    type: String,
    required: true,
    unique: true
  },
  name: {
    type: String,
    trim: true
  },
  // Aadhar stored as string to preserve leading zeros; digits only
  aadharNumber: {
    type: String,
    unique: true,
    sparse: true,
    index: true,
    match: [/^\d{12}$/, 'Aadhar number must be exactly 12 digits']
  },
  // Voter ID e.g. ABC1234567 — stored uppercase
  voterIdNumber: {
    type: String,
    unique: true,
    sparse: true,
    index: true
  },
  email: {
    type: String,
    trim: true,
    lowercase: true,
    sparse: true,
    index: true
  },
  passwordHash: {
    type: String
  },
  biometricEnabled: {
    type: Boolean,
    default: false
  },
  biometricPublicKey: {
    type: String
  },
  webAuthnCredentialId: {
    type: String,
    sparse: true
  },
  isVerified: {
    type: Boolean,
    default: false
  },
  isActive: {
    type: Boolean,
    default: true
  },
  isBanned: {
    type: Boolean,
    default: false
  },
  banReason: String,
  lastLogin: Date,
  loginAttempts: {
    type: Number,
    default: 0
  },
  lockUntil: Date,
  deviceId: String,
  devicePlatform: {
    type: String,
    enum: ['ios', 'android', 'web']
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

userSchema.pre('save', function(next) {
  this.updatedAt = new Date();
  // Always uppercase voterIdNumber before save
  if (this.voterIdNumber) {
    this.voterIdNumber = this.voterIdNumber.toUpperCase();
  }
  next();
});

userSchema.methods.comparePassword = async function(password) {
  if (!this.passwordHash) return false;
  return bcrypt.compare(password, this.passwordHash);
};

userSchema.methods.isLocked = function() {
  return !!(this.lockUntil && this.lockUntil > Date.now());
};

userSchema.methods.toPublicJSON = function() {
  return {
    id: this._id,
    did: this.did,
    publicKey: this.publicKey,
    name: this.name,
    voterIdNumber: this.voterIdNumber,
    email: this.email,
    biometricEnabled: this.biometricEnabled,
    isVerified: this.isVerified,
    isActive: this.isActive,
    lastLogin: this.lastLogin,
    createdAt: this.createdAt
  };
};

module.exports = mongoose.model('User', userSchema);
