/**
 * PropFlow — Firebase Cloud Functions
 *
 * Entry point for all Cloud Functions:
 * - Circle Wallets API (embedded wallet creation for investors)
 * - Circle Gateway webhook (rent deposit → distribution trigger)
 * - Admin utilities (KYC approval trigger, rent distribution)
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { ethers } = require('ethers');

admin.initializeApp();

// Import modules
const { createWallet, getWallet } = require("./circle/wallets");
const { gatewayWebhook } = require("./circle/gateway");

// ══════════════════════════════════════════════
//  Circle Wallets API — Callable Functions
// ══════════════════════════════════════════════

/**
 * Create a Circle wallet for a new investor.
 *
 * Called from Flutter on first login. Creates a Circle user and
 * wallet on ARC_TESTNET, then stores walletId + walletAddress
 * in the user's Firestore document.
 *
 * Request body: { userId: string }
 * Response: { walletId: string, walletAddress: string }
 */
exports.createWallet = functions.https.onRequest(async (req, res) => {
  // CORS
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST");
  res.set("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") {
    return res.status(204).send("");
  }

  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  try {
    const { userId } = req.body;
    if (!userId) {
      return res.status(400).json({ error: "userId is required" });
    }

    const result = await createWallet(userId);

    // Store in Firestore
    await admin.firestore().collection("users").doc(userId).update({
      walletId: result.walletId,
      walletAddress: result.walletAddress,
    });

    return res.status(200).json(result);
  } catch (error) {
    console.error("createWallet error:", error);
    return res.status(500).json({ error: error.message });
  }
});

/**
 * Get wallet details including balance.
 *
 * Query params: ?walletId=<id>
 * Response: { walletId, address, balances }
 */
exports.getWallet = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");

  if (req.method === "OPTIONS") {
    return res.status(204).send("");
  }

  try {
    const { walletId } = req.query;
    if (!walletId) {
      return res.status(400).json({ error: "walletId is required" });
    }

    const result = await getWallet(walletId);
    return res.status(200).json(result);
  } catch (error) {
    console.error("getWallet error:", error);
    return res.status(500).json({ error: error.message });
  }
});

// ══════════════════════════════════════════════
//  Circle Gateway — Webhook Handler
// ══════════════════════════════════════════════

/**
 * Webhook endpoint for Circle Gateway payment events.
 *
 * When a property manager sends USDC via Gateway, this function
 * triggers rent distribution on the RentDistributor contract.
 *
 * Fallback: If Gateway is not available on Arc testnet, admin
 * triggers distribution manually from the Flutter admin screen.
 */
exports.gatewayWebhook = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");

  if (req.method === "OPTIONS") {
    return res.status(204).send("");
  }

  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  try {
    const result = await gatewayWebhook(req.body);
    return res.status(200).json(result);
  } catch (error) {
    console.error("gatewayWebhook error:", error);
    return res.status(500).json({ error: error.message });
  }
});

// ══════════════════════════════════════════════
//  Firestore Triggers
// ══════════════════════════════════════════════

/**
 * Auto-create Circle wallet when a new user document is created.
 *
 * This is a backup trigger — the primary wallet creation happens
 * via the callable function from Flutter. This catches cases where
 * the callable function fails or the user refreshes before it completes.
 */
exports.onUserCreated = functions.firestore
  .document("users/{uid}")
  .onCreate(async (snap, context) => {
    const uid = context.params.uid;
    const userData = snap.data();

    // Skip if wallet already exists
    if (userData.walletId) return null;

    try {
      const result = await createWallet(uid);
      await snap.ref.update({
        walletId: result.walletId,
        walletAddress: result.walletAddress,
      });
      console.log(`Wallet created for user ${uid}: ${result.walletAddress}`);
    } catch (error) {
      console.error(`Auto-wallet creation failed for ${uid}:`, error);
    }

    return null;
  });

