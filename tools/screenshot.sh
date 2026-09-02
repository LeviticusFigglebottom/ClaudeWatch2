#!/usr/bin/env bash
# Screenshot harness: runs the game under Xvfb with lavapipe and executes console commands.
# Usage: tools/screenshot.sh "<console commands separated by ;>" [WxH]
#   e.g. tools/screenshot.sh "map kestrel control 4; wait 300; hero vesper; wait 200; shot screenshots/kestrel_fp.png; wait 5; cam_overview; wait 10; shot screenshots/kestrel_ov.png; wait 5; quit"
# Console commands: map <id> [mode] [bots], hero <id>, wait <ticks>, shot <path>, cam x y z yaw pitch [fov],
#   cam_follow <net_id|local> [dist], cam_overview, cam_off, set <cvar> <v>, timescale <f>, status, quit.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CMDS="${1:-wait 60; shot screenshots/menu.png; wait 5; quit}"
RES="${2:-1600x900}"
mkdir -p "$ROOT/screenshots"
xvfb-run -a -s "-screen 0 ${RES}x24" "$ROOT/tools/godot.sh" --rendering-driver vulkan --resolution "$RES" -- --client --cmd "$CMDS" 2>&1 \
  | grep -E "saved|SCRIPT ERROR|Parse Error|\[console\] >" | grep -v "^\[console\] > wait"
