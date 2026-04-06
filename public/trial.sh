#!/bin/sh
# Bolt Enterprise Trial Installer — delegates to install.sh with trial edition
exec sh -c "$(curl -fsSL https://sparcle.app/install.sh)" -- trial
