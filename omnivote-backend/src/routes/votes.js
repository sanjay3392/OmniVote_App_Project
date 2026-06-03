const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const Vote = require('../models/Vote');
const Election = require('../models/Election');
const blockchainService = require('../services/blockchainService');
const { authenticateUser } = require('../middleware/auth');

// POST /api/votes/cast - Cast a vote
router.post('/cast', authenticateUser, [
  body('electionId').notEmpty().isString(),
  body('candidateId').notEmpty().isString(),
  body('biometricVerified').isBoolean()
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const { electionId, candidateId, biometricVerified } = req.body;

    // Validate election
    const election = await Election.findById(electionId);
    if (!election) {
      return res.status(404).json({ success: false, message: 'Election not found' });
    }

    if (!election.isActive) {
      return res.status(400).json({ success: false, message: 'Election is not currently active' });
    }

    // Validate candidate
    const candidate = election.candidates.id(candidateId);
    if (!candidate) {
      return res.status(404).json({ success: false, message: 'Candidate not found' });
    }

    // Check biometric requirement
    // 1. If election requires biometric — biometricVerified must be true
    if (election.settings.requireBiometric && !biometricVerified) {
      return res.status(403).json({ success: false, message: 'Biometric verification required for this election.' });
    }
    // 2. If this user has biometricEnabled on their account — they must always verify
    if (req.user.biometricEnabled && !biometricVerified) {
      return res.status(403).json({ success: false, message: 'Your account requires biometric verification to vote.' });
    }

    // Hash voter DID for anonymous storage
    const voterDIDHash = blockchainService.hashVoterDID(req.user.did);

    // Check double voting
    const existingVote = await Vote.findOne({ electionId, voterDIDHash });
    if (existingVote) {
      return res.status(409).json({
        success: false,
        message: 'You have already voted in this election',
        data: { transactionHash: existingVote.transactionHash }
      });
    }

    // Check eligibility
    if (election.eligibleVoters.length > 0 && !election.eligibleVoters.includes(req.user.did)) {
      return res.status(403).json({ success: false, message: 'You are not eligible to vote in this election' });
    }

    // Generate ZK proof
    let zkProof = null;
    if (election.settings.enableZKProof) {
      zkProof = await blockchainService.generateZKProof({
        voterId: req.user.did,
        electionId
      });
    }

    // Cast vote on blockchain
    const blockchainResult = await blockchainService.castVote({
      electionId,
      candidateId,
      voterId: req.user.did,
      zkProof
    });

    // Save vote to database
    const vote = new Vote({
      electionId,
      candidateId,
      voterDIDHash,
      transactionHash: blockchainResult.transactionHash,
      status: 'confirmed',
      zkProof,
      blockNumber: blockchainResult.blockNumber,
      confirmationBlocks: 3,
      network: blockchainResult.network,
      fee: blockchainResult.fee,
      ipAddress: req.ip,
      deviceId: req.user.deviceId
    });

    await vote.save();

    // Update election vote counts
    await Election.findByIdAndUpdate(electionId, {
      $inc: {
        totalVotes: 1,
        [`candidates.${election.candidates.findIndex(c => c._id.toString() === candidateId)}.voteCount`]: 1
      }
    });

    res.status(201).json({
      success: true,
      message: 'Vote cast successfully',
      data: {
        voteReceipt: {
          id: vote._id,
          transactionHash: vote.transactionHash,
          electionId,
          candidateName: candidate.name,
          timestamp: vote.timestamp,
          status: vote.status,
          zkProof: vote.zkProof,
          blockNumber: vote.blockNumber,
          network: vote.network,
          fee: vote.fee
        }
      }
    });
  } catch (error) {
    if (error.code === 11000) {
      return res.status(409).json({ success: false, message: 'You have already voted in this election' });
    }
    console.error('Vote cast error:', error);
    res.status(500).json({ success: false, message: 'Failed to cast vote', error: error.message });
  }
});

// GET /api/votes/receipt/:transactionHash - Get vote receipt
router.get('/receipt/:transactionHash', authenticateUser, async (req, res) => {
  try {
    const vote = await Vote.findOne({ transactionHash: req.params.transactionHash });
    if (!vote) {
      return res.status(404).json({ success: false, message: 'Vote receipt not found' });
    }

    const election = await Election.findById(vote.electionId);
    const candidate = election?.candidates.id(vote.candidateId);

    // Get live blockchain confirmation
    const blockchainDetails = await blockchainService.getTransactionDetails(vote.transactionHash);

    res.json({
      success: true,
      data: {
        vote: {
          id: vote._id,
          transactionHash: vote.transactionHash,
          status: vote.status,
          timestamp: vote.timestamp,
          zkProof: vote.zkProof,
          blockNumber: vote.blockNumber,
          confirmationBlocks: blockchainDetails.confirmations || vote.confirmationBlocks,
          network: vote.network,
          fee: vote.fee
        },
        election: election ? { id: election._id, title: election.title, status: election.status } : null,
        candidate: candidate ? { id: candidate._id, name: candidate.name, party: candidate.party } : null,
        confirmed: (blockchainDetails.confirmations || 3) >= 3
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/votes/verify/:transactionHash - Public verification
router.get('/verify/:transactionHash', async (req, res) => {
  try {
    const vote = await Vote.findOne({ transactionHash: req.params.transactionHash });
    if (!vote) {
      return res.status(404).json({ success: false, message: 'Transaction not found on record' });
    }

    const blockchainDetails = await blockchainService.verifyTransaction(vote.transactionHash);

    res.json({
      success: true,
      data: {
        valid: true,
        transactionHash: vote.transactionHash,
        status: blockchainDetails.status,
        timestamp: vote.timestamp,
        confirmationBlocks: blockchainDetails.confirmationBlocks,
        network: vote.network,
        zkProofPresent: !!vote.zkProof
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/votes/my-votes - Get current user's vote history
router.get('/my-votes', authenticateUser, async (req, res) => {
  try {
    const voterDIDHash = blockchainService.hashVoterDID(req.user.did);
    const votes = await Vote.find({ voterDIDHash }).sort({ timestamp: -1 });

    const enrichedVotes = await Promise.all(votes.map(async (vote) => {
      const election = await Election.findById(vote.electionId).select('title status type organizationName');
      return {
        id: vote._id,
        transactionHash: vote.transactionHash,
        status: vote.status,
        timestamp: vote.timestamp,
        network: vote.network,
        election: election || null
      };
    }));

    res.json({ success: true, data: { votes: enrichedVotes } });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
