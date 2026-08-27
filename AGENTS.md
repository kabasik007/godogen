# Godogen Source Repo

This repository is not a published game repo. It is the source that `publish.sh` (Linux/macOS) or `publish.ps1` (Windows) renders into a runtime game repo for a chosen engine and host agent.

## Source Layout

- `prompts/runtime.md` — the engine-agnostic runtime manifest text
- `asset-gen/` — the asset-generation skill (CLI tools + docs), the one skill every published repo carries
- `engines/babylon.md`, `engines/godot.md`, `engines/bevy.md` — per-engine guides (stack, project sketch, capture recipe, silent-failure traps)
- `publish.sh` — renders a runtime repo with `--engine {godot,bevy,babylon}`, `--agent {claude,codex}` on POSIX hosts
- `publish.ps1` — native Windows PowerShell publisher with equivalent `-Engine`, `-Agent`, `-Out`, and `-Force` options
- `scripts/` — render helpers: `render_dir.py` (token substitution), `generate_codex_metadata.py` (Codex `openai.yaml`), plus Windows preflight diagnostics

## Editing Rules

- Do not create or maintain `.claude/skills/` or `.agents/skills/` in this source repo.
- Keep `publish.sh` and `publish.ps1` behavior aligned when publisher semantics or template tokens change.
- Runtime docs must not assume Bash when the operation can run on Windows; use rendered host tokens or include a PowerShell equivalent for shell-specific commands.
- Don't give obvious guidance. The agent is a highly capable LLM, and the deliverable (a recorded video, or a live URL the user watches) surfaces its own mistakes — so keep the guides to what the model can't infer or discover fast.
- When you change or remove a feature, describe the new state on its own terms. Name the new thing as if it were always the design.
