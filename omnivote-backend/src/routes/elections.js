const express = require('express');
const router = express.Router();
const Election = require('../models/Election');
const Vote = require('../models/Vote');
const { authenticateUser } = require('../middleware/auth');

// GET /api/elections - Get all public elections
router.get('/', async (req, res) => {
  try {
    const { status, type, page = 1, limit = 20 } = req.query;
    const query = { isPublic: true };

    if (status) query.status = status;
    if (type) query.type = type;

    // Auto-update statuses
    const now = new Date();
    await Election.updateMany(
      { status: 'pending', startDate: { $lte: now }, endDate: { $gte: now } },
      { $set: { status: 'active' } }
    );
    await Election.updateMany(
      { status: { $in: ['pending', 'active'] }, endDate: { $lt: now } },
      { $set: { status: 'closed' } }
    );

    const total = await Election.countDocuments(query);
    const elections = await Election.find(query)
      .sort({ startDate: -1 })
      .skip((page - 1) * limit)
      .limit(Number(limit))
      .select('-eligibleVoters');

    res.json({
      success: true,
      data: {
        elections,
        pagination: {
          total,
          page: Number(page),
          pages: Math.ceil(total / limit),
          limit: Number(limit)
        }
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/elections/:id - Get single election
router.get('/:id', async (req, res) => {
  try {
    const election = await Election.findById(req.params.id).select('-eligibleVoters');
    if (!election) {
      return res.status(404).json({ success: false, message: 'Election not found' });
    }
    res.json({ success: true, data: { election } });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/elections/:id/results - Get election results
router.get('/:id/results', async (req, res) => {
  try {
    const election = await Election.findById(req.params.id);
    if (!election) {
      return res.status(404).json({ success: false, message: 'Election not found' });
    }

    if (election.status === 'pending') {
      return res.status(403).json({ success: false, message: 'Election has not started yet' });
    }

    // Aggregate votes — include ALL non-failed statuses to avoid missing votes
    // due to status discrepancies between 'pending', 'confirmed', 'verified'
    const voteStats = await Vote.aggregate([
      { $match: { electionId: election._id, status: { $nin: ['failed'] } } },
      { $group: { _id: '$candidateId', count: { $sum: 1 } } }
    ]);

    // Also get total as a safety cross-check using a simple count
    const rawTotal = await Vote.countDocuments({
      electionId: election._id,
      status: { $nin: ['failed'] }
    });

    const aggregatedTotal = voteStats.reduce((sum, s) => sum + s.count, 0);
    // Use whichever is larger — raw count catches any aggregation miss
    const totalVotes = Math.max(aggregatedTotal, rawTotal);

    const results = election.candidates.map(candidate => {
      // Match by both string and ObjectId to handle any storage inconsistency
      const candidateIdStr = candidate._id.toString();
      const stats = voteStats.find(s =>
        s._id && s._id.toString() === candidateIdStr
      );
      const voteCount = stats ? stats.count : 0;
      return {
        candidateId: candidate._id,
        name: candidate.name,
        party: candidate.party,
        imageUrl: candidate.imageUrl || null,
        voteCount,
        percentage: totalVotes > 0
          ? (voteCount / totalVotes * 100).toFixed(2)
          : '0.00'
      };
    });

    results.sort((a, b) => b.voteCount - a.voteCount);

    // Sync stored counters to match aggregation (source of truth)
    // This fixes the home screen live preview which reads candidates[].voteCount
    const needsSync = election.totalVotes !== totalVotes ||
      election.candidates.some(c => {
        const candidateIdStr = c._id.toString();
        const stats = voteStats.find(s => s._id && s._id.toString() === candidateIdStr);
        return c.voteCount !== (stats ? stats.count : 0);
      });

    if (needsSync) {
      const candidateUpdates = {};
      election.candidates.forEach((c, idx) => {
        const candidateIdStr = c._id.toString();
        const stats = voteStats.find(s => s._id && s._id.toString() === candidateIdStr);
        candidateUpdates[`candidates.${idx}.voteCount`] = stats ? stats.count : 0;
      });
      await election.updateOne({ $set: { totalVotes, ...candidateUpdates } });
    }

    res.json({
      success: true,
      data: {
        electionId: election._id,
        title: election.title,
        status: election.status,
        totalVotes,
        turnoutTarget: election.turnoutTarget || null,
        turnoutPct: (election.turnoutTarget && election.turnoutTarget > 0)
          ? (totalVotes / election.turnoutTarget * 100).toFixed(1)
          : null,
        results,
        winner: election.status === 'closed' ? results[0] : null
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/elections/:id/check-eligibility - Check if user can vote
router.post('/:id/check-eligibility', authenticateUser, async (req, res) => {
  try {
    const election = await Election.findById(req.params.id);
    if (!election) {
      return res.status(404).json({ success: false, message: 'Election not found' });
    }

    if (!election.isActive) {
      return res.json({ success: true, data: { eligible: false, reason: 'Election is not active' } });
    }

    // Check if eligible voters list exists and user is in it
    if (election.eligibleVoters.length > 0) {
      if (!election.eligibleVoters.includes(req.user.did)) {
        return res.json({ success: true, data: { eligible: false, reason: 'Not in eligible voters list' } });
      }
    }

    // Check if already voted
    const blockchainService = require('../services/blockchainService');
    const voterDIDHash = blockchainService.hashVoterDID(req.user.did);
    const existingVote = await Vote.findOne({
      electionId: election._id,
      voterDIDHash
    });

    if (existingVote) {
      return res.json({
        success: true,
        data: {
          eligible: false,
          reason: 'Already voted',
          voteReceipt: { transactionHash: existingVote.transactionHash, timestamp: existingVote.timestamp }
        }
      });
    }

    res.json({ success: true, data: { eligible: true, reason: null } });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
