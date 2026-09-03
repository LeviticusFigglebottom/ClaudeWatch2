# Blockers and workarounds

Things the build environment could not do, and what was done instead. None of these leave a stub in
the game; they are limits on *how the game was produced*.

| Blocker | Impact | Workaround |
|---|---|---|
| No physical GPU in the build container (Mesa lavapipe only) | Rendering at ~5–10 fps under Xvfb; every screenshot costs 20–40 s | Screenshot harness runs under `xvfb-run` with `--rendering-driver vulkan`; draw-call, primitive and VRAM counts are the meaningful numbers here, and frame times are not: they reflect software rasterisation, not target hardware |
| No audio device | Godot falls back to the dummy audio driver | Audio validated numerically (peak/RMS/duration/spectrogram) by `tools/audio/gen_audio.py`; in-game playback verified only for "no missing id" and bus routing |
| Four CPU cores, single machine | Bot-vs-bot simulation runs ~6.5× real time per process | `tools/sim.py` runs four processes; balance passes report the exact match counts they were based on rather than a round "thousands" |
| No human playtesters | "Bots feel like people" was judged by telemetry (reaction/accuracy distributions, mistake rates) and by reading bot decision traces, not by blind tests | `docs/AI.md` documents the behaviors; `bot_directive` events and the `status` console command expose what bots are thinking |
| No voice actors / TTS | Hero voice lines are non-verbal "radio" stingers per hero (synthesized) rather than spoken lines | Ult callouts use distinct musical motifs per hero, friendly/enemy variants |
| GitHub API access limited to this repository | Third-party Godot addons were cloned over plain git (GUT) rather than through the Asset Library | GUT 9.7 vendored under `addons/gut` |
| Kenney "Animated Characters" packs unavailable at the source URL | No rigged humanoid animations | Heroes use a procedural rig (`HeroRig`) with procedural locomotion/aim/death animation, which also guarantees unique silhouettes |
