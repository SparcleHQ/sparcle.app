#!/bin/sh
# Bolt Installer — https://sparcle.app/install.sh
# Works on macOS and Linux.
#
# Usage:
#   curl -fsSL https://sparcle.app/install.sh | sh                  # Personal edition (default)
#   curl -fsSL https://sparcle.app/install.sh | sh -s -- trial      # Enterprise Trial
#   curl -fsSL https://sparcle.app/install.sh | sh -s -- personal   # Personal (explicit)
#
# What this does:
#   1. Detects your OS and architecture
#   2. Fetches the latest release version from GitHub
#   3. Downloads the correct installer from GitHub Releases
#   4. Installs to /Applications (admin macOS) or ~/Applications (non-admin macOS), and ~/.local/bin on Linux
#   5. Marks the app as trusted for your OS to launch safely
#   6. Launches the app
#
# No password required. Safe to re-run — overwrites previous installation.
set -e

# ── Config ───────────────────────────────────────────────────────────────────
FALLBACK_VERSION="0.1.0"
GITHUB_REPO="Sparcle-LLC/sparcle.app"
DEFAULT_BOLT_PG_RELEASES_URL="https://github.com/Sparcle-LLC/sparcle.app"
DEFAULT_BOLT_PG_FALLBACK_RELEASES_URL="https://github.com/theseus-rs/postgresql-binaries"
DEFAULT_BOLT_PG_PREWARM_REQUIRED="1"
DEFAULT_BOLT_PG_VERSION="18.3.0"
MANIFEST_PUBLISH_RETRY_MAX="24"
MANIFEST_PUBLISH_RETRY_DELAY="5"
DEFAULT_BOLT_API_PORT_BASE="13018"
DEFAULT_BOLT_API_PORT_RANGE="10"
DOWNLOAD_RETRY_MAX="5"
DOWNLOAD_RETRY_DELAY="2"

