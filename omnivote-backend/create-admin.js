/**
 * create-admin.js  —  Drop this in your backend root and run:
 *   node create-admin.js
 *
 * Directly inserts the admin document into MongoDB using the raw
 * db.collection() API — bypasses all model/schema hook issues.
 */

require('dotenv').config();
const mongoose = require('mongoose');
const bcrypt   = require('bcryptjs');

async function main() {
  // 1. Validate .env
  const uri = process.env.MONGODB_URI || '';
  if (!uri || uri.includes('<username>') || uri.includes('<password>')) {
    console.error('\n❌  MONGODB_URI in your .env still has placeholders.');
    console.error('    Replace <username> and <password> with your real Atlas credentials.\n');
    process.exit(1);
  }

  // 2. Connect
  console.log('\n🔌  Connecting to MongoDB Atlas...');
  await mongoose.connect(uri);
  console.log('✅  Connected to:', mongoose.connection.host, '\n');

  const db = mongoose.connection.db;

  // 3. Create / reset admin
  const ADMIN_USERNAME = process.env.ADMIN_USERNAME || 'admin';
  const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'Admin@OmniVote2024!';
  const ADMIN_EMAIL    = process.env.ADMIN_EMAIL    || 'admin@omnivote.io';

  const hash = await bcrypt.hash(ADMIN_PASSWORD, 12);
  const admins = db.collection('admins');
  const existing = await admins.findOne({ username: ADMIN_USERNAME });

  if (existing) {
    await admins.updateOne(
      { username: ADMIN_USERNAME },
      { $set: { passwordHash: hash, isActive: true, updatedAt: new Date() } }
    );
    console.log(`✅  Admin "${ADMIN_USERNAME}" found — password reset to: ${ADMIN_PASSWORD}`);
  } else {
    await admins.insertOne({
      username: ADMIN_USERNAME,
      email: ADMIN_EMAIL,
      passwordHash: hash,
      role: 'super_admin',
      permissions: {
        manageElections: true,
        manageUsers: true,
        viewAnalytics: true,
        manageAdmins: true,
        systemSettings: true
      },
      isActive: true,
      createdAt: new Date(),
      updatedAt: new Date()
    });
    console.log(`✅  Admin "${ADMIN_USERNAME}" created!`);
  }

  // 4. Seed elections if empty
  const elections = db.collection('elections');
  const electionCount = await elections.countDocuments();

  if (electionCount === 0) {
    await elections.insertMany([
      {
        title: '2026 Presidential Election',
        description: 'Cast your vote for the next President. Secured on Solana blockchain.',
        organizationName: 'Federal Election Commission',
        type: 'presidential',
        status: 'active',
        startDate: new Date(Date.now() - 24 * 60 * 60 * 1000),
        endDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
        totalVotes: 0,
        isPublic: true,
        eligibleVoters: [],
        settings: { requireBiometric: false, allowAnonymous: false, enableZKProof: false, maxVotesPerUser: 1 },
        candidates: [
          { name: 'John Smith',    party: 'Democratic Party', description: 'Progressive leader with 20 years of experience', voteCount: 0 },
          { name: 'Sarah Johnson', party: 'Republican Party', description: 'Conservative advocate for economic growth',       voteCount: 0 }
        ],
        createdAt: new Date(),
        updatedAt: new Date()
      },
      {
        title: 'City Council Election',
        description: 'Vote for your local city council representative.',
        organizationName: 'City of Springfield',
        type: 'general',
        status: 'active',
        startDate: new Date(Date.now() - 12 * 60 * 60 * 1000),
        endDate: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
        totalVotes: 0,
        isPublic: true,
        eligibleVoters: [],
        settings: { requireBiometric: false, allowAnonymous: false, enableZKProof: false, maxVotesPerUser: 1 },
        candidates: [
          { name: 'Michael Davis', description: 'Infrastructure and community development', voteCount: 0 },
          { name: 'Emma Wilson',   description: 'Education and local business champion',    voteCount: 0 }
        ],
        createdAt: new Date(),
        updatedAt: new Date()
      }
    ]);
    console.log('✅  2 sample elections seeded!');
  } else {
    console.log(`⏭️   ${electionCount} election(s) already exist — skipping.`);
  }

  // 5. Verify password works correctly
  const saved = await admins.findOne({ username: ADMIN_USERNAME });
  const ok = saved && await bcrypt.compare(ADMIN_PASSWORD, saved.passwordHash);
  console.log(`\n🔐  Login test: ${ok ? '✅  Password verified successfully' : '❌  FAILED — check for errors above'}`);

  // 6. Summary
  console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('🎉  Done! Now run: npm start');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('   Admin URL  →  http://localhost:3000/admin');
  console.log(`   Username   →  ${ADMIN_USERNAME}`);
  console.log(`   Password   →  ${ADMIN_PASSWORD}`);
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  await mongoose.disconnect();
}

main().catch(err => {
  console.error('\n❌  Error:', err.message);
  process.exit(1);
});
