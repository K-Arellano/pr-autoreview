#!/usr/bin/env bash
# Install (or reinstall) the launchd agent that runs review.sh on an interval.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
[ -f "$ROOT/config.env" ] && . "$ROOT/config.env"
INTERVAL_SECONDS="${INTERVAL_SECONDS:-900}"

LABEL="local.pr-autoreview"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/pr-autoreview.log"

for bin in gh claude jq git; do
  command -v "$bin" >/dev/null || { echo "missing dependency: $bin" >&2; exit 1; }
done
gh auth status >/dev/null 2>&1 || { echo "run: gh auth login" >&2; exit 1; }

# launchd can't read ~/Desktop, ~/Documents etc. (macOS privacy), so run from a copy.
# Re-run ./install.sh after editing anything here.
APP_DIR="$HOME/.local/share/pr-autoreview"
mkdir -p "$APP_DIR"
rsync -a --delete --exclude .git "$ROOT/" "$APP_DIR/"
chmod +x "$APP_DIR/review.sh"
mkdir -p "$HOME/Library/LaunchAgents" "$(dirname "$LOG")"

cat >"$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$APP_DIR/review.sh</string>
  </array>
  <key>StartInterval</key><integer>$INTERVAL_SECONDS</integer>
  <key>RunAtLoad</key><false/>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key><string>$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
    <key>HOME</key><string>$HOME</string>
  </dict>
  <key>StandardOutPath</key><string>$LOG</string>
  <key>StandardErrorPath</key><string>$LOG</string>
</dict>
</plist>
EOF

# Dashboard: a small always-on local web server.
DASH_LABEL="local.pr-autoreview.dashboard"
DASH_PLIST="$HOME/Library/LaunchAgents/$DASH_LABEL.plist"
DASHBOARD_PORT="${DASHBOARD_PORT:-8787}"
cat >"$DASH_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$DASH_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/python3</string>
    <string>$APP_DIR/dashboard/serve.py</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>EnvironmentVariables</key>
  <dict>
    <key>DASHBOARD_PORT</key><string>$DASHBOARD_PORT</string>
    <key>HOME</key><string>$HOME</string>
  </dict>
  <key>StandardOutPath</key><string>$LOG</string>
  <key>StandardErrorPath</key><string>$LOG</string>
</dict>
</plist>
EOF

for l in "$LABEL" "$DASH_LABEL"; do
  launchctl bootout "gui/$(id -u)/$l" 2>/dev/null || true
done
launchctl bootstrap "gui/$(id -u)" "$PLIST"
launchctl bootstrap "gui/$(id -u)" "$DASH_PLIST"
echo "Installed $LABEL — runs every ${INTERVAL_SECONDS}s. Logs: $LOG"
echo "Dashboard: http://localhost:$DASHBOARD_PORT"
echo "Run now:  launchctl kickstart gui/$(id -u)/$LABEL"
