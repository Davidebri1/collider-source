#!/usr/bin/env bash
# v9.1.7: every web build runs the pane guard first; a violation stops it.
# Usage: tool/build_web.sh <out-dir> [extra flutter build args]
set -euo pipefail
cd "$(dirname "$0")/.."
out="$1"; shift
dart run tool/pane_guard.dart
# batch 4: every pane centred on the full screen (fails if > 2 px off).
flutter test test/cpane_centre_test.dart test/side_nav_clear_test.dart test/pane_rect_report_test.dart
flutter build web --release --base-href /collider-app/ -o "$out" "$@"
