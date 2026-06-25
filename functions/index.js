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
