# OmniVote Backend

Full Node.js/Express backend for the OmniVote blockchain voting platform.

## Architecture

```
omnivote-backend/
├── src/
│   ├── server.js              # Main Express server
│   ├── config/
│   │   └── database.js        # MongoDB connection
│   ├── models/
│   │   ├── User.js            # User model with DID/biometric support
│   │   ├── Election.js        # Election & candidate models
│   │   ├── Vote.js            # Vote records with ZK proofs
│   │   └── Admin.js           # Admin users
│   ├── routes/
│   │   ├── auth.js            # User authentication
│   │   ├── elections.js       # Public election endpoints
│   │   ├── votes.js           # Vote casting & verification
│   │   ├── users.js           # User profile management
│   │   └── admin.js           # Admin API (all management)
│   ├── middleware/
│   │   └── auth.js            # JWT auth + permission middleware
│   └── services/
│       └── blockchainService.js  # Blockchain/Solana integration layer
├── admin/
│   └── index.html             # Admin panel SPA
├── scripts/
│   └── seed.js                # Database seeder
├── .env                       # Environment config
└── package.json
```

## Quick Start

### 1. Install dependencies
```bash
npm install
```

### 2. Setup environment
Edit `.env` with your values:
```env
MONGODB_URI=mongodb://localhost:27017/omnivote
JWT_SECRET=your-secret-key-here
ADMIN_USERNAME=admin
ADMIN_PASSWORD=Admin@OmniVote2024!
```

### 3. Seed the database
```bash
npm run seed
```

### 4. Start server
```bash
npm start
# or for development
npm run dev
```

The server runs at **http://localhost:3000**

## Admin Panel

Access at: **http://localhost:3000/admin**

Default credentials:
- Username: `admin`
- Password: `Admin@OmniVote2024!`

### Admin Panel Features:
- **Dashboard** — Live stats, vote trends chart, activity feed
- **Elections** — Full CRUD, create/edit/cancel elections, manage candidates
- **Votes** — Browse blockchain vote records with ZK proof status
- **Users** — View users, ban/unban, verify identity
- **Analytics** — Vote trends, user registrations, election comparisons
- **Admins** — Create sub-admins with role-based permissions

## API Reference

### Authentication
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/register` | Register new user (returns DID + keys) |
| POST | `/api/auth/login` | Login with password or biometric |
| POST | `/api/auth/biometric/enable` | Enable biometric auth |
| POST | `/api/auth/refresh` | Refresh JWT token |
| GET  | `/api/auth/me` | Get current user |

### Elections
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET  | `/api/elections` | List public elections |
| GET  | `/api/elections/:id` | Get single election |
| GET  | `/api/elections/:id/results` | Get real-time results |
| POST | `/api/elections/:id/check-eligibility` | Check if user can vote |

### Voting
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/votes/cast` | Cast a vote (authenticated) |
| GET  | `/api/votes/receipt/:hash` | Get vote receipt |
| GET  | `/api/votes/verify/:hash` | Public vote verification |
| GET  | `/api/votes/my-votes` | User's vote history |

### Admin API (requires admin token)
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/admin/login` | Admin login |
| GET  | `/api/admin/dashboard` | Dashboard stats |
| GET/POST | `/api/admin/elections` | List/create elections |
| GET/PUT/DELETE | `/api/admin/elections/:id` | Manage election |
| POST | `/api/admin/elections/:id/cancel` | Cancel election |
| GET  | `/api/admin/elections/:id/votes` | Election votes |
| GET  | `/api/admin/users` | List users |
| POST | `/api/admin/users/:id/ban` | Ban user |
| POST | `/api/admin/users/:id/unban` | Unban user |
| POST | `/api/admin/users/:id/verify` | Verify user |
| GET  | `/api/admin/analytics` | Analytics data |
| GET/POST | `/api/admin/admins` | Manage admins |

## Flutter Integration

Update `app_constants.dart`:
```dart
static const String baseUrl = 'http://YOUR_SERVER_IP:3000';
```

### Register a user:
```dart
POST /api/auth/register
{
  "name": "John Doe",
  "email": "john@example.com",
  "password": "MyPassword123",
  "devicePlatform": "android"
}
```
Returns: `{ token, user: { id, did, publicKey, ... }, privateKey }`
⚠️ Store `privateKey` securely - only returned once!

### Cast a vote:
```dart
POST /api/votes/cast
Authorization: Bearer <token>
{
  "electionId": "election_id_here",
  "candidateId": "candidate_id_here",
  "biometricVerified": true
}
```
Returns: `{ voteReceipt: { transactionHash, ... } }`

## Security Features
- JWT authentication with expiry
- Biometric verification support
- Zero-knowledge proofs for anonymous voting
- Hashed voter DIDs (prevents double-voting without revealing identity)
- Rate limiting on all endpoints (strict on vote casting)
- Helmet.js security headers
- Account lockout after failed attempts
- Role-based admin permissions

## Production Notes
- Replace `blockchainService.js` with actual Solana web3.js integration
- Use environment variables for all secrets
- Enable HTTPS (use nginx reverse proxy)
- Consider Redis for session management
- Add email verification flow
- Set up proper MongoDB indexes and backups
