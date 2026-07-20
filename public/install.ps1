# Bolt Installer for Windows — https://sparcle.app/install.ps1
# Usage (run in PowerShell):
#   irm https://sparcle.app/install.ps1 | iex                                            # Bolt (free), latest
#   $env:BOLT_VERSION='0.1.18'; irm https://sparcle.app/install.ps1 | iex                # Pin a specific version
#
# Backwards-compat: $env:EDITION='personal', 'free', 'trial', or 'enterprise'
# all accept and resolve to the same free Bolt build.
#
# What this does:
#   1. Resolves the target version ($env:BOLT_VERSION > /releases/latest)
#   2. Downloads the correct installer from GitHub Releases (with on-disk cache)
#   3. Marks the file as trusted for Windows to run safely
#   4. Runs the installer silently
#   5. Launches the app
#
# Re-runs are network-free when the cached download still matches the remote
# (per-version cache at %LOCALAPPDATA%\Sparcle\bolt-installer\v<version>\ —
# override with $env:BOLT_INSTALLER_CACHE_DIR).
#
# No admin required. Safe to re-run.

param(
  [string]$Edition = "",
  [string]$Version = ""
)

# Allow $env:EDITION as fallback (needed for irm | iex which can't pass params)
if (-not $Edition) {
  $Edition = if ($env:EDITION) { $env:EDITION } else { "personal" }
}

# Same pattern for version pinning.
if (-not $Version -and $env:BOLT_VERSION) {
  $Version = $env:BOLT_VERSION
}
$VersionPinned = [bool]$Version
if ($Version) { $Version = $Version -replace '^v', '' }

$ErrorActionPreference = "Stop"

# ── Config ──────────────────────────────────────────────────────────────────
$FallbackVersion = "0.1.0"
$GitHubRepo      = "SparcleHQ/sparcle.app"
$DefaultBoltPgReleasesUrl = "https://sparcle.app"
$DefaultBoltPgFallbackReleasesUrl = ""
$DownloadRetryMax = 5
$DownloadRetryDelaySeconds = 2
$BoltApiReadyTimeoutSeconds = 120
$BoltApiPortBase = 13018
$BoltApiPortRange = 10
$PrewarmRetryAttempts = 3
$PrewarmRetryDelaySeconds = 2
$CacheBaseDir = if ($env:BOLT_INSTALLER_CACHE_DIR) {
  $env:BOLT_INSTALLER_CACHE_DIR
} else {
  Join-Path $env:LOCALAPPDATA "Sparcle\bolt-installer"
}
$CacheKeepVersions = 2

# ── Resolve version (env/param > /releases/latest) ──────────────────────────
if (-not $Version) {
  try {
    $Release = Invoke-RestMethod "https://api.github.com/repos/$GitHubRepo/releases/latest" -TimeoutSec 5 -ErrorAction Stop
    $Version = ($Release.tag_name -replace '^v', '')
    if (-not $Version) { throw "empty tag" }
  } catch {
    $Version = $FallbackVersion
    Write-Host "  ⚠  Could not fetch latest version — using v$Version" -ForegroundColor Yellow
  }
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

function Get-RemoteAssetInfo {
  param([string]$Url)
  try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $resp = Invoke-WebRequest -Uri $Url -Method Head -UseBasicParsing -TimeoutSec 30 -MaximumRedirection 10 -ErrorAction Stop
    $sizeHdr = $resp.Headers['Content-Length']
    $etagHdr = $resp.Headers['ETag']
    if ($sizeHdr -is [array]) { $sizeHdr = $sizeHdr[0] }
    if ($etagHdr -is [array]) { $etagHdr = $etagHdr[0] }
    $size = 0
    if ($sizeHdr) { [void][int64]::TryParse([string]$sizeHdr, [ref]$size) }
    return @{ Size = $size; Etag = [string]$etagHdr }
  }
  catch {
    return $null
  }
}

