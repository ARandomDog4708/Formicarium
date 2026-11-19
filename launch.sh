#!/usr/bin/env sh
set -eu
ANT_PROJECT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
if command -v godot >/dev/null 2>&1; then
    ANT_ENGINE=godot
elif command -v godot4 >/dev/null 2>&1; then
    ANT_ENGINE=godot4
else
    echo "Install Godot 4.6 or newer from https://godotengine.org/download/"
    echo "Then open project.godot and press F5."
    exit 1
fi
if [ ! -d "$ANT_PROJECT_DIR/.godot" ]; then
    "$ANT_ENGINE" --headless --editor --path "$ANT_PROJECT_DIR" --import --quit
fi
exec "$ANT_ENGINE" --path "$ANT_PROJECT_DIR" "$@"
