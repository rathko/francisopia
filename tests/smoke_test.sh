#!/bin/bash
# Francis-opia visual smoke test — launches the game, sends input, takes screenshots.
#
# Usage:
#   ./tests/smoke_test.sh              # Auto-detect display (Radek's X11 or Xvfb)
#   ./tests/smoke_test.sh --xvfb       # Force Xvfb virtual display
#   ./tests/smoke_test.sh --display :1 # Use specific display
#
# Requirements (all managed by Ansible eos-install.yml):
#   - godot (4.6+)                    # pacman: godot
#   - xdotool                         # pacman: xdotool
#   - imagemagick (import/convert)    # pacman: imagemagick
#   - xorg-xhost + xauth             # pacman: xorg-xhost
#   - xorg-server-xvfb               # pacman: xorg-server-xvfb (--xvfb mode only)
#
# Display access setup (when running as claude user on Radek's display):
#   1. Radek runs: xhost +local:
#   2. Radek runs: cp $XAUTHORITY /home/shared/xauth && chmod 644 /home/shared/xauth
#   3. If needed:  sudo chmod 777 /tmp/.X11-unix/X1
#   Or deploy via Ansible: ans eos-install.yml --tags gaming
#
# Known issues:
#   - nvidia-open-dkms >= 595.58.03 breaks Xvfb (segfault in libnvidia-egl-gbm.so.1)
#   - Last working nvidia version for Xvfb: 590.48.01 (2026-03-28)
#   - Workaround: use --display :1 with Radek's display instead of --xvfb

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SCREENSHOT_DIR="$SCRIPT_DIR/screenshots"
TEMP_DIR="${TMPDIR:-/tmp}"
GODOT_XDG="$TEMP_DIR/francisopia_smoke_xdg"
WAIT_STARTUP=8
WAIT_INPUT=1

mkdir -p "$SCREENSHOT_DIR" "$GODOT_XDG"

# Parse args
USE_XVFB=false
DISPLAY_OVERRIDE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --xvfb) USE_XVFB=true; shift ;;
        --display) DISPLAY_OVERRIDE="$2"; shift 2 ;;
        -h|--help)
            head -30 "$0" | grep "^#" | sed 's/^# \?//'
            exit 0 ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

# Check core dependencies
for cmd in xdotool godot; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "FAIL: $cmd not found (install via Ansible: ans eos-install.yml)"
        exit 1
    fi
done

# Need either import (imagemagick) or xwd+convert for screenshots
if ! command -v import &>/dev/null && ! command -v xwd &>/dev/null; then
    echo "FAIL: imagemagick (import) not found"
    exit 1
fi

cleanup() {
    [[ -n "${GODOT_PID:-}" ]] && kill "$GODOT_PID" 2>/dev/null || true
    [[ -n "${XVFB_PID:-}" ]] && kill "$XVFB_PID" 2>/dev/null || true
    wait "${GODOT_PID:-}" 2>/dev/null || true
    wait "${XVFB_PID:-}" 2>/dev/null || true
}
trap cleanup EXIT

# === Display setup ===
if [[ "$USE_XVFB" == "true" ]]; then
    echo "Starting Xvfb..."
    # Force mesa software rendering to avoid nvidia conflicts
    export __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json
    export __GLX_VENDOR_LIBRARY_NAME=mesa
    export LIBGL_ALWAYS_SOFTWARE=1
    export MESA_GL_VERSION_OVERRIDE=3.3

    Xvfb :99 -screen 0 1280x800x24 -ac &
    XVFB_PID=$!
    sleep 2

    if ! kill -0 "$XVFB_PID" 2>/dev/null; then
        echo "FAIL: Xvfb crashed. nvidia >= 595 breaks Xvfb."
        echo "  Use --display :1 with Radek's display instead."
        echo "  Or downgrade: sudo pacman -U /var/cache/pacman/pkg/nvidia-open-dkms-590.48.01-*.pkg.tar.zst"
        exit 1
    fi
    export DISPLAY=:99
    echo "OK: Xvfb on :99"
elif [[ -n "$DISPLAY_OVERRIDE" ]]; then
    export DISPLAY="$DISPLAY_OVERRIDE"
