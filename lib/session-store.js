'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const session = require('express-session');

class FileSessionStore extends session.Store {
  constructor(directory) {
    super();
    this.directory = directory;
    fs.mkdirSync(directory, { recursive: true, mode: 0o700 });
    const timer = setInterval(() => {
      this.sweep().catch(() => {});
    }, 60 * 60 * 1000);
    timer.unref();
  }

  file(sid) {
    const value = String(sid || '');
    if (!/^[A-Za-z0-9_-]{20,128}$/.test(value)) throw new Error('Invalid session id');
    return path.join(this.directory, value + '.json');
  }

  async write(sid, sess) {
    const filePath = this.file(sid);
    const temporary = filePath + '.' + process.pid + '.' + crypto.randomBytes(4).toString('hex') + '.tmp';
    const handle = await fs.promises.open(temporary, 'wx', 0o600);
    try {
      await handle.writeFile(JSON.stringify(sess));
      await handle.sync();
    } finally {
      await handle.close();
    }
    try {
      await fs.promises.rename(temporary, filePath);
    } catch (error) {
      await fs.promises.unlink(temporary).catch(() => {});
      throw error;
    }
  }

  get(sid, callback) {
    let filePath;
    try { filePath = this.file(sid); } catch (error) { return callback(null, null); }
    fs.promises.readFile(filePath, 'utf8').then(async text => {
      const sess = JSON.parse(text);
      const expires = Date.parse(sess?.cookie?.expires || '');
      if (expires && expires <= Date.now()) {
        await fs.promises.unlink(filePath).catch(() => {});
        return callback(null, null);
      }
      callback(null, sess);
    }).catch(error => {
      if (error.code === 'ENOENT') return callback(null, null);
      fs.promises.unlink(filePath).catch(() => {}).finally(() => callback(null, null));
    });
  }

  set(sid, sess, callback) {
    this.write(sid, sess).then(() => callback(null)).catch(callback);
  }

  touch(sid, sess, callback) {
    this.write(sid, sess).then(() => callback(null)).catch(callback);
  }

  destroy(sid, callback) {
    let filePath;
    try { filePath = this.file(sid); } catch (error) { return callback(null); }
    fs.promises.unlink(filePath).then(() => callback(null)).catch(error => {
      callback(error.code === 'ENOENT' ? null : error);
    });
  }

  async entries() {
    const names = await fs.promises.readdir(this.directory);
    const values = await Promise.all(names.filter(name => /^[A-Za-z0-9_-]{20,128}\.json$/.test(name)).map(async name => {
      try {
        const sid = name.slice(0, -5);
        const sess = JSON.parse(await fs.promises.readFile(path.join(this.directory, name), 'utf8'));
        const expires = Date.parse(sess?.cookie?.expires || '');
        if (expires && expires <= Date.now()) {
          await fs.promises.unlink(path.join(this.directory, name)).catch(() => {});
          return null;
        }
        return [sid, sess];
      } catch (error) {
        return null;
      }
    }));
    return values.filter(Boolean);
  }

  all(callback) {
    this.entries().then(entries => callback(null, Object.fromEntries(entries))).catch(callback);
  }

  sweep() {
    return this.entries();
  }
}

module.exports = FileSessionStore;
