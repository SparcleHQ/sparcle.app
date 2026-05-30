#!/bin/sh
# DEPRECATED — Bolt is now free for individuals; the separate trial flow has
# been retired. This shim delegates to install.sh so any old links keep working.
#
# Use:
#   curl -fsSL https://sparcle.app/install.sh | sh
#
# This file may be removed in a future release.
set -e
echo "[bolt] note: /trial.sh is deprecated. Bolt is free for individuals." >&2
echo "[bolt]       Switching to https://sparcle.app/install.sh ..." >&2
exec curl -fsSL https://sparcle.app/install.sh | sh -s -- "$@"
