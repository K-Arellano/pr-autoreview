#!/usr/bin/env bash
set -euo pipefail
LABEL="local.pr-autoreview"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
echo "Uninstalled $LABEL. State (~/.local/state/pr-autoreview) and clone cache (~/.cache/pr-autoreview) were left in place."
