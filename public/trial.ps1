# DEPRECATED - Bolt is now free for individuals; the separate trial flow has
# been retired. This shim delegates to install.ps1 so any old links keep working.
#
# Use:
#   irm https://sparcle.app/install.ps1 | iex
#
# This file may be removed in a future release.
Write-Host "[bolt] note: /trial.ps1 is deprecated. Bolt is free for individuals."
Write-Host "[bolt]       Switching to https://sparcle.app/install.ps1 ..."
iex (irm https://sparcle.app/install.ps1)
