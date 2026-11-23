'use strict';

const crypto = require('crypto');
const ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

function base32Encode(buffer) {
  let bits = 0, value = 0, output = '';
  for (const byte of buffer) {
    value = (value << 8) | byte;
    bits += 8;
    while (bits >= 5) {
      output += ALPHABET[(value >>> (bits - 5)) & 31];
      bits -= 5;
    }
  }
  if (bits) output += ALPHABET[(value << (5 - bits)) & 31];
  return output;
}

function base32Decode(value) {
  let bits = 0, current = 0;
  const bytes = [];
  for (const char of String(value || '').replace(/[\s=-]/g, '').toUpperCase()) {
    const index = ALPHABET.indexOf(char);
    if (index < 0) throw new Error('Invalid TOTP secret');
    current = (current << 5) | index;
    bits += 5;
    if (bits >= 8) {
      bytes.push((current >>> (bits - 8)) & 255);
      bits -= 8;
    }
  }
  return Buffer.from(bytes);
}

function createSecret() {
  return base32Encode(crypto.randomBytes(20));
}

function totp(secret, timestamp = Date.now()) {
  const counter = BigInt(Math.floor(timestamp / 30000));
  const buffer = Buffer.alloc(8);
  buffer.writeBigUInt64BE(counter);
  const digest = crypto.createHmac('sha1', base32Decode(secret)).update(buffer).digest();
  const offset = digest[digest.length - 1] & 15;
  return String((digest.readUInt32BE(offset) & 0x7fffffff) % 1000000).padStart(6, '0');
}

function verifyTotpStep(secret, code, timestamp = Date.now()) {
  const normalized = String(code || '').replace(/[\s-]/g, '');
  if (!/^\d{6}$/.test(normalized)) return null;
  const expected = Buffer.from(normalized);
  for (const offset of [-1, 0, 1]) {
    const step = Math.floor(timestamp / 30000) + offset;
    if (step < 0) continue;
    const candidate = Buffer.from(totp(secret, step * 30000));
    if (crypto.timingSafeEqual(candidate, expected)) return step;
  }
  return null;
}

function verifyTotp(secret, code, timestamp = Date.now()) {
  return verifyTotpStep(secret, code, timestamp) !== null;
}

function totpUri(secret, login, issuer = 'NIX Panel') {
  const account = String(login || 'user').slice(0, 64);
  return 'otpauth://totp/' + encodeURIComponent(issuer + ':' + account) + '?secret=' + secret + '&issuer=' + encodeURIComponent(issuer) + '&algorithm=SHA1&digits=6&period=30';
}

module.exports = { base32Encode, base32Decode, createSecret, totp, verifyTotp, verifyTotpStep, totpUri };
