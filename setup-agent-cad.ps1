param(
  [switch]$InstallDeps,
  [switch]$InstallViewerDeps,
  [switch]$InstallPlaywright,
  [string]$Proxy = ""
)

$ErrorActionPreference = "Stop"

$WorkspaceRoot = $PSScriptRoot
$UpstreamRoot = Join-Path $WorkspaceRoot "upstream\text-to-cad"
$WorkRoot = Join-Path $WorkspaceRoot "work"
$PythonExe = Join-Path $WorkspaceRoot ".venv\Scripts\python.exe"

function Ensure-UpstreamCheckout {
  if (Test-Path -LiteralPath (Join-Path $UpstreamRoot "AGENTS.md")) {
    return
  }
  if (-not (Test-Path -LiteralPath (Join-Path $WorkspaceRoot ".gitmodules"))) {
    throw "Missing upstream checkout and .gitmodules: $UpstreamRoot"
  }
  Write-Host "initializing upstream submodule..."
  git -C $WorkspaceRoot submodule update --init --recursive upstream/text-to-cad
  if (-not (Test-Path -LiteralPath (Join-Path $UpstreamRoot "AGENTS.md"))) {
    throw "Failed to initialize upstream checkout: $UpstreamRoot"
  }
}

function Get-WorkspaceProxy {
  if ($Proxy) {
    return $Proxy
  }
  if ($env:HTTPS_PROXY) {
    return $env:HTTPS_PROXY
  }
  if ($env:HTTP_PROXY) {
    return $env:HTTP_PROXY
  }
  try {
    $internetSettings = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    if ($internetSettings.ProxyEnable -eq 1 -and $internetSettings.ProxyServer) {
      return [string]$internetSettings.ProxyServer
    }
  } catch {
  }
  return ""
}

function Remove-ReparseOrFile {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    return
  }
  $item = Get-Item -LiteralPath $Path -Force
  if ($item.PSIsContainer -and ($item.LinkType -eq "Junction" -or $item.LinkType -eq "SymbolicLink")) {
    [System.IO.Directory]::Delete($Path)
    return
  }
  if (-not $item.PSIsContainer) {
    Remove-Item -LiteralPath $Path -Force
    return
  }
  throw "Refusing to replace real directory: $Path"
}

function Ensure-Junction {
  param(
    [string]$Link,
    [string]$Target
  )
  $resolvedTarget = [System.IO.Path]::GetFullPath($Target)
  if (-not (Test-Path -LiteralPath $resolvedTarget -PathType Container)) {
    throw "Junction target does not exist: $resolvedTarget"
  }
  if (Test-Path -LiteralPath $Link) {
    $item = Get-Item -LiteralPath $Link -Force
    $currentTarget = @($item.Target)[0]
    if (($item.LinkType -eq "Junction" -or $item.LinkType -eq "SymbolicLink") -and $currentTarget -eq $resolvedTarget) {
      Write-Host "ok: $Link -> $resolvedTarget"
      return
    }
    Remove-ReparseOrFile -Path $Link
  }
  New-Item -ItemType Junction -Path $Link -Target $resolvedTarget | Out-Null
  Write-Host "linked: $Link -> $resolvedTarget"
}

function Ensure-WorkDirs {
  foreach ($dir in @(
    $WorkRoot,
    (Join-Path $WorkRoot "models"),
    (Join-Path $WorkRoot "briefs"),
    (Join-Path $WorkRoot "references"),
    (Join-Path $WorkRoot "scratch"),
    (Join-Path $WorkspaceRoot ".agents\skills")
  )) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
}

function Configure-GitProxy {
  param([string]$ProxyUrl)
  if (-not $ProxyUrl) {
    return
  }
  git -C $UpstreamRoot config http.proxy $ProxyUrl
  git -C $UpstreamRoot config https.proxy $ProxyUrl
  Write-Host "configured upstream git proxy: $ProxyUrl"
}

function Restore-UpstreamJunctions {
  $records = git -C $UpstreamRoot ls-files -s | Where-Object { $_ -match "^120000 " }
  $links = @()
  foreach ($record in $records) {
    $rel = ($record -split "`t", 2)[1]
    $links += $rel
    $linkPath = Join-Path $UpstreamRoot ($rel -replace "/", [System.IO.Path]::DirectorySeparatorChar)
    $targetText = git -C $UpstreamRoot cat-file -p "HEAD:$rel"
    $targetPath = [System.IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $linkPath) $targetText))
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $linkPath) | Out-Null
    Ensure-Junction -Link $linkPath -Target $targetPath
  }
  if ($links.Count -gt 0) {
    git -C $UpstreamRoot update-index --skip-worktree -- $links
  }
}

function Link-AgentSkills {
  $skillsRoot = Join-Path $UpstreamRoot "skills"
  $skillNames = Get-ChildItem -LiteralPath $skillsRoot -Directory |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "SKILL.md") } |
    Select-Object -ExpandProperty Name

  $destinations = @(
    (Join-Path $env:USERPROFILE ".codex\skills"),
    (Join-Path $env:USERPROFILE ".config\opencode\skills"),
    (Join-Path $WorkspaceRoot ".agents\skills")
  )

  foreach ($destination in $destinations) {
    New-Item -ItemType Directory -Force -Path $destination | Out-Null
    foreach ($skill in $skillNames) {
      $source = Join-Path $skillsRoot $skill
      $link = Join-Path $destination $skill
      Ensure-Junction -Link $link -Target $source
    }
  }
}

function Install-PythonDeps {
  $env:PYTHONUTF8 = "1"
  if (-not (Test-Path -LiteralPath $PythonExe)) {
    python -m venv (Join-Path $WorkspaceRoot ".venv")
  }
  & $PythonExe -m pip install --upgrade pip
  & $PythonExe -m pip install `
    --editable (Join-Path $UpstreamRoot "packages\cadpy") `
    --editable (Join-Path $UpstreamRoot "packages\cadpy_metadata") `
    --editable (Join-Path $UpstreamRoot "viewer\moveit2_server") `
    ezdxf playwright networkx lxml pytest trimesh
}

function Install-ViewerDeps {
  npm --prefix (Join-Path $UpstreamRoot "viewer") ci
}

function Install-PlaywrightBrowser {
  $env:PYTHONUTF8 = "1"
  & $PythonExe -m playwright install chromium
}

$workspaceProxy = Get-WorkspaceProxy
if ($workspaceProxy) {
  $env:HTTP_PROXY = $workspaceProxy
  $env:HTTPS_PROXY = $workspaceProxy
}

Ensure-UpstreamCheckout
Ensure-WorkDirs
Configure-GitProxy -ProxyUrl $workspaceProxy
Restore-UpstreamJunctions
Link-AgentSkills

if ($InstallDeps) {
  Install-PythonDeps
}
if ($InstallViewerDeps) {
  Install-ViewerDeps
}
if ($InstallPlaywright) {
  Install-PlaywrightBrowser
}

Write-Host ""
Write-Host "Agent CAD workspace ready: $WorkspaceRoot"
Write-Host "Use work\ for CAD artifacts and upstream\text-to-cad\ only for upstream project changes."
