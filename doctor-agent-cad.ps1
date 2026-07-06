param(
  [switch]$Json
)

$WorkspaceRoot = $PSScriptRoot
$UpstreamRoot = Join-Path $WorkspaceRoot "upstream\text-to-cad"
$PythonExe = Join-Path $WorkspaceRoot ".venv\Scripts\python.exe"
$ViewerRoot = Join-Path $UpstreamRoot "viewer"
$Checks = New-Object System.Collections.Generic.List[object]

function Add-Check {
  param(
    [string]$Name,
    [bool]$Ok,
    [string]$Detail,
    [string]$Fix = ""
  )
  $Checks.Add([pscustomobject]@{
    name = $Name
    ok = $Ok
    detail = $Detail
    fix = $Fix
  }) | Out-Null
}

function Command-Exists {
  param([string]$Name)
  return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Test-Command {
  param(
    [string]$Name,
    [string[]]$CommandArgs = @("--version")
  )
  if (-not (Command-Exists $Name)) {
    Add-Check $Name $false "$Name is not on PATH." "Install $Name and reopen PowerShell."
    return
  }
  try {
    $output = & $Name @CommandArgs 2>&1 | Select-Object -First 1
    Add-Check $Name $true ([string]$output)
  } catch {
    Add-Check $Name $false "$Name exists but failed: $($_.Exception.Message)" "Check the $Name installation."
  }
}

Test-Command -Name git -CommandArgs @("--version")
Test-Command -Name node -CommandArgs @("--version")
Test-Command -Name npm -CommandArgs @("--version")

$upstreamOk = Test-Path -LiteralPath (Join-Path $UpstreamRoot "AGENTS.md")
Add-Check "upstream submodule" $upstreamOk $UpstreamRoot "Run: git submodule update --init --recursive, or .\setup-agent-cad.ps1"

$workOk = Test-Path -LiteralPath (Join-Path $WorkspaceRoot "work\README.md")
Add-Check "work area" $workOk (Join-Path $WorkspaceRoot "work") "Run: .\setup-agent-cad.ps1"

$pythonOk = Test-Path -LiteralPath $PythonExe
Add-Check ".venv python" $pythonOk $PythonExe "Run: .\setup-agent-cad.ps1 -InstallDeps"

if ($pythonOk) {
  try {
    $env:PYTHONUTF8 = "1"
    $importOutput = & $PythonExe -c "import cadpy, build123d, ezdxf, trimesh, playwright; print('python CAD imports ok')" 2>&1
    Add-Check "python CAD packages" $true ([string]($importOutput | Select-Object -Last 1))
  } catch {
    Add-Check "python CAD packages" $false "Required Python packages are missing or stale." "Run: .\setup-agent-cad.ps1 -InstallDeps"
  }

  try {
    $pwOutput = & $PythonExe -c "from pathlib import Path; import os; root=Path(os.environ.get('LOCALAPPDATA',''))/'ms-playwright'; ok=any(root.glob('chromium_headless_shell-*')); print('playwright chromium ok' if ok else 'missing')" 2>&1
    $pwOk = ([string]($pwOutput | Select-Object -Last 1)) -match "ok"
    Add-Check "Playwright Chromium" $pwOk ([string]($pwOutput | Select-Object -Last 1)) "Run: .\setup-agent-cad.ps1 -InstallPlaywright"
  } catch {
    Add-Check "Playwright Chromium" $false "Could not check Playwright browsers." "Run: .\setup-agent-cad.ps1 -InstallPlaywright"
  }
}

$viewerDepsOk = Test-Path -LiteralPath (Join-Path $ViewerRoot "node_modules\.bin\vite.cmd")
Add-Check "viewer npm deps" $viewerDepsOk (Join-Path $ViewerRoot "node_modules") "Run: .\setup-agent-cad.ps1 -InstallViewerDeps"

$localCadSkill = Join-Path $WorkspaceRoot ".agents\skills\cad\SKILL.md"
$opencodeCadSkill = Join-Path $env:USERPROFILE ".config\opencode\skills\cad\SKILL.md"
$codexCadSkill = Join-Path $env:USERPROFILE ".codex\skills\cad\SKILL.md"
Add-Check "workspace cad skill link" (Test-Path -LiteralPath $localCadSkill) $localCadSkill "Run: .\setup-agent-cad.ps1"
Add-Check "opencode cad skill link" (Test-Path -LiteralPath $opencodeCadSkill) $opencodeCadSkill "Run: .\setup-agent-cad.ps1"
Add-Check "codex cad skill link" (Test-Path -LiteralPath $codexCadSkill) $codexCadSkill "Run: .\setup-agent-cad.ps1"

if ($Json) {
  $Checks | ConvertTo-Json -Depth 4
} else {
  foreach ($check in $Checks) {
    $prefix = if ($check.ok) { "[OK]  " } else { "[MISS]" }
    Write-Host "$prefix $($check.name): $($check.detail)"
    if (-not $check.ok -and $check.fix) {
      Write-Host "       fix: $($check.fix)"
    }
  }
  $missing = @($Checks | Where-Object { -not $_.ok })
  Write-Host ""
  if ($missing.Count -eq 0) {
    Write-Host "Agent CAD workspace looks ready."
  } else {
    Write-Host "$($missing.Count) item(s) need attention."
  }
}

if (@($Checks | Where-Object { -not $_.ok }).Count -gt 0) {
  exit 1
}