# Walk back recent releases looking for the most recent one whose asset names
# match a regex. Suffix examples:
#   '-x86_64-pc-windows-msvc\.exe$'
#   '-x86_64-pc-windows-msvc\.(exe|msi)$'
# Used when the current /releases/latest tag is missing the user's installer
# (partial ship in flight, or a single-asset 502'd silently like trial mac
# arm64 on v0.1.31). Returns the tag (without leading v) or $null.
function Find-LatestReleaseWithAsset {
  param(
    [string]$FilePrefixPattern,
    [string]$SuffixPattern
  )
  try {
    $releases = Invoke-RestMethod "https://api.github.com/repos/$GitHubRepo/releases?per_page=10" -TimeoutSec 10 -ErrorAction Stop
    foreach ($rel in $releases) {
      foreach ($asset in $rel.assets) {
        if ($asset.name -match ("^" + $FilePrefixPattern + "-[0-9][0-9.]*" + $SuffixPattern)) {
          return ($rel.tag_name -replace '^v', '')
        }
      }
    }
  } catch {
    return $null
  }
  return $null
}

function Test-CacheFresh {
  param(
    [string]$Cached,
    [string]$Meta,
    [hashtable]$Remote
  )
  if (-not (Test-Path $Cached)) { return $false }
  if (-not $Remote -or -not $Remote.Size -or $Remote.Size -le 1000) { return $false }
  $info = Get-Item $Cached -ErrorAction SilentlyContinue
  if (-not $info -or $info.Length -ne $Remote.Size) { return $false }
  if ((Test-Path $Meta) -and $Remote.Etag) {
    $savedEtag = ""
    foreach ($line in Get-Content $Meta -ErrorAction SilentlyContinue) {
      if ($line -match '^etag\t(.+)$') { $savedEtag = $Matches[1]; break }
    }
    if ($savedEtag -and $savedEtag -ne $Remote.Etag) { return $false }
  }
  return $true
}

function Save-CacheMeta {
  param(
    [string]$Meta,
    [hashtable]$Remote
  )
  $lines = @()
  if ($Remote.Size) { $lines += "size`t$($Remote.Size)" }
  if ($Remote.Etag) { $lines += "etag`t$($Remote.Etag)" }
  $lines += "fetched_at`t$([DateTime]::UtcNow.ToString('o'))"
  Set-Content -Path $Meta -Value $lines -Encoding UTF8
}

function Invoke-CacheGc {
  param([string]$CurrentVersionDir)
  if (-not (Test-Path $CacheBaseDir)) { return }
  try {
    $dirs = Get-ChildItem -Path $CacheBaseDir -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like 'v*' -and $_.FullName -ne $CurrentVersionDir } |
            Sort-Object LastWriteTime -Descending
    $skip = [Math]::Max(0, $CacheKeepVersions - 1)
    $toDelete = $dirs | Select-Object -Skip $skip
    foreach ($d in $toDelete) {
      Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $d.FullName
    }
  } catch {
    # Best-effort GC — never fail the install over leftover cache.
  }
}

function Get-CachedOrDownload {
  param(
    [string]$Url,
    [string]$FileName,
    [string]$Label
  )
  $verDir   = Join-Path $CacheBaseDir "v$Version"
  New-Item -ItemType Directory -Force -Path $verDir | Out-Null
  $dlPath   = Join-Path $verDir $FileName
  $metaPath = "$dlPath.meta"
  $partial  = "$dlPath.partial"

  $remote = Get-RemoteAssetInfo -Url $Url
  if ($remote -and (Test-CacheFresh -Cached $dlPath -Meta $metaPath -Remote $remote)) {
    $sizeMb = [math]::Round((Get-Item $dlPath).Length / 1MB, 1)
    Ok "Using cached $Label (${sizeMb}MB) — skipping download"
    return @{ Path = $dlPath; VersionDir = $verDir }
  }

  Info "Downloading $Label..."
  if (Test-Path $partial) { Remove-Item -Force $partial -ErrorAction SilentlyContinue }
  Invoke-DownloadWithRetry -Url $Url -OutFile $partial -Label $Label
  if (-not (Test-Path $partial) -or (Get-Item $partial).Length -lt 1000) {
    Remove-Item -Force $partial -ErrorAction SilentlyContinue
    throw "Downloaded file is missing or too small."
  }
  Move-Item -Force $partial $dlPath

  if (-not $remote) { $remote = Get-RemoteAssetInfo -Url $Url }
  if (-not $remote) { $remote = @{} }
  # Authoritative size = what we wrote to disk.
  $remote.Size = (Get-Item $dlPath).Length
  Save-CacheMeta -Meta $metaPath -Remote $remote

  $sizeMb = [math]::Round((Get-Item $dlPath).Length / 1MB, 1)
  Ok "Downloaded ${sizeMb}MB"
  return @{ Path = $dlPath; VersionDir = $verDir }
}

