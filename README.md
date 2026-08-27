# Godogen

Autonomous game development for Godot, Bevy, and Babylon.js with Claude Code and Codex.

[![Watch the video](https://img.youtube.com/vi/eUz19GROIpY/maxresdefault.jpg)](https://youtu.be/eUz19GROIpY)

[Watch the demos](https://youtu.be/eUz19GROIpY) · [Prompts](docs/demo_prompts.md)

Describe a game. The agent builds it, generates assets, runs the engine, and proves the result — as a live game you watch and steer, or as a recorded video when you're not there. It reads the situation and decides which, in the run.

This repo is not a game. It is the source for a generator that produces games: **godogen -> game repo -> game**. You publish into a fresh game repo — choosing engine and host-agent flavor — then the agent runs inside that repo and builds the actual game from a short engine guide.

## Source layout

A published repo is intentionally thin: a runtime manifest, a one-page engine guide, and the asset-generation skill. The agent recreates everything else (project scaffold, capture tooling) from the guide.

- `prompts/runtime.md` — the runtime manifest
- `asset-gen/` — the cross-engine asset-generation skill
- `engines/babylon.md`, `engines/godot.md`, `engines/bevy.md` — per-engine guides
- [publish.sh](publish.sh) — publisher for Linux/macOS
- [publish.ps1](publish.ps1) — native PowerShell publisher for Windows

Engine and host agent (Claude vs Codex) are publish-time render choices, not separate source trees.

## What the agent does

- **Godot 4** — C#/.NET projects with build-time scene generation, runtime scripts, and Jolt physics.
- **Bevy** — Rust/Bevy projects with code-first ECS scenes and offscreen capture.
- **Babylon.js** — TypeScript/Vite browser games served at a live URL.
- **Asset generation** — Gemini for precise references and characters, xAI Grok for textures and simple objects, Tripo3D for image-to-3D and rigged biped animation; animated sprites via Grok video with loop detection and background removal.
- **Proof over claims** — the agent judges results from the running game (a live URL or a recorded clip), not from a clean compile, so visible defects drive the next iteration.
- **You choose your involvement** — watch the live game (a Babylon.js URL, or a Godot/Bevy project you run) and steer at decision points, or leave the run unattended and get a 15–20s proof recording at the end. The agent takes its cue from how you frame the task.

## Getting started

### Prerequisites

- [Godot 4](https://godotengine.org/download/) **.NET build** on `PATH` for Godot projects
- .NET 9 SDK for current Godot C# projects
- Rust/Cargo for Bevy projects
- Node.js 22.12+ and npm for Babylon.js projects
- Chrome or Chromium with hardware WebGL2 for Babylon.js browser capture
- Python 3.10+ with pip
- `ffmpeg` for proof-video encoding; ImageMagick is used by some asset workflows
- API keys as environment variables when paid asset generation is used:
  - `GOOGLE_API_KEY` — [Google AI Studio](https://aistudio.google.com/) for Gemini image generation
  - `XAI_API_KEY` — [xAI Grok](https://console.x.ai/home) for image/video generation
  - `TRIPO3D_API_KEY` — [Tripo3D](https://platform.tripo3d.ai/) for 3D generation
- Claude Code or Codex

See [setup.md](setup.md) for Linux, macOS, and Windows setup details. `xvfb` and `vulkan-tools` are Linux-specific; Windows does not require Xvfb for Godot capture.

### Publish a game repo — Linux/macOS

Pick the engine and host agent:

```bash
./publish.sh --engine godot   --agent claude --out ~/my-game       # CLAUDE.md + .claude/skills/
./publish.sh --engine babylon --agent codex  --out ~/my-game       # AGENTS.md + .agents/skills/
./publish.sh --engine bevy    --agent claude --out ~/my-game
```

Pass `--force` to wipe existing contents at the target before re-publishing.

### Publish a game repo — Windows

Use native PowerShell; WSL, Bash, and `rsync` are not required:

```powershell
.\publish.ps1 -Engine godot -Agent codex -Out C:\games\my-game
Set-Location C:\games\my-game
codex
```

If script execution is blocked by local policy, use a process-only bypass instead of changing the machine-wide policy:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\publish.ps1 -Engine godot -Agent codex -Out C:\games\my-game
```

For Godot, verify the exact environment that Codex will inherit before starting a run:

```powershell
dotnet --version
godot --version
godot --headless --quit
codex --version
```

`godot --version` must report a Mono/.NET build. Merely having a Godot desktop shortcut is not enough — the CLI must be callable from the shell used to start Codex.

## Running on a server

A full generation run can take hours, so it's convenient to offload it to a server — ideally a GPU instance, since engine rendering and video capture are much faster with hardware acceleration.

- Keep the session alive across SSH drops with `tmux` or `screen`.
- Enable remote control so you can check in and steer the run from any device — both Claude Code and Codex have official remote-control interfaces.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

Follow progress: [@alex_erm](https://x.com/alex_erm)
