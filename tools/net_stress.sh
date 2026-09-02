#!/usr/bin/env bash
# Network stress: runs a local match with simulated latency/loss/jitter on the client and prints
# reconciliation statistics. Usage: tools/net_stress.sh [latency_ms] [loss 0..1] [jitter_ms] [ticks]
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LAT="${1:-120}"; LOSS="${2:-0.05}"; JIT="${3:-30}"; TICKS="${4:-1800}"
FILTER='ALSA|snd_|audio_driver|dummy driver|Godot Engine|^$|missing sound|WARNING|at: |GDScript backtrace|^\s+\[[0-9]+\]|cell height|mismatch|This warning|The cell|navigation mesh|ceiled|floored'
"$ROOT/tools/godot.sh" --headless -- --client --cmd "map test_range control 9; wait 300; lag $LAT $LOSS $JIT; wait $TICKS; net_stats; status; quit" 2>&1 | grep -vE "$FILTER" | grep -E "console|SCRIPT ERROR|ping|k/d" | head -40
