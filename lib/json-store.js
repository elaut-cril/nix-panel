'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

function writeJsonSync(filePath, value, { mode = 0o600, spacing = 2 } = {}) {
  const directory = path.dirname(filePath);
  fs.mkdirSync(directory, { recursive: true });
  const temporary = filePath + '.' + process.pid + '.' + crypto.randomBytes(6).toString('hex') + '.tmp';
  let descriptor;
  try {
    descriptor = fs.openSync(temporary, 'wx', mode);
    fs.writeFileSync(descriptor, JSON.stringify(value, null, spacing) + '\n', 'utf8');
    fs.fsyncSync(descriptor);
    fs.closeSync(descriptor);
    descriptor = undefined;
    fs.renameSync(temporary, filePath);
  } finally {
    if (descriptor !== undefined) {
      try { fs.closeSync(descriptor); } catch (error) {}
    }
    try { fs.unlinkSync(temporary); } catch (error) {}
  }
}

function readJsonSync(filePath, fallback) {
  try {
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch (error) {
    if (error.code === 'ENOENT') return fallback;
    throw error;
  }
}

class JsonStore {
  constructor(filePath, initialValue) {
    this.filePath = filePath;
    this.value = readJsonSync(filePath, initialValue);
    this.queue = Promise.resolve();
  }

  get() {
    return this.value;
  }

  update(mutator) {
    const operation = this.queue.then(async () => {
      const draft = structuredClone(this.value);
      const result = await mutator(draft);
      writeJsonSync(this.filePath, draft, { spacing: 0 });
      this.value = draft;
      return result;
    });
    this.queue = operation.catch(() => {});
    return operation;
  }
}

module.exports = { readJsonSync, writeJsonSync, JsonStore };
