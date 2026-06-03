const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const { body, validationResult } = require('express-validator');
const User = require('../models/User');
const blockchainService = require('../services/blockchainService');
const { authenticateUser } = require('../middleware/auth');

// POST /api/auth/register
// Body: { name, aadharNumber (12 digits), voterIdNumber, email? }
router.post('/register', [
  body('name').notEmpty().trim().isLength({ min: 2, max: 100 }).withMessage('Full name is required (2-100 chars)'),
  body('aadharNumber')
    .notEmpty().withMessage('Aadhar number is required')
    .matches(/^\d{12}$/).withMessage('Aadhar must be exactly 12 digits'),
  body('voterIdNumber')
    .notEmpty().trim().isLength({ min: 6, max: 20 }).withMessage('Voter ID is required'),
  body('email').optional().isEmail().normalizeEmail(),
  body('deviceId').optional().isString(),
  body('devicePlatform').optional().isIn(['ios', 'android', 'web'])
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const { name, aadharNumber, voterIdNumber, email, deviceId, devicePlatform } = req.body;
    const upperVoterId = voterIdNumber.trim().toUpperCase();

    // Uniqueness checks
    const [existingAadhar, existingVoter] = await Promise.all([
      User.findOne({ aadharNumber }),
      User.findOne({ voterIdNumber: upperVoterId })
    ]);
    if (existingAadhar) {
      return res.status(409).json({ success: false, message: 'Aadhar number already registered' });
    }
    if (existingVoter) {
      return res.status(409).json({ success: false, message: 'Voter ID already registered' });
    }
    if (email) {
      const existingEmail = await User.findOne({ email });
      if (existingEmail) {
        return res.status(409).json({ success: false, message: 'Email already registered' });
      }
    }

    // Generate blockchain identity
    const [did, keyPair] = await Promise.all([
      blockchainService.generateDID(),
      blockchainService.generateKeyPair()
    ]);

    const user = new User({
      did,
      publicKey: keyPair.publicKey,
      name,
      aadharNumber,
      voterIdNumber: upperVoterId,
      email,
      deviceId,
      devicePlatform,
      isActive: true,
      biometricEnabled: false  // biometric disabled
    });

    await user.save();

    const token = jwt.sign(
      { userId: user._id, did: user.did },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
    );

    res.status(201).json({
      success: true,
      message: 'Account created successfully',
      data: {
        token,
        user: user.toPublicJSON(),
        privateKey: keyPair.privateKey
      }
    });
  } catch (error) {
    console.error('Register error:', error);
    res.status(500).json({ success: false, message: 'Registration failed', error: error.message });
  }
});

// POST /api/auth/login
// Body: { voterIdNumber } — captcha is validated on the Flutter side
router.post('/login', [
  body('voterIdNumber').optional().isString().trim(),
  body('did').optional().isString(),
  body('email').optional().isEmail(),
  body('password').optional().isString(),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const { voterIdNumber, did, email, password } = req.body;

    // At least one identifier must be provided
    if (!voterIdNumber && !did && !email) {
      return res.status(400).json({ success: false, message: 'Voter ID is required to login' });
    }

    let user;
    if (voterIdNumber) {
      user = await User.findOne({ voterIdNumber: voterIdNumber.toUpperCase() });
    } else if (did) {
      user = await User.findOne({ did });
    } else if (email) {
      user = await User.findOne({ email });
    }

    if (!user) {
      return res.status(404).json({ success: false, message: 'Voter ID not found. Please register first.' });
    }

    if (!user.isActive) {
      return res.status(403).json({ success: false, message: 'Account deactivated' });
    }

    if (user.isBanned) {
      return res.status(403).json({ success: false, message: `Account banned: ${user.banReason}` });
    }

    if (user.isLocked()) {
      return res.status(423).json({ success: false, message: 'Account temporarily locked. Try again later.' });
    }

    // VoterID login: finding the unique record IS authentication (captcha handled on frontend)
    // Password login still supported as fallback
    let authenticated = false;
    if (voterIdNumber) {
      authenticated = true;  // identity confirmed by unique voterIdNumber lookup
    } else if (password) {
      authenticated = await user.comparePassword(password);
    } else {
      authenticated = true;  // DID or email lookup without password = identity-based auth
    }

    if (!authenticated) {
      user.loginAttempts = (user.loginAttempts || 0) + 1;
      if (user.loginAttempts >= 5) {
        user.lockUntil = new Date(Date.now() + 15 * 60 * 1000);
      }
      await user.save();
      return res.status(401).json({ success: false, message: 'Invalid credentials' });
    }

    user.loginAttempts = 0;
    user.lockUntil = undefined;
    user.lastLogin = new Date();
    await user.save();

    const token = jwt.sign(
      { userId: user._id, did: user.did },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
    );

    res.json({
      success: true,
      message: 'Login successful',
      data: { token, user: user.toPublicJSON() }
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ success: false, message: 'Login failed', error: error.message });
  }
});

