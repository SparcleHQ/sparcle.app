#!/bin/sh
# Bolt CLI Installer — https://sparcle.app/install-cli.sh
# Installs the `bolt-cli` command-line tool on macOS and Linux.
#
# Usage:
#   curl -fsSL https://sparcle.app/install-cli.sh | sh                            # latest
#   curl -fsSL https://sparcle.app/install-cli.sh | sh -s -- 0.1.18               # pin a specific version
#   BOLT_VERSION=0.1.18 curl -fsSL https://sparcle.app/install-cli.sh | sh        # pin via env
#
# What this does:
#   1. Detects your OS and architecture
#   2. Resolves target version ($BOLT_VERSION > positional arg > /releases/latest)
#   3. Downloads the correct bolt-cli binary (with on-disk cache; re-runs are
#      network-free if the cached file still matches the remote)
#   4. Installs to ~/.local/bin (works without sudo on macOS and Linux)
#   5. Adds ~/.local/bin to PATH in your shell rc if needed
#
# After install, run:
#   bolt-cli connect --token <TOKEN>
set -e

FALLBACK_VERSION="0.1.0"
GITHUB_REPO="Sparcle-LLC/sparcle.app"
CACHE_BASE_DIR="${BOLT_INSTALLER_CACHE_DIR:-${HOME}/.cache/bolt-installer}"
CACHE_KEEP_VERSIONS="2"

info()  { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
ok()    { printf '\033[1;32m ✓ \033[0m %s\n' "$1"; }
warn()  { printf '\033[1;33m ⚠ \033[0m %s\n' "$1"; }
fail()  { printf '\033[1;31m ✗ \033[0m %s\n' "$1" >&2; exit 1; }

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

is_cache_fresh() {
  cached="$1"
  meta="$2"
  [ -f "$cached" ] || return 1
  local_size=$(wc -c < "$cached" 2>/dev/null | tr -d ' ')
  [ -n "$local_size" ] && [ "$local_size" -gt 10000 ] || return 1
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

# ── Pre-flight ───────────────────────────────────────────────────────────────
OS="$(uname)"
case "$OS" in
  Darwin) PLATFORM="macos" ;;
  Linux)  PLATFORM="linux" ;;
  *)      fail "Unsupported OS: $OS. Visit https://sparcle.app" ;;
esac

command -v curl >/dev/null 2>&1 || fail "curl is required but not found."

# ── Detect architecture ──────────────────────────────────────────────────────
ARCH=$(uname -m)
case "$PLATFORM-$ARCH" in
  macos-arm64)   RUST_TRIPLE="aarch64-apple-darwin" ;;
  macos-x86_64)  RUST_TRIPLE="x86_64-apple-darwin" ;;
  linux-x86_64)  RUST_TRIPLE="x86_64-unknown-linux-gnu" ;;
  linux-aarch64) fail "bolt-cli is not available for Linux ARM64. Only x86_64 is supported." ;;
  *)             fail "Unsupported platform: $PLATFORM $ARCH" ;;
esac

# ── Resolve version (env > positional arg > /releases/latest) ────────────────
VERSION=""
if [ -n "${BOLT_VERSION:-}" ]; then
  VERSION="$(printf '%s' "$BOLT_VERSION" | sed 's/^v//')"
elif [ -n "${1:-}" ]; then
  VERSION="$(printf '%s' "$1" | sed 's/^v//')"
fi
if [ -z "$VERSION" ]; then
  VERSION="$FALLBACK_VERSION"
  LATEST_URL="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"
  API_RESP=$(curl -fsSL --max-time 5 "$LATEST_URL" 2>/dev/null || true)
  V=$(echo "$API_RESP" | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/' | sed 's/^v//' || true)
  if [ -n "$V" ]; then
    VERSION="$V"
  else
    warn "Could not fetch latest version — using v${VERSION}"
  fi
fi

FILE_NAME="bolt-cli-${VERSION}-${RUST_TRIPLE}"
FILE_URL="https://github.com/${GITHUB_REPO}/releases/download/v${VERSION}/${FILE_NAME}"

# ── Per-platform walk-back ───────────────────────────────────────────────────
# If the current /releases/latest tag is missing the user's platform bolt-cli
# (partial ship in flight, or a single-asset upload silently 502'd from GitHub —
# the same failure mode that hit the desktop trial mac arm64 DMG on v0.1.31),
# walk back through recent releases to find the first one that has it. Skipped
# when the user explicitly pinned via $BOLT_VERSION or a positional arg.
VERSION_PINNED=0
if [ -n "${BOLT_VERSION:-}" ] || [ -n "${1:-}" ]; then
  VERSION_PINNED=1
fi

asset_head_ok() {
  _url="$1"
  _code=$(curl -sIL --max-time 5 -o /dev/null -w '%{http_code}' "$_url" 2>/dev/null || echo "000")
  case "$_code" in 200|302) return 0 ;; *) return 1 ;; esac
}

