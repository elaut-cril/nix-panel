'use strict';

class RateLimiter {
  constructor({ windowMs, max, maxKeys = 10000 }) {
    this.windowMs = windowMs;
    this.max = max;
    this.maxKeys = maxKeys;
    this.entries = new Map();
  }

  get(key) {
    const now = Date.now();
    const current = this.entries.get(key);
    if (!current || now - current.startedAt >= this.windowMs) return null;
    return current;
  }

  isLimited(key) {
    const current = this.get(key);
    return !!current && current.count >= this.max;
  }

  record(key) {
    const normalized = String(key || 'unknown').slice(0, 160);
    const current = this.get(normalized);
    if (current) {
      current.count++;
      return current.count;
    }
    if (this.entries.size >= this.maxKeys) {
      const oldest = this.entries.keys().next().value;
      this.entries.delete(oldest);
    }
    this.entries.set(normalized, { count: 1, startedAt: Date.now() });
    return 1;
  }

  reset(key) {
    this.entries.delete(String(key || 'unknown').slice(0, 160));
  }

  sweep() {
    const now = Date.now();
    for (const [key, value] of this.entries) {
      if (now - value.startedAt >= this.windowMs) this.entries.delete(key);
    }
  }
}

function securityHeaders(req, res, next) {
  res.set({
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'SAMEORIGIN',
    'Referrer-Policy': 'no-referrer',
    'Permissions-Policy': 'camera=(), microphone=(), geolocation=()',
    'Cross-Origin-Opener-Policy': 'same-origin-allow-popups',
    'Content-Security-Policy': "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; media-src 'self' data: blob:; connect-src 'self' ws: wss:; font-src 'self' data:; object-src 'none'; base-uri 'self'; frame-ancestors 'self'; form-action 'self'"
  });
  if (req.secure) res.set('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
  if (req.path.startsWith('/api/')) res.set('Cache-Control', 'no-store');
  next();
}

function sameOriginMutations(req, res, next) {
  if (!req.path.startsWith('/api/') || ['GET', 'HEAD', 'OPTIONS'].includes(req.method)) return next();
  const origin = req.get('origin');
  if (!origin) return next();
  try {
    if (new URL(origin).host !== req.get('host')) return res.status(403).json({ error: 'Запрос с другого источника запрещён' });
  } catch (error) {
    return res.status(403).json({ error: 'Некорректный Origin' });
  }
  next();
}

function socketSameOrigin(req, callback) {
  const origin = req.headers.origin;
  if (!origin) return callback(null, true);
  try {
    callback(null, new URL(origin).host === req.headers.host);
  } catch (error) {
    callback(null, false);
  }
}

module.exports = { RateLimiter, securityHeaders, sameOriginMutations, socketSameOrigin };
