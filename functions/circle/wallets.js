/**
 * PropFlow — Circle Wallets API Wrapper
 *
 * Handles embedded wallet creation for investors on Arc Testnet
 * using Circle's Programmable Wallets (user-controlled).
 *
 * API Reference: https://developers.circle.com/wallets
 *
 * Environment variables required:
 *   CIRCLE_API_KEY — from https://console.circle.com
 *
 * Endpoints used:
 *   POST /v1/w3s/users          — Create a Circle user
 *   POST /v1/w3s/user/wallets   — Create a wallet on ARC_TESTNET
 *   GET  /v1/w3s/wallets/{id}   — Get wallet details + balance
 */

const axios = require("axios");
const { v4: uuidv4 } = require("uuid");
const functions = require("firebase-functions");

// Circle API configuration
// TODO: Replace with your Circle API key from console.circle.com
const CIRCLE_API_KEY =
  process.env.CIRCLE_API_KEY || "YOUR_CIRCLE_API_KEY";
const CIRCLE_BASE_URL = "https://api.circle.com";

// Axios instance with auth headers
const circleApi = axios.create({
  baseURL: CIRCLE_BASE_URL,
  headers: {
    "Content-Type": "application/json",
    Authorization: `Bearer ${CIRCLE_API_KEY}`,
  },
});

/**
 * Create a Circle user and wallet on Arc Testnet.
 *
 * @param {string} userId - Firebase UID of the investor
 * @returns {{ walletId: string, walletAddress: string }}
 */
async function createWallet(userId) {
  try {
    // Step 1: Create a Circle user
    const userResponse = await circleApi.post("/v1/w3s/users", {
      userId: userId,
    });

    console.log("Circle user created:", userResponse.data);

    // Try to get a user session token for user-controlled wallets
    const tokenResponse = await circleApi.post("/v1/w3s/users/token", {
      userId: userId,
    });
    const userToken = tokenResponse.data?.data?.userToken;

    // Step 2: Create a wallet for the user on Arc Testnet
    const idempotencyKey = uuidv4();

    const walletResponse = await circleApi.post("/v1/w3s/user/wallets", {
      userId: userId,
      blockchains: ["ARC-TESTNET"],
      accountType: "EOA",
      idempotencyKey: idempotencyKey,
    }, {
      headers: {
        "X-User-Token": userToken
      }
    });

    console.log("Circle wallet created:", walletResponse.data);

    // Extract wallet details
    const wallet = walletResponse.data?.data?.wallets?.[0];
    if (!wallet) {
      throw new Error("Wallet creation succeeded but no wallet returned");
    }

    return {
      walletId: wallet.id,
      walletAddress: wallet.address,
    };
  } catch (error) {
    const errorMsg = error.response ? JSON.stringify(error.response.data) : error.message;
    console.warn(`Circle wallet creation failed (${errorMsg}), falling back to local EOA generation...`);

    // Generate a standard EOA wallet locally using ethers
    const { ethers } = require("ethers");
    const localWallet = ethers.Wallet.createRandom();

    return {
      walletId: `local-${uuidv4()}`,
      walletAddress: localWallet.address,
      privateKey: localWallet.privateKey // Store private key if they need it for signing locally
    };
  }
}

/**
 * Get wallet details and balances from Circle.
 *
 * @param {string} walletId - Circle wallet ID
 * @returns {{ walletId: string, address: string, balances: Array }}
 */
async function getWallet(walletId) {
  const response = await circleApi.get(`/v1/w3s/wallets/${walletId}`);

  const wallet = response.data?.data?.wallet;
  if (!wallet) {
    throw new Error("Wallet not found");
  }

  // Fetch token balances
  let balances = [];
  try {
    const balanceResponse = await circleApi.get(
      `/v1/w3s/wallets/${walletId}/balances`
    );
    balances = balanceResponse.data?.data?.tokenBalances || [];
  } catch (balError) {
    console.warn("Balance fetch failed:", balError.message);
  }

  return {
    walletId: wallet.id,
    address: wallet.address,
    state: wallet.state,
    blockchain: wallet.blockchain,
    balances: balances.map((b) => ({
      token: b.token?.symbol || "UNKNOWN",
      amount: b.amount || "0",
      decimals: b.token?.decimals || 6,
    })),
  };
}

module.exports = { createWallet, getWallet };
