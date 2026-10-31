#!/usr/bin/env bash
# Build Flutter web for Collider. Maps box env COLLIDER_* → --dart-define
# without printing or logging key values.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export PATH="${FLUTTER_BIN:-/home/box/flutter/bin}:$PATH"

DEFINES=()
# name_in_dart|env_var
map_define() {
  local dart_name="$1" env_name="$2"
  local val="${!env_name-}"
  if [[ -n "${val}" ]]; then
    DEFINES+=(--dart-define="${dart_name}=${val}")
  fi
}

# Production web: COLLIDER_PROXY only (Cloudflare Worker holds keys).
# Optional provider dart-defines are for non-web / emergency — omit on Pages builds.
# OpenRouter / Groq / Vercel removed from the browser bundle.
map_define COLLIDER_PROXY COLLIDER_PROXY
map_define COLLIDER_THEMES COLLIDER_THEMES
# Emergency-only (empty in CI web builds):
if [[ "${COLLIDER_ALLOW_EMBEDDED_KEYS:-}" == "1" ]]; then
  map_define CRAZYROUTER_KEY COLLIDER_CRAZYROUTER_KEY
  map_define NVIDIA_KEY COLLIDER_NVIDIA_KEY
  map_define COMMANDCODE_KEY COLLIDER_COMMANDCODE_KEY
  map_define COMMANDCODE_BASE COLLIDER_COMMANDCODE_BASEURL
  map_define OPENCODE_KEY COLLIDER_OPENCODE_KEY
  map_define MINIMAX_KEY COLLIDER_MINIMAX_KEY
fi

# Report which defines are present (names only — never values).
present=()
for d in "${DEFINES[@]+"${DEFINES[@]}"}"; do
  # --dart-define=NAME=...
  name="${d#--dart-define=}"
  name="${name%%=*}"
  present+=("$name")
done
if ((${#present[@]})); then
  echo "build_web: dart-defines present: ${present[*]}"
else
  echo "build_web: no dart-defines beyond script defaults (keys must be empty; use COLLIDER_PROXY)"
fi

BASE_HREF="${BASE_HREF:-/collider-app/}"
flutter build web --release --base-href "$BASE_HREF" "${DEFINES[@]+"${DEFINES[@]}"}"
echo "build_web: wrote build/web (base-href=$BASE_HREF)"
