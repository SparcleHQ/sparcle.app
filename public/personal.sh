#!/bin/sh
# DEPRECATED - Bolt is now one product (Bolt Enterprise), free for everyone.
# This shim delegates to install.sh so any bookmarked link keeps working.
#
# Use:
#   curl -fsSL https://sparcle.app/install.sh | sh
#
# This file may be removed in a future release.
set -e
echo "[bolt] note: /personal.sh is deprecated. Bolt is free for everyone." >&2
echo "[bolt]       Switching to https://sparcle.app/install.sh ..." >&2
exec curl -fsSL https://sparcle.app/install.sh | sh -s -- "$@"
