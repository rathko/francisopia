#!/usr/bin/env bash
# Francis-opia launcher — sets display env and captures logs
set -euo pipefail

GAME_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="${GAME_DIR}/godot.log"

# Auto-detect Xwayland auth file
XAUTH_FILE=$(pgrep -a Xwayland 2>/dev/null | grep -oP '/run/user/\d+/xauth_\S+' || true)

if [[ -n "$XAUTH_FILE" && -f "$XAUTH_FILE" ]]; then
    export XAUTHORITY="$XAUTH_FILE"
    echo "Using Xwayland auth: $XAUTH_FILE"
fi

# Set XDG_RUNTIME_DIR if missing
if [[ -z "${XDG_RUNTIME_DIR:-}" ]]; then
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
fi

# Set DISPLAY if missing
if [[ -z "${DISPLAY:-}" ]]; then
    export DISPLAY=":1"
fi

echo "Launching Francis-opia..."
echo "Log: $LOG_FILE"
echo "---"

# Filter nvidia 595+ shutdown crash backtrace (Godot engine bug, harmless)
# Full output still goes to log file, only console is filtered
godot --path "$GAME_DIR" "$@" 2>&1 | tee "$LOG_FILE" | grep -v "^handle_crash:\|^Engine version:\|^Dumping the backtrace\|^\[[0-9]*\] \|^-- END OF\|^====\|IOT instruction"
