const mongoose = require('mongoose');

const candidateSchema = new mongoose.Schema({
  name: { type: String, required: true },
  party: String,
  description: String,
  imageUrl: String,
  voteCount: { type: Number, default: 0 },
  position: String,
  bio: String,
  manifesto: String
}, { _id: true });

const electionSchema = new mongoose.Schema({
  title: {
    type: String,
    required: true,
    trim: true
  },
  description: {
    type: String,
    required: true
  },
  organizationName: {
    type: String,
    required: true
  },
  type: {
    type: String,
    enum: ['general', 'presidential', 'parliamentary', 'corporate', 'dao', 'referendum'],
    default: 'general'
  },
  status: {
    type: String,
    enum: ['pending', 'active', 'closed', 'cancelled'],
    default: 'pending'
  },
  startDate: {
    type: Date,
    required: true
  },
  endDate: {
    type: Date,
    required: true
  },
  candidates: [candidateSchema],
  totalVotes: {
    type: Number,
    default: 0
  },
  // Optional: total eligible voters — used to compute turnout %
  turnoutTarget: {
    type: Number,
    default: null
  },
  imageUrl: String,
  bannerUrl: String,
  isPublic: {
    type: Boolean,
    default: true
  },
  // Eligible voters (DIDs) - empty means all registered users
  eligibleVoters: [String],
  // Blockchain contract address
  contractAddress: String,
  // Settings
  settings: {
    requireBiometric: { type: Boolean, default: true },
    allowAnonymous: { type: Boolean, default: false },
    maxVotesPerUser: { type: Number, default: 1 },
    enableZKProof: { type: Boolean, default: true }
  },
  createdBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Admin'
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

electionSchema.pre('save', function(next) {
  this.updatedAt = new Date();
  const now = new Date();

  // Only auto-manage status for pending/closed transitions
  // Never override an explicit admin status change (active/cancelled)
  if (this.isModified('status')) {
    // Admin explicitly set status — respect it, just enforce closed on expired
    if (this.status !== 'cancelled' && now > this.endDate) {
      this.status = 'closed';
    }
  } else {
    // No explicit status change — auto-transition based on dates
    if (this.status === 'cancelled') {
      // frozen — do nothing
    } else if (now > this.endDate) {
      this.status = 'closed';
    } else if (now >= this.startDate && this.status === 'pending') {
      this.status = 'active';
    }
  }
  next();
});

electionSchema.virtual('isActive').get(function() {
  const now = new Date();
  return this.status === 'active' && now >= this.startDate && now <= this.endDate;
});

electionSchema.virtual('hasEnded').get(function() {
  return new Date() > this.endDate || this.status === 'closed';
});

electionSchema.set('toJSON', { virtuals: true });

module.exports = mongoose.model('Election', electionSchema);
