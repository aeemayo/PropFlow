const axios = require('axios');
const crypto = require('crypto');

const TELEGRAM_API = `https://api.telegram.org/bot${process.env.TELEGRAM_BOT_TOKEN}`;

/**
 * Generates a signed token so only requests with the correct secret
 * can trigger an approval — prevents anyone who finds the Cloud
 * Function URL from approving arbitrary users.
 */
function signToken(userId) {
  return crypto
    .createHmac('sha256', process.env.TELEGRAM_WEBHOOK_SECRET)
    .update(userId)
    .digest('hex')
    .slice(0, 16);
}

function verifyToken(userId, token) {
  return signToken(userId) === token;
}

/**
 * Masks a NIN for display, e.g. 12345678901 -> 123●●●●●●901
 */
function maskNin(nin) {
  if (!nin || nin.length < 6) return nin;
  return `${nin.slice(0, 3)}${'●'.repeat(nin.length - 6)}${nin.slice(-3)}`;
}

/**
 * Sends a KYC approval request to your Telegram chat with inline
 * Approve / Reject buttons. Telegram delivers the button press to
 * your webhook function as a callback_query.
 *
 * @param {object} params
 * @param {string} params.functionsBaseUrl - e.g. https://us-central1-propflow.cloudfunctions.net
 * @param {string} params.userId
 * @param {string} params.fullName
 * @param {string} params.nin
 * @param {string} params.walletAddress
 */
async function sendKycApprovalRequest({ functionsBaseUrl, userId, fullName, nin, walletAddress }) {
  const token = signToken(userId);

  const text =
    `🔔 *New KYC Request — PropFlow*\n\n` +
    `👤 *Name:* ${fullName}\n` +
    `🪪 *NIN:* ${maskNin(nin)}\n` +
    `🏦 *Wallet:* \`${walletAddress}\`\n\n` +
    `Tap a button below to decide.`;

  await axios.post(`${TELEGRAM_API}/sendMessage`, {
    chat_id: process.env.TELEGRAM_CHAT_ID,
    text,
    parse_mode: 'Markdown',
    reply_markup: {
      inline_keyboard: [
        [
          { text: '✅ Approve', callback_data: `approve:${userId}:${token}` },
          { text: '❌ Reject', callback_data: `reject:${userId}:${token}` },
        ],
      ],
    },
  });
}

/**
 * Sends a plain confirmation message back to your chat — used after
 * a decision has been processed, so the bot doesn't go silent.
 */
async function sendConfirmation(text) {
  await axios.post(`${TELEGRAM_API}/sendMessage`, {
    chat_id: process.env.TELEGRAM_CHAT_ID,
    text,
    parse_mode: 'Markdown',
  });
}

/**
 * Edits the original message to show the final decision and remove
 * the buttons, so you can't double-tap Approve by accident.
 */
async function editMessageAfterDecision(chatId, messageId, decisionText) {
  await axios.post(`${TELEGRAM_API}/editMessageText`, {
    chat_id: chatId,
    message_id: messageId,
    text: decisionText,
    parse_mode: 'Markdown',
  });
}

module.exports = {
  sendKycApprovalRequest,
  sendConfirmation,
  editMessageAfterDecision,
  verifyToken,
  maskNin,
};
