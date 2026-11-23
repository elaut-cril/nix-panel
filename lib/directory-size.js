'use strict';

const fs = require('fs');
const path = require('path');

async function directorySize(root, options = {}) {
  const deadline = options.deadline ?? Date.now() + 1500;
  const budget = options.budget || { entries: 0, maxEntries: 8000 };
  const shouldSkip = options.shouldSkip || (() => false);
  let total = 0;
  let complete = true;

  async function walk(directory, depth) {
    if (depth > 256 || Date.now() >= deadline || budget.entries >= budget.maxEntries) {
      complete = false;
      return;
    }
    let handle;
    try {
      handle = await fs.promises.opendir(directory);
    } catch (error) {
      complete = false;
      return;
    }
    try {
      for await (const entry of handle) {
        if (Date.now() >= deadline || budget.entries >= budget.maxEntries) {
          complete = false;
          break;
        }
        budget.entries++;
        const fullPath = path.join(directory, entry.name);
        if (shouldSkip(fullPath)) {
          complete = false;
          continue;
        }
        if (entry.isSymbolicLink()) continue;
        if (entry.isDirectory()) {
          await walk(fullPath, depth + 1);
          continue;
        }
        if (!entry.isFile()) continue;
        try {
          const stat = await fs.promises.stat(fullPath);
          total += stat.size;
        } catch (error) {
          complete = false;
        }
      }
    } catch (error) {
      complete = false;
    }
  }

  await walk(root, 0);
  return { size: total, partial: !complete, entries: budget.entries };
}

module.exports = { directorySize };
