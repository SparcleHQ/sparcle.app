#!/bin/sh
# Bolt Installer — https://sparcle.app/install.sh
# Works on macOS and Linux.
#
# CANONICAL SOURCE OF TRUTH for the consumer `curl | sh` installer. The copy at
# bolt-native/scripts/install/install.sh is a read-only mirror — edit HERE only
# and re-sync it. (dist/install.sh is the built artifact `astro build` emits.)
#
# Usage:
#   curl -fsSL https://sparcle.app/install.sh | sh                          # Bolt (free), latest
#   curl -fsSL https://sparcle.app/install.sh | sh -s -- personal 0.1.18    # Specific version (positional)
#   BOLT_VERSION=0.1.18 curl -fsSL https://sparcle.app/install.sh | sh      # Specific version (env)
#
# Backwards-compat: `personal`, `free`, `trial`, and `enterprise` are all
# accepted as the edition argument and resolve to the same free Bolt build.
#
# What this does:
#   1. Detects your OS and architecture
#   2. Resolves the target version (BOLT_VERSION env > positional arg > /releases/latest)
#   3. Downloads the correct installer from GitHub Releases (with on-disk cache)
#   4. On Linux, auto-falls-back to the most recent release that ships Linux artifacts
#      (if BOLT_VERSION is not pinned by the user)
#   5. Installs to /Applications (admin macOS) or ~/Applications (non-admin macOS), and ~/.local/bin on Linux
#   6. Marks the app as trusted for your OS to launch safely
#   7. Launches the app
#
# Re-runs are network-free when the cached download still matches the remote
# (per-version cache at ~/.cache/bolt-installer/v<version>/ — override with
# BOLT_INSTALLER_CACHE_DIR).
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
DEFAULT_BOLT_API_PORT_BASE="13018"
DEFAULT_BOLT_API_PORT_RANGE="10"
DOWNLOAD_RETRY_MAX="5"
DOWNLOAD_RETRY_DELAY="2"
CACHE_BASE_DIR="${BOLT_INSTALLER_CACHE_DIR:-${HOME}/.cache/bolt-installer}"
CACHE_KEEP_VERSIONS="2"

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

  # Try plaintext http:// first; fall back to https:// (with -k for the
  # locally-generated sidecar cert) since the API may be in TLS mode.
  while [ "$elapsed" -lt "$timeout_seconds" ]; do
    for port in $(seq "$port_base" "$port_end"); do
      for path in /api/health /health; do
        if curl -fsS --max-time 1 "http://127.0.0.1:${port}${path}" >/dev/null 2>&1; then
          api_url="http://127.0.0.1:${port}${path}"
          printf '%s\n' "$api_url"
          return 0
        fi
        if curl -fskS --max-time 1 "https://127.0.0.1:${port}${path}" >/dev/null 2>&1; then
          api_url="https://127.0.0.1:${port}${path}"
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
    BOLT_LAUNCHED=1
    return 0
  fi

  info "Verifying API runtime readiness..."
  if api_url=$(wait_for_api_readiness "$timeout_seconds"); then
    ok "API is healthy at ${api_url}"
    BOLT_LAUNCHED=1
    return 0
  fi

  fail "Install completed, but API readiness check failed (tried /api/health and /health on ports ${port_base}-${port_end} for ${timeout_seconds}s)."
}

select_release_asset() {
  desired_ext="$1"
  FILE_NAME="${FILE_PREFIX}-${VERSION}-${RUST_TRIPLE}.${desired_ext}"
  FILE_URL="${BASE_URL}/${FILE_NAME}"
  EXT="${FILE_NAME##*.}"
}

# HEAD the URL and probe size + etag of the final redirect target.
# Side effects: sets REMOTE_SIZE and REMOTE_ETAG (either may be empty).
probe_remote_asset() {
  url="$1"
  REMOTE_SIZE=""
  REMOTE_ETAG=""
  headers=$(curl -fsILS --max-time 30 "$url" 2>/dev/null || true)
  [ -n "$headers" ] || return 1
  REMOTE_SIZE=$(printf '%s\n' "$headers" | awk 'BEGIN{IGNORECASE=1} tolower($1)=="content-length:" {gsub(/\r/,""); v=$2} END{print v}')
  REMOTE_ETAG=$(printf '%s\n' "$headers" | awk 'BEGIN{IGNORECASE=1} tolower($1)=="etag:" {gsub(/\r/,""); v=$2; for(i=3;i<=NF;i++) v=v" "$i} END{print v}')
  [ -n "$REMOTE_SIZE" ] || return 1
  return 0
}