# ── Helpers ──────────────────────────────────────────────────────────────────
info()  { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
ok()    { printf '\033[1;32m ✓ \033[0m %s\n' "$1"; }
warn()  { printf '\033[1;33m ⚠ \033[0m %s\n' "$1"; }
fail()  { printf '\033[1;31m ✗ \033[0m %s\n' "$1" >&2; exit 1; }

wait_for_api_readiness() {
  timeout_seconds="${1:-90}"
  port_base="${BOLT_API_PORT_BASE:-$DEFAULT_BOLT_API_PORT_BASE}"
  port_range="${BOLT_API_PORT_RANGE:-$DEFAULT_BOLT_API_PORT_RANGE}"
  port_end=$((port_base + port_range - 1))
  api_url=""
  elapsed=0

  while [ "$elapsed" -lt "$timeout_seconds" ]; do
    for port in $(seq "$port_base" "$port_end"); do
      for path in /api/health /health; do
        if curl -fsS --max-time 1 "http://127.0.0.1:${port}${path}" >/dev/null 2>&1; then
          api_url="http://127.0.0.1:${port}${path}"
          printf '%s\n' "$api_url"
          return 0
        fi
      done
    done
    sleep 1
    elapsed=$((elapsed + 1))
  done

  return 1
}

verify_runtime_contract() {
  timeout_seconds="${BOLT_API_READY_TIMEOUT:-90}"
  port_base="${BOLT_API_PORT_BASE:-$DEFAULT_BOLT_API_PORT_BASE}"
  port_range="${BOLT_API_PORT_RANGE:-$DEFAULT_BOLT_API_PORT_RANGE}"
  port_end=$((port_base + port_range - 1))
  if [ "${BOLT_SKIP_API_HEALTH_CHECK:-0}" = "1" ]; then
    warn "Skipping API health verification (BOLT_SKIP_API_HEALTH_CHECK=1)"
    return 0
  fi

  info "Verifying API runtime readiness..."
  if api_url=$(wait_for_api_readiness "$timeout_seconds"); then
    ok "API is healthy at ${api_url}"
    return 0
  fi

  fail "Install completed, but API readiness check failed (tried /api/health and /health on ports ${port_base}-${port_end} for ${timeout_seconds}s)."
}

manifest_get() {
  key="$1"
  printf '%s\n' "$MANIFEST_CONTENT" | grep "^${key}=" | head -1 | cut -d= -f2-
}

manifest_state_from_content() {
  content="$1"
  printf '%s\n' "$content" | grep '^PUBLISH_STATE=' | head -1 | cut -d= -f2-
}

fetch_release_manifest() {
  retry=1
  while [ "$retry" -le "$MANIFEST_PUBLISH_RETRY_MAX" ]; do
    MANIFEST_CONTENT=$(curl -fsSL --max-time 5 "$MANIFEST_URL" 2>/dev/null || true)
    if [ -z "$MANIFEST_CONTENT" ]; then
      return 0
    fi

    state=$(manifest_state_from_content "$MANIFEST_CONTENT")
    if [ "$state" = "in_progress" ]; then
      if [ "$retry" -eq "$MANIFEST_PUBLISH_RETRY_MAX" ]; then
        fail "The latest release is still being prepared. Please retry in a minute."
      fi
      warn "Latest release is still being prepared — waiting (${retry}/${MANIFEST_PUBLISH_RETRY_MAX})..."
      sleep "$MANIFEST_PUBLISH_RETRY_DELAY"
      retry=$((retry + 1))
      continue
    fi

    return 0
  done
}

select_release_asset() {
  desired_ext="$1"
  desired_key=$(printf '%s' "$desired_ext" | tr '[:lower:]' '[:upper:]')
  asset_name=""
  asset_sha=""

  if [ -n "${MANIFEST_CONTENT:-}" ]; then
    asset_name=$(manifest_get "DESKTOP_ASSET_${TARGET_KEY}_${desired_key}")
    asset_sha=$(manifest_get "DESKTOP_SHA256_${TARGET_KEY}_${desired_key}")

    if [ -z "$asset_name" ]; then
      asset_name=$(manifest_get "DESKTOP_ASSET_${TARGET_KEY}")
      asset_sha=$(manifest_get "DESKTOP_SHA256_${TARGET_KEY}")
    fi
  fi

  if [ -z "$asset_name" ]; then
    asset_name="${FILE_PREFIX}-${VERSION}-${RUST_TRIPLE}.${desired_ext}"
    asset_sha=""
  fi

  FILE_NAME="$asset_name"
  FILE_URL="${BASE_URL}/${FILE_NAME}"
  EXT="${FILE_NAME##*.}"
  EXPECTED_SHA256="$asset_sha"
}

verify_download_checksum() {
  [ -n "${EXPECTED_SHA256:-}" ] || return 0

  if command -v shasum >/dev/null 2>&1; then
    ACTUAL_SHA256=$(shasum -a 256 "${DL_PATH}" | awk '{print $1}')
  elif command -v sha256sum >/dev/null 2>&1; then
    ACTUAL_SHA256=$(sha256sum "${DL_PATH}" | awk '{print $1}')
  else
    warn "No SHA256 tool found (shasum/sha256sum). Skipping checksum verification."
    return 0
  fi

  if [ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]; then
    fail "Checksum mismatch for ${FILE_NAME}. Expected ${EXPECTED_SHA256}, got ${ACTUAL_SHA256}."
  fi

  ok "Checksum verified"
}

configure_pg_runtime_sources() {
  # Allow operators to override via exported env vars before running installer.
  if [ -z "${BOLT_PG_RELEASES_URL:-}" ]; then
    export BOLT_PG_RELEASES_URL="$DEFAULT_BOLT_PG_RELEASES_URL"
  fi

  if [ -z "${BOLT_PG_FALLBACK_RELEASES_URL:-}" ] && [ -n "$DEFAULT_BOLT_PG_FALLBACK_RELEASES_URL" ]; then
    export BOLT_PG_FALLBACK_RELEASES_URL="$DEFAULT_BOLT_PG_FALLBACK_RELEASES_URL"
  fi

  info "PostgreSQL source (primary): ${BOLT_PG_RELEASES_URL}"
  if [ -n "${BOLT_PG_FALLBACK_RELEASES_URL:-}" ]; then
    info "PostgreSQL source (fallback): ${BOLT_PG_FALLBACK_RELEASES_URL}"
  else
    info "PostgreSQL source (fallback): <not configured>"
  fi
}

persist_pg_runtime_sources() {
  app_identifier="$1"
  config_dir=""

  case "$PLATFORM" in
    macos)
      config_dir="${HOME}/Library/Application Support/${app_identifier}/embedded-postgres"
      ;;
    linux)
      config_dir="${XDG_DATA_HOME:-${HOME}/.local/share}/${app_identifier}/embedded-postgres"
      ;;
    *)
      return 0
      ;;
  esac

  mkdir -p "$config_dir" 2>/dev/null || return 0
  config_file="${config_dir}/sources.env"

  {
    echo "# Generated by Bolt installer"
    echo "BOLT_PG_RELEASES_URL=${BOLT_PG_RELEASES_URL}"
    if [ -n "${BOLT_PG_FALLBACK_RELEASES_URL:-}" ]; then
      echo "BOLT_PG_FALLBACK_RELEASES_URL=${BOLT_PG_FALLBACK_RELEASES_URL}"
    fi
  } > "$config_file"

  info "Persisted PostgreSQL sources config: ${config_file}"
}

persist_database_runtime_config() {
  app_identifier="$1"
  config_dir=""

  case "$PLATFORM" in
    macos)
      config_dir="${HOME}/Library/Application Support/${app_identifier}"
      ;;
    linux)
      config_dir="${XDG_DATA_HOME:-${HOME}/.local/share}/${app_identifier}"
      ;;
    *)
      return 0
      ;;
  esac

  mkdir -p "$config_dir" 2>/dev/null || return 0
  config_file="${config_dir}/database.env"

  if [ "${BOLT_DATABASE_MODE:-}" != "external" ] && [ "${BOLT_SKIP_EMBEDDED_PG:-}" != "1" ]; then
    rm -f "$config_file" 2>/dev/null || true
    return 0
  fi

  [ -n "${APP__DATABASE__POSTGRES__HOST:-}" ] || fail "External DB mode requires APP__DATABASE__POSTGRES__HOST"
  [ -n "${APP__DATABASE__POSTGRES__PORT:-}" ] || fail "External DB mode requires APP__DATABASE__POSTGRES__PORT"
  [ -n "${APP__DATABASE__POSTGRES__DATABASE:-}" ] || fail "External DB mode requires APP__DATABASE__POSTGRES__DATABASE"
  [ -n "${APP__DATABASE__POSTGRES__USERNAME:-}" ] || fail "External DB mode requires APP__DATABASE__POSTGRES__USERNAME"
  [ -n "${DATABASE_PASSWORD:-}" ] || fail "External DB mode requires DATABASE_PASSWORD"

  {
    echo "# Generated by Bolt installer"
    echo "BOLT_DATABASE_MODE=external"
    echo "BOLT_SKIP_EMBEDDED_PG=1"
    echo "APP__DATABASE__POSTGRES__HOST=${APP__DATABASE__POSTGRES__HOST}"
    echo "APP__DATABASE__POSTGRES__PORT=${APP__DATABASE__POSTGRES__PORT}"
    echo "APP__DATABASE__POSTGRES__DATABASE=${APP__DATABASE__POSTGRES__DATABASE}"
    echo "APP__DATABASE__POSTGRES__USERNAME=${APP__DATABASE__POSTGRES__USERNAME}"
    echo "DATABASE_PASSWORD=${DATABASE_PASSWORD}"
    if [ -n "${APP__DATABASE__POSTGRES__SSL_MODE:-}" ]; then
      echo "APP__DATABASE__POSTGRES__SSL_MODE=${APP__DATABASE__POSTGRES__SSL_MODE}"
    fi
  } > "$config_file"

  chmod 600 "$config_file" 2>/dev/null || true
  info "Persisted external database config: ${config_file}"
}

