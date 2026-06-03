const crypto = require('crypto');

class BlockchainService {
  /**
   * Generate a Decentralized Identity (DID)
   */
  async generateDID() {
    const bytes = crypto.randomBytes(32);
    const hash = crypto.createHash('sha256').update(bytes).digest('hex');
    return `did:omnivote:${hash.substring(0, 42)}`;
  }

  /**
   * Generate public/private key pair
   * FIX: Node.js crypto.generateKeyPairSync only accepts format: 'pem' or 'der'.
   *      'base64' is not a valid format — it was causing ERR_INVALID_ARG_VALUE.
   *      We now export as 'pem' and strip the PEM headers to get a clean base64 string.
   */
  async generateKeyPair() {
    const { publicKey, privateKey } = crypto.generateKeyPairSync('ec', {
      namedCurve: 'secp256k1',
      publicKeyEncoding: { type: 'spki', format: 'pem' },
      privateKeyEncoding: { type: 'pkcs8', format: 'pem' }
    });

    // Strip PEM headers/footers and newlines to get raw base64
    const toBase64 = (pem) => pem
      .replace(/-----BEGIN [^-]+-----/, '')
      .replace(/-----END [^-]+-----/, '')
      .replace(/\s+/g, '');

    return {
      publicKey: toBase64(publicKey),
      privateKey: toBase64(privateKey)
    };
  }

  /**
   * Cast a vote and return a transaction hash
   */
  async castVote({ electionId, candidateId, voterId, zkProof }) {
    // Simulate blockchain transaction delay
    await this._simulateDelay(1500);

    const data = `${electionId}${candidateId}${voterId}${Date.now()}${Math.random()}`;
    const transactionHash = crypto.createHash('sha256').update(data).digest('hex');

    return {
      transactionHash,
      blockNumber: Math.floor(Math.random() * 1000000) + 200000000,
      fee: 0.00025,
      network: 'Solana Mainnet',
      status: 'confirmed'
    };
  }

  /**
   * Verify a transaction on-chain
   */
  async verifyTransaction(transactionHash) {
    await this._simulateDelay(800);
    return {
      status: 'confirmed',
      confirmationBlocks: Math.floor(Math.random() * 7) + 3,
      blockNumber: Math.floor(Math.random() * 1000000) + 200000000,
      timestamp: new Date().toISOString()
    };
  }

  /**
   * Generate zero-knowledge proof
   */
  async generateZKProof({ voterId, electionId }) {
    await this._simulateDelay(1000);
    const data = `${voterId}${electionId}${Date.now()}`;
    const proof = crypto.createHash('sha256').update(data).digest('hex');
    return `zkp:${proof}`;
  }

  /**
   * Verify eligibility using ZK proof
   */
  async verifyEligibility({ voterId, electionId, zkProof }) {
    await this._simulateDelay(600);
    // In production, verify against smart contract
    return { eligible: true, reason: null };
  }

  /**
   * Hash a voter's DID for anonymous storage
   */
  hashVoterDID(did) {
    return crypto.createHash('sha256').update(did + process.env.JWT_SECRET).digest('hex');
  }

  /**
   * Get estimated transaction fee
   */
  async estimateTransactionFee() {
    return 0.00025; // SOL
  }

  /**
   * Get wallet balance
   */
  async getBalance(publicKey) {
    await this._simulateDelay(400);
    return 1.5 + Math.random() * 0.5;
  }

  /**
   * Get full transaction details
   */
  async getTransactionDetails(transactionHash) {
    await this._simulateDelay(600);
    return {
      hash: transactionHash,
      timestamp: new Date().toISOString(),
      status: 'confirmed',
      blockNumber: Math.floor(Math.random() * 1000000) + 200000000,
      confirmations: Math.floor(Math.random() * 10) + 3,
      fee: '0.00025',
      network: 'Solana Mainnet'
    };
  }

  _simulateDelay(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

module.exports = new BlockchainService();
