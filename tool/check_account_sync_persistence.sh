#!/usr/bin/env bash
# Fails if feature code writes SharedPreferences or FileBlobs persistence
# outside lib/core/account_sync (and FileBlobs implementation / openExternal).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
fail=0

# SharedPreferences.getInstance outside account_sync
hits=$(rg -n 'SharedPreferences\.getInstance' lib packages --type dart -g '!**/test/**' -g '!**/account_sync/**' || true)
if [[ -n "$hits" ]]; then
  echo "FAIL: SharedPreferences.getInstance outside account_sync:"
  echo "$hits"
  fail=1
fi

# FileBlobs.put/get/delete/keys outside account_sync and file_blobs_* 
hits=$(rg -n 'FileBlobs\.(put|get|delete|keys)\(' lib packages --type dart -g '!**/test/**' -g '!**/account_sync/**' -g '!**/file_blobs*.dart' || true)
if [[ -n "$hits" ]]; then
  echo "FAIL: FileBlobs persistence outside account_sync:"
  echo "$hits"
  fail=1
fi

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "OK: account sync persistence guard"
