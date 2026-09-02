#!/usr/bin/env bash
# Full validation: import, build hero data, run a short headless bot match, report script errors.
# Usage: tools/check.sh [map] [mode] [ticks]
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MAP="${1:-test_range}"; MODE="${2:-control}"; TICKS="${3:-900}"
FILTER='ALSA|snd_|audio_driver|dummy driver|Godot Engine|^$|GUT\] Could not get version|cell height|mismatch|This warning|The cell|navigation mesh that uses|ceiled|floored|at: generator_bake|non-equal opposite anchors|consider using set_deferred|_set_size'
cd "$ROOT"
echo "== import"; "$ROOT/tools/godot.sh" --headless --import 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error|Failed to load" | head -30
echo "== build data"; "$ROOT/tools/godot.sh" --headless res://tools/build_data.tscn 2>&1 | grep -vE "$FILTER" | grep -E "ERROR|built|FAIL" | head -40
echo "== match $MAP/$MODE for $TICKS ticks"
"$ROOT/tools/godot.sh" --headless -- --client --cmd "map $MAP $MODE 9; wait $TICKS; status; quit" 2>&1 | grep -vE "$FILTER" | grep -vE "^\s+\[[0-9]+\] |GDScript backtrace|^\s+at: |missing sound id" | head -80
