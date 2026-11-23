'use strict';

const { spawn } = require('child_process');

async function launchGuiCommand(value, { spawnProcess = spawn, graceMs = 1500 } = {}) {
  const command = String(value || '').replace(/\0/g, '').trim();
  if (!command) return { started: false };
  if (command.length > 2000) throw new Error('Команда GUI не должна превышать 2000 символов');

  return new Promise((resolve, reject) => {
    let child;
    try {
      child = spawnProcess('/bin/bash', ['-lc', command], { detached: true, stdio: ['ignore', 'pipe', 'pipe'] });
    } catch (error) {
      reject(error);
      return;
    }
    let output = '', settled = false;
    const timer = setTimeout(() => finish(null), graceMs);
    function finish(error) {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      if (error) reject(error);
      else resolve({ started: true });
    }
    function append(chunk) {
      output = (output + chunk.toString()).slice(-1200);
    }
    child.stdout.on('data', append);
    child.stderr.on('data', append);
    child.once('error', finish);
    child.once('exit', (code, signal) => {
      if (code === 0) return finish(null);
      const details = output.replace(/\s+/g, ' ').trim();
      finish(new Error('Команда GUI завершилась с кодом ' + code + (signal ? ' (' + signal + ')' : '') + (details ? ': ' + details : '')));
    });
  });
}

module.exports = { launchGuiCommand };
