#!/usr/bin/env sh
set -eu
ANT_PROJECT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
if command -v godot >/dev/null 2>&1; then
    ANT_ENGINE=godot
else
    ANT_ENGINE=godot4
fi
"$ANT_ENGINE" --headless --path "$ANT_PROJECT_DIR" --script res://tests/run_tests.gd
exec "$ANT_ENGINE" --headless --path "$ANT_PROJECT_DIR" --script res://tests/app_smoke.gd
