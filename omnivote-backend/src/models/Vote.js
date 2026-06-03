const mongoose = require('mongoose');

const voteSchema = new mongoose.Schema({
  electionId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Election',
    required: true,
    index: true
  },
  candidateId: {
    type: mongoose.Schema.Types.ObjectId,
    required: true
  },
  // We store the DID (not userId) to maintain anonymity while preventing double-voting
  voterDIDHash: {
    type: String,
    required: true,
    index: true
  },
  transactionHash: {
    type: String,
    required: true,
    unique: true
  },
  status: {
    type: String,
    enum: ['pending', 'confirmed', 'failed', 'verified'],
    default: 'pending'
  },
  zkProof: String,
  blockNumber: Number,
  confirmationBlocks: {
    type: Number,
    default: 0
  },
  ipAddress: String,
  deviceId: String,
  timestamp: {
    type: Date,
    default: Date.now,
    index: true
  },
  verifiedAt: Date,
  network: {
    type: String,
    default: 'Solana Mainnet'
  },
  fee: {
    type: Number,
    default: 0.00025
  }
});

// Compound index to prevent double voting
voteSchema.index({ electionId: 1, voterDIDHash: 1 }, { unique: true });

module.exports = mongoose.model('Vote', voteSchema);
