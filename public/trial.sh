#!/bin/sh
# Bolt Enterprise Trial Installer — delegates to install.sh with trial edition
set -e
curl -fsSL https://sparcle.app/install.sh | sh -s -- trial
