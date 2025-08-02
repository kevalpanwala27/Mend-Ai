const crypto = require('crypto');

/**
 * ZEGOCLOUD Token Generator
 * Generate tokens for secure ZEGOCLOUD authentication
 */

// Your ZEGOCLOUD App credentials
const APP_ID = 123456789; // Replace with your actual ZEGOCLOUD App ID
const SERVER_SECRET = "your_server_secret_here"; // Replace with your actual Server Secret

/**
 * Generate ZEGOCLOUD token for user authentication
 * @param {string} userID - Unique user identifier
 * @param {number} effectiveTimeInSeconds - Token validity duration (default: 24 hours)
 * @returns {string} - Generated token
 */
function generateToken(userID, effectiveTimeInSeconds = 86400) {
  if (!userID) {
    throw new Error('userID is required');
  }

  const payload = {
    iss: APP_ID,
    exp: Math.floor(Date.now() / 1000) + effectiveTimeInSeconds,
    userId: userID,
    iat: Math.floor(Date.now() / 1000),
  };

  // Create the token header
  const header = {
    alg: 'HS256',
    typ: 'JWT'
  };

  // Encode header and payload
  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));

  // Create signature
  const signature = crypto
    .createHmac('sha256', SERVER_SECRET)
    .update(`${encodedHeader}.${encodedPayload}`)
    .digest('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '');

  return `${encodedHeader}.${encodedPayload}.${signature}`;
}

/**
 * Base64 URL encode helper function
 */
function base64UrlEncode(str) {
  return Buffer.from(str)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '');
}

/**
 * Validate if a token is still valid
 * @param {string} token - Token to validate
 * @returns {boolean} - Whether token is valid
 */
function validateToken(token) {
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return false;

    const payload = JSON.parse(Buffer.from(parts[1], 'base64').toString());
    const now = Math.floor(Date.now() / 1000);
    
    return payload.exp > now && payload.iss === APP_ID;
  } catch (error) {
    return false;
  }
}

module.exports = {
  generateToken,
  validateToken,
  APP_ID
};