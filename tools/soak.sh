#!/usr/bin/env bash
# Soak test: a long headless bot match with periodic perf/status sampling and error capture.
# Usage: tools/soak.sh [map] [mode] [minutes]
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MAP="${1:-test_range}"; MODE="${2:-control}"; MIN="${3:-10}"
TICKS=$((MIN * 60 * 60))
CMDS="map $MAP $MODE 9"
for i in $(seq 1 "$MIN"); do CMDS="$CMDS; wait 3600; perf; status"; done
CMDS="$CMDS; quit"
mkdir -p "$ROOT/sim_out"
LOG="$ROOT/sim_out/soak_${MAP}_${MODE}.log"
"$ROOT/tools/godot.sh" --headless --fixed-fps 60 -- --client --cmd "$CMDS" > "$LOG" 2>&1
echo "== soak $MAP/$MODE ${MIN} min (sim) -> $LOG"
grep -cE "SCRIPT ERROR" "$LOG" | sed 's/^/script errors: /'
grep -E "^\[console\] (fps|mem|draw|server tick|tick )" "$LOG" | tail -12
grep -E "SCRIPT ERROR" -A3 "$LOG" | head -30
