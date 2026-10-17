#!/usr/bin/env bash
# v9.1.7: every web build runs the pane guard first; a violation stops it.
# Usage: tool/build_web.sh <out-dir> [extra flutter build args]
set -euo pipefail
cd "$(dirname "$0")/.."
out="$1"; shift
dart run tool/pane_guard.dart
flutter build web --release --base-href /collider-app/ -o "$out" "$@"