# Returns 0 (skip download) if the cached file matches the remote.
# Requires probe_remote_asset to have been run first.
is_cache_fresh() {
  cached="$1"
  meta="$2"
  [ -f "$cached" ] || return 1
  local_size=$(wc -c < "$cached" 2>/dev/null | tr -d ' ')
  [ -n "$local_size" ] && [ "$local_size" -gt 1000 ] || return 1
  [ -n "$REMOTE_SIZE" ] || return 1
  [ "$local_size" = "$REMOTE_SIZE" ] || return 1
  if [ -f "$meta" ] && [ -n "$REMOTE_ETAG" ]; then
    saved_etag=$(awk -F'\t' '$1=="etag" {sub(/^etag\t/,""); print; exit}' "$meta")
    if [ -n "$saved_etag" ] && [ "$saved_etag" != "$REMOTE_ETAG" ]; then
      return 1
    fi
  fi
  return 0
}

write_cache_meta() {
  meta="$1"
  {
    printf 'size\t%s\n' "$REMOTE_SIZE"
    [ -n "$REMOTE_ETAG" ] && printf 'etag\t%s\n' "$REMOTE_ETAG"
    printf 'fetched_at\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "")"
  } > "$meta" 2>/dev/null || true
}

gc_cache() {
  [ -d "$CACHE_BASE_DIR" ] || return 0
  current="v${VERSION}"
  # Keep the current version + the most-recent (CACHE_KEEP_VERSIONS - 1) others.
  ls -1t "$CACHE_BASE_DIR" 2>/dev/null | while IFS= read -r entry; do
    case "$entry" in
      v*) printf '%s\n' "$entry" ;;
    esac
  done | awk -v cur="$current" -v keep="$CACHE_KEEP_VERSIONS" '
    $0==cur {next}
    {others[++n]=$0}
    END {
      # Keep (keep-1) most-recent non-current; delete the rest.
      drop_from = keep
      for (i=drop_from; i<=n; i++) print others[i]
    }
  ' | while IFS= read -r stale; do
    [ -n "$stale" ] || continue
    rm -rf "${CACHE_BASE_DIR}/${stale}" 2>/dev/null || true
  done
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
# Set to 1 only once the app is confirmed launched+healthy (see
# verify_runtime_contract) so the closing banner never claims "running" when the
# app was merely installed but not started.
BOLT_LAUNCHED=0
OS="$(uname)"
case "$OS" in
  Darwin) PLATFORM="macos" ;;
  Linux)  PLATFORM="linux" ;;
  *)      fail "Unsupported OS: $OS. Visit https://sparcle.app/download" ;;
esac

command -v curl >/dev/null 2>&1 || fail "curl is required but not found."
configure_pg_runtime_sources

# ── Cleanup trap ─────────────────────────────────────────────────────────────
# Note: the download cache under $CACHE_BASE_DIR persists across runs so that
# re-running this installer with the same version skips the download entirely.
# Only ephemeral state (DMG mount point, .partial residue from a failed
# download) is cleaned up on exit.
TMPDIR_MOUNT=""
PARTIAL_PATH=""
cleanup() {
  if [ -n "${TMPDIR_MOUNT}" ] && [ -d "${TMPDIR_MOUNT}" ]; then
    if [ "$PLATFORM" = "macos" ]; then
      hdiutil detach "${TMPDIR_MOUNT}" -quiet 2>/dev/null || true
    fi
    rm -rf "${TMPDIR_MOUNT}"
  fi
  # Drop any partial download that didn't finish; never touch the cache file.
  if [ -n "${PARTIAL_PATH}" ] && [ -f "${PARTIAL_PATH}" ]; then
    rm -f "${PARTIAL_PATH}" 2>/dev/null || true
  fi
}
trap cleanup EXIT

