#!/usr/bin/env bash
# Workers Builds: pull the Flutter web zip already published by the release
# pipeline (no Flutter SDK on the Cloudflare image). Override with:
#   COLLIDER_WEB_ZIP_URL=https://...
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
TAG="${COLLIDER_WEB_RELEASE_TAG:-v9.2.0-smartgen}"
ASSET="${COLLIDER_WEB_ZIP_ASSET:-collider-9.2.0-web.zip}"
URL="${COLLIDER_WEB_ZIP_URL:-https://github.com/Davidebri1/collider-source/releases/download/${TAG}/${ASSET}}"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
echo "Fetching $URL"
curl -fsSL -o "$tmp/web.zip" "$URL"
rm -rf "$DIST"
mkdir -p "$DIST"
unzip -q "$tmp/web.zip" -d "$tmp/out"
# Zip may be flat build/web contents, or nested (build/web, web/, collider-app/).
if [[ -f "$tmp/out/index.html" ]]; then
  cp -a "$tmp/out"/. "$DIST"/
elif [[ -f "$tmp/out/web/index.html" ]]; then
  cp -a "$tmp/out/web"/. "$DIST"/
elif [[ -f "$tmp/out/build/web/index.html" ]]; then
  cp -a "$tmp/out/build/web"/. "$DIST"/
else
  # Single top-level folder
  inner="$(find "$tmp/out" -maxdepth 2 -name index.html | head -1)"
  if [[ -z "$inner" ]]; then
    echo "No index.html in zip" >&2
    exit 1
  fi
  cp -a "$(dirname "$inner")"/. "$DIST"/
fi
# Keep a placeholder if somehow empty
test -f "$DIST/index.html"
echo "dist ready: $(find "$DIST" | wc -l) files"