// ══════════════════════════════════════════════
//  On-chain Write Operations — Platform Signing
//  All use ADMIN_PRIVATE_KEY from .env
// ══════════════════════════════════════════════

const ARC_RPC      = process.env.ARC_TESTNET_RPC || 'https://rpc.testnet.arc.network';
const ARC_CHAIN_ID = parseInt(process.env.ARC_CHAIN_ID || '5042002');

function getPlatformSigner() {
  const provider = new ethers.JsonRpcProvider(ARC_RPC, ARC_CHAIN_ID);
  return new ethers.Wallet(process.env.ADMIN_PRIVATE_KEY, provider);
}

// Minimal ABIs
const KYC_ABI = ['function approve(address investor) external'];
const PROPTOKEN_ABI = [
  'function purchaseFor(address recipient, uint256 amount) external',
  'function pricePerToken() view returns (uint256)',
];
const USDC_ABI = ['function approve(address spender, uint256 amount) external returns (bool)'];
const DISTRIBUTOR_ABI = [
  'function claimRentFor(address holder) external',
  'function payoutExpiredRent(address holder) external',
  'function getClaimableRent(address holder) view returns (uint256)',
  'function getExpiredRent(address holder) view returns (uint256)',
];

/**
 * purchaseShares — buy PropTokens on behalf of an investor.
 *
 * Body: { userId: string, shares: number }
 * Flow:
 *   1. Look up investor's walletAddress from Firestore
 *   2. Platform wallet approves USDC spend on PropToken contract
 *   3. Platform wallet calls PropToken.purchaseFor(walletAddress, amount)
 *   4. Returns { txHash }
 */
exports.purchaseShares = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(204).send('');
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  try {
    const { userId, shares } = req.body;
    if (!userId || !shares || shares <= 0) {
      return res.status(400).json({ error: 'userId and shares are required' });
    }

    // Get investor wallet address
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    if (!userDoc.exists) return res.status(404).json({ error: 'User not found' });
    const walletAddress = userDoc.data().walletAddress;
    if (!walletAddress) return res.status(400).json({ error: 'User has no Arc wallet yet' });

    const signer = getPlatformSigner();
    const propTokenAddr = process.env.PROP_TOKEN_ADDRESS;
    const usdcAddr      = process.env.USDC_ADDRESS || '0x3600000000000000000000000000000000000000';

    const propToken = new ethers.Contract(propTokenAddr, PROPTOKEN_ABI, signer);
    const usdc      = new ethers.Contract(usdcAddr, USDC_ABI, signer);

    // Calculate cost: shares * pricePerToken / 1e18
    const pricePerToken = await propToken.pricePerToken();
    const amountWei     = ethers.parseUnits(shares.toString(), 18);
    const cost          = (amountWei * pricePerToken) / BigInt(10 ** 18);

    // Step 1: Approve USDC
    const approveTx = await usdc.approve(propTokenAddr, cost);
    await approveTx.wait();
    console.log('USDC approved:', approveTx.hash);

    // Step 2: purchaseFor recipient
    const purchaseTx = await propToken.purchaseFor(walletAddress, amountWei);
    const receipt    = await purchaseTx.wait();
    console.log('purchaseFor done:', receipt.hash);

    // Record in Firestore
    await admin.firestore().collection('transactions').add({
      userId,
      propertyId: 'lekki-heights-lagos',
      type: 'purchase',
      amountUSDC: Number(cost) / 1e6,
      shares,
      txHash: receipt.hash,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return res.status(200).json({ txHash: receipt.hash });
  } catch (error) {
    console.error('purchaseShares error:', error);
    return res.status(500).json({ error: error.message });
  }
});

/**
 * approveKycOnChain — call KYCRegistry.approve(walletAddress).
 *
 * Body: { walletAddress: string }
 * Returns: { txHash }
 */