# ── Parse edition argument ───────────────────────────────────────────────────
# Bolt is one product (Bolt Enterprise) shipped as one binary per platform,
# free to download for everyone. The legacy `personal`, `free`, and `trial`
# argument values are still accepted as no-op aliases so any bookmarked curl
# one-liner keeps working. Bundle id and installed-app folder are
# `app.sparcle.bolt.enterprise` — existing "Bolt Enterprise" installs (incl.
# the old "trial" build) upgrade in place; older "Bolt Personal" installs
# are not migrated (those users re-curl-install if they care).
EDITION="${1:-enterprise}"
case "$EDITION" in
  enterprise|personal|free|trial)
    APP_NAME="Bolt Enterprise"
    FILE_PREFIX="Bolt-Enterprise"
    ;;
  *)
    fail "Unknown edition: $EDITION. Bolt is free; just run without arguments."
    ;;
esac

# ── Resolve version (env > positional arg > /releases/latest) ────────────────
# VERSION_PINNED=1 means the user explicitly chose a version, so on Linux
# we should NOT silently walk back to an older release if assets are missing.
VERSION=""
VERSION_PINNED=0
if [ -n "${BOLT_VERSION:-}" ]; then
  VERSION="$(printf '%s' "$BOLT_VERSION" | sed 's/^v//')"
  VERSION_PINNED=1
elif [ -n "${2:-}" ]; then
  VERSION="$(printf '%s' "$2" | sed 's/^v//')"
  VERSION_PINNED=1
fi

