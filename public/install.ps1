# Bolt Installer for Windows — https://sparcle.app/install.ps1
# Usage (run in PowerShell):
#   irm https://sparcle.app/install.ps1 | iex                                  # Personal edition (default)
#   $env:EDITION='trial'; irm https://sparcle.app/install.ps1 | iex            # Enterprise Trial
#
# What this does:
#   1. Fetches the latest release version from GitHub
#   2. Downloads the correct installer from GitHub Releases
#   3. Verifies checksums when manifest metadata is available
#   4. Marks the file as trusted for Windows to run safely
#   5. Runs the installer silently
#   6. Installs optional runtime API/PWA components when available
#   7. Launches the app
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

function Wait-ForApiReadiness {
  param(
    [int]$TimeoutSeconds = 90
  )

  $elapsed = 0
  while ($elapsed -lt $TimeoutSeconds) {
    foreach ($port in 13018..13027) {
      foreach ($path in @('/api/health', '/health')) {
        $url = "http://127.0.0.1:$port$path"
        try {
          $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 1 -ErrorAction Stop
          if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 300) {
            return $url
          }
        }
        catch {
          # Keep probing until timeout.
        }
      }
    }

    Start-Sleep -Seconds 1
    $elapsed += 1
  }

  return $null
}

function Verify-RuntimeContract {
  if ($env:BOLT_SKIP_API_HEALTH_CHECK -eq '1') {
    Warn 'Skipping API health verification (BOLT_SKIP_API_HEALTH_CHECK=1)'
    return
  }

  $timeout = 90
  if ($env:BOLT_API_READY_TIMEOUT -and $env:BOLT_API_READY_TIMEOUT -match '^\d+$') {
    $timeout = [int]$env:BOLT_API_READY_TIMEOUT
  }

  Info 'Verifying API runtime readiness...'
  $apiUrl = Wait-ForApiReadiness -TimeoutSeconds $timeout
  if ($apiUrl) {
    Ok "API is healthy at $apiUrl"
    return
  }

  Fail "Install completed, but API readiness check failed (tried /api/health and /health on ports 13018-13027 for ${timeout}s)."
}

$ManifestContent = ""
$ManifestMap = @{}
$ManifestUrl = ""
$ExpectedSha256 = ""
$ResolvedDesktopAsset = ""
$ResolvedDesktopSha = ""
$TargetKey = ""

function Parse-ManifestContent {
  param(
    [string]$Content
  )

  $map = @{}
  if (-not $Content) {
    return $map
  }

  foreach ($line in ($Content -split "`n")) {
    $trimmed = $line.Trim()
    if (-not $trimmed -or $trimmed.StartsWith("#")) {
      continue
    }

    $parts = $trimmed.Split('=', 2)
    if ($parts.Count -eq 2) {
      $map[$parts[0]] = $parts[1]
    }
  }

  return $map
}

function Get-ManifestValue {
  param(
    [string]$Key
  )

  if ($ManifestMap.ContainsKey($Key)) {
    return [string]$ManifestMap[$Key]
  }

  return ""
}

function Get-FileSha256 {
  param(
    [string]$Path
  )

  return (Get-FileHash -Path $Path -Algorithm SHA256).Hash.ToLower()
}

function Verify-DownloadChecksum {
  param(
    [string]$Path,
    [string]$Expected,
    [string]$Label
  )

  if (-not $Expected) {
    return
  }

  $actual = Get-FileSha256 -Path $Path
  if ($actual -ne $Expected.ToLower()) {
    Fail "Checksum mismatch for $Label. Expected $Expected, got $actual."
  }

  Ok "Checksum verified"
}

