#!/usr/bin/env bash
# Fail the build if Smart Gen AppBars regress to left-aligned titles.
# Allowed centerTitle: false only when the same AppBar hosts a TextField (data input).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
fail=0

# Theme must centre AppBar titles by default (multi-line AppBarTheme OK).
if ! rg -U -q 'appBarTheme:\s*const AppBarTheme\([\s\S]*?centerTitle:\s*true' packages/smartgen_planka/lib/main.dart; then
  echo "FAIL: packages/smartgen_planka/lib/main.dart missing appBarTheme centerTitle: true"
  fail=1
fi

# Any centerTitle: false must sit in an AppBar whose title is a TextField.
while IFS= read -r hit; do
  file="${hit%%:*}"
  line="${hit#*:}"; line="${line%%:*}"
  # Pull a window around the hit and require TextField in the AppBar block.
  start=$((line > 12 ? line - 12 : 1))
  end=$((line + 20))
  window="$(sed -n "${start},${end}p" "$file")"
  if ! printf '%s\n' "$window" | grep -q 'TextField'; then
    echo "FAIL: $file:$line centerTitle: false without nearby TextField (data-input exception)"
    fail=1
  fi
done < <(rg -n 'centerTitle:\s*false' packages/smartgen_planka/lib lib/features/smartgen --glob '*.dart' || true)

# Board menu must not force left.
if rg -n 'centerTitle:\s*false' packages/smartgen_planka/lib/features/board_menu --glob '*.dart' >/dev/null 2>&1; then
  echo "FAIL: Board menu must not set centerTitle: false"
  fail=1
fi

if ((fail)); then
  echo "check_smartgen_headers: FAILED"
  exit 1
fi
echo "check_smartgen_headers: OK"