if [ -z "$VERSION" ]; then
  # Per-platform "latest" pointer: each OS/arch advances independently as its build
  # publishes (channel-stable/bolt-latest-<os>-<arch>.json). Falls back to the
  # global latest release + the arch walk-back below when no pointer exists.
  case "$(uname -s)" in Darwin) _ph_os=darwin ;; Linux) _ph_os=linux ;; *) _ph_os=linux ;; esac
  case "$(uname -m)" in arm64|aarch64) _ph_arch=aarch64 ;; *) _ph_arch=x86_64 ;; esac
  PTR_URL="https://github.com/${GITHUB_REPO}/releases/download/${CHANNEL_TAG:-channel-stable}/bolt-latest-${_ph_os}-${_ph_arch}.json"
  PTR_V=$(curl -fsSL --max-time 5 "$PTR_URL" 2>/dev/null | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1 | sed 's/^v//' || true)
  if [ -n "$PTR_V" ]; then
    VERSION="$PTR_V"
  else
    LATEST_URL="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"
    API_RESP=$(curl -fsSL --max-time 5 "$LATEST_URL" 2>/dev/null || true)
    V=$(echo "$API_RESP" | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/' | sed 's/^v//' || true)
    if [ -n "$V" ]; then
      VERSION="$V"
    else
      VERSION="$FALLBACK_VERSION"
      warn "Could not fetch latest version — using v${VERSION}"
    fi
  fi
fi
BASE_URL="https://github.com/${GITHUB_REPO}/releases/download/v${VERSION}"

# find_latest_release_with_asset(pattern_glob_suffix)
# Walks the recent releases list and prints the tag (without leading v) of the
# most recent release whose asset name matches the FILE_PREFIX + given suffix.
# Suffix examples: "-x86_64-unknown-linux-gnu.(deb|AppImage)"
#                  "-x86_64-apple-darwin.dmg"
find_latest_release_with_asset() {
  suffix_re="$1"
  api_resp=$(curl -fsSL --max-time 10 "https://api.github.com/repos/${GITHUB_REPO}/releases?per_page=30" 2>/dev/null || true)
  [ -n "$api_resp" ] || return 1
  printf '%s\n' "$api_resp" | awk -v prefix="$FILE_PREFIX" -v suffix="$suffix_re" '
    /"tag_name":/ {
      tag = $0
      sub(/.*"tag_name": *"/, "", tag); sub(/".*/, "", tag)
    }
    /"name":/ {
      name = $0
      sub(/.*"name": *"/, "", name); sub(/".*/, "", name)
      pat = "^" prefix "-[0-9][0-9.]*" suffix "$"
      if (name ~ pat) {
        sub(/^v/, "", tag)
        print tag
        exit
      }
    }
  '
}

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

select_release_asset "$EXT"

echo ""
echo "  ⚡ Bolt Installer"
echo "  ─────────────────────────────────────"
echo "  Edition:       ${APP_NAME}"
echo "  Version:       ${VERSION}"
echo "  Platform:      ${PLATFORM} (${ARCH})"
echo ""

# ── Download (with per-version cache) ────────────────────────────────────────
# fetch_with_cache: populates $DL_PATH from $FILE_URL, reusing the cached file
# when its size+ETag match the remote. Returns 0 on success, 1 if the asset is
# not available on the server (so the caller can fall through to a fallback
# asset like AppImage when .deb is missing).
fetch_with_cache() {
  CACHE_DIR="${CACHE_BASE_DIR}/v${VERSION}"
  mkdir -p "$CACHE_DIR" 2>/dev/null || true
  DL_PATH="${CACHE_DIR}/${FILE_NAME}"
  META_PATH="${DL_PATH}.meta"
  PARTIAL_PATH="${DL_PATH}.partial"

  # Probe remote first so we know what "fresh" means. If HEAD fails (network
  # blip, server doesn't allow HEAD) we fall through to the normal download.
  probe_ok=0
  if probe_remote_asset "$FILE_URL"; then
    probe_ok=1
    if is_cache_fresh "$DL_PATH" "$META_PATH"; then
      ok "Using cached ${FILE_NAME} ($(du -h "$DL_PATH" | cut -f1 | tr -d ' ')) — skipping download"
      return 0
    fi
  fi

  info "Downloading ${FILE_NAME}..."
  rm -f "$PARTIAL_PATH" 2>/dev/null || true
  HTTP_CODE=$(curl -fSL \
    --retry "${DOWNLOAD_RETRY_MAX}" \
    --retry-all-errors \
    --retry-delay "${DOWNLOAD_RETRY_DELAY}" \
    --connect-timeout 15 \
    --max-time 300 \
    -w '%{http_code}' \
    -o "${PARTIAL_PATH}" \
    "${FILE_URL}" 2>/dev/null) || true

  if [ ! -f "${PARTIAL_PATH}" ] || [ "$(wc -c < "${PARTIAL_PATH}" | tr -d ' ')" -lt 1000 ]; then
    rm -f "${PARTIAL_PATH}" 2>/dev/null || true
    PARTIAL_PATH=""
    return 1
  fi

  # Atomic publish into the cache.
  mv -f "${PARTIAL_PATH}" "${DL_PATH}"
  PARTIAL_PATH=""

  # Persist metadata so the next run can decide cache-fresh without a HEAD
  # round-trip ambiguity. Probe again if we didn't earlier, so the size we
  # record actually corresponds to the bytes on disk.
  if [ "$probe_ok" -ne 1 ]; then
    probe_remote_asset "$FILE_URL" || true
  fi
  # Authoritative size = bytes on disk (server-reported can be stripped by
  # proxies; what we just wrote is what we'll compare next time).
  REMOTE_SIZE=$(wc -c < "${DL_PATH}" | tr -d ' ')
  write_cache_meta "$META_PATH"

  ok "Downloaded $(du -h "${DL_PATH}" | cut -f1 | tr -d ' ')"
  return 0
}

# download_for_platform tries the preferred extension and (on Linux) falls
# back from .deb to .AppImage within the SAME version. Returns 0 on success,
# 1 if neither asset is available on the server for this version+platform.
download_for_platform() {
  select_release_asset "$EXT"
  if fetch_with_cache; then
    return 0
  fi
  if [ "$USE_DEB" -eq 1 ]; then
    warn ".deb package not available — falling back to AppImage..."
    USE_DEB=0
    select_release_asset "AppImage"
    fetch_with_cache && return 0
  fi
  return 1
}

if ! download_for_platform; then
  # Per-platform walk-back: if the requested VERSION's release is missing this
  # platform's artifact (a partial ship still in flight, a single-file upload
  # that silently 502'd from GitHub, or a version that simply never shipped this
  # arch), install the most recent release that DOES ship the right artifact for
  # THIS platform/arch. This applies EVEN to an explicitly pinned version: a
  # pinned version with no build for the user's arch degrades to the newest
  # version that has one rather than hard-failing, so the install still works
  # (with a clear notice). Only when NO recent release has a build for this arch
  # do we fail.
  requested_version="$VERSION"
  fallback_version=""
  case "$PLATFORM" in
    linux)
      fallback_version=$(find_latest_release_with_asset '-x86_64-unknown-linux-gnu\\.(deb|AppImage)' 2>/dev/null || true)
      ;;
    macos)
      # RUST_TRIPLE is already aarch64-apple-darwin or x86_64-apple-darwin.
      fallback_version=$(find_latest_release_with_asset '-'"${RUST_TRIPLE}"'\\.dmg' 2>/dev/null || true)
      ;;
  esac

  if [ -n "$fallback_version" ] && [ "$fallback_version" != "$VERSION" ]; then
    if [ "$VERSION_PINNED" -eq 1 ]; then
      warn "v${requested_version} of ${APP_NAME} has no ${PLATFORM} ${ARCH} build — installing v${fallback_version} (newest release with a ${ARCH} build) instead."
    else
      warn "v${VERSION} has no ${PLATFORM} ${ARCH} artifacts for ${APP_NAME} — falling back to v${fallback_version}"
    fi
    VERSION="$fallback_version"
    BASE_URL="https://github.com/${GITHUB_REPO}/releases/download/v${VERSION}"
    if [ "$PLATFORM" = "linux" ]; then
      USE_DEB=0
      if command -v dpkg >/dev/null 2>&1; then USE_DEB=1; EXT="deb"; else EXT="AppImage"; fi
    else
      EXT="dmg"
    fi
    if ! download_for_platform; then
      fail "Download failed: no working ${PLATFORM} ${ARCH} build of ${APP_NAME} found in recent releases.\n  Check https://sparcle.app/download for supported platforms."
    fi
  else
    fail "Download failed: ${FILE_NAME} not found (HTTP ${HTTP_CODE:-?}).\n  ${APP_NAME} has no ${PLATFORM} ${ARCH} build in any recent release yet.\n  Check https://sparcle.app/download for supported platforms."
  fi
