#!/bin/sh
# Bolt Enterprise Trial Installer — delegates to install.sh with trial edition.
#
# Usage:
#   curl -fsSL https://sparcle.app/trial.sh | sh                       # latest
#   curl -fsSL https://sparcle.app/trial.sh | sh -s -- 0.1.18          # pin a version
#   BOLT_VERSION=0.1.18 curl -fsSL https://sparcle.app/trial.sh | sh   # pin via env
set -e
curl -fsSL https://sparcle.app/install.sh | sh -s -- trial "$@"
