require('dotenv').config();
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const Admin = require('../src/models/Admin');
const Election = require('../src/models/Election');
const User = require('../src/models/User');
const crypto = require('crypto');

async function seed() {
  try {
    await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/omnivote');
    console.log('🌱 Connected to MongoDB. Seeding...');

    // Create super admin
    const existingAdmin = await Admin.findOne({ username: 'admin' });
    if (!existingAdmin) {
      const admin = new Admin({
        username: process.env.ADMIN_USERNAME || 'admin',
        email: process.env.ADMIN_EMAIL || 'admin@omnivote.io',
        passwordHash: await bcrypt.hash(process.env.ADMIN_PASSWORD || 'Admin@OmniVote2024!', 12),
        role: 'super_admin',
        permissions: {
          manageElections: true,
          manageUsers: true,
          viewAnalytics: true,
          manageAdmins: true,
          systemSettings: true
        }
      });
      await admin.save();
      console.log('✅ Super admin created:', admin.username);
      console.log('   Password:', process.env.ADMIN_PASSWORD || 'Admin@OmniVote2024!');
    } else {
      console.log('⏭️  Admin already exists, skipping');
    }

    // Create sample elections
    const existingElections = await Election.countDocuments();
    if (existingElections === 0) {
      const elections = [
        {
          title: '2026 Presidential Election',
          description: 'Cast your vote for the next President. Your vote is securely recorded on the Solana blockchain.',
          organizationName: 'Federal Election Commission',
          type: 'presidential',
          status: 'active',
          startDate: new Date(Date.now() - 24 * 60 * 60 * 1000),
          endDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
          totalVotes: 45678921,
          imageUrl: null,
          candidates: [
            { name: 'John Smith', party: 'Democratic Party', description: 'Progressive leader with 20 years of experience in public service', voteCount: 23456789 },
            { name: 'Sarah Johnson', party: 'Republican Party', description: 'Conservative advocate for economic growth and national security', voteCount: 22222132 }
          ]
        },
        {
          title: 'City Council Election - Springfield',
          description: 'Vote for your local city council representative for the upcoming 4-year term.',
          organizationName: 'City of Springfield',
          type: 'general',
          status: 'active',
          startDate: new Date(Date.now() - 12 * 60 * 60 * 1000),
          endDate: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
          totalVotes: 12543,
          candidates: [
            { name: 'Michael Davis', description: 'Focused on infrastructure and community development', voteCount: 6754 },
            { name: 'Emma Wilson', description: 'Champion for education and local businesses', voteCount: 5789 }
          ]
        },
        {
          title: 'TechCorp Annual Board Election',
          description: 'Shareholders vote for the Board of Directors for the upcoming fiscal year.',
          organizationName: 'TechCorp Inc.',
          type: 'corporate',
          status: 'pending',
          startDate: new Date(Date.now() + 5 * 24 * 60 * 60 * 1000),
          endDate: new Date(Date.now() + 12 * 24 * 60 * 60 * 1000),
          totalVotes: 0,
          candidates: [
            { name: 'Robert Chen', description: 'Former CFO with 15 years in tech finance' },
            { name: 'Lisa Anderson', description: 'Serial entrepreneur and tech industry veteran' },
            { name: 'James Martinez', description: 'AI/ML expert and innovation strategist' }
          ]
        },
        {
          title: 'DAO Governance Proposal #47',
          description: 'Community vote on protocol upgrade v3.0 which includes new staking mechanisms.',
          organizationName: 'DeFi Protocol DAO',
          type: 'dao',
          status: 'closed',
          startDate: new Date(Date.now() - 10 * 24 * 60 * 60 * 1000),
          endDate: new Date(Date.now() - 3 * 24 * 60 * 60 * 1000),
          totalVotes: 8934,
          candidates: [
            { name: 'Approve Proposal', description: 'Implement protocol upgrade v3.0', voteCount: 6723 },
            { name: 'Reject Proposal', description: 'Maintain current protocol', voteCount: 2211 }
          ]
        }
      ];

      await Election.insertMany(elections);
      console.log(`✅ ${elections.length} elections seeded`);
    } else {
      console.log('⏭️  Elections exist, skipping');
    }

    // Create sample users
    const existingUsers = await User.countDocuments();
    if (existingUsers === 0) {
      const users = Array.from({ length: 5 }, (_, i) => {
        const bytes = crypto.randomBytes(32);
        const hash = crypto.createHash('sha256').update(bytes).digest('hex');
        return {
          did: `did:omnivote:${hash.substring(0, 42)}`,
          publicKey: crypto.randomBytes(32).toString('base64'),
          name: ['Alice Johnson', 'Bob Martinez', 'Carol Kim', 'David Okafor', 'Eva Chen'][i],
          email: [`alice@example.com`, `bob@example.com`, `carol@example.com`, `david@example.com`, `eva@example.com`][i],
          passwordHash: bcrypt.hashSync('Password123!', 10),
          isVerified: i < 3,
          isActive: true,
          lastLogin: new Date(Date.now() - Math.random() * 7 * 24 * 60 * 60 * 1000)
        };
      });
      await User.insertMany(users);
      console.log(`✅ ${users.length} sample users seeded`);
    }

    console.log('\n🎉 Seeding complete!');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('Admin Panel: http://localhost:3000/admin');
    console.log('Username:', process.env.ADMIN_USERNAME || 'admin');
    console.log('Password:', process.env.ADMIN_PASSWORD || 'Admin@OmniVote2024!');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    await mongoose.disconnect();
  } catch (err) {
    console.error('❌ Seeding error:', err);
    process.exit(1);
  }
}

seed();
