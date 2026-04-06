#!/bin/sh
# Bolt Personal Installer — delegates to install.sh with personal edition
set -e
curl -fsSL https://sparcle.app/install.sh | sh -s -- personal