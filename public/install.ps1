# Bolt Installer for Windows — https://sparcle.app/install.ps1
# Usage (run in PowerShell):
#   irm https://sparcle.app/install.ps1 | iex                                  # Personal edition (default)
#   $env:EDITION='trial'; irm https://sparcle.app/install.ps1 | iex            # Enterprise Trial
#
# What this does:
#   1. Fetches the latest release version from GitHub
#   2. Downloads the correct installer from GitHub Releases
#   3. Verifies checksums when release metadata is available
#   4. Marks the file as trusted for Windows to run safely
#   5. Runs the installer silently
#   6. Launches the app
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
$DefaultBoltPgReleasesUrl = "https://sparcle.app"
$DefaultBoltPgFallbackReleasesUrl = ""
$DownloadRetryMax = 5
$DownloadRetryDelaySeconds = 2
$BoltApiReadyTimeoutSeconds = 120
$BoltApiPortBase = 13018
$BoltApiPortRange = 10
$PrewarmRetryAttempts = 3
$PrewarmRetryDelaySeconds = 2

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
function Warn($msg)  { Write-Host "  ⚠  $msg" -ForegroundColor Yellow }
function Fail($msg)  { Write-Host "   ✗  " -ForegroundColor Red -NoNewline; Write-Host $msg; exit 1 }

function Invoke-DownloadWithRetry {
  param(
    [string]$Url,
    [string]$OutFile,
    [string]$Label
  )

  for ($attempt = 1; $attempt -le $DownloadRetryMax; $attempt++) {
    try {
      [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
      Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing -TimeoutSec 60 -ErrorAction Stop
      return
    }
    catch {
      if ($attempt -eq $DownloadRetryMax) {
        throw
      }
      Warn "Download retry $attempt/$DownloadRetryMax failed for $Label. Retrying..."
      Start-Sleep -Seconds $DownloadRetryDelaySeconds
    }
  }
}

function Wait-ApiReadiness {
  param(
    [int]$TimeoutSeconds = 120
  )

  $portEnd = $BoltApiPortBase + $BoltApiPortRange - 1
  $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
  while ($stopwatch.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
    for ($port = $BoltApiPortBase; $port -le $portEnd; $port++) {
      foreach ($path in @("/api/health", "/health")) {
        try {
          $response = Invoke-WebRequest -Uri "http://127.0.0.1:$port$path" -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
          if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 300) {
            return "http://127.0.0.1:$port$path"
          }
        }
        catch {
          # keep probing
        }
      }
    }
    Start-Sleep -Seconds 1
  }

  return $null
}

function Verify-RuntimeContract {
  if ($env:BOLT_SKIP_API_HEALTH_CHECK -eq "1") {
    Warn "Skipping API health verification (BOLT_SKIP_API_HEALTH_CHECK=1)"
    return
  }

  Info "Verifying API runtime readiness..."
  $readyUrl = Wait-ApiReadiness -TimeoutSeconds $BoltApiReadyTimeoutSeconds
  if ($readyUrl) {
    Ok "API is healthy at $readyUrl"
    return
  }

  Fail "Install completed, but API readiness check failed (tried /api/health and /health on ports $BoltApiPortBase-$($BoltApiPortBase + $BoltApiPortRange - 1) for ${BoltApiReadyTimeoutSeconds}s)."
}

function Select-ReleaseAsset {
  param(
    [string]$DesiredExt
  )

  $script:FileName = "$FilePrefix-$Version-$Arch.$DesiredExt"
  $script:FileUrl = "$BaseUrl/$($script:FileName)"
}

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

