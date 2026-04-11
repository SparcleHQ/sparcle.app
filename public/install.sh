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
#   4. Installs to /Applications (macOS) or ~/.local/bin (Linux)
#   5. Marks the app as trusted for your OS to launch safely
#   6. Launches the app
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
# ── Pre-flight checks ───────────────────────────────────────────────────────
OS="$(uname)"
case "$OS" in
  Darwin) PLATFORM="macos" ;;
  Linux)  PLATFORM="linux" ;;
  *)      fail "Unsupported OS: $OS. Visit https://sparcle.app/download" ;;
esac

command -v curl >/dev/null 2>&1 || fail "curl is required but not found."

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
TMPDIR_DL=$(mktemp -d)  # cleaned up by EXIT trap
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

  if ! rm -rf "/Applications/${APP_NAME}.app" 2>/dev/null; then
    sudo rm -rf "/Applications/${APP_NAME}.app" 2>/dev/null < /dev/tty || true
  fi

  if ! cp -R "${SOURCE_APP}" /Applications/ 2>/dev/null; then
    info "Password may be required to write to /Applications..."
    sudo cp -R "${SOURCE_APP}" /Applications/ < /dev/tty \
      || { hdiutil detach "${MOUNT_POINT}" -quiet 2>/dev/null; fail "Failed to install to /Applications."; }
  fi
  ok "Installed to /Applications/${APP_NAME}.app"

  info "Marking ${APP_NAME} as trusted..."
  if ! xattr -cr "/Applications/${APP_NAME}.app" 2>/dev/null; then
    sudo xattr -cr "/Applications/${APP_NAME}.app" 2>/dev/null < /dev/tty || true
  fi
  ok "App trusted — ready to launch"

  # Link CLI
  mkdir -p "${HOME}/.local/bin"
  ln -sf "/Applications/${APP_NAME}.app/Contents/MacOS/${APP_NAME}" "${HOME}/.local/bin/bolt" 2>/dev/null || true
  case ":${PATH}:" in
    *":${HOME}/.local/bin:"*) ;;
    *) add_to_path "${HOME}/.local/bin" ;;
  esac

  hdiutil detach "${MOUNT_POINT}" -quiet 2>/dev/null || true

  info "Launching ${APP_NAME}..."
  open "/Applications/${APP_NAME}.app"
}

# ══════════════════════════════════════════════════════════════════════════════
# Linux: install AppImage → make executable → launch
# ══════════════════════════════════════════════════════════════════════════════
install_linux() {
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

  case ":${PATH}:" in
    *":${INSTALL_DIR}:"*) ;;
    *) add_to_path "${INSTALL_DIR}" ;;
  esac

  info "Launching ${APP_NAME}..."
  launch_linux_app "${DEST}" "${APP_NAME}" || return 1
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
