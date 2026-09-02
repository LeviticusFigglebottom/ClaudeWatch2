#!/usr/bin/env bash
# Parse gate. Runs Godot's --check-only over every .gd file and reports real parse errors.
#
# Why this exists: `--import` does NOT surface parse errors in scripts that are only loaded at
# runtime (UI screens, hero behaviors, map builders). A broken UI screen imports clean and then
# crashes the moment a player opens it. This catches that.
#
# `--check-only` on a bare script cannot see autoloads, so "Identifier not found: <Autoload>" is a
# false positive and is filtered out. Genuine "Parse Error" lines are what we report.
#
# Usage: tools/parse_check.sh [path ...]      (defaults to src tools tests)
# Exit code 1 if any file has a parse error.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-/opt/godot/Godot_v4.7.2-stable_linux.x86_64}"
JOBS="${JOBS:-4}"
AUTOLOADS='EventBus|Registry|Settings|Console|App'
cd "$ROOT"

check_one() {
  local f="$1"
  local out
  out=$("$GODOT_BIN" --headless --path "$ROOT" --check-only -s "res://$f" 2>&1 \
        | grep -E "Parse Error" \
        | grep -vE "Identifier not found: ($AUTOLOADS)")
  if [ -n "$out" ]; then
    # Emit the whole report as ONE write so parallel jobs cannot interleave their lines.
    printf '%s\n' "PARSE FAIL: $f" "$(echo "$out" | sed 's/^/    /')"
  fi
}
export -f check_one
export ROOT GODOT_BIN AUTOLOADS

TARGETS="${*:-src tools tests}"
mapfile -t FILES < <(find $TARGETS -name '*.gd' 2>/dev/null | sort)
printf '%s\n' "${FILES[@]}" | xargs -P "$JOBS" -I{} bash -c 'check_one "$@"' _ {} > /tmp/parse_check_out.txt 2>&1

FAILS=$(grep -c "^PARSE FAIL" /tmp/parse_check_out.txt || true)
cat /tmp/parse_check_out.txt
echo "checked ${#FILES[@]} scripts, $FAILS with parse errors"
[ "$FAILS" -eq 0 ]