function Save-PgRuntimeSources {
  param(
    [string]$AppIdentifier
  )

  $configDir = Join-Path $env:APPDATA "$AppIdentifier\embedded-postgres"
  New-Item -ItemType Directory -Force -Path $configDir | Out-Null
  $configFile = Join-Path $configDir "sources.env"

  $lines = @(
    "# Generated by Bolt installer",
    "BOLT_PG_RELEASES_URL=$($env:BOLT_PG_RELEASES_URL)"
  )

  if ($env:BOLT_PG_FALLBACK_RELEASES_URL) {
    $lines += "BOLT_PG_FALLBACK_RELEASES_URL=$($env:BOLT_PG_FALLBACK_RELEASES_URL)"
  }

  Set-Content -Path $configFile -Value $lines -Encoding UTF8
  Info "Persisted PostgreSQL sources config: $configFile"
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
    for ($attempt = 1; $attempt -le $PrewarmRetryAttempts; $attempt++) {
      $proc = Start-Process -FilePath $ExecutablePath -ArgumentList "prewarm-postgres" -WindowStyle Hidden -PassThru -Wait
      if ($proc.ExitCode -eq 0) {
        Ok "Embedded PostgreSQL prewarm complete"
        return
      }

      if ($attempt -lt $PrewarmRetryAttempts) {
        Warn "Embedded PostgreSQL prewarm attempt $attempt/$PrewarmRetryAttempts failed (exit $($proc.ExitCode)); retrying..."
        Start-Sleep -Seconds $PrewarmRetryDelaySeconds
      } else {
        Write-Host "  ⚠  Embedded PostgreSQL prewarm failed after $PrewarmRetryAttempts attempts (app will retry on first launch) [exit $($proc.ExitCode)]" -ForegroundColor Yellow
      }
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

# Prefer the NSIS .exe installer for consumer `irm | iex` flows: it ships with
# a UAC manifest, so Windows triggers the elevation prompt automatically when
# launched unelevated (which is exactly how `iex` lands). The MSI is the
# fallback — and only works when already running elevated, because Tauri's
# MSI is built perMachine-only (no per-user MSI variant in Tauri v2).
# If $env:BOLT_INSTALL_MSI is set (or the .exe download 404s), we fall through
# to the MSI path with self-elevation.
$PreferMsi = [bool]$env:BOLT_INSTALL_MSI
$InstallerExt = if ($PreferMsi) { "msi" } else { "exe" }
Select-ReleaseAsset -DesiredExt $InstallerExt

Write-Host ""
Write-Host "  ⚡ Bolt Installer" -ForegroundColor Cyan
Write-Host "  ─────────────────────────────────────"
Write-Host "  Edition:       $AppName"
Write-Host "  Version:       $Version"
Write-Host "  Architecture:  $Arch"
Write-Host "  Installer:     $InstallerExt"
Write-Host ""

# ── Download ────────────────────────────────────────────────────────────────
$TmpDir  = Join-Path $env:TEMP "bolt-install"
New-Item -ItemType Directory -Force -Path $TmpDir | Out-Null
$DlPath  = Join-Path $TmpDir $FileName

Info "Downloading $FileName..."
try {
  Invoke-DownloadWithRetry -Url $FileUrl -OutFile $DlPath -Label $FileName
} catch {
  if ($InstallerExt -eq "exe") {
    # NSIS .exe is a newer artifact — fall back to MSI if the server doesn't
    # have it (e.g. a release from before we shipped NSIS alongside MSI).
    Warn "NSIS .exe not available for v$Version — falling back to MSI..."
    $InstallerExt = "msi"
    Select-ReleaseAsset -DesiredExt $InstallerExt
    $DlPath  = Join-Path $TmpDir $FileName
    try {
      Invoke-DownloadWithRetry -Url $FileUrl -OutFile $DlPath -Label $FileName
    } catch {
      Remove-Item -Recurse -Force $TmpDir -ErrorAction SilentlyContinue
      Fail "Download failed: $FileName not found.`n  $AppName may not be available for $Arch yet.`n  Check https://sparcle.app/download for supported platforms."
    }
  } else {
    Remove-Item -Recurse -Force $TmpDir -ErrorAction SilentlyContinue
    Fail "Download failed: $FileName not found.`n  $AppName may not be available for $Arch yet.`n  Check https://sparcle.app/download for supported platforms."
  }
}

$Size = [math]::Round((Get-Item $DlPath).Length / 1MB, 1)
Ok "Downloaded ${Size}MB"

# ── Mark as trusted for Windows to run safely ───────────────────────────────
Info "Marking $AppName as trusted..."
Unblock-File -Path $DlPath -ErrorAction SilentlyContinue
Ok "Installer trusted — no SmartScreen warnings"

# ── Install ─────────────────────────────────────────────────────────────────
Info "Installing $AppName..."
$isAdmin = Is-Administrator

if ($InstallerExt -eq "exe") {
  # NSIS installer — /S for silent, UAC manifest auto-elevates via OS prompt.
  # Start-Process -Wait returns the process exit code from the setup.exe,
  # which NSIS maps to a non-zero value on user-cancelled UAC.
  $proc = Start-Process -FilePath $DlPath -ArgumentList "/S" -Wait -PassThru
  if ($proc.ExitCode -eq 0) {
    Ok "Installed successfully"
  } elseif ($proc.ExitCode -eq 1223) {
    Fail "Installation cancelled (you clicked No on the UAC prompt)."
  } else {
    Fail "Installation failed (exit code $($proc.ExitCode)).`n  Try running the installer manually: $DlPath"
  }
} else {
  # Prefer per-user install so non-admin users can install successfully;
  # but Tauri MSIs are perMachine and will reject ALLUSERS=2 with code 1625.
  # On that, relaunch this install step elevated via UAC.
  $perUserArgs = "/i `"$DlPath`" /quiet /norestart ALLUSERS=2 MSIINSTALLPERUSER=1"
  $proc = Start-Process msiexec.exe -ArgumentList $perUserArgs -Wait -PassThru

  if ($proc.ExitCode -eq 0) {
    Ok "Installed successfully (single-user mode)"
  } elseif ($proc.ExitCode -in 1625, 1603, 1925 -and -not $isAdmin) {
    # Tauri MSIs are perMachine-only — Windows rejected the per-user install
    # attempt. Self-elevate and retry as machine-wide. UAC prompts once.
    Info "Per-user MSI rejected (exit $($proc.ExitCode)); retrying as Administrator via UAC..."
    $elevProc = Start-Process msiexec.exe -Verb RunAs -ArgumentList "/i `"$DlPath`" /passive /norestart ALLUSERS=1" -Wait -PassThru
    if ($elevProc.ExitCode -ne 0) {
      Fail "Elevated install failed (exit code $($elevProc.ExitCode)). Try: msiexec /i `"$DlPath`" /passive"
    }
    Ok "Installed successfully (all-users mode via UAC)"
  } elseif ($proc.ExitCode -eq 1925 -and $isAdmin) {
    Info "Per-user install failed in admin context, retrying machine-wide..."
    $machineArgs = "/i `"$DlPath`" /quiet /norestart ALLUSERS=1"
    $proc = Start-Process msiexec.exe -ArgumentList $machineArgs -Wait -PassThru
    if ($proc.ExitCode -ne 0) {
      Fail "Installation failed (exit code $($proc.ExitCode))."
    }
    Ok "Installed successfully (all-users mode)"
  } else {
    Fail "Installation failed (exit code $($proc.ExitCode))."
  }
}

# ── Cleanup ────────────────────────────────────────────────────────────────
Remove-Item -Recurse -Force $TmpDir -ErrorAction SilentlyContinue
Save-PgRuntimeSources -AppIdentifier $AppIdentifier

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
  Verify-RuntimeContract
} else {
  # Fallback: try Start Menu shortcut
  $Shortcut = Get-ChildItem "$env:APPDATA\Microsoft\Windows\Start Menu\Programs" -Filter "$AppName.lnk" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($Shortcut) {
    Info "Launching $AppName..."
    Start-Process $Shortcut.FullName
    Verify-RuntimeContract
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
