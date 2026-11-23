#!/usr/bin/env bash
set -euo pipefail

SOURCE=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
BASE=$SOURCE/work/wsl-node
RUNTIME=$SOURCE/work/wsl-runtime
NODE_HOME=$BASE/node-v22.21.1
export PATH="$NODE_HOME/bin:$PATH"

if [ ! -f "$RUNTIME/nix-config.json" ]; then
  RUNTIME="$RUNTIME" node <<'NODE'
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const runtime = process.env.RUNTIME;
const dataDir = path.join(runtime, 'data');
fs.mkdirSync(dataDir, { recursive: true });
const config = {
  port: 8081,
  host: '127.0.0.1',
  startPath: '/',
  dataDir,
  sessionSecret: crypto.randomBytes(48).toString('hex'),
  language: 'ru',
  httpRedirect: false
};
fs.writeFileSync(path.join(runtime, 'nix-config.json'), JSON.stringify(config, null, 2), { mode: 0o600 });
NODE
fi

cd "$RUNTIME"
exec node server.js