function Wait-ApiReadiness {
  param(
    [int]$TimeoutSeconds = 120
  )

  $portEnd = $BoltApiPortBase + $BoltApiPortRange - 1
  # Try plaintext http:// first, then https:// (skipping cert validation for
  # the locally-generated sidecar cert) since the API may be in TLS mode.
  $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
  while ($stopwatch.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
    for ($port = $BoltApiPortBase; $port -le $portEnd; $port++) {
      foreach ($path in @("/api/health", "/health")) {
        foreach ($scheme in @("http", "https")) {
          try {
            $url = "${scheme}://127.0.0.1:$port$path"
            $iwrParams = @{
              Uri             = $url
              UseBasicParsing = $true
              TimeoutSec      = 2
              ErrorAction     = "Stop"
            }
            if ($scheme -eq "https" -and (Get-Command Invoke-WebRequest).Parameters.ContainsKey("SkipCertificateCheck")) {
              $iwrParams.SkipCertificateCheck = $true
            }
            $response = Invoke-WebRequest @iwrParams
            if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 300) {
              return $url
            }
          }
          catch {
            # keep probing
          }
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

function Stop-BoltProcesses {
  # NSIS /S silently skips files that are in use, so an "upgrade" over a
  # running Bolt is a no-op for any locked binary — most painfully the
  # bolt-api sidecar, which stays at the first-installed version forever
  # while the user sees "Installed successfully" on every retry.
  # Kill known image names defensively before invoking the installer.
  $names = @('bolt', 'bolt-api', 'Bolt', 'Bolt Personal', 'Bolt Enterprise')
  $killed = $false
  foreach ($n in $names) {
    $procs = Get-Process -Name $n -ErrorAction SilentlyContinue
    if ($procs) {
      $procs | Stop-Process -Force -ErrorAction SilentlyContinue
      $killed = $true
    }
  }
  if ($killed) {
    Start-Sleep -Milliseconds 500
    Info "Stopped running Bolt processes so files can be replaced"
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
# Bolt is one product (Bolt Enterprise) shipped as one binary per platform,
# free to download for everyone. Legacy `personal`, `free`, `trial` argument
# values are accepted as no-op aliases so any bookmarked one-liner keeps
# working. Bundle id + installed-app folder are app.sparcle.bolt.enterprise.
switch ($Edition.ToLower()) {
  { $_ -in "enterprise", "personal", "free", "trial" } {
    $Edition       = "enterprise"
    $AppName       = "Bolt Enterprise"
    $FilePrefix    = "Bolt-Enterprise"
    $AppIdentifier = "app.sparcle.bolt.enterprise"
  }
  default {
    Fail "Unknown edition: $Edition. Bolt is free; just run without arguments."
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

# Per-platform walk-back: if v$Version doesn't have either the .exe or .msi for
# this edition (partial ship, or a single-asset silent 502 — the same failure
# that hit trial mac arm64 on v0.1.31), walk back recent releases to find one
# that does. Skipped when the user pinned a version via $env:BOLT_VERSION or
# -Version arg.
if (-not $VersionPinned) {
  $primaryInfo = Get-RemoteAssetInfo -Url $FileUrl
  if (-not $primaryInfo) {
    # Try the other extension first within the same release.
    $altExt = if ($InstallerExt -eq "exe") { "msi" } else { "exe" }
    $altUrl = "$BaseUrl/$FilePrefix-$Version-$Arch.$altExt"
    if (-not (Get-RemoteAssetInfo -Url $altUrl)) {
      Warn "v$Version has no Windows installer for $AppName — checking earlier releases..."
      $prefixPattern = [regex]::Escape($FilePrefix)
      $suffixPattern = "-" + [regex]::Escape($Arch) + "\.(exe|msi)$"
      $fallback = Find-LatestReleaseWithAsset -FilePrefixPattern $prefixPattern -SuffixPattern $suffixPattern
      if ($fallback -and $fallback -ne $Version) {
        Warn "Installing v$fallback (latest v$Version is mid-ship for Windows)"
        $Version = $fallback
        $BaseUrl = "https://github.com/$GitHubRepo/releases/download/v$Version"
        Select-ReleaseAsset -DesiredExt $InstallerExt
      }
    }
  }
}

Write-Host ""
Write-Host "  ⚡ Bolt Installer" -ForegroundColor Cyan
Write-Host "  ─────────────────────────────────────"
Write-Host "  Edition:       $AppName"
Write-Host "  Version:       $Version"
Write-Host "  Architecture:  $Arch"
Write-Host "  Installer:     $InstallerExt"
Write-Host ""

# ── Download (with per-version cache) ───────────────────────────────────────
# Cache layout: $CacheBaseDir\v<version>\<file> + sidecar <file>.meta with
# size/etag. Re-running this script with the same version is a no-op for the
# network when the cached file still matches the remote.
try {
  $cacheResult = Get-CachedOrDownload -Url $FileUrl -FileName $FileName -Label $FileName
  $DlPath = $cacheResult.Path
  $VersionDir = $cacheResult.VersionDir
} catch {
  if ($InstallerExt -eq "exe") {
    Warn "NSIS .exe not available for v$Version — falling back to MSI..."
    $InstallerExt = "msi"
    Select-ReleaseAsset -DesiredExt $InstallerExt
    try {
      $cacheResult = Get-CachedOrDownload -Url $FileUrl -FileName $FileName -Label $FileName
      $DlPath = $cacheResult.Path
      $VersionDir = $cacheResult.VersionDir
    } catch {
      Fail "Download failed: $FileName not found.`n  $AppName may not be available for $Arch yet.`n  Check https://sparcle.app/download for supported platforms."
    }
  } else {
    Fail "Download failed: $FileName not found.`n  $AppName may not be available for $Arch yet.`n  Check https://sparcle.app/download for supported platforms."
  }
}

# Prune older version caches in the background.
Invoke-CacheGc -CurrentVersionDir $VersionDir

# ── Mark as trusted for Windows to run safely ───────────────────────────────
Info "Marking $AppName as trusted..."
Unblock-File -Path $DlPath -ErrorAction SilentlyContinue
Ok "Installer trusted — no SmartScreen warnings"

# ── Install ─────────────────────────────────────────────────────────────────
Stop-BoltProcesses
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

# ── Persist runtime config ─────────────────────────────────────────────────
# (download cache under $CacheBaseDir is intentionally preserved for re-runs)
Save-PgRuntimeSources -AppIdentifier $AppIdentifier

# ── Launch ─────────────────────────────────────────────────────────────────
# Tauri uses the Cargo crate name for the binary (`bolt.exe`), not the
# productName — same quirk Mac install.sh documents at install_macos().
# The install *directory* is productName ("Bolt Enterprise", "Bolt Personal",
# "Bolt"); the .exe inside is always `bolt.exe`.
$ExeName = "bolt.exe"
$ProgramFiles = $env:ProgramFiles
$LocalPrograms = Join-Path $env:LOCALAPPDATA "Programs"
$SearchRoots = @(
  (Join-Path $ProgramFiles $AppName),
  (Join-Path $LocalPrograms $AppName)
)
$ExePath = $null
foreach ($root in $SearchRoots) {
  $candidate = Join-Path $root $ExeName
  if (Test-Path $candidate) {
    $ExePath = Get-Item $candidate
    break
  }
}

if ($ExePath) {
  Invoke-PostgresPrewarm -ExecutablePath $ExePath.FullName -AppIdentifier $AppIdentifier

  Info "Launching $AppName..."
  Start-Process $ExePath.FullName
  Verify-RuntimeContract
} else {
  # Fallback: try Start Menu shortcut in both user and machine locations.
  # NSIS perMachine installs put shortcuts under %ProgramData%, not %APPDATA%.
  $ShortcutRoots = @(
    (Join-Path $env:APPDATA     'Microsoft\Windows\Start Menu\Programs'),
    (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs')
  )
  $Shortcut = $null
  foreach ($r in $ShortcutRoots) {
    if (Test-Path $r) {
      $Shortcut = Get-ChildItem $r -Filter "$AppName.lnk" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
      if ($Shortcut) { break }
    }
  }
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
    Write-Host "  All features unlocked - free for individuals"
  }
}
Write-Host ""