// POST /api/auth/refresh
router.post('/refresh', authenticateUser, async (req, res) => {
  try {
    const token = jwt.sign(
      { userId: req.user._id, did: req.user.did },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
    );
    res.json({ success: true, data: { token } });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/auth/me
router.get('/me', authenticateUser, async (req, res) => {
  res.json({ success: true, data: { user: req.user.toPublicJSON() } });
});

// POST /api/auth/biometric/login
// Called when user logs in via fingerprint. Verifies biometricEnabled on account.
router.post('/biometric/login', [
  body('voterIdNumber').notEmpty().isString().trim(),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const { voterIdNumber } = req.body;
    const user = await User.findOne({ voterIdNumber: voterIdNumber.toUpperCase() });

    if (!user) {
      return res.status(404).json({ success: false, message: 'Voter ID not found.' });
    }
    if (!user.isActive) {
      return res.status(403).json({ success: false, message: 'Account deactivated.' });
    }
    if (!user.biometricEnabled) {
      return res.status(403).json({
        success: false,
        message: 'Biometric login is not enabled for this account. '
               + 'Log in with Voter ID + captcha and enable it from your profile.'
      });
    }

    user.loginAttempts = 0;
    user.lastLogin = new Date();
    await user.save();

    const token = jwt.sign(
      { userId: user._id, did: user.did },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
    );

    res.json({ success: true, message: 'Biometric login successful', data: { token, user: user.toPublicJSON() } });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/auth/biometric/enable
// Called after local fingerprint scan succeeds — marks biometricEnabled = true on user
router.post('/biometric/enable', authenticateUser, async (req, res) => {
  try {
    const { biometricPublicKey } = req.body;

    await User.findByIdAndUpdate(req.user._id, {
      biometricEnabled: true,
      ...(biometricPublicKey ? { biometricPublicKey } : {}),
    });

    res.json({ success: true, message: 'Biometric authentication enabled.' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/auth/biometric/disable
router.post('/biometric/disable', authenticateUser, async (req, res) => {
  try {
    await User.findByIdAndUpdate(req.user._id, {
      biometricEnabled: false,
      biometricPublicKey: null,
    });
    res.json({ success: true, message: 'Biometric authentication disabled.' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// ═══════════════════════════════════════════════════════════════
// WebAuthn (Web Fingerprint) Routes
// Used by the Flutter web app and standalone web pages
// ═══════════════════════════════════════════════════════════════

const crypto = require('crypto');

// Generate a random challenge for WebAuthn registration or authentication
function generateChallenge() {
  return crypto.randomBytes(32).toString('base64url');
}

// In-memory challenge store (replace with Redis in production)
const challengeStore = new Map();

// POST /api/auth/webauthn/register/challenge
// Returns a challenge for the client to sign with their authenticator
router.post('/webauthn/register/challenge', authenticateUser, async (req, res) => {
  try {
    const challenge = generateChallenge();
    challengeStore.set(`reg_${req.user._id}`, { challenge, expires: Date.now() + 5 * 60 * 1000 });
    res.json({
      success: true,
      data: {
        challenge,
        userId: req.user._id.toString(),
        userName: req.user.name,
        rpName: 'OmniVote',
        rpId: req.headers.origin ? new URL(req.headers.origin).hostname : 'localhost',
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/auth/webauthn/register/verify
// Verifies the signed challenge and stores the credential
router.post('/webauthn/register/verify', authenticateUser, async (req, res) => {
  try {
    const { credentialId, publicKey, clientDataJSON, attestationObject } = req.body;
    if (!credentialId || !publicKey) {
      return res.status(400).json({ success: false, message: 'Missing credential data' });
    }

    const stored = challengeStore.get(`reg_${req.user._id}`);
    if (!stored || Date.now() > stored.expires) {
      return res.status(400).json({ success: false, message: 'Challenge expired. Please try again.' });
    }
    challengeStore.delete(`reg_${req.user._id}`);

    // Store WebAuthn credential on user
    await User.findByIdAndUpdate(req.user._id, {
      biometricEnabled: true,
      biometricPublicKey: publicKey,
      webAuthnCredentialId: credentialId,
    });

    res.json({ success: true, message: 'Fingerprint registered successfully.' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/auth/webauthn/login/challenge
// Returns a challenge for authentication (no auth required — user identifying themselves)
router.post('/webauthn/login/challenge', [
  body('voterIdNumber').notEmpty().isString().trim(),
], async (req, res) => {
  try {
    const { voterIdNumber } = req.body;
    const user = await User.findOne({ voterIdNumber: voterIdNumber.toUpperCase() });
    if (!user) return res.status(404).json({ success: false, message: 'Voter ID not found.' });
    if (!user.biometricEnabled || !user.webAuthnCredentialId) {
      return res.status(403).json({ success: false, message: 'WebAuthn not registered for this account.' });
    }

    const challenge = generateChallenge();
    challengeStore.set(`auth_${user._id}`, { challenge, expires: Date.now() + 5 * 60 * 1000 });

    res.json({
      success: true,
      data: {
        challenge,
        credentialId: user.webAuthnCredentialId,
        rpId: req.headers.origin ? new URL(req.headers.origin).hostname : 'localhost',
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/auth/webauthn/login/verify
// Verifies the WebAuthn assertion and logs the user in
router.post('/webauthn/login/verify', [
  body('voterIdNumber').notEmpty().isString().trim(),
  body('credentialId').notEmpty().isString(),
  body('clientDataJSON').notEmpty().isString(),
  body('signature').notEmpty().isString(),
], async (req, res) => {
  try {
    const { voterIdNumber, credentialId, clientDataJSON, signature } = req.body;
    const user = await User.findOne({ voterIdNumber: voterIdNumber.toUpperCase() });
    if (!user) return res.status(404).json({ success: false, message: 'Voter ID not found.' });

    const stored = challengeStore.get(`auth_${user._id}`);
    if (!stored || Date.now() > stored.expires) {
      return res.status(400).json({ success: false, message: 'Challenge expired.' });
    }

    // Verify credentialId matches
    if (user.webAuthnCredentialId !== credentialId) {
      return res.status(401).json({ success: false, message: 'Credential mismatch.' });
    }

    // Verify clientDataJSON contains the challenge
    try {
      const clientData = JSON.parse(Buffer.from(clientDataJSON, 'base64url').toString());
      if (clientData.challenge !== stored.challenge) {
        return res.status(401).json({ success: false, message: 'Challenge verification failed.' });
      }
    } catch {
      return res.status(401).json({ success: false, message: 'Invalid client data.' });
    }
    challengeStore.delete(`auth_${user._id}`);

    user.lastLogin = new Date();
    await user.save();

    const token = jwt.sign(
      { userId: user._id, did: user.did },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
    );

    res.json({ success: true, message: 'WebAuthn login successful', data: { token, user: user.toPublicJSON() } });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/auth/webauthn/vote/challenge
// Challenge for vote confirmation via WebAuthn (requires auth)
router.post('/webauthn/vote/challenge', authenticateUser, async (req, res) => {
  try {
    if (!req.user.biometricEnabled || !req.user.webAuthnCredentialId) {
      return res.status(403).json({ success: false, message: 'WebAuthn not registered.' });
    }
    const challenge = generateChallenge();
    challengeStore.set(`vote_${req.user._id}`, { challenge, expires: Date.now() + 5 * 60 * 1000 });
    res.json({
      success: true,
      data: {
        challenge,
        credentialId: req.user.webAuthnCredentialId,
        rpId: req.headers.origin ? new URL(req.headers.origin).hostname : 'localhost',
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/auth/webauthn/vote/verify
// Verifies fingerprint before vote is cast
router.post('/webauthn/vote/verify', authenticateUser, [
  body('credentialId').notEmpty().isString(),
  body('clientDataJSON').notEmpty().isString(),
  body('signature').notEmpty().isString(),
], async (req, res) => {
  try {
    const { credentialId, clientDataJSON } = req.body;
    const stored = challengeStore.get(`vote_${req.user._id}`);
    if (!stored || Date.now() > stored.expires) {
      return res.status(400).json({ success: false, message: 'Challenge expired.' });
    }
    if (req.user.webAuthnCredentialId !== credentialId) {
      return res.status(401).json({ success: false, message: 'Credential mismatch.' });
    }
    try {
      const clientData = JSON.parse(Buffer.from(clientDataJSON, 'base64url').toString());
      if (clientData.challenge !== stored.challenge) {
        return res.status(401).json({ success: false, message: 'Challenge verification failed.' });
      }
    } catch {
      return res.status(401).json({ success: false, message: 'Invalid client data.' });
    }
    challengeStore.delete(`vote_${req.user._id}`);
    res.json({ success: true, message: 'WebAuthn vote verification successful.' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET /api/auth/webauthn/enrolled — Admin: list all users with WebAuthn enrolled
router.get('/webauthn/enrolled', authenticateUser, async (req, res) => {
  try {
    const users = await User.find({ biometricEnabled: true, webAuthnCredentialId: { $exists: true, $ne: null } })
      .select('name voterIdNumber did biometricEnabled createdAt lastLogin webAuthnCredentialId')
      .lean();
    res.json({ success: true, data: { users, total: users.length } });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});


// POST /api/auth/webauthn/enroll-for-user
// Admin: generate challenge on behalf of a specific user (for fingerprint machine)
router.post('/webauthn/enroll-for-user', authenticateUser, [
  body('voterIdNumber').notEmpty().isString().trim(),
], async (req, res) => {
  try {
    const { voterIdNumber } = req.body;
    const target = await User.findOne({ voterIdNumber: voterIdNumber.toUpperCase() });
    if (!target) return res.status(404).json({ success: false, message: 'User not found.' });

    const challenge = generateChallenge();
    challengeStore.set('reg_' + target._id, { challenge, expires: Date.now() + 5 * 60 * 1000 });

    res.json({
      success: true,
      data: {
        challenge,
        userId: target._id.toString(),
        userName: target.name,
        rpName: 'OmniVote',
        rpId: req.headers.origin ? new URL(req.headers.origin).hostname : 'localhost',
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/auth/webauthn/enroll-for-user/verify
// Admin: store fingerprint credential for target user
router.post('/webauthn/enroll-for-user/verify', authenticateUser, [
  body('voterIdNumber').notEmpty().isString().trim(),
  body('credentialId').notEmpty().isString(),
], async (req, res) => {
  try {
    const { voterIdNumber, credentialId, publicKey, clientDataJSON } = req.body;
    const target = await User.findOne({ voterIdNumber: voterIdNumber.toUpperCase() });
    if (!target) return res.status(404).json({ success: false, message: 'User not found.' });

    const stored = challengeStore.get('reg_' + target._id);
    if (!stored || Date.now() > stored.expires) {
      return res.status(400).json({ success: false, message: 'Challenge expired.' });
    }
    challengeStore.delete('reg_' + target._id);

    await User.findByIdAndUpdate(target._id, {
      biometricEnabled: true,
      biometricPublicKey: publicKey || '',
      webAuthnCredentialId: credentialId,
    });

    res.json({ success: true, message: 'Fingerprint enrolled for ' + voterIdNumber });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/auth/webauthn/revoke
// Admin: remove fingerprint enrollment from user
router.post('/webauthn/revoke', authenticateUser, [
  body('voterIdNumber').notEmpty().isString().trim(),
], async (req, res) => {
  try {
    const { voterIdNumber } = req.body;
    await User.findOneAndUpdate(
      { voterIdNumber: voterIdNumber.toUpperCase() },
      { biometricEnabled: false, webAuthnCredentialId: null, biometricPublicKey: null }
    );
    res.json({ success: true, message: 'Fingerprint revoked for ' + voterIdNumber });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});


module.exports = router;
