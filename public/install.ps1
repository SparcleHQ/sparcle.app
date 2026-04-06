# Bolt Installer for Windows — https://sparcle.app/install.ps1
# Usage (run in PowerShell):
#   irm https://sparcle.app/install.ps1 | iex                                  # Personal edition (default)
#   $env:EDITION='trial'; irm https://sparcle.app/install.ps1 | iex            # Enterprise Trial
#
# What this does:
#   1. Fetches the latest release version from GitHub
#   2. Downloads the correct installer from GitHub Releases
#   2. Marks the file as trusted for Windows to run safely
#   3. Runs the installer silently
#   4. Launches the app
#
# No admin required. Safe to re-run.

param(
  [string]$Edition = ""
)

# Allow $env:EDITION as fallback (needed for irm | iex which can't pass params)
if (-not $Edition) {
  $Edition = if ($env:EDITION) { $env:EDITION } else { "personal" }
}

$ErrorActionPreference = "Stop"

# ── Config ──────────────────────────────────────────────────────────────────
$FallbackVersion = "0.1.0"
$GitHubRepo      = "Sparcle-LLC/sparcle.app"

# ── Fetch latest version from GitHub ────────────────────────────────────────
try {
  $Release = Invoke-RestMethod "https://api.github.com/repos/$GitHubRepo/releases/latest" -TimeoutSec 5 -ErrorAction Stop
  $Version = ($Release.tag_name -replace '^v', '')
  if (-not $Version) { throw "empty tag" }
} catch {
  $Version = $FallbackVersion
  Write-Host "  ⚠  Could not fetch latest version — using v$Version" -ForegroundColor Yellow
}
$BaseUrl = "https://github.com/$GitHubRepo/releases/download/v$Version"

# ── Helpers ─────────────────────────────────────────────────────────────────
function Info($msg)  { Write-Host "  ==> " -ForegroundColor Blue -NoNewline; Write-Host $msg }
function Ok($msg)    { Write-Host "   ✓  " -ForegroundColor Green -NoNewline; Write-Host $msg }
function Fail($msg)  { Write-Host "   ✗  " -ForegroundColor Red -NoNewline; Write-Host $msg; exit 1 }

# ── Parse edition ───────────────────────────────────────────────────────────
switch ($Edition.ToLower()) {
  "personal" {
    $AppName    = "Bolt Personal"
    $FilePrefix = "Bolt-Personal"
  }
  { $_ -in "trial", "enterprise" } {
    $Edition    = "trial"
    $AppName    = "Bolt Enterprise"
    $FilePrefix = "Bolt-Enterprise-Trial"
  }
  default {
    Fail "Unknown edition: $Edition. Use 'personal' or 'trial'."
  }
}

# ── Detect architecture ────────────────────────────────────────────────────
$Arch = if ([Environment]::Is64BitOperatingSystem) {
  if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "aarch64-pc-windows-msvc" }
  else { "x86_64-pc-windows-msvc" }
} else {
  Fail "32-bit Windows is not supported."
}

$FileName = "$FilePrefix-$Version-$Arch.msi"
$FileUrl  = "$BaseUrl/$FileName"

Write-Host ""
Write-Host "  ⚡ Bolt Installer" -ForegroundColor Cyan
Write-Host "  ─────────────────────────────────────"
Write-Host "  Edition:       $AppName"
Write-Host "  Version:       $Version"
Write-Host "  Architecture:  $Arch"
Write-Host ""

# ── Download ────────────────────────────────────────────────────────────────
$TmpDir  = Join-Path $env:TEMP "bolt-install"
New-Item -ItemType Directory -Force -Path $TmpDir | Out-Null
$DlPath  = Join-Path $TmpDir $FileName

Info "Downloading $FileName..."
try {
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  Invoke-WebRequest -Uri $FileUrl -OutFile $DlPath -UseBasicParsing
} catch {
  Remove-Item -Recurse -Force $TmpDir -ErrorAction SilentlyContinue
  Fail "Download failed. Check https://sparcle.app/download for available versions."
}

$Size = [math]::Round((Get-Item $DlPath).Length / 1MB, 1)
Ok "Downloaded ${Size}MB"

# ── Mark as trusted for Windows to run safely ───────────────────────────────
Info "Marking $AppName as trusted..."
Unblock-File -Path $DlPath -ErrorAction SilentlyContinue
Ok "Installer trusted — no SmartScreen warnings"

# ── Install (silent MSI) ───────────────────────────────────────────────────
Info "Installing $AppName..."
$msiArgs = "/i `"$DlPath`" /quiet /norestart"
$proc = Start-Process msiexec.exe -ArgumentList $msiArgs -Wait -PassThru
if ($proc.ExitCode -ne 0) {
  Fail "Installation failed (exit code $($proc.ExitCode))."
}
Ok "Installed successfully"

# ── Cleanup ────────────────────────────────────────────────────────────────
Remove-Item -Recurse -Force $TmpDir -ErrorAction SilentlyContinue

# ── Launch ─────────────────────────────────────────────────────────────────
$ExeName = ($AppName -replace ' ', '-') + ".exe"
$ProgramFiles = $env:ProgramFiles
$ExePath = Get-ChildItem -Path "$ProgramFiles\$AppName" -Filter $ExeName -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1

if ($ExePath) {
  Info "Launching $AppName..."
  Start-Process $ExePath.FullName
} else {
  # Fallback: try Start Menu shortcut
  $Shortcut = Get-ChildItem "$env:APPDATA\Microsoft\Windows\Start Menu\Programs" -Filter "$AppName.lnk" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($Shortcut) {
    Info "Launching $AppName..."
    Start-Process $Shortcut.FullName
  } else {
    Info "Installation complete — launch $AppName from the Start Menu."
  }
}

Write-Host ""
Write-Host "  ✅  $AppName is ready!" -ForegroundColor Green
Write-Host ""
switch ($Edition) {
  "personal" {
    Write-Host "  Next: Add your AI API key in Settings → AI Configuration"
    Write-Host "  Tip:  Google Gemini has a free tier — works great with Bolt"
  }
  "trial" {
    Write-Host "  Next: Try instant demo mode, or configure your own IDP + LLM"
    Write-Host "  Trial: 7 days, all features unlocked"
  }
}
Write-Host ""
