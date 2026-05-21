#!/bin/sh
# Bolt Personal Installer — delegates to install.sh with personal edition.
#
# Usage:
#   curl -fsSL https://sparcle.app/personal.sh | sh                       # latest
#   curl -fsSL https://sparcle.app/personal.sh | sh -s -- 0.1.18          # pin a version
#   BOLT_VERSION=0.1.18 curl -fsSL https://sparcle.app/personal.sh | sh   # pin via env
set -e
curl -fsSL https://sparcle.app/install.sh | sh -s -- personal "$@"