fi

# Prune old version caches in the background of the user's awareness.
gc_cache

# ══════════════════════════════════════════════════════════════════════════════
# macOS: mount DMG → copy .app → trust → launch
# ══════════════════════════════════════════════════════════════════════════════
install_macos() {
  # Fresh, isolated mount point for hdiutil — never inside the persistent
  # download cache (we don't want the mount to live beyond this process).
  TMPDIR_MOUNT=$(mktemp -d)
  MOUNT_POINT="${TMPDIR_MOUNT}"

  info "Installing ${APP_NAME}..."
  hdiutil attach "${DL_PATH}" -quiet -nobrowse -mountpoint "${MOUNT_POINT}" 2>/dev/null \
    || fail "Failed to mount DMG. The download may be corrupted — try again."

  SOURCE_APP=$(find "${MOUNT_POINT}" -maxdepth 1 -name "*.app" | head -1)
  [ -n "${SOURCE_APP}" ] || { hdiutil detach "${MOUNT_POINT}" -quiet 2>/dev/null; fail "No .app found in DMG."; }

  # Fully stop any running Bolt before replacing the bundle. A bare `sleep 1`
  # let bolt-api linger: macOS `cp` then silently skips the in-use binary (the
  # "upgrade" keeps running OLD code), and a lingering sidecar holding the
  # embedded Postgres cluster contends with the fresh launch. Send TERM, poll
  # until the processes actually exit, then SIGKILL any straggler.
  pkill -f "${APP_NAME}.app/Contents/MacOS" 2>/dev/null || true
  _bolt_stop_deadline=$(( $(date +%s) + 8 ))
  while pgrep -f "${APP_NAME}.app/Contents/MacOS" >/dev/null 2>&1; do
    if [ "$(date +%s)" -ge "${_bolt_stop_deadline}" ]; then
      pkill -9 -f "${APP_NAME}.app/Contents/MacOS" 2>/dev/null || true
      break
    fi
    sleep 0.3
  done
  sleep 0.5

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

  APP_IDENTIFIER="app.sparcle.bolt.enterprise"
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

  # Wipe stale WebKitGTK cache dirs on upgrade so the freshly-installed
  # PWA bundle is what the WebView serves on first launch. Without this,
  # an upgrade install (e.g. 0.1.35 → 0.1.38) leaves caches.delete /
  # indexedDB.deleteDatabase unable to evict the cached service-worker
  # bundle, and the in-app "Build ID mismatch — Self-heal did not stick"
  # error fires on every launch (see bolt-pwa build-id-watcher.ts).
  # Fresh installs no-op (dirs don't exist yet). Run as the invoking user
  # (NOT under sudo) because the dirs are user-owned in $HOME.
  CACHE_IDENTIFIER="app.sparcle.bolt.enterprise"
  CACHE_BASE="${HOME}/.local/share/${CACHE_IDENTIFIER}"
  for cache_dir in CacheStorage WebKitCache databases localstorage mediakeys storage; do
    rm -rf "${CACHE_BASE}/${cache_dir}" 2>/dev/null || true
  done
  rm -f "${CACHE_BASE}/hsts-storage.sqlite" 2>/dev/null || true
  rm -f "${CACHE_BASE}/.last-build-id" 2>/dev/null || true

  sudo dpkg -i "${DL_PATH}" < /dev/tty \
    || { sudo apt-get install -f -y < /dev/tty 2>/dev/null || true; sudo dpkg -i "${DL_PATH}" < /dev/tty; } \
    || fail "Failed to install .deb package. Try: sudo dpkg -i ${DL_PATH}"
  ok "Installed ${APP_NAME} via dpkg"

  # Find and launch the installed binary. The Tauri .deb names the main GUI
  # binary after the Cargo package (`bolt`) — NOT the productName — and installs
  # the sidecar next to it as `bolt-api`. So the old guesses (`Bolt-Enterprise`)
  # never matched, and the fallback passed a .deb FILENAME to `dpkg -L` (which
  # wants a package NAME), so nothing resolved: the app was never launched and
  # the installer still printed "is running!". Resolve the real path from dpkg's
  # file list for the actual package, excluding the sidecar.
  LAUNCH_BIN=""
  for candidate in "/usr/bin/bolt" "/usr/local/bin/bolt" \
                   "/usr/bin/${APP_FILE_NAME}" "/usr/local/bin/${APP_FILE_NAME}"; do
    [ -x "$candidate" ] && LAUNCH_BIN="$candidate" && break
  done
  if [ -z "$LAUNCH_BIN" ]; then
    PKG_NAME=$(dpkg-deb -f "${DL_PATH}" Package 2>/dev/null || true)
    [ -n "$PKG_NAME" ] || PKG_NAME="bolt-enterprise"
    LAUNCH_BIN=$(dpkg -L "$PKG_NAME" 2>/dev/null \
      | grep -E '/usr(/local)?/bin/' | grep -vE '/bolt-api$' \
      | while IFS= read -r p; do [ -x "$p" ] && [ ! -d "$p" ] && printf '%s\n' "$p" && break; done)
  fi

  if [ -n "$LAUNCH_BIN" ] && [ -x "$LAUNCH_BIN" ]; then
    APP_IDENTIFIER="app.sparcle.bolt.enterprise"
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

  # Copy (not move) so the cache survives for the next re-run.
  cp -f "${DL_PATH}" "${DEST}"
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

  APP_IDENTIFIER="app.sparcle.bolt.enterprise"
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

# ══════════════════════════════════════════════════════════════════════════════
# Integrity verification of the downloaded artifact
# ══════════════════════════════════════════════════════════════════════════════
# Defends the curl|sh path against corrupted or tampered downloads. Two layers
# with graceful degradation:
#   1. SHA-256 (zero new deps): recompute the file's hash and compare against the
#      release's SHA256SUMS, fetched over HTTPS from the same release.
#   2. minisign (authenticity, stronger): when `minisign` is installed, verify the
#      artifact's detached .sig against the key baked into THIS installer (served
#      over HTTPS from sparcle.app). Linux .AppImage / Windows .msi ship a .sig
#      today; macOS .dmg will once the release pipeline signs it.
# A mismatch ALWAYS aborts and deletes the file. "Neither available" (an older
# release, or no minisign + no SHA256SUMS) warns and continues so existing
# releases still install — unless BOLT_REQUIRE_VERIFICATION=1, which makes
# verification mandatory (recommended for locked-down/MDM fleets).
BOLT_MINISIGN_PUBKEY="RWSd12rmLcdOLGl9yZ2hL7tigihN0ZGT923La8KNXaLQfW3lsSsPom0Q"

sha256_of() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" 2>/dev/null | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" 2>/dev/null | awk '{print $1}'
  fi
}

