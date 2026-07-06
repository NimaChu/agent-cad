# Agent CAD Workspace

This outer directory is the user workspace. Keep upstream source code and user CAD work separate.

## Layout

- `upstream/text-to-cad/`: read-mostly checkout of `earthtojake/text-to-cad`.
- `work/`: user-owned CAD briefs, generated models, references, and scratch files.
- `.venv/`: local Python runtime for this workspace; recreate it on another machine.
- `.agents/skills/`: workspace-local skill links created by `setup-agent-cad.ps1`.

## Editing Rules

- On first use on a new computer, run `.\doctor-agent-cad.ps1`. If it reports missing dependencies, run `.\setup-agent-cad.ps1 -InstallDeps -InstallViewerDeps -InstallPlaywright` before CAD generation.
- If `upstream/text-to-cad/AGENTS.md` is missing, run `git submodule update --init --recursive` or `.\setup-agent-cad.ps1`.
- Do not edit files under `upstream/text-to-cad/` unless the user explicitly asks to modify the upstream project or fix its code.
- Put user CAD generators, STEP/STP, STL, 3MF, GLB, DXF, URDF, SRDF, SDF, G-code, snapshots, and notes under `work/`.
- Prefer `work/models/` for durable CAD and robot-description artifacts.
- Use `work/scratch/` for disposable experiments.
- If upstream work is requested, follow `upstream/text-to-cad/AGENTS.md` and work from its `develop` branch.

## Commands

Use the upstream skills and scripts, but run them from this outer workspace so paths resolve into `work/`:

```powershell
$env:PYTHONUTF8 = "1"
.\.venv\Scripts\python.exe upstream\text-to-cad\skills\cad\scripts\step work\models\part.py
.\.venv\Scripts\python.exe upstream\text-to-cad\skills\cad\scripts\inspect refs work\models\part.step --facts --planes --positioning
.\.venv\Scripts\python.exe upstream\text-to-cad\skills\cad\scripts\snapshot --input work\models\part.step --output work\models\snapshots\part.png --camera iso
```

Start CAD Viewer against the user model area:

```powershell
node upstream\text-to-cad\viewer\scripts\start-agent-viewer.mjs --host 127.0.0.1 --dir "$PWD\work\models" --json
```

Run `.\doctor-agent-cad.ps1` after copying this workspace to another computer. Run `.\setup-agent-cad.ps1 -InstallDeps -InstallViewerDeps -InstallPlaywright` if the doctor reports missing items.
