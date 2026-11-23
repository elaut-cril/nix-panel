'use strict';

const crypto = require('crypto');

const SCRYPT_N = 16384;
const SCRYPT_R = 8;
const SCRYPT_P = 1;
const KEY_LENGTH = 64;
const MAX_PASSWORD_LENGTH = 256;

function validatePassword(password) {
  return typeof password === 'string' && password.length > 0 && password.length <= MAX_PASSWORD_LENGTH;
}

function hashPasswordSync(password) {
  if (!validatePassword(password)) throw new Error('Некорректная длина пароля');
  const salt = crypto.randomBytes(16);
  const hash = crypto.scryptSync(password, salt, KEY_LENGTH, {
    N: SCRYPT_N,
    r: SCRYPT_R,
    p: SCRYPT_P,
    maxmem: 64 * 1024 * 1024
  });
  return ['scrypt', SCRYPT_N, SCRYPT_R, SCRYPT_P, salt.toString('base64'), hash.toString('base64')].join('$');
}

function hashPassword(password) {
  if (!validatePassword(password)) return Promise.reject(new Error('Некорректная длина пароля'));
  const salt = crypto.randomBytes(16);
  return new Promise((resolve, reject) => {
    crypto.scrypt(password, salt, KEY_LENGTH, {
      N: SCRYPT_N,
      r: SCRYPT_R,
      p: SCRYPT_P,
      maxmem: 64 * 1024 * 1024
    }, (error, hash) => {
      if (error) return reject(error);
      resolve(['scrypt', SCRYPT_N, SCRYPT_R, SCRYPT_P, salt.toString('base64'), hash.toString('base64')].join('$'));
    });
  });
}

function verifyPassword(password, encoded) {
  if (!validatePassword(password) || typeof encoded !== 'string') return Promise.resolve(false);
  const parts = encoded.split('$');
  if (parts.length !== 6 || parts[0] !== 'scrypt') return Promise.resolve(false);
  const N = Number(parts[1]);
  const r = Number(parts[2]);
  const p = Number(parts[3]);
  if (N !== SCRYPT_N || r !== SCRYPT_R || p !== SCRYPT_P) return Promise.resolve(false);
  let salt;
  let expected;
  try {
    salt = Buffer.from(parts[4], 'base64');
    expected = Buffer.from(parts[5], 'base64');
  } catch (error) {
    return Promise.resolve(false);
  }
  if (salt.length !== 16 || expected.length !== KEY_LENGTH) return Promise.resolve(false);
  return new Promise(resolve => {
    crypto.scrypt(password, salt, KEY_LENGTH, {
      N,
      r,
      p,
      maxmem: 64 * 1024 * 1024
    }, (error, actual) => {
      resolve(!error && crypto.timingSafeEqual(actual, expected));
    });
  });
}

function verifyLegacyPassword(password, stored) {
  if (!validatePassword(password) || typeof stored !== 'string') return false;
  const actualDigest = crypto.createHash('sha256').update(password).digest();
  const storedDigest = crypto.createHash('sha256').update(stored).digest();
  return crypto.timingSafeEqual(actualDigest, storedDigest);
}

module.exports = {
  MAX_PASSWORD_LENGTH,
  hashPassword,
  hashPasswordSync,
  verifyPassword,
  verifyLegacyPassword
};
