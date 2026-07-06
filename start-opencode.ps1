$ErrorActionPreference = "Stop"

Set-Location $PSScriptRoot
$env:PYTHONUTF8 = "1"

if (-not $env:HTTP_PROXY -and -not $env:HTTPS_PROXY) {
  try {
    $internetSettings = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    if ($internetSettings.ProxyEnable -eq 1 -and $internetSettings.ProxyServer) {
      $env:HTTP_PROXY = [string]$internetSettings.ProxyServer
      $env:HTTPS_PROXY = [string]$internetSettings.ProxyServer
    }
  } catch {
  }
}

opencode
