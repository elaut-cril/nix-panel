'use strict';

const fs = require('fs');

async function readSnapshot() {
  const names = await fs.promises.readdir('/proc');
  const pids = names.filter(name => /^\d+$/.test(name)).map(Number);
  const totalText = await fs.promises.readFile('/proc/stat', 'utf8');
  const totalLine = totalText.split('\n')[0].trim().split(/\s+/).slice(1).map(Number);
  const totalTicks = totalLine.reduce((sum, value) => sum + (Number.isFinite(value) ? value : 0), 0);
  const processes = new Map();
  let cursor = 0;
  async function readNext() {
    while (cursor < pids.length) {
      const pid = pids[cursor++];
      try {
        const [statText, statusText] = await Promise.all([
          fs.promises.readFile('/proc/' + pid + '/stat', 'utf8'),
          fs.promises.readFile('/proc/' + pid + '/status', 'utf8')
        ]);
        const close = statText.lastIndexOf(')');
        if (close === -1) continue;
        const fields = statText.slice(close + 2).trim().split(/\s+/);
        const utime = Number(fields[11]);
        const stime = Number(fields[12]);
        const startTicks = Number(fields[19]);
        const rssMatch = statusText.match(/^VmRSS:\s*(\d+)\s+kB$/m);
        if (![utime, stime, startTicks].every(Number.isFinite)) continue;
        processes.set(pid, { cpuTicks: utime + stime, startTicks, rssKb: rssMatch ? Number(rssMatch[1]) : null });
      } catch (error) {}
    }
  }
  await Promise.all(Array.from({ length: Math.min(24, pids.length) }, readNext));
  return { time: Date.now(), totalTicks, processes };
}

function createProcessSampler() {
  let previous = null;
  const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));

  async function sample() {
    let current = await readSnapshot();
    if (!previous || current.time - previous.time > 10000) {
      previous = current;
      await sleep(350);
      current = await readSnapshot();
    }
    const cpu = new Map();
    const rssKb = new Map();
    const totalDelta = current.totalTicks - previous.totalTicks;
    if (totalDelta > 0) {
      for (const [pid, process] of current.processes) {
        const before = previous.processes.get(pid);
        if (!before || before.startTicks !== process.startTicks) continue;
        const processDelta = process.cpuTicks - before.cpuTicks;
        if (processDelta >= 0) cpu.set(pid, processDelta / totalDelta * 100);
      }
    }
    for (const [pid, process] of current.processes) {
      if (process.rssKb !== null) rssKb.set(pid, process.rssKb);
    }
    previous = current;
    return { cpu, rssKb, sampledAt: current.time };
  }

  return sample;
}

module.exports = { createProcessSampler };
