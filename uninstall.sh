#!/usr/bin/env bash
set -euo pipefail
LABEL="local.pr-autoreview"
for l in "$LABEL" "$LABEL.dashboard"; do
  launchctl bootout "gui/$(id -u)/$l" 2>/dev/null || true
  rm -f "$HOME/Library/LaunchAgents/$l.plist"
done
echo "Uninstalled $LABEL. State (~/.local/state/pr-autoreview) and clone cache (~/.cache/pr-autoreview) were left in place."
