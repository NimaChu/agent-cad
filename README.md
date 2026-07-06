# Agent CAD Workspace

This folder is a portable wrapper workspace for CAD agents.

```text
E:\agent-cad
├─ upstream\text-to-cad\   # original open-source project, read-mostly
├─ work\                   # your CAD work and generated artifacts
├─ .venv\                  # local Python environment, machine-specific
├─ .agents\skills\         # workspace-local skill links
├─ setup-agent-cad.ps1     # rebuild links and dependencies
└─ start-opencode.ps1      # start opencode with CAD-friendly env vars
```

## Can I copy this to another PC?

Yes, but treat it as a source/workspace copy, not a fully installed app image.

Portable:

- `upstream\text-to-cad`
- `work`
- `AGENTS.md`, `README.md`, and setup scripts

Machine-specific and often needs rebuilding:

- `.venv`
- `node_modules`
- Playwright browser binaries
- Windows junctions under `.agents\skills`, Codex skills, opencode skills, and upstream development symlink paths

After copying, open PowerShell in the copied folder and run:

```powershell
.\setup-agent-cad.ps1 -InstallDeps -InstallViewerDeps -InstallPlaywright
```

Then start opencode from this folder:

```powershell
.\start-opencode.ps1
```

## Daily Use

Keep new CAD work under `work\`, especially `work\models\`.

Use the upstream CAD scripts through the root `.venv`:

```powershell
$env:PYTHONUTF8 = "1"
.\.venv\Scripts\python.exe upstream\text-to-cad\skills\cad\scripts\step work\models\example.py
```

If you intentionally need to modify the open-source project, work inside `upstream\text-to-cad` and follow its `AGENTS.md`.
