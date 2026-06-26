/**
 * PropFlow — Circle Gateway Webhook Handler
 *
 * Handles incoming USDC rent deposits via Circle Gateway.
 * When a property manager sends USDC to the Gateway-managed address,
 * this webhook triggers the RentDistributor contract to distribute
 * rent to all PropToken holders.
 *
 * API Reference: https://developers.circle.com/gateway
 *
 * Fallback: If Gateway webhooks are not available on Arc testnet
 * during the hackathon, admin triggers distribution manually from
 * the Flutter admin screen. The architecture still shows the full
 * Gateway integration in the submission diagram.
 *
 * Environment variables required:
 *   ADMIN_PRIVATE_KEY    — Private key of the contract owner
 *   RENT_DISTRIBUTOR_ADDR — Deployed RentDistributor contract address
 */

const { ethers } = require("ethers");
const admin = require("firebase-admin");
const functions = require("firebase-functions");

// Arc Testnet configuration
const ARC_RPC = "https://rpc.testnet.arc.network";
const ARC_CHAIN_ID = 5042002;

// Contract configuration (update after Remix deployment)
const RENT_DISTRIBUTOR_ADDRESS =
  process.env.RENT_DISTRIBUTOR_ADDRESS ||
  "0x0000000000000000000000000000000000000000";

const ADMIN_PRIVATE_KEY =
  process.env.ADMIN_PRIVATE_KEY ||
  "0x0000000000000000000000000000000000000000000000000000000000000000";

// Minimal ABI for RentDistributor
const RENT_DISTRIBUTOR_ABI = [
  "function distributeRent() external",
  "function depositRent(uint256 amount) external",
  "function rentPool() view returns (uint256)",
  "function totalDistributed() view returns (uint256)",
];

/**
 * Process a Gateway webhook event for rent payment.
 *
 * Expected payload from Circle Gateway:
 * {
 *   "type": "payment",
 *   "data": {
 *     "id": "...",
 *     "amount": { "amount": "1200.00", "currency": "USD" },
 *     "status": "confirmed",
 *     "settlementAmount": { "amount": "1200.00", "currency": "USDC" },
 *     "blockchain": "ARC-TESTNET",
 *     "txHash": "0x..."
 *   }
 * }
 *
 * @param {Object} payload - Gateway webhook payload
 * @returns {{ success: boolean, txHash?: string, message?: string }}
 */
async function gatewayWebhook(payload) {
  console.log("Gateway webhook received:", JSON.stringify(payload));

  // Validate payload
  if (!payload || !payload.type) {
    return { success: false, message: "Invalid payload" };
  }

  // Only process confirmed payments
  if (payload.type !== "payment" || payload.data?.status !== "confirmed") {
    console.log("Ignoring non-confirmed payment event:", payload.type);
    return { success: true, message: "Event ignored (not a confirmed payment)" };
  }

  const paymentData = payload.data;
  const amount = parseFloat(paymentData.settlementAmount?.amount || "0");

  if (amount <= 0) {
    return { success: false, message: "Invalid payment amount" };
  }

  console.log(`Processing rent payment: ${amount} USDC`);

  try {
    // Connect to Arc Testnet
    const provider = new ethers.JsonRpcProvider(ARC_RPC, ARC_CHAIN_ID);
    const signer = new ethers.Wallet(ADMIN_PRIVATE_KEY, provider);

    // Create contract instance
    const rentDistributor = new ethers.Contract(
      RENT_DISTRIBUTOR_ADDRESS,
      RENT_DISTRIBUTOR_ABI,
      signer
    );

    // Call distributeRent()
    console.log("Calling distributeRent() on RentDistributor...");
    const tx = await rentDistributor.distributeRent();
    const receipt = await tx.wait();

    console.log(
      "Rent distributed! TX:",
      receipt.hash,
      "Block:",
      receipt.blockNumber
    );

    // Record distribution in Firestore
    await admin.firestore().collection("rentDistributions").add({
      totalUSDC: amount,
      perTokenUSDC: 0, // Calculated from contract events
      txHash: receipt.hash,
      gatewayPaymentId: paymentData.id || null,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      txHash: receipt.hash,
      message: `Distributed ${amount} USDC to all holders`,
    };
  } catch (error) {
    console.error("Rent distribution failed:", error);

    // Log failed attempt for debugging
    await admin.firestore().collection("failedDistributions").add({
      error: error.message,
      payload: JSON.stringify(payload),
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: false,
      message: `Distribution failed: ${error.message}`,
    };
  }
}

module.exports = { gatewayWebhook };