exports.approveKycOnChain = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(204).send('');
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  try {
    const { walletAddress } = req.body;
    if (!walletAddress) return res.status(400).json({ error: 'walletAddress is required' });

    const signer = getPlatformSigner();
    const kycRegistry = new ethers.Contract(
      process.env.KYC_REGISTRY_ADDRESS,
      KYC_ABI,
      signer
    );

    const tx      = await kycRegistry.approve(walletAddress);
    const receipt = await tx.wait();
    console.log('KYC approved onchain:', walletAddress, receipt.hash);

    return res.status(200).json({ txHash: receipt.hash });
  } catch (error) {
    console.error('approveKycOnChain error:', error);
    return res.status(500).json({ error: error.message });
  }
});

/**
 * distributeRentOnChain — call RentDistributor.distributeRent().
 *
 * Body: {} (empty)
 * Returns: { txHash }
 */
exports.distributeRentOnChain = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(204).send('');
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  try {
    const signer = getPlatformSigner();
    
    // Minimal ABI for PropToken to get holders
    const PROPTOKEN_ABI_EXP = ['function getHolders() external view returns (address[] memory)'];
    const propToken = new ethers.Contract(
      process.env.PROP_TOKEN_ADDRESS,
      PROPTOKEN_ABI_EXP,
      signer
    );

    const distributor = new ethers.Contract(
      process.env.RENT_DISTRIBUTOR_ADDRESS,
      DISTRIBUTOR_ABI,
      signer
    );

    const holders = await propToken.getHolders();
    const txHashes = [];

    for (let i = 0; i < holders.length; i++) {
      const holder = holders[i];
      // Check if holder has expired rent on-chain
      const expiredAmount = await distributor.getExpiredRent(holder);
      if (expiredAmount > 0) {
        console.log(`Auto-paying expired rent for ${holder}: ${expiredAmount} units...`);
        const tx = await distributor.payoutExpiredRent(holder);
        const receipt = await tx.wait();
        txHashes.push(receipt.hash);
        console.log(`Auto-paid expired rent for ${holder}. TX:`, receipt.hash);
      }
    }

    return res.status(200).json({ txHashes });
  } catch (error) {
    console.error('distributeRentOnChain error:', error);
    return res.status(500).json({ error: error.message });
  }
});

/**
 * claimRent — call RentDistributor.claimRentFor(walletAddress).
 *
 * Body: { userId: string }
 * Returns: { txHash }
 */
exports.claimRent = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(204).send('');
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  try {
    const { userId } = req.body;
    if (!userId) return res.status(400).json({ error: 'userId is required' });

    // Get user wallet address from Firestore
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    if (!userDoc.exists) return res.status(404).json({ error: 'User not found' });
    const walletAddress = userDoc.data().walletAddress;
    if (!walletAddress) return res.status(400).json({ error: 'User has no wallet address yet' });

    const signer = getPlatformSigner();
    const distributor = new ethers.Contract(
      process.env.RENT_DISTRIBUTOR_ADDRESS,
      DISTRIBUTOR_ABI,
      signer
    );

    // Read claimable amount before claiming
    const claimedAmount = await distributor.getClaimableRent(walletAddress);

    const tx      = await distributor.claimRentFor(walletAddress);
    const receipt = await tx.wait();
    console.log('Rent claimed:', walletAddress, receipt.hash);

    // Record the transaction in Firestore for the portfolio transaction history
    if (claimedAmount > 0) {
      await admin.firestore().collection('transactions').add({
        userId: userId,
        propertyId: 'lekki-heights-lagos',
        type: 'rent',
        amountUSDC: Number(ethers.formatUnits(claimedAmount, 6)),
        shares: 0,
        txHash: receipt.hash,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log('Recorded rent transaction in Firestore:', userId, claimedAmount.toString());
    }

    return res.status(200).json({ txHash: receipt.hash });
  } catch (error) {
    console.error('claimRent error:', error);
    return res.status(500).json({ error: error.message });
  }
});
