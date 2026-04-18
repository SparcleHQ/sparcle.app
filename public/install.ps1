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
$DefaultBoltPgReleasesUrl = "https://github.com/theseus-rs/postgresql-binaries"
$DefaultBoltPgFallbackReleasesUrl = ""

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
function Configure-PgRuntimeSources {
  # Keep any user-provided env vars unchanged; only set defaults when absent.
  if (-not $env:BOLT_PG_RELEASES_URL) {
    $env:BOLT_PG_RELEASES_URL = $DefaultBoltPgReleasesUrl
  }

  if (-not $env:BOLT_PG_FALLBACK_RELEASES_URL -and $DefaultBoltPgFallbackReleasesUrl) {
    $env:BOLT_PG_FALLBACK_RELEASES_URL = $DefaultBoltPgFallbackReleasesUrl
  }

  Info "PostgreSQL source (primary): $($env:BOLT_PG_RELEASES_URL)"
  if ($env:BOLT_PG_FALLBACK_RELEASES_URL) {
    Info "PostgreSQL source (fallback): $($env:BOLT_PG_FALLBACK_RELEASES_URL)"
  } else {
    Info "PostgreSQL source (fallback): <not configured>"
  }
}
function Is-Administrator {
  try {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  } catch {
    return $false
  }
}

function Invoke-PostgresPrewarm {
  param(
    [string]$ExecutablePath,
    [string]$AppIdentifier
  )

  if (-not (Test-Path $ExecutablePath)) {
    Write-Host "  ⚠  Skipping PostgreSQL prewarm: executable not found at $ExecutablePath" -ForegroundColor Yellow
    return
  }

  Info "Prewarming embedded PostgreSQL (user-space, one-time setup)..."
  $previous = [Environment]::GetEnvironmentVariable("BOLT_APP_IDENTIFIER", "Process")
  try {
    [Environment]::SetEnvironmentVariable("BOLT_APP_IDENTIFIER", $AppIdentifier, "Process")
    $proc = Start-Process -FilePath $ExecutablePath -ArgumentList "prewarm-postgres" -WindowStyle Hidden -PassThru -Wait
    if ($proc.ExitCode -eq 0) {
      Ok "Embedded PostgreSQL prewarm complete"
    } else {
      Write-Host "  ⚠  Embedded PostgreSQL prewarm failed (app will retry on first launch) [exit $($proc.ExitCode)]" -ForegroundColor Yellow
    }
  }
  catch {
    Write-Host "  ⚠  Embedded PostgreSQL prewarm failed (app will retry on first launch): $($_.Exception.Message)" -ForegroundColor Yellow
  }
  finally {
    [Environment]::SetEnvironmentVariable("BOLT_APP_IDENTIFIER", $previous, "Process")
  }
}

# ── Parse edition ───────────────────────────────────────────────────────────
switch ($Edition.ToLower()) {
  "personal" {
    $AppName    = "Bolt Personal"
    $FilePrefix = "Bolt-Personal"
    $AppIdentifier = "app.sparcle.bolt.personal"
  }
  { $_ -in "trial", "enterprise" } {
    $Edition    = "trial"
    $AppName    = "Bolt Enterprise"
    $FilePrefix = "Bolt-Enterprise-Trial"
    $AppIdentifier = "app.sparcle.bolt.enterprise"
  }
  default {
    Fail "Unknown edition: $Edition. Use 'personal' or 'trial'."
  }
}

Configure-PgRuntimeSources

# ── Detect architecture ────────────────────────────────────────────────────
$RealArch = $env:PROCESSOR_ARCHITECTURE
$Arch = if ([Environment]::Is64BitOperatingSystem) {
  if ($RealArch -eq "ARM64") {
    # x86_64 MSI runs fine on Windows ARM64 via built-in emulation
    "x86_64-pc-windows-msvc"
  } else {
    "x86_64-pc-windows-msvc"
  }
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
  Fail "Download failed: $FileName not found.`n  $AppName may not be available for $Arch yet.`n  Check https://sparcle.app/download for supported platforms."
}

$Size = [math]::Round((Get-Item $DlPath).Length / 1MB, 1)
Ok "Downloaded ${Size}MB"

# ── Mark as trusted for Windows to run safely ───────────────────────────────
Info "Marking $AppName as trusted..."
Unblock-File -Path $DlPath -ErrorAction SilentlyContinue
Ok "Installer trusted — no SmartScreen warnings"

# ── Install (silent MSI) ───────────────────────────────────────────────────
Info "Installing $AppName..."
$isAdmin = Is-Administrator

# Prefer per-user install so non-admin users can install successfully.
$perUserArgs = "/i `"$DlPath`" /quiet /norestart ALLUSERS=2 MSIINSTALLPERUSER=1"
$proc = Start-Process msiexec.exe -ArgumentList $perUserArgs -Wait -PassThru

if ($proc.ExitCode -eq 0) {
  Ok "Installed successfully (single-user mode)"
} elseif ($proc.ExitCode -eq 1925 -and $isAdmin) {
  # If elevated context still hits permission edge-cases, try machine-wide mode.
  Info "Per-user install failed in admin context, retrying machine-wide install..."
  $machineArgs = "/i `"$DlPath`" /quiet /norestart ALLUSERS=1"
  $proc = Start-Process msiexec.exe -ArgumentList $machineArgs -Wait -PassThru
  if ($proc.ExitCode -ne 0) {
    Fail "Installation failed (exit code $($proc.ExitCode))."
  }
  Ok "Installed successfully (all-users mode)"
} elseif ($proc.ExitCode -in 1603, 1925) {
  Fail "Installation failed (exit code $($proc.ExitCode)).`n  This usually means Windows blocked all-users MSI install privileges.`n  Re-run the same command in an Administrator PowerShell, or contact IT to allow per-user MSI installs."
} else {
  Fail "Installation failed (exit code $($proc.ExitCode))."
}

# ── Cleanup ────────────────────────────────────────────────────────────────
Remove-Item -Recurse -Force $TmpDir -ErrorAction SilentlyContinue

# ── Launch ─────────────────────────────────────────────────────────────────
$ExeName = ($AppName -replace ' ', '-') + ".exe"
$ProgramFiles = $env:ProgramFiles
$LocalPrograms = Join-Path $env:LOCALAPPDATA "Programs"
$SearchRoots = @(
  (Join-Path $ProgramFiles $AppName),
  (Join-Path $LocalPrograms $AppName),
  $ProgramFiles,
  $LocalPrograms
)
$ExePath = $null
foreach ($root in $SearchRoots) {
  if (Test-Path $root) {
    $ExePath = Get-ChildItem -Path $root -Filter $ExeName -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($ExePath) { break }
  }
}

if ($ExePath) {
  Invoke-PostgresPrewarm -ExecutablePath $ExePath.FullName -AppIdentifier $AppIdentifier

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
