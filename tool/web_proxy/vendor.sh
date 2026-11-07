#!/usr/bin/env bash
# Copy the pinned Scramjet / bare-mux / epoxy browser files into web/proxy so
# `flutter build web` ships them on the app origin (the service worker has to
# be served from there). Unmodified upstream files.
set -euo pipefail
cd "$(dirname "$0")"
[ -d node_modules ] || npm ci --no-audit --no-fund || npm install --no-audit --no-fund
W=../../web/proxy; M=node_modules/@mercuryworkshop
mkdir -p $W/scram $W/baremux $W/libcurl
cp $M/scramjet/dist/scramjet.all.js $M/scramjet/dist/scramjet.sync.js $M/scramjet/dist/scramjet.wasm.wasm $W/scram/
cp $M/bare-mux/dist/index.js $M/bare-mux/dist/worker.js $W/baremux/
cp $M/libcurl-transport/dist/index.mjs $W/libcurl/
cp $M/scramjet/LICENSE $W/scram/LICENSE 2>/dev/null || true
cp $M/bare-mux/LICENSE $W/baremux/LICENSE 2>/dev/null || true
cp $M/libcurl-transport/LICENSE $W/libcurl/LICENSE 2>/dev/null || true
echo vendored
