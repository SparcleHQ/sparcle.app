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
#   3. Installs to /Applications (macOS) or ~/.local/bin (Linux)
#   4. Marks the app as trusted for your OS to launch safely
#   5. Launches the app
#
# No password required. Safe to re-run — overwrites previous installation.
set -e

# ── Config ───────────────────────────────────────────────────────────────────
FALLBACK_VERSION="0.1.0"
GITHUB_REPO="Sparcle-LLC/sparcle.app"

# ── Helpers ──────────────────────────────────────────────────────────────────
info()  { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
ok()    { printf '\033[1;32m ✓ \033[0m %s\n' "$1"; }
warn()  { printf '\033[1;33m ⚠ \033[0m %s\n' "$1"; }
fail()  { printf '\033[1;31m ✗ \033[0m %s\n' "$1" >&2; exit 1; }

# ── Pre-flight checks ───────────────────────────────────────────────────────
OS="$(uname)"
case "$OS" in
  Darwin) PLATFORM="macos" ;;
  Linux)  PLATFORM="linux" ;;
  *)      fail "Unsupported OS: $OS. Visit https://sparcle.app/download" ;;
esac

command -v curl >/dev/null 2>&1 || fail "curl is required but not found."

# ── Fetch latest version from GitHub ─────────────────────────────────────────
VERSION="$FALLBACK_VERSION"
LATEST_URL="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"
if TAG=$(curl -fsSL --max-time 5 "$LATEST_URL" 2>/dev/null | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/'); then
  V=$(echo "$TAG" | sed 's/^v//')
  if [ -n "$V" ]; then
    VERSION="$V"
  fi
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
  macos-arm64)   RUST_TRIPLE="aarch64-apple-darwin"  ; EXT="dmg" ;;
  macos-x86_64)  RUST_TRIPLE="x86_64-apple-darwin"   ; EXT="dmg" ;;
  linux-x86_64)  RUST_TRIPLE="x86_64-unknown-linux-gnu" ; EXT="AppImage" ;;
  linux-aarch64) RUST_TRIPLE="aarch64-unknown-linux-gnu" ; EXT="AppImage" ;;
  *)             fail "Unsupported platform: $PLATFORM $ARCH" ;;
esac

FILE_NAME="${FILE_PREFIX}-${VERSION}-${RUST_TRIPLE}.${EXT}"
FILE_URL="${BASE_URL}/${FILE_NAME}"

echo ""
echo "  ⚡ Bolt Installer"
echo "  ─────────────────────────────────────"
echo "  Edition:       ${APP_NAME}"
echo "  Version:       ${VERSION}"
echo "  Platform:      ${PLATFORM} (${ARCH})"
echo ""

# ── Download ─────────────────────────────────────────────────────────────────
TMPDIR_DL=$(mktemp -d)
DL_PATH="${TMPDIR_DL}/${FILE_NAME}"

info "Downloading ${FILE_NAME}..."
HTTP_CODE=$(curl -fSL -w '%{http_code}' -o "${DL_PATH}" "${FILE_URL}" 2>/dev/null) || true

if [ ! -f "${DL_PATH}" ] || [ "$(wc -c < "${DL_PATH}" | tr -d ' ')" -lt 1000 ]; then
  rm -rf "${TMPDIR_DL}"
  fail "Download failed (HTTP ${HTTP_CODE}). Check https://sparcle.app/download for available versions."
fi

ok "Downloaded $(du -h "${DL_PATH}" | cut -f1 | tr -d ' ')"

# ══════════════════════════════════════════════════════════════════════════════
# macOS: mount DMG → copy .app → trust → launch
# ══════════════════════════════════════════════════════════════════════════════
install_macos() {
  MOUNT_POINT="${TMPDIR_DL}/bolt-mount"
  mkdir -p "${MOUNT_POINT}"

  info "Installing ${APP_NAME} to /Applications..."
  hdiutil attach "${DL_PATH}" -quiet -nobrowse -mountpoint "${MOUNT_POINT}" 2>/dev/null \
    || fail "Failed to mount DMG. The download may be corrupted — try again."

  SOURCE_APP=$(find "${MOUNT_POINT}" -maxdepth 1 -name "*.app" | head -1)
  [ -n "${SOURCE_APP}" ] || { hdiutil detach "${MOUNT_POINT}" -quiet 2>/dev/null; fail "No .app found in DMG."; }

  pkill -f "${APP_NAME}.app/Contents/MacOS" 2>/dev/null || true
  sleep 1

  rm -rf "/Applications/${APP_NAME}.app" 2>/dev/null || true
  cp -R "${SOURCE_APP}" /Applications/
  ok "Installed to /Applications/${APP_NAME}.app"

  info "Marking ${APP_NAME} as trusted..."
  xattr -cr "/Applications/${APP_NAME}.app" 2>/dev/null || true
  ok "App trusted — ready to launch"

  hdiutil detach "${MOUNT_POINT}" -quiet 2>/dev/null || true
  rm -rf "${TMPDIR_DL}"

  info "Launching ${APP_NAME}..."
  open "/Applications/${APP_NAME}.app"
}

# ══════════════════════════════════════════════════════════════════════════════
# Linux: install AppImage → make executable → launch
# ══════════════════════════════════════════════════════════════════════════════
install_linux() {
  # AppImage requires FUSE — detect and install if missing
  if ! command -v fusermount >/dev/null 2>&1 && ! command -v fusermount3 >/dev/null 2>&1; then
    warn "FUSE not found — AppImage needs it to run."
    if command -v apt-get >/dev/null 2>&1; then
      info "Detected Ubuntu/Debian — installing libfuse2..."
      sudo apt-get update -qq && sudo apt-get install -y -qq libfuse2 \
        && ok "libfuse2 installed" \
        || warn "Could not install libfuse2. You may need to run: sudo apt install libfuse2"
    elif command -v dnf >/dev/null 2>&1; then
      info "Detected Fedora/RHEL — installing fuse-libs..."
      sudo dnf install -y -q fuse-libs \
        && ok "fuse-libs installed" \
        || warn "Could not install fuse-libs. You may need to run: sudo dnf install fuse-libs"
    elif command -v pacman >/dev/null 2>&1; then
      info "Detected Arch — installing fuse2..."
      sudo pacman -S --noconfirm fuse2 \
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

  # Stop running instance if any
  pkill -f "${APP_FILE_NAME}" 2>/dev/null || true
  sleep 1

  mv "${DL_PATH}" "${DEST}"
  chmod +x "${DEST}"
  ok "Installed to ${DEST}"

  rm -rf "${TMPDIR_DL}"

  # Add to PATH hint if not already there
  case ":${PATH}:" in
    *":${INSTALL_DIR}:"*) ;;
    *) warn "${INSTALL_DIR} is not in your PATH. Add it: export PATH=\"\${HOME}/.local/bin:\${PATH}\"" ;;
  esac

  info "Launching ${APP_NAME}..."
  nohup "${DEST}" >/dev/null 2>&1 &
}

# ── Run platform installer ───────────────────────────────────────────────────
case "$PLATFORM" in
  macos) install_macos ;;
  linux) install_linux ;;
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
