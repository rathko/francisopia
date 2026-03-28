#!/bin/bash
# Francis-opia unit test runner
# Runs all GDScript unit tests via Godot headless mode.
#
# Usage (from any user):
#   ./tests/run_unit_tests.sh
#
# From Claude user (sandbox):
#   ./tests/run_unit_tests.sh
#
# From Radek:
#   godot --headless --path ~/src/pai/francisopia --script tests/run_tests.gd

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Temp dir for Godot user data (avoids permission issues in sandbox)
TMPDIR="${TMPDIR:-/tmp}"
GODOT_TMP="$TMPDIR/godot_test_data"
mkdir -p "$GODOT_TMP"

# Force mesa software rendering (nvidia EGL crashes Xvfb)
export __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json
export __GLX_VENDOR_LIBRARY_NAME=mesa
export LIBGL_ALWAYS_SOFTWARE=1
export MESA_GL_VERSION_OVERRIDE=3.3
export XDG_DATA_HOME="$GODOT_TMP"

# Try headless first (works if Xvfb wrapper handles display)
if xvfb-run --auto-servernum --server-args="-screen 0 1280x800x24" \
    godot --rendering-driver opengl3 --headless \
    --path "$PROJECT_DIR" --script tests/run_tests.gd 2>&1; then
    exit 0
fi

# Fallback: direct headless (Radek's session with native display)
echo "xvfb-run failed, trying direct headless..."
godot --headless --path "$PROJECT_DIR" --script tests/run_tests.gd 2>&1
