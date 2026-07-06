# Agent CAD Workspace

This folder is a portable wrapper workspace for CAD agents.

```text
E:\agent-cad
+-- upstream\text-to-cad\   # original open-source project, read-mostly
+-- work\                   # your CAD work and generated artifacts
+-- .venv\                  # local Python environment, machine-specific
+-- .agents\skills\         # workspace-local skill links
+-- doctor-agent-cad.ps1    # report missing dependencies/config
+-- setup-agent-cad.ps1     # rebuild links and dependencies
+-- start-opencode.ps1      # start opencode with CAD-friendly env vars
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

After cloning or copying, open PowerShell in the workspace folder and run the doctor:

```powershell
.\doctor-agent-cad.ps1
```

If anything is missing, run:

```powershell
.\setup-agent-cad.ps1 -InstallDeps -InstallViewerDeps -InstallPlaywright
```

Then start opencode from this folder:

```powershell
.\start-opencode.ps1
```

## Daily Use

Keep new CAD work under `work\`, especially `work\models\`.

opencode desktop loads `.opencode/plugins/agent-cad-bootstrap.js` from this workspace. On workspace load it runs `doctor-agent-cad.ps1`; if setup is missing, it runs `setup-agent-cad.ps1 -InstallDeps -InstallViewerDeps -InstallPlaywright` automatically. For manual shells, run `doctor-agent-cad.ps1` when you want an explicit readiness report.

Use the upstream CAD scripts through the root `.venv`:

```powershell
$env:PYTHONUTF8 = "1"
.\.venv\Scripts\python.exe upstream\text-to-cad\skills\cad\scripts\step work\models\example.py
```

If you intentionally need to modify the open-source project, work inside `upstream\text-to-cad` and follow its `AGENTS.md`.

## Clone From GitHub

Preferred:

```powershell
git clone --recurse-submodules https://github.com/NimaChu/agent-cad.git
cd agent-cad
.\doctor-agent-cad.ps1
```

If cloned without submodules, `setup-agent-cad.ps1` will initialize `upstream\text-to-cad` automatically.