verify_download() {
  [ -f "$DL_PATH" ] || fail "Internal error: downloaded file missing before verification."
  fname=$(basename "$DL_PATH")
  verified=0
  method=""

  # Layer 1 — SHA-256 against the release's SHA256SUMS.
  sums_path="${CACHE_DIR}/SHA256SUMS-${VERSION}"
  if curl -fsSL --max-time 30 -o "$sums_path" "${BASE_URL}/SHA256SUMS" 2>/dev/null && [ -s "$sums_path" ]; then
    expected=$(awk -v f="$fname" '($2==f)||($2=="*"f){print $1; exit}' "$sums_path")
    if [ -n "$expected" ]; then
      actual=$(sha256_of "$DL_PATH" || true)   # `|| true`: under `set -e`, a host with neither shasum nor sha256sum must fail-soft (warn), not abort the installer
      if [ -z "$actual" ]; then
        warn "No SHA-256 tool (shasum/sha256sum) found — skipping checksum verification."
      elif [ "$expected" = "$actual" ]; then
        verified=1; method="SHA-256"
      else
        rm -f "$DL_PATH" 2>/dev/null || true
        fail "Integrity check FAILED for ${fname}.\n  expected ${expected}\n  got      ${actual:-none}\n  The download is corrupted or has been tampered with — do not run it.\n  Re-download from https://sparcle.app/download; if it fails again, contact security@sparcle.app."
      fi
    fi
  fi

  # Layer 2 — minisign authenticity (best-effort; stronger than a checksum).
  if command -v minisign >/dev/null 2>&1; then
    sig_path="${DL_PATH}.sig"
    if curl -fsSL --max-time 30 -o "$sig_path" "${BASE_URL}/${fname}.sig" 2>/dev/null && [ -s "$sig_path" ]; then
      if minisign -V -P "$BOLT_MINISIGN_PUBKEY" -m "$DL_PATH" -x "$sig_path" >/dev/null 2>&1; then
        if [ -n "$method" ]; then method="${method} + minisign"; else method="minisign"; fi
        verified=1
      else
        rm -f "$DL_PATH" 2>/dev/null || true
        fail "Signature verification FAILED for ${fname} — it is NOT authentically signed by Sparcle.\n  Do not run it. Re-download from https://sparcle.app/download or contact security@sparcle.app."
      fi
    fi
  fi

  if [ "$verified" -eq 1 ]; then
    ok "Verified ${fname} (${method})"
  else
    warn "Could not verify ${fname}: no signature/checksum available for this release."
    if ! command -v minisign >/dev/null 2>&1; then
      warn "Install 'minisign' (brew install minisign / apt install minisign) for signature verification."
    fi
    if [ "${BOLT_REQUIRE_VERIFICATION:-0}" = "1" ]; then
      rm -f "$DL_PATH" 2>/dev/null || true
      fail "BOLT_REQUIRE_VERIFICATION=1 is set but ${fname} could not be verified — aborting."
    fi
  fi
}

# Verify before we mount/install/run anything from the download.
verify_download

# ── Run platform installer ───────────────────────────────────────────────────
case "$PLATFORM" in
  macos) install_macos ;;
  linux) install_linux || { echo ""; fail "Installation succeeded but ${APP_NAME} failed to launch. See above for details."; } ;;
esac

echo ""
if [ "${BOLT_LAUNCHED:-0}" = "1" ]; then
  echo "  ✅  ${APP_NAME} is running!"
else
  echo "  ✅  ${APP_NAME} is installed — launch it from your application menu"
  echo "      (or run: bolt)"
fi
echo ""
if [ "$EDITION" = "personal" ]; then
  echo "  Next: Add your AI API key in Settings → AI Configuration"
  echo "  Tip:  Google Gemini has a free tier — works great with Bolt"
else
  echo "  Next: Try instant demo mode, or configure your own IDP + LLM"
  echo "  All features unlocked — free for individuals"
fi
echo ""
echo ""