else
    export DISPLAY="${DISPLAY:-:1}"
fi

# Xauth: try shared cookie from /home/shared/xauth
if [[ -f /home/shared/xauth && -r /home/shared/xauth ]]; then
    XAUTH_TMP="$TEMP_DIR/.francisopia_xauth"
    cp /home/shared/xauth "$XAUTH_TMP" 2>/dev/null || true
    export XAUTHORITY="$XAUTH_TMP"
    # Add cookie for bare display name (xauth extract uses hostname prefix)
    COOKIE=$(xauth -f "$XAUTHORITY" list 2>/dev/null | head -1 | awk '{print $NF}' || true)
    if [[ -n "$COOKIE" ]]; then
        xauth -f "$XAUTHORITY" add "$DISPLAY" MIT-MAGIC-COOKIE-1 "$COOKIE" 2>/dev/null || true
    fi
fi

# Verify display
if ! xdpyinfo >/dev/null 2>&1; then
    echo "FAIL: Cannot connect to display $DISPLAY"
    echo "  Setup: Radek runs 'xhost +local:'"
    echo "  Then:  cp \$XAUTHORITY /home/shared/xauth && chmod 644 /home/shared/xauth"
    echo "  Then:  sudo chmod 777 /tmp/.X11-unix/X1  (if socket is restricted)"
    exit 1
fi
echo "OK: Display $DISPLAY"

# === Software rendering ===
export LIBGL_ALWAYS_SOFTWARE=1
export MESA_GL_VERSION_OVERRIDE=3.3
export __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json
export __GLX_VENDOR_LIBRARY_NAME=mesa
export XDG_DATA_HOME="$GODOT_XDG"

# === Launch Godot ===
echo "Launching Francis-opia..."
godot --rendering-driver opengl3 --path "$PROJECT_DIR" 2>"$TEMP_DIR/francisopia_smoke_stderr.log" &
GODOT_PID=$!
sleep "$WAIT_STARTUP"

if ! kill -0 "$GODOT_PID" 2>/dev/null; then
    echo "FAIL: Godot crashed on startup"
    grep -i "error\|fatal\|parse" "$TEMP_DIR/francisopia_smoke_stderr.log" 2>/dev/null | head -10
    exit 1
fi
echo "OK: Godot running (pid=$GODOT_PID)"

# Find window
GODOT_WIN=$(xdotool search --name "Francis-opia" 2>/dev/null | head -1)
if [[ -z "$GODOT_WIN" ]]; then
    echo "FAIL: Could not find Francis-opia window"
    exit 1
fi
echo "OK: Window $GODOT_WIN"

take_screenshot() {
    local name="$1"
    local path="$SCREENSHOT_DIR/$name"
    import -window "$GODOT_WIN" "$path" 2>/dev/null || \
        xwd -id "$GODOT_WIN" -silent 2>/dev/null | convert xwd:- "$path" 2>/dev/null || \
        { echo "FAIL: Could not capture screenshot $name"; exit 1; }

    local size
    size=$(stat -c%s "$path" 2>/dev/null || echo "0")
    if [[ "$size" -lt 1000 ]]; then
        echo "FAIL: Screenshot $name appears blank ($size bytes)"
        exit 1
    fi
    echo "PASS: $name ($size bytes)"
}

# === Test 1: Startup ===
take_screenshot "01_startup.png"

# === Test 2: Move right (D key) ===
xdotool windowfocus --sync "$GODOT_WIN" 2>/dev/null
sleep 0.5
xdotool keydown d; sleep "$WAIT_INPUT"; xdotool keyup d; sleep 0.5
take_screenshot "02_after_move.png"

# === Test 3: Jump (Space) ===
xdotool key space; sleep "$WAIT_INPUT"
take_screenshot "03_after_jump.png"

# === Verify game survived ===
if ! kill -0 "$GODOT_PID" 2>/dev/null; then
    echo "FAIL: Godot crashed during gameplay"
    exit 1
fi

echo ""
echo "=== SMOKE TEST PASSED ==="
echo "Screenshots: $SCREENSHOT_DIR/"
ls -1 "$SCREENSHOT_DIR/"*.png 2>/dev/null
