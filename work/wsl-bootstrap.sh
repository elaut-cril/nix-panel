#!/usr/bin/env bash
set -euo pipefail

SOURCE=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
BASE=$SOURCE/work/wsl-node
RUNTIME=$SOURCE/work/wsl-runtime
NODE_VERSION=22.21.1
NODE_HOME=$BASE/node-v$NODE_VERSION
RELEASE=node-v$NODE_VERSION-linux-x64.tar.xz

mkdir -p "$BASE" "$RUNTIME/public" "$RUNTIME/data" "$RUNTIME/lib"
if [ ! -x "$NODE_HOME/bin/node" ]; then
  curl -fsSL "https://nodejs.org/dist/v$NODE_VERSION/$RELEASE" -o "$BASE/$RELEASE"
  curl -fsSL "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt" -o "$BASE/SHASUMS256.txt"
  (
    cd "$BASE"
    sha256sum --ignore-missing -c SHASUMS256.txt
  )
  mkdir -p "$NODE_HOME"
  tar -xJf "$BASE/$RELEASE" -C "$NODE_HOME" --strip-components=1
fi
export PATH="$NODE_HOME/bin:$PATH"
node --version

cd "$SOURCE"
npm install --package-lock-only --ignore-scripts --no-audit --no-fund
cp "$SOURCE/server.js" "$SOURCE/remote.js" "$SOURCE/remote-portal-worker.js" "$SOURCE/package.json" "$SOURCE/package-lock.json" "$RUNTIME/"
cp "$SOURCE"/lib/*.js "$RUNTIME/lib/"
cp "$SOURCE/public/index.html" "$SOURCE/public/login.html" "$SOURCE/public/block.html" "$RUNTIME/public/"
if [ -d "$SOURCE/public/assets" ]; then
  mkdir -p "$RUNTIME/public/assets"
  cp "$SOURCE/public/assets"/* "$RUNTIME/public/assets/"
fi
cd "$RUNTIME"
npm ci --no-audit --no-fund
