#!/usr/bin/env bash
# Runs the Godot 4.7.2 binary serialized through a lock so parallel authors don't corrupt the import cache.
# Usage: tools/godot.sh [godot args...]   (from the repo root)
set -euo pipefail
GODOT_BIN="${GODOT_BIN:-/opt/godot/Godot_v4.7.2-stable_linux.x86_64}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCK="/tmp/ringfall_godot.lock"
exec flock "$LOCK" "$GODOT_BIN" --path "$ROOT" "$@"