function Select-ReleaseAsset {
  param(
    [string]$DesiredExt
  )

  $desiredKey = $DesiredExt.ToUpper()
  $assetName = ""
  $assetSha = ""

  if ($ManifestMap.Count -gt 0) {
    $assetName = Get-ManifestValue -Key "DESKTOP_ASSET_${TargetKey}_${desiredKey}"
    $assetSha = Get-ManifestValue -Key "DESKTOP_SHA256_${TargetKey}_${desiredKey}"

    if (-not $assetName) {
      $assetName = Get-ManifestValue -Key "DESKTOP_ASSET_${TargetKey}"
      $assetSha = Get-ManifestValue -Key "DESKTOP_SHA256_${TargetKey}"
    }
  }

  if (-not $assetName) {
    $assetName = "$FilePrefix-$Version-$Arch.$DesiredExt"
    $assetSha = ""
  }

  $script:FileName = $assetName
  $script:FileUrl = "$BaseUrl/$assetName"
  $script:ExpectedSha256 = $assetSha
  $script:ResolvedDesktopAsset = $assetName
  $script:ResolvedDesktopSha = $assetSha
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

function Persist-ReleaseTuple {
  param(
    [string]$AppIdentifier
  )

  $tupleDir = Join-Path $env:APPDATA $AppIdentifier
  New-Item -ItemType Directory -Force -Path $tupleDir | Out-Null
  $tupleFile = Join-Path $tupleDir "release-tuple.env"

  $releaseTag = Get-ManifestValue -Key "RELEASE_TAG"
  $releaseVersion = Get-ManifestValue -Key "RELEASE_VERSION"
  $runtimeTupleId = Get-ManifestValue -Key "RUNTIME_TUPLE_ID"
  $apiVersion = Get-ManifestValue -Key "API_VERSION"
  $apiSha = Get-ManifestValue -Key "API_SHA"
  $pwaVersion = Get-ManifestValue -Key "PWA_VERSION"
  $pwaSha = Get-ManifestValue -Key "PWA_SHA"
  $nativeVersion = Get-ManifestValue -Key "NATIVE_VERSION"
  $nativeSha = Get-ManifestValue -Key "NATIVE_SHA"

  if (-not $releaseTag) { $releaseTag = "v$Version" }
  if (-not $releaseVersion) { $releaseVersion = $Version }

  $lines = @(
    "# Generated by Bolt installer",
    "MANIFEST_URL=$ManifestUrl",
    "RELEASE_TAG=$releaseTag",
    "RELEASE_VERSION=$releaseVersion",
    "EDITION=$Edition",
    "RUST_TRIPLE=$Arch",
    "RUNTIME_TUPLE_ID=$runtimeTupleId",
    "RESOLVED_DESKTOP_ASSET=$ResolvedDesktopAsset",
    "RESOLVED_DESKTOP_SHA256=$ResolvedDesktopSha",
    "API_VERSION=$apiVersion",
    "API_SHA=$apiSha",
    "PWA_VERSION=$pwaVersion",
    "PWA_SHA=$pwaSha",
    "NATIVE_VERSION=$nativeVersion",
    "NATIVE_SHA=$nativeSha"
  )

  Set-Content -Path $tupleFile -Value $lines -Encoding UTF8
  Info "Persisted release tuple metadata: $tupleFile"
}

function Upsert-TupleValue {
  param(
    [string]$TupleFile,
    [string]$Key,
    [string]$Value
  )

  $content = @()
  if (Test-Path $TupleFile) {
    $content = Get-Content -Path $TupleFile -ErrorAction SilentlyContinue
  }

  $filtered = @()
  foreach ($line in $content) {
    if (-not $line.StartsWith("$Key=")) {
      $filtered += $line
    }
  }
  $filtered += "$Key=$Value"

  Set-Content -Path $TupleFile -Value $filtered -Encoding UTF8
}

function Install-OptionalPwaComponent {
  param(
    [string]$AppIdentifier
  )

  $pwaAsset = Get-ManifestValue -Key "PWA_ASSET"
  if (-not $pwaAsset) {
    return
  }

  $pwaSha = Get-ManifestValue -Key "PWA_SHA"
  $pwaChecksum = Get-ManifestValue -Key "PWA_SHA256"
  $componentSuffix = if ($pwaSha) { $pwaSha } else { $Version }

  $componentBase = Join-Path $env:APPDATA "$AppIdentifier\components\pwa"
  $targetDir = Join-Path $componentBase $componentSuffix
  $markerFile = Join-Path $targetDir ".installed"
  $tupleFile = Join-Path (Join-Path $env:APPDATA $AppIdentifier) "release-tuple.env"

  if ((Test-Path $markerFile) -and (Test-Path (Join-Path $targetDir "index.html"))) {
    Upsert-TupleValue -TupleFile $tupleFile -Key "RUNTIME_PWA_DIR" -Value $targetDir
    return
  }

  New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
  $tmpDir = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null
  $pwaTar = Join-Path $tmpDir $pwaAsset
  $pwaUrl = "$BaseUrl/$pwaAsset"

  Info "Downloading optional PWA component: $pwaAsset"
  try {
    Invoke-WebRequest -Uri $pwaUrl -OutFile $pwaTar -UseBasicParsing
  }
  catch {
    Warn "Could not download PWA component $pwaAsset. Continuing with bundled assets."
    Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue
    return
  }

  if ($pwaChecksum) {
    Verify-DownloadChecksum -Path $pwaTar -Expected $pwaChecksum -Label $pwaAsset
  }

  try {
    tar -xzf $pwaTar -C $targetDir
  }
  catch {
    Warn "Failed to extract PWA component $pwaAsset. Continuing with bundled assets."
    Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue
    return
  }

  if (-not (Test-Path (Join-Path $targetDir "index.html"))) {
    Warn "Extracted PWA component is missing index.html. Continuing with bundled assets."
    Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue
    return
  }

  Set-Content -Path $markerFile -Value ([DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")) -Encoding UTF8
  Upsert-TupleValue -TupleFile $tupleFile -Key "RUNTIME_PWA_DIR" -Value $targetDir
  Upsert-TupleValue -TupleFile $tupleFile -Key "RESOLVED_PWA_ASSET" -Value $pwaAsset
  Ok "Installed optional PWA component into $targetDir"
  Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue
}

function Install-OptionalApiComponent {
  param(
    [string]$AppIdentifier
  )

  $apiAsset = Get-ManifestValue -Key "API_ASSET_${TargetKey}"
  if (-not $apiAsset) {
    return
  }

  $apiSha = Get-ManifestValue -Key "API_SHA"
  $apiChecksum = Get-ManifestValue -Key "API_SHA256_${TargetKey}"
  $componentSuffix = if ($apiSha) { $apiSha } else { $Version }

  $componentBase = Join-Path $env:APPDATA "$AppIdentifier\components\api"
  $targetDir = Join-Path $componentBase $componentSuffix
  $runtimeBin = Join-Path $targetDir "bolt-api.exe"
  $markerFile = Join-Path $targetDir ".installed"
  $tupleFile = Join-Path (Join-Path $env:APPDATA $AppIdentifier) "release-tuple.env"

  if ((Test-Path $markerFile) -and (Test-Path $runtimeBin)) {
    Upsert-TupleValue -TupleFile $tupleFile -Key "RUNTIME_API_BIN" -Value $runtimeBin
    return
  }

  New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
  $tmpDir = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null
  $apiTar = Join-Path $tmpDir $apiAsset
  $apiUrl = "$BaseUrl/$apiAsset"

  Info "Downloading optional API component: $apiAsset"
  try {
    Invoke-WebRequest -Uri $apiUrl -OutFile $apiTar -UseBasicParsing
  }
  catch {
    Warn "Could not download API component $apiAsset. Continuing with bundled sidecar."
    Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue
    return
  }

  if ($apiChecksum) {
    Verify-DownloadChecksum -Path $apiTar -Expected $apiChecksum -Label $apiAsset
  }

  try {
    tar -xzf $apiTar -C $targetDir
  }
  catch {
    Warn "Failed to extract API component $apiAsset. Continuing with bundled sidecar."
    Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue
    return
  }

  if (-not (Test-Path $runtimeBin)) {
    Warn "Extracted API component is missing bolt-api.exe. Continuing with bundled sidecar."
    Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue
    return
  }

  Set-Content -Path $markerFile -Value ([DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")) -Encoding UTF8
  Upsert-TupleValue -TupleFile $tupleFile -Key "RUNTIME_API_BIN" -Value $runtimeBin
  Upsert-TupleValue -TupleFile $tupleFile -Key "RESOLVED_API_ASSET" -Value $apiAsset
  Ok "Installed optional API component into $targetDir"
  Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue
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

$TargetKey = $Arch.ToUpper().Replace('-', '_').Replace('.', '_')
$ManifestUrl = "$BaseUrl/bolt-manifest-$Edition.env"
try {
  $ManifestContent = Invoke-WebRequest -Uri $ManifestUrl -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop | Select-Object -ExpandProperty Content
  $ManifestMap = Parse-ManifestContent -Content $ManifestContent
  if ($ManifestMap.Count -gt 0) {
    Info "Using release manifest: bolt-manifest-$Edition.env"
  }
}
catch {
  $ManifestContent = ""
  $ManifestMap = @{}
}

Select-ReleaseAsset -DesiredExt "msi"

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

Verify-DownloadChecksum -Path $DlPath -Expected $ExpectedSha256 -Label $FileName

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
Save-PgRuntimeSources -AppIdentifier $AppIdentifier
Persist-ReleaseTuple -AppIdentifier $AppIdentifier
Install-OptionalApiComponent -AppIdentifier $AppIdentifier
Install-OptionalPwaComponent -AppIdentifier $AppIdentifier

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
