#!/bin/sh
# Bolt CLI Installer — https://sparcle.app/install-cli.sh
# Installs the `bolt-cli` command-line tool on macOS and Linux.
#
# Usage:
#   curl -fsSL https://sparcle.app/install-cli.sh | sh
#
# What this does:
#   1. Detects your OS and architecture
#   2. Fetches the latest release version from GitHub
#   3. Downloads the correct bolt-cli binary
#   4. Installs to ~/.local/bin (works without sudo on macOS and Linux)
#   5. Adds ~/.local/bin to PATH in your shell rc if needed
#
# After install, run:
#   bolt-cli connect --token <TOKEN>
set -e

FALLBACK_VERSION="0.1.0"
GITHUB_REPO="Sparcle-LLC/sparcle.app"

info()  { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
ok()    { printf '\033[1;32m ✓ \033[0m %s\n' "$1"; }
warn()  { printf '\033[1;33m ⚠ \033[0m %s\n' "$1"; }
fail()  { printf '\033[1;31m ✗ \033[0m %s\n' "$1" >&2; exit 1; }

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

# ── Fetch latest version ─────────────────────────────────────────────────────
VERSION="$FALLBACK_VERSION"
LATEST_URL="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"
API_RESP=$(curl -fsSL --max-time 5 "$LATEST_URL" 2>/dev/null || true)
V=$(echo "$API_RESP" | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/' | sed 's/^v//' || true)
if [ -n "$V" ]; then
  VERSION="$V"
else
  warn "Could not fetch latest version — using v${VERSION}"
fi

FILE_NAME="bolt-cli-${VERSION}-${RUST_TRIPLE}"
FILE_URL="https://github.com/${GITHUB_REPO}/releases/download/v${VERSION}/${FILE_NAME}"

echo ""
echo "  ⚡ Bolt CLI Installer"
echo "  ─────────────────────────────────────"
echo "  Version:   ${VERSION}"
echo "  Platform:  ${PLATFORM} (${ARCH})"
echo ""

# ── Download ─────────────────────────────────────────────────────────────────
TMPDIR_DL=$(mktemp -d)
DL_PATH="${TMPDIR_DL}/bolt-cli"

info "Downloading bolt-cli..."
HTTP_CODE=$(curl -fSL -w '%{http_code}' -o "${DL_PATH}" "${FILE_URL}" 2>/dev/null) || true

if [ ! -f "${DL_PATH}" ] || [ "$(wc -c < "${DL_PATH}" | tr -d ' ')" -lt 10000 ]; then
  rm -rf "${TMPDIR_DL}"
  fail "Download failed (HTTP ${HTTP_CODE}). Check https://sparcle.app for help."
fi

ok "Downloaded $(du -h "${DL_PATH}" | cut -f1 | tr -d ' ')"
chmod +x "${DL_PATH}"

# ── Install ───────────────────────────────────────────────────────────────────
# Always install to ~/.local/bin — works on macOS and Linux without sudo,
# safe to run in piped (non-interactive) shells, and no TTY required.
INSTALL_DIR="${HOME}/.local/bin"
mkdir -p "${INSTALL_DIR}"
mv "${DL_PATH}" "${INSTALL_DIR}/bolt-cli"
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

rm -rf "${TMPDIR_DL}"

echo ""
echo "  ✅  bolt-cli installed!"
echo ""
echo "  Usage:  bolt-cli connect --token <TOKEN>"
echo "  Help:   https://sparcle.app/docs/cli"
echo ""