runtime_asset_triple() {
  case "$RUST_TRIPLE" in
    aarch64-apple-darwin) echo "aarch64-apple-darwin" ;;
    x86_64-apple-darwin) echo "x86_64-apple-darwin" ;;
    x86_64-unknown-linux-gnu) echo "x86_64-unknown-linux-gnu" ;;
    *) echo "" ;;
  esac
}

runtime_repo_from_url() {
  url="$1"
  repo=$(printf '%s' "$url" | sed -E 's#^https?://(www\.)?github\.com/##' | sed -E 's#/$##')
  owner=$(printf '%s' "$repo" | cut -d/ -f1)
  name=$(printf '%s' "$repo" | cut -d/ -f2)
  if [ -n "$owner" ] && [ -n "$name" ] && [ "$owner" != "$repo" ]; then
    echo "$owner/$name"
  else
    echo ""
  fi
}

seed_embedded_postgres_runtime() {
  app_identifier="$1"

  if [ "${BOLT_DATABASE_MODE:-}" = "external" ] || [ "${BOLT_SKIP_EMBEDDED_PG:-}" = "1" ]; then
    return 0
  fi

  runtime_version="${BOLT_PG_VERSION:-$DEFAULT_BOLT_PG_VERSION}"
  triple=$(runtime_asset_triple)
  [ -n "$triple" ] || return 0

  case "$PLATFORM" in
    macos)
      base_dir="${HOME}/Library/Application Support/${app_identifier}"
      ;;
    linux)
      base_dir="${XDG_DATA_HOME:-${HOME}/.local/share}/${app_identifier}"
      ;;
    *)
      return 0
      ;;
  esac

  install_root="${base_dir}/embedded-postgres/installation"
  target_dir="${install_root}/${runtime_version}"
  pg_ctl_path="${target_dir}/bin/pg_ctl"

  if [ -x "$pg_ctl_path" ]; then
    info "Embedded PostgreSQL runtime already present: ${target_dir}"
    return 0
  fi

  mkdir -p "$install_root"
  tmp_dir=$(mktemp -d)
  asset="postgresql-${runtime_version}-${triple}.tar.gz"

  primary_repo=$(runtime_repo_from_url "${BOLT_PG_RELEASES_URL}")
  fallback_repo=$(runtime_repo_from_url "${BOLT_PG_FALLBACK_RELEASES_URL:-}")

  c1=""
  c2=""
  c3=""
  c4=""
  if [ -n "$primary_repo" ]; then
    c1="https://github.com/${primary_repo}/releases/download/v${runtime_version}/${asset}"
    c2="https://github.com/${primary_repo}/releases/download/${runtime_version}/${asset}"
  fi
  if [ -n "$fallback_repo" ]; then
    c3="https://github.com/${fallback_repo}/releases/download/v${runtime_version}/${asset}"
    c4="https://github.com/${fallback_repo}/releases/download/${runtime_version}/${asset}"
  fi

  archive_path="${tmp_dir}/${asset}"
  downloaded=0
  for url in "$c1" "$c2" "$c3" "$c4"; do
    [ -n "$url" ] || continue
    info "Seeding PostgreSQL runtime from ${url}"
    if curl -fSL -o "$archive_path" "$url" 2>/dev/null; then
      downloaded=1
      break
    fi
  done

  if [ "$downloaded" -ne 1 ]; then
    rm -rf "$tmp_dir"
    warn "Could not pre-seed PostgreSQL runtime archive. Prewarm will attempt runtime download."
    return 0
  fi

  staging_dir="${install_root}/.seed-${runtime_version}-$$"
  rm -rf "$staging_dir"
  mkdir -p "$staging_dir"

  if ! tar -xzf "$archive_path" -C "$staging_dir"; then
    rm -rf "$tmp_dir" "$staging_dir"
    warn "Failed to extract PostgreSQL runtime archive during pre-seed."
    return 0
  fi

  if [ ! -x "${staging_dir}/bin/pg_ctl" ]; then
    chmod -R u+rwX "$staging_dir" 2>/dev/null || true
    chmod 755 "${staging_dir}/bin"/* 2>/dev/null || true
  fi

  if [ "$PLATFORM" = "macos" ]; then
    libpq_path="${staging_dir}/lib/postgresql/libpq.5.dylib"
    if [ -f "$libpq_path" ]; then
      install_name_tool -id "$libpq_path" "$libpq_path" >/dev/null 2>&1 || true
      for target in "${staging_dir}/bin"/* "${staging_dir}/lib/postgresql"/*.dylib; do
        [ -f "$target" ] || continue
        install_name_tool -change "/opt/homebrew/Cellar/postgresql@18/18.3/lib/postgresql/libpq.5.dylib" "$libpq_path" "$target" >/dev/null 2>&1 || true
        install_name_tool -change "/opt/homebrew/opt/postgresql@18/lib/postgresql/libpq.5.dylib" "$libpq_path" "$target" >/dev/null 2>&1 || true
      done
    fi
  fi

  if [ "$PLATFORM" = "macos" ]; then
    xattr -cr "$staging_dir" 2>/dev/null || true
    find "$staging_dir" -type f \( -name "*.dylib" -o -path "*/bin/*" \) -print0 | \
      xargs -0 -I{} /usr/bin/codesign --force --sign - "{}" >/dev/null 2>&1 || true
  fi

  rm -rf "$target_dir"
  mv "$staging_dir" "$target_dir"
  rm -rf "$tmp_dir"
  info "Pre-seeded embedded PostgreSQL runtime: ${target_dir}"
}

stop_running_linux_app() {
  target_path="$1"

  command -v pgrep >/dev/null 2>&1 || return 0

  pgrep -f -- "$target_path" 2>/dev/null | while IFS= read -r pid; do
    [ -n "$pid" ] || continue
    [ "$pid" = "$$" ] && continue

    exe_path=$(readlink -f "/proc/$pid/exe" 2>/dev/null || true)
    exe_name=$(basename "$exe_path" 2>/dev/null || printf '')

    case "$exe_name" in
      sh|dash|bash|zsh|curl|wget|env|nohup|pkill|pgrep)
        continue
        ;;
    esac

    kill "$pid" 2>/dev/null || true
  done

  sleep 1
}

launch_linux_app() {
  app_path="$1"
  app_name="$2"
  launch_log=$(mktemp)

  # If FUSE is usable, try native AppImage launch first.
  if fuse_usable; then
    nohup "$app_path" >"$launch_log" 2>&1 &
    launch_pid=$!
    sleep 2
    if kill -0 "$launch_pid" 2>/dev/null; then
      rm -f "$launch_log"
      return 0
    fi
    # FUSE appeared available but launch still failed — check if it's a
    # FUSE mount error (user namespaces disabled, etc.) before giving up.
    if ! grep -qi 'fuse\|Cannot mount AppImage\|user namespace' "$launch_log"; then
      warn "${app_name} did not stay running after launch."
      warn "Try manually: ${app_path}"
      sed 's/^/   /' "$launch_log" | head -20
      rm -f "$launch_log"
      return 1
    fi
  fi

  # FUSE not available (or FUSE mount failed) — use extract-and-run.
  # This is transparent to the user; the app runs identically.
  APPIMAGE_EXTRACT_AND_RUN=1 nohup "$app_path" >"$launch_log" 2>&1 &
  launch_pid=$!
  sleep 2
  if kill -0 "$launch_pid" 2>/dev/null; then
    rm -f "$launch_log"
    return 0
  fi

  warn "${app_name} did not stay running after launch."
  warn "Try manually: APPIMAGE_EXTRACT_AND_RUN=1 ${app_path}"
  sed 's/^/   /' "$launch_log" | head -20
  rm -f "$launch_log"
  return 1
}

cleanup_legacy_linux_native_install() {
  app_file_name="$1"
  rm -rf "${HOME}/.local/opt/${app_file_name}" 2>/dev/null || true
  rm -f "${HOME}/.local/bin/${app_file_name}" 2>/dev/null || true
  rm -f "${HOME}/.local/share/applications/${app_file_name}.desktop" 2>/dev/null || true
  rm -f "${HOME}/.local/share/icons/hicolor/256x256/apps/${app_file_name}.png" 2>/dev/null || true
}

# Returns 0 if FUSE is usable for AppImage mounting, 1 otherwise.
# Checks: /dev/fuse exists, is readable by the current user, and fusermount/fusermount3 is in PATH.
fuse_usable() {
  [ -e /dev/fuse ] && [ -r /dev/fuse ] && \
    { command -v fusermount >/dev/null 2>&1 || command -v fusermount3 >/dev/null 2>&1; }
}

# Idempotently add a directory to PATH in common shell rc files.
add_to_path() {
  dir="$1"
  line="export PATH=\"${dir}:\${PATH}\""
  added=0
  for rc in "${HOME}/.bashrc" "${HOME}/.zshrc" "${HOME}/.profile"; do
    [ -f "$rc" ] || continue
    grep -qF "${dir}" "$rc" 2>/dev/null && continue
    printf '\n# Added by Bolt installer\n%s\n' "$line" >> "$rc"
    ok "Added ${dir} to PATH in $(basename "$rc") — restart shell or: source $rc"
    added=1
  done
  if [ "$added" -eq 0 ]; then
    warn "${dir} is not in your PATH. Add it: ${line}"
  fi
}

prewarm_embedded_postgres() {
  app_bin="$1"
  app_identifier="$2"

  if [ "${BOLT_DATABASE_MODE:-}" = "external" ] || [ "${BOLT_SKIP_EMBEDDED_PG:-}" = "1" ]; then
    info "Skipping embedded PostgreSQL prewarm (external database mode enabled)"
    return 0
  fi

  prewarm_required="${BOLT_PG_PREWARM_REQUIRED:-$DEFAULT_BOLT_PG_PREWARM_REQUIRED}"

  [ -x "$app_bin" ] || {
    warn "Skipping PostgreSQL prewarm: executable not found at ${app_bin}"
    return 0
  }

  info "Prewarming embedded PostgreSQL (user-space, one-time setup)..."
  prewarm_log=$(mktemp)

  if [ "${PLATFORM}" = "linux" ] && echo "$app_bin" | grep -q '\.AppImage$'; then
    if BOLT_APP_IDENTIFIER="$app_identifier" APPIMAGE_EXTRACT_AND_RUN=1 "$app_bin" prewarm-postgres >"$prewarm_log" 2>&1; then
      ok "Embedded PostgreSQL prewarm complete"
    else
      if [ "$prewarm_required" = "1" ] || [ "$prewarm_required" = "true" ] || [ "$prewarm_required" = "TRUE" ] || [ "$prewarm_required" = "yes" ] || [ "$prewarm_required" = "YES" ]; then
        warn "Embedded PostgreSQL prewarm failed (strict mode enabled)"
        sed 's/^/   /' "$prewarm_log" | tail -40
        rm -f "$prewarm_log"
        fail "Embedded PostgreSQL prewarm failed. Fix network/runtime source and re-run installer."
      fi
      warn "Embedded PostgreSQL prewarm failed (app will retry on first launch)"
      sed 's/^/   /' "$prewarm_log" | tail -20
    fi
  else
    if BOLT_APP_IDENTIFIER="$app_identifier" "$app_bin" prewarm-postgres >"$prewarm_log" 2>&1; then
      ok "Embedded PostgreSQL prewarm complete"
    else
      if [ "$prewarm_required" = "1" ] || [ "$prewarm_required" = "true" ] || [ "$prewarm_required" = "TRUE" ] || [ "$prewarm_required" = "yes" ] || [ "$prewarm_required" = "YES" ]; then
        warn "Embedded PostgreSQL prewarm failed (strict mode enabled)"
        sed 's/^/   /' "$prewarm_log" | tail -40
        rm -f "$prewarm_log"
        fail "Embedded PostgreSQL prewarm failed. Fix network/runtime source and re-run installer."
      fi
      warn "Embedded PostgreSQL prewarm failed (app will retry on first launch)"
      sed 's/^/   /' "$prewarm_log" | tail -20
    fi
  fi

  rm -f "$prewarm_log"
}

resolve_macos_executable() {
  app_path="$1"
  plist_path="$app_path/Contents/Info.plist"
  macos_dir="$app_path/Contents/MacOS"

  if [ -f "$plist_path" ]; then
    exec_name=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$plist_path" 2>/dev/null || true)
    if [ -n "$exec_name" ] && [ -x "$macos_dir/$exec_name" ]; then
      echo "$macos_dir/$exec_name"
      return 0
    fi
  fi

  first_exec=$(find "$macos_dir" -maxdepth 1 -type f -perm -111 2>/dev/null | head -1 || true)
  if [ -n "$first_exec" ]; then
    echo "$first_exec"
    return 0
  fi

  echo "$macos_dir/bolt"
}
# ── Pre-flight checks ───────────────────────────────────────────────────────
OS="$(uname)"
case "$OS" in
  Darwin) PLATFORM="macos" ;;
  Linux)  PLATFORM="linux" ;;
  *)      fail "Unsupported OS: $OS. Visit https://sparcle.app/download" ;;
esac

command -v curl >/dev/null 2>&1 || fail "curl is required but not found."
configure_pg_runtime_sources

# ── Cleanup trap ─────────────────────────────────────────────────────────────
TMPDIR_DL=""
cleanup() {
  if [ -n "${TMPDIR_DL}" ] && [ -d "${TMPDIR_DL}" ]; then
    # Detach any mounted DMG on macOS
    if [ "$PLATFORM" = "macos" ] && [ -d "${TMPDIR_DL}/bolt-mount" ]; then
      hdiutil detach "${TMPDIR_DL}/bolt-mount" -quiet 2>/dev/null || true
    fi
    rm -rf "${TMPDIR_DL}"
  fi
}
trap cleanup EXIT

# ── Fetch latest version from GitHub ─────────────────────────────────────────
VERSION="$FALLBACK_VERSION"
LATEST_URL="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"
API_RESP=$(curl -fsSL --max-time 5 "$LATEST_URL" 2>/dev/null || true)
V=$(echo "$API_RESP" | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/' | sed 's/^v//' || true)
if [ -n "$V" ]; then
  VERSION="$V"
else
  warn "Could not fetch latest version — using v${VERSION}"
fi
BASE_URL="https://github.com/${GITHUB_REPO}/releases/download/v${VERSION}"

# ── Parse edition argument ───────────────────────────────────────────────────
EDITION="${1:-personal}"
case "$EDITION" in
  personal)
    APP_NAME="Bolt Personal"
    FILE_PREFIX="Bolt-Personal"
    ;;
  trial|enterprise)
    EDITION="trial"
    APP_NAME="Bolt Enterprise"
    FILE_PREFIX="Bolt-Enterprise-Trial"
    ;;
  *)
    fail "Unknown edition: $EDITION. Use 'personal' or 'trial'."
    ;;
esac

# ── Detect architecture ─────────────────────────────────────────────────────
ARCH=$(uname -m)
case "$PLATFORM-$ARCH" in
  macos-arm64)   RUST_TRIPLE="aarch64-apple-darwin" ; EXT="dmg" ;;
  macos-x86_64)  RUST_TRIPLE="x86_64-apple-darwin" ; EXT="dmg" ;;
  linux-x86_64)  RUST_TRIPLE="x86_64-unknown-linux-gnu" ; EXT="AppImage" ;;
  linux-aarch64) fail "Bolt desktop is not yet available for Linux ARM64.\n  The CLI tool is available: curl -fsSL https://sparcle.app/install-cli.sh | sh" ;;
  *)             fail "Unsupported platform: $PLATFORM $ARCH. Visit https://sparcle.app/download" ;;
esac

# ── Prefer .deb on Debian/Ubuntu (better desktop integration) ────────────
USE_DEB=0
if [ "$PLATFORM" = "linux" ] && command -v dpkg >/dev/null 2>&1; then
  USE_DEB=1
  EXT="deb"
fi

TARGET_KEY=$(printf '%s' "$RUST_TRIPLE" | tr '[:lower:]-.' '[:upper:]__')
MANIFEST_URL="${BASE_URL}/bolt-manifest-${EDITION}.env"
fetch_release_manifest

select_release_asset "$EXT"

echo ""
echo "  ⚡ Bolt Installer"
echo "  ─────────────────────────────────────"
echo "  Edition:       ${APP_NAME}"
echo "  Version:       ${VERSION}"
echo "  Platform:      ${PLATFORM} (${ARCH})"
echo ""

# ── Download ─────────────────────────────────────────────────────────────────
TMPDIR_DL=$(mktemp -d)  # cleaned up by EXIT trap
DL_PATH="${TMPDIR_DL}/${FILE_NAME}"

info "Downloading ${FILE_NAME}..."
HTTP_CODE=$(curl -fSL \
  --retry "${DOWNLOAD_RETRY_MAX}" \
  --retry-all-errors \
  --retry-delay "${DOWNLOAD_RETRY_DELAY}" \
  --connect-timeout 15 \
  --max-time 300 \
  -w '%{http_code}' \
  -o "${DL_PATH}" \
  "${FILE_URL}" 2>/dev/null) || true

if [ ! -f "${DL_PATH}" ] || [ "$(wc -c < "${DL_PATH}" | tr -d ' ')" -lt 1000 ]; then
  rm -rf "${TMPDIR_DL}"
  # On Linux with .deb, retry with AppImage before giving up
  if [ "$USE_DEB" -eq 1 ]; then
    warn ".deb package not available — falling back to AppImage..."
    USE_DEB=0
    select_release_asset "AppImage"
    TMPDIR_DL=$(mktemp -d)
    DL_PATH="${TMPDIR_DL}/${FILE_NAME}"
    HTTP_CODE=$(curl -fSL \
      --retry "${DOWNLOAD_RETRY_MAX}" \
      --retry-all-errors \
      --retry-delay "${DOWNLOAD_RETRY_DELAY}" \
      --connect-timeout 15 \
      --max-time 300 \
      -w '%{http_code}' \
      -o "${DL_PATH}" \
      "${FILE_URL}" 2>/dev/null) || true
    if [ ! -f "${DL_PATH}" ] || [ "$(wc -c < "${DL_PATH}" | tr -d ' ')" -lt 1000 ]; then
      rm -rf "${TMPDIR_DL}"
      fail "Download failed: ${FILE_NAME} not found (HTTP ${HTTP_CODE}).\n  ${APP_NAME} may not be available for ${PLATFORM} ${ARCH} yet.\n  Check https://sparcle.app/download for supported platforms."
    fi
  else
    fail "Download failed: ${FILE_NAME} not found (HTTP ${HTTP_CODE}).\n  ${APP_NAME} may not be available for ${PLATFORM} ${ARCH} yet.\n  Check https://sparcle.app/download for supported platforms."
  fi
fi

verify_download_checksum

ok "Downloaded $(du -h "${DL_PATH}" | cut -f1 | tr -d ' ')"

# ══════════════════════════════════════════════════════════════════════════════
# macOS: mount DMG → copy .app → trust → launch
# ══════════════════════════════════════════════════════════════════════════════
install_macos() {
  MOUNT_POINT="${TMPDIR_DL}/bolt-mount"
  mkdir -p "${MOUNT_POINT}"

  info "Installing ${APP_NAME}..."
  hdiutil attach "${DL_PATH}" -quiet -nobrowse -mountpoint "${MOUNT_POINT}" 2>/dev/null \
    || fail "Failed to mount DMG. The download may be corrupted — try again."

  SOURCE_APP=$(find "${MOUNT_POINT}" -maxdepth 1 -name "*.app" | head -1)
  [ -n "${SOURCE_APP}" ] || { hdiutil detach "${MOUNT_POINT}" -quiet 2>/dev/null; fail "No .app found in DMG."; }

  pkill -f "${APP_NAME}.app/Contents/MacOS" 2>/dev/null || true
  sleep 1

  INSTALL_BASE="/Applications"
  INSTALL_APP_PATH="${INSTALL_BASE}/${APP_NAME}.app"
  installed=0

  # First try system Applications without elevation.
  rm -rf "${INSTALL_APP_PATH}" 2>/dev/null || true
  if cp -R "${SOURCE_APP}" "${INSTALL_BASE}/" 2>/dev/null; then
    installed=1
  fi

  # If needed, try sudo only when a tty is available.
  if [ "$installed" -ne 1 ] && [ -r /dev/tty ]; then
    info "Password may be required to write to /Applications..."
    sudo rm -rf "${INSTALL_APP_PATH}" 2>/dev/null < /dev/tty || true
    if sudo cp -R "${SOURCE_APP}" "${INSTALL_BASE}/" < /dev/tty; then
      installed=1
    fi
  fi

  # Non-admin fallback: per-user Applications folder.
  if [ "$installed" -ne 1 ]; then
    INSTALL_BASE="${HOME}/Applications"
    INSTALL_APP_PATH="${INSTALL_BASE}/${APP_NAME}.app"
    info "Falling back to per-user install location: ${INSTALL_BASE}"
    mkdir -p "${INSTALL_BASE}" || { hdiutil detach "${MOUNT_POINT}" -quiet 2>/dev/null; fail "Failed to create ${INSTALL_BASE}."; }
    rm -rf "${INSTALL_APP_PATH}" 2>/dev/null || true
    cp -R "${SOURCE_APP}" "${INSTALL_BASE}/" \
      || { hdiutil detach "${MOUNT_POINT}" -quiet 2>/dev/null; fail "Failed to install to ${INSTALL_BASE}."; }
    installed=1
  fi

  [ "$installed" -eq 1 ] || { hdiutil detach "${MOUNT_POINT}" -quiet 2>/dev/null; fail "Failed to install ${APP_NAME}."; }
  ok "Installed to ${INSTALL_APP_PATH}"

  info "Marking ${APP_NAME} as trusted..."
  if ! xattr -cr "${INSTALL_APP_PATH}" 2>/dev/null; then
    if [ -r /dev/tty ]; then
      sudo xattr -cr "${INSTALL_APP_PATH}" 2>/dev/null < /dev/tty || true
    fi
  fi
  ok "App trusted — ready to launch"

  APP_IDENTIFIER="app.sparcle.bolt.personal"
  if [ "$EDITION" = "trial" ]; then
    APP_IDENTIFIER="app.sparcle.bolt.enterprise"
  fi
  persist_pg_runtime_sources "$APP_IDENTIFIER"
  seed_embedded_postgres_runtime "$APP_IDENTIFIER"
  persist_database_runtime_config "$APP_IDENTIFIER"
  APP_EXECUTABLE=$(resolve_macos_executable "${INSTALL_APP_PATH}")
  prewarm_embedded_postgres "$APP_EXECUTABLE" "$APP_IDENTIFIER"

  # Link CLI
  mkdir -p "${HOME}/.local/bin"
  ln -sf "${INSTALL_APP_PATH}/Contents/MacOS/${APP_NAME}" "${HOME}/.local/bin/bolt" 2>/dev/null || true
  case ":${PATH}:" in
    *":${HOME}/.local/bin:"*) ;;
    *) add_to_path "${HOME}/.local/bin" ;;
  esac

  hdiutil detach "${MOUNT_POINT}" -quiet 2>/dev/null || true

  info "Launching ${APP_NAME}..."
  open "${INSTALL_APP_PATH}"
  verify_runtime_contract
}

# ══════════════════════════════════════════════════════════════════════════════
# Linux (.deb): install via dpkg → launch
# ══════════════════════════════════════════════════════════════════════════════
install_linux_deb() {
  APP_FILE_NAME=$(echo "${APP_NAME}" | tr ' ' '-')

  info "Installing ${APP_NAME} via .deb package..."

  cleanup_legacy_linux_native_install "${APP_FILE_NAME}"

  # Stop any running instance
  APPIMAGE_PATH="${HOME}/.local/bin/${APP_FILE_NAME}.AppImage"
  stop_running_linux_app "${APPIMAGE_PATH}"
  pkill -f "${APP_FILE_NAME}" 2>/dev/null || true
  sleep 1

  # Remove old AppImage if switching to .deb
  rm -f "${APPIMAGE_PATH}" 2>/dev/null || true

  sudo dpkg -i "${DL_PATH}" < /dev/tty \
    || { sudo apt-get install -f -y < /dev/tty 2>/dev/null || true; sudo dpkg -i "${DL_PATH}" < /dev/tty; } \
    || fail "Failed to install .deb package. Try: sudo dpkg -i ${DL_PATH}"
  ok "Installed ${APP_NAME} via dpkg"

  # Find and launch the installed binary
  LAUNCH_BIN=""
  for candidate in "/usr/bin/${APP_FILE_NAME}" "/usr/local/bin/${APP_FILE_NAME}"; do
    [ -x "$candidate" ] && LAUNCH_BIN="$candidate" && break
  done
  if [ -z "$LAUNCH_BIN" ]; then
    LAUNCH_BIN=$(dpkg -L "${DL_PATH##*/}" 2>/dev/null | grep '/usr.*/bin/' | head -1 || true)
  fi

  if [ -n "$LAUNCH_BIN" ] && [ -x "$LAUNCH_BIN" ]; then
    APP_IDENTIFIER="app.sparcle.bolt.personal"
    if [ "$EDITION" = "trial" ]; then
      APP_IDENTIFIER="app.sparcle.bolt.enterprise"
    fi
    persist_pg_runtime_sources "$APP_IDENTIFIER"
    seed_embedded_postgres_runtime "$APP_IDENTIFIER"
    persist_database_runtime_config "$APP_IDENTIFIER"
    prewarm_embedded_postgres "$LAUNCH_BIN" "$APP_IDENTIFIER"

    info "Launching ${APP_NAME}..."
    nohup "$LAUNCH_BIN" >/dev/null 2>&1 &
    verify_runtime_contract
  else
    info "Installed — launch ${APP_NAME} from your application menu."
  fi
}

