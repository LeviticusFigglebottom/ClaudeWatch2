#!/usr/bin/env bash
# Runs the GUT unit suite headless. Exit code = test result.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/tools/godot.sh" --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | grep -vE "ALSA|snd_|audio_driver|dummy driver"