if [ "$VERSION_PINNED" -eq 0 ] && ! asset_head_ok "$FILE_URL"; then
  warn "v${VERSION} does not yet have bolt-cli for ${RUST_TRIPLE} — checking earlier releases..."
  RELEASES_RESP=$(curl -fsSL --max-time 10 "https://api.github.com/repos/${GITHUB_REPO}/releases?per_page=10" 2>/dev/null || true)
  for _v in $(echo "$RELEASES_RESP" | grep '"tag_name"' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/' | sed 's/^v//'); do
    [ "$_v" = "$VERSION" ] && continue
    _candidate_url="https://github.com/${GITHUB_REPO}/releases/download/v${_v}/bolt-cli-${_v}-${RUST_TRIPLE}"
    if asset_head_ok "$_candidate_url"; then
      warn "Installing bolt-cli v${_v} (latest v${VERSION} is mid-ship for ${RUST_TRIPLE})"
      VERSION="$_v"
      FILE_NAME="bolt-cli-${VERSION}-${RUST_TRIPLE}"
      FILE_URL="https://github.com/${GITHUB_REPO}/releases/download/v${VERSION}/${FILE_NAME}"
      break
    fi
  done
fi

echo ""
echo "  ⚡ Bolt CLI Installer"
echo "  ─────────────────────────────────────"
echo "  Version:   ${VERSION}"
echo "  Platform:  ${PLATFORM} (${ARCH})"
echo ""

# ── Download (with per-version cache) ────────────────────────────────────────
CACHE_DIR="${CACHE_BASE_DIR}/v${VERSION}"
mkdir -p "${CACHE_DIR}"
DL_PATH="${CACHE_DIR}/${FILE_NAME}"
META_PATH="${DL_PATH}.meta"
PARTIAL_PATH="${DL_PATH}.partial"

probe_ok=0
if probe_remote_asset "${FILE_URL}"; then
  probe_ok=1
fi

if [ "$probe_ok" -eq 1 ] && is_cache_fresh "${DL_PATH}" "${META_PATH}"; then
  ok "Using cached bolt-cli ($(du -h "${DL_PATH}" | cut -f1 | tr -d ' ')) — skipping download"
else
  info "Downloading bolt-cli..."
  rm -f "${PARTIAL_PATH}" 2>/dev/null || true
  HTTP_CODE=$(curl -fSL -w '%{http_code}' -o "${PARTIAL_PATH}" "${FILE_URL}" 2>/dev/null) || true

  if [ ! -f "${PARTIAL_PATH}" ] || [ "$(wc -c < "${PARTIAL_PATH}" | tr -d ' ')" -lt 10000 ]; then
    rm -f "${PARTIAL_PATH}" 2>/dev/null || true
    fail "Download failed (HTTP ${HTTP_CODE}). Check https://sparcle.app for help."
  fi

  mv -f "${PARTIAL_PATH}" "${DL_PATH}"

  [ "$probe_ok" -eq 1 ] || probe_remote_asset "${FILE_URL}" || true
  REMOTE_SIZE=$(wc -c < "${DL_PATH}" | tr -d ' ')
  write_cache_meta "${META_PATH}"

  ok "Downloaded $(du -h "${DL_PATH}" | cut -f1 | tr -d ' ')"
fi

# Garbage-collect older versions, keep current + 1.
if [ -d "${CACHE_BASE_DIR}" ]; then
  current="v${VERSION}"
  ls -1t "${CACHE_BASE_DIR}" 2>/dev/null \
    | awk -v cur="$current" -v keep="$CACHE_KEEP_VERSIONS" '
        /^v/ && $0!=cur {n++; if (n>=keep) print}
      ' \
    | while IFS= read -r stale; do
        [ -n "$stale" ] || continue
        rm -rf "${CACHE_BASE_DIR}/${stale}" 2>/dev/null || true
      done
fi

# ── Install ───────────────────────────────────────────────────────────────────
# Always install to ~/.local/bin — works on macOS and Linux without sudo,
# safe to run in piped (non-interactive) shells, and no TTY required.
INSTALL_DIR="${HOME}/.local/bin"
mkdir -p "${INSTALL_DIR}"
# cp (not mv) so the cache survives for re-runs.
cp -f "${DL_PATH}" "${INSTALL_DIR}/bolt-cli"
chmod +x "${INSTALL_DIR}/bolt-cli"
ok "Installed to ${INSTALL_DIR}/bolt-cli"

# Persist to PATH in shell rc files (takes effect on next login).
case ":${PATH}:" in
  *":${INSTALL_DIR}:"*) ;;
  *)
    LINE="export PATH=\"${INSTALL_DIR}:\${PATH}\""
    for rc in "${HOME}/.bashrc" "${HOME}/.zshrc" "${HOME}/.profile"; do
      [ -f "$rc" ] || continue
      grep -qF "${INSTALL_DIR}" "$rc" 2>/dev/null && continue
      printf '\n# Added by Bolt CLI installer\n%s\n' "$LINE" >> "$rc"
      ok "Added ${INSTALL_DIR} to PATH in $(basename "$rc")"
    done
    warn "Restart your shell or run: export PATH=\"${INSTALL_DIR}:\${PATH}\""
  ;;
esac

echo ""
echo "  ✅  bolt-cli installed!"
echo ""
echo "  Usage:  bolt-cli connect --token <TOKEN>"
echo "  Help:   https://sparcle.app/docs/cli"
echo ""