# ══════════════════════════════════════════════════════════════════════════════
# Linux (AppImage): install AppImage → make executable → launch
# ══════════════════════════════════════════════════════════════════════════════
install_linux_appimage() {
  if ! command -v fusermount >/dev/null 2>&1 && ! command -v fusermount3 >/dev/null 2>&1; then
    warn "FUSE not found — AppImage needs it to run."
    if command -v apt-get >/dev/null 2>&1; then
      info "Detected Ubuntu/Debian — installing libfuse2..."
      sudo apt-get update -qq < /dev/tty || true
      sudo apt-get install -y -qq libfuse2 < /dev/tty \
        && ok "libfuse2 installed" \
        || warn "Could not install libfuse2. You may need to run: sudo apt install libfuse2"
    elif command -v dnf >/dev/null 2>&1; then
      info "Detected Fedora/RHEL — installing fuse-libs..."
      sudo dnf install -y -q fuse-libs < /dev/tty \
        && ok "fuse-libs installed" \
        || warn "Could not install fuse-libs. You may need to run: sudo dnf install fuse-libs"
    elif command -v pacman >/dev/null 2>&1; then
      info "Detected Arch — installing fuse2..."
      sudo pacman -S --noconfirm fuse2 < /dev/tty \
        && ok "fuse2 installed" \
        || warn "Could not install fuse2. You may need to run: sudo pacman -S fuse2"
    else
      warn "Could not detect package manager. Install FUSE manually for AppImage support."
    fi
  fi

  INSTALL_DIR="${HOME}/.local/bin"
  mkdir -p "${INSTALL_DIR}"

  APP_FILE_NAME=$(echo "${APP_NAME}" | tr ' ' '-')
  DEST="${INSTALL_DIR}/${APP_FILE_NAME}.AppImage"

  info "Installing ${APP_NAME} to ${DEST}..."

  cleanup_legacy_linux_native_install "${APP_FILE_NAME}"
  stop_running_linux_app "${DEST}"

  mv "${DL_PATH}" "${DEST}"
  chmod +x "${DEST}"
  ok "Installed to ${DEST}"

  # ── Desktop integration: .desktop file + icon ──────────────────────────────
  ICON_DIR="${HOME}/.local/share/icons/hicolor/256x256/apps"
  ICON_PATH="${ICON_DIR}/${APP_FILE_NAME}.png"
  DESKTOP_DIR="${HOME}/.local/share/applications"
  DESKTOP_FILE="${DESKTOP_DIR}/${APP_FILE_NAME}.desktop"

  mkdir -p "${ICON_DIR}" "${DESKTOP_DIR}"

  # Extract icon from AppImage (Tauri embeds .DirIcon as PNG)
  EXTRACT_TMP=$(mktemp -d)
  if cd "${EXTRACT_TMP}" && "${DEST}" --appimage-extract "*.png" >/dev/null 2>&1; then
    EXTRACTED_ICON=$(find "${EXTRACT_TMP}/squashfs-root" -name "*.png" -type f 2>/dev/null | head -1)
    if [ -n "${EXTRACTED_ICON}" ]; then
      cp "${EXTRACTED_ICON}" "${ICON_PATH}" 2>/dev/null && ok "Icon installed"
    fi
  fi
  rm -rf "${EXTRACT_TMP}"
  cd "${INSTALL_DIR}" 2>/dev/null || true

  cat > "${DESKTOP_FILE}" <<DESKTOP_EOF
[Desktop Entry]
Type=Application
Name=${APP_NAME}
Exec=${DEST}
Icon=${APP_FILE_NAME}
Comment=Bolt — AI-powered productivity
Categories=Office;Productivity;
Terminal=false
StartupNotify=true
DESKTOP_EOF
  chmod +x "${DESKTOP_FILE}"
  ok "Desktop shortcut created — ${APP_NAME} will appear in your application menu"

  case ":${PATH}:" in
    *":${INSTALL_DIR}:"*) ;;
    *) add_to_path "${INSTALL_DIR}" ;;
  esac

  APP_IDENTIFIER="app.sparcle.bolt.personal"
  if [ "$EDITION" = "trial" ]; then
    APP_IDENTIFIER="app.sparcle.bolt.enterprise"
  fi
  persist_pg_runtime_sources "$APP_IDENTIFIER"
  seed_embedded_postgres_runtime "$APP_IDENTIFIER"
  persist_database_runtime_config "$APP_IDENTIFIER"
  prewarm_embedded_postgres "$DEST" "$APP_IDENTIFIER"

  info "Launching ${APP_NAME}..."
  launch_linux_app "${DEST}" "${APP_NAME}" || return 1
  verify_runtime_contract
}

# ══════════════════════════════════════════════════════════════════════════════
# Linux: dispatch to .deb or AppImage installer
# ══════════════════════════════════════════════════════════════════════════════
install_linux() {
  if [ "$USE_DEB" -eq 1 ]; then
    install_linux_deb
  else
    install_linux_appimage
  fi
}

# ── Run platform installer ───────────────────────────────────────────────────
case "$PLATFORM" in
  macos) install_macos ;;
  linux) install_linux || { echo ""; fail "Installation succeeded but ${APP_NAME} failed to launch. See above for details."; } ;;
esac

echo ""
echo "  ✅  ${APP_NAME} is running!"
echo ""
if [ "$EDITION" = "personal" ]; then
  echo "  Next: Add your AI API key in Settings → AI Configuration"
  echo "  Tip:  Google Gemini has a free tier — works great with Bolt"
else
  echo "  Next: Try instant demo mode, or configure your own IDP + LLM"
  echo "  Trial: 7 days, all features unlocked"
fi
echo ""
echo ""
