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

# Providers: CrazyRouter, NVIDIA, OpenCode, Command Code, MiniMax (+ Vercel AI Gateway relay).
# OpenRouter / Groq removed.
map_define CRAZYROUTER_KEY COLLIDER_CRAZYROUTER_KEY
map_define NVIDIA_KEY COLLIDER_NVIDIA_KEY
map_define COMMANDCODE_KEY COLLIDER_COMMANDCODE_KEY
map_define COMMANDCODE_BASE COLLIDER_COMMANDCODE_BASEURL
map_define OPENCODE_KEY COLLIDER_OPENCODE_KEY
map_define MINIMAX_KEY COLLIDER_MINIMAX_KEY
map_define VERCEL_KEY COLLIDER_VERCEL_KEY
map_define COLLIDER_PROXY COLLIDER_PROXY
map_define COLLIDER_THEMES COLLIDER_THEMES

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
  echo "build_web: no provider dart-defines (using compile-time defaults)"
fi

BASE_HREF="${BASE_HREF:-/collider-app/}"
flutter build web --release --base-href "$BASE_HREF" "${DEFINES[@]+"${DEFINES[@]}"}"
echo "build_web: wrote build/web (base-href=$BASE_HREF)"
