#!/bin/sh
# Bolt Installer — https://sparcle.app/install.sh
# Usage:
#   curl -fsSL https://sparcle.app/install.sh | sh                  # Personal edition (default)
#   curl -fsSL https://sparcle.app/install.sh | sh -s -- trial      # Enterprise Trial
#   curl -fsSL https://sparcle.app/install.sh | sh -s -- personal   # Personal (explicit)
#
# What this does:
#   1. Detects your Mac architecture (Apple Silicon / Intel)
#   2. Downloads the correct DMG from GitHub Releases
#   3. Mounts, installs to /Applications
#   4. Marks the app as trusted for macOS to launch safely
#   5. Launches the app
#
# Safe to re-run — overwrites previous installation.
set -e

# ── Config ───────────────────────────────────────────────────────────────────
VERSION="0.1.0"
GITHUB_REPO="Sparcle-LLC/bolt-native"
BASE_URL="https://github.com/${GITHUB_REPO}/releases/download/v${VERSION}"

# ── Helpers ──────────────────────────────────────────────────────────────────
info()  { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
ok()    { printf '\033[1;32m ✓ \033[0m %s\n' "$1"; }
warn()  { printf '\033[1;33m ⚠ \033[0m %s\n' "$1"; }
fail()  { printf '\033[1;31m ✗ \033[0m %s\n' "$1" >&2; exit 1; }

# ── Pre-flight checks ───────────────────────────────────────────────────────
[ "$(uname)" = "Darwin" ] || fail "This installer is for macOS only. Visit https://sparcle.app/download for other platforms."

command -v curl >/dev/null 2>&1 || fail "curl is required but not found."

# ── Parse edition argument ───────────────────────────────────────────────────
EDITION="${1:-personal}"
case "$EDITION" in
  personal)
    APP_NAME="Bolt Personal"
    DMG_PREFIX="Bolt-Personal"
    ;;
  trial|enterprise)
    EDITION="trial"
    APP_NAME="Bolt Enterprise"
    DMG_PREFIX="Bolt-Enterprise-Trial"
    ;;
  *)
    fail "Unknown edition: $EDITION. Use 'personal' or 'trial'."
    ;;
esac

# ── Detect architecture ─────────────────────────────────────────────────────
ARCH=$(uname -m)
case "$ARCH" in
  arm64)  RUST_TRIPLE="aarch64-apple-darwin" ;;
  x86_64) RUST_TRIPLE="x86_64-apple-darwin"  ;;
  *)      fail "Unsupported architecture: $ARCH" ;;
esac

DMG_NAME="${DMG_PREFIX}-${VERSION}-${RUST_TRIPLE}.dmg"
DMG_URL="${BASE_URL}/${DMG_NAME}"

echo ""
echo "  ⚡ Bolt Installer"
echo "  ─────────────────────────────────────"
echo "  Edition:       ${APP_NAME}"
echo "  Version:       ${VERSION}"
echo "  Architecture:  ${ARCH}"
echo ""

# ── Download ─────────────────────────────────────────────────────────────────
TMPDIR_DL=$(mktemp -d)
DMG_PATH="${TMPDIR_DL}/${DMG_NAME}"

info "Downloading ${DMG_NAME}..."
HTTP_CODE=$(curl -fSL -w '%{http_code}' -o "${DMG_PATH}" "${DMG_URL}" 2>/dev/null) || true

if [ ! -f "${DMG_PATH}" ] || [ "$(wc -c < "${DMG_PATH}" | tr -d ' ')" -lt 1000 ]; then
  rm -rf "${TMPDIR_DL}"
  fail "Download failed (HTTP ${HTTP_CODE}). Check https://sparcle.app/download for available versions."
fi

ok "Downloaded $(du -h "${DMG_PATH}" | cut -f1 | tr -d ' ')"

# ── Mount & Install ──────────────────────────────────────────────────────────
MOUNT_POINT="${TMPDIR_DL}/bolt-mount"
mkdir -p "${MOUNT_POINT}"

info "Installing ${APP_NAME} to /Applications..."
hdiutil attach "${DMG_PATH}" -quiet -nobrowse -mountpoint "${MOUNT_POINT}" 2>/dev/null \
  || fail "Failed to mount DMG. The download may be corrupted — try again."

# Find the .app inside the mounted DMG
SOURCE_APP=$(find "${MOUNT_POINT}" -maxdepth 1 -name "*.app" | head -1)
[ -n "${SOURCE_APP}" ] || { hdiutil detach "${MOUNT_POINT}" -quiet 2>/dev/null; fail "No .app found in DMG."; }

# Kill running instance if any
pkill -f "${APP_NAME}.app/Contents/MacOS" 2>/dev/null || true
sleep 1

# Copy to /Applications (overwrites previous)
rm -rf "/Applications/${APP_NAME}.app" 2>/dev/null || true
cp -R "${SOURCE_APP}" /Applications/
ok "Installed to /Applications/${APP_NAME}.app"

# ── Mark as trusted for macOS to launch safely ──────────────────────────────
info "Marking ${APP_NAME} as trusted..."
xattr -cr "/Applications/${APP_NAME}.app" 2>/dev/null || true
ok "App trusted — ready to launch"

# ── Cleanup ──────────────────────────────────────────────────────────────────
hdiutil detach "${MOUNT_POINT}" -quiet 2>/dev/null || true
rm -rf "${TMPDIR_DL}"

# ── Launch ───────────────────────────────────────────────────────────────────
info "Launching ${APP_NAME}..."
open "/Applications/${APP_NAME}.app"

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
