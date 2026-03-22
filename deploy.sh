#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# Francis-opia Steam Deck Deploy Pipeline
# ═══════════════════════════════════════════════════════════════════
#
# FIRST-TIME SETUP: See README.md "Deploy to Steam Deck" section.
# Requires: Tailscale on both machines (with --ssh on Deck), Godot export templates.
# No SSH keys or sshd needed — Tailscale SSH handles auth via tailnet identity.
#
# USAGE:
#    ./deploy.sh              # Export + deploy to Steam Deck
#    ./deploy.sh --export     # Export only (no transfer)
#    ./deploy.sh --deploy     # Transfer only (skip export)
#
# ═══════════════════════════════════════════════════════════════════

set -euo pipefail

# ─── CONFIG (edit these) ─────────────────────────────────────────
DECK_USER="deck"
DECK_HOST="steamdeck"                # Tailscale MagicDNS name
DECK_PATH="/home/deck/Games/francisopia"
GAME_NAME="francisopia"
# ─────────────────────────────────────────────────────────────────

GAME_DIR="$(cd "$(dirname "$0")" && pwd)"
EXPORT_DIR="${GAME_DIR}/export"
EXPORT_PRESET="Linux"
BINARY_NAME="${GAME_NAME}.x86_64"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()  { echo -e "${BLUE}[deploy]${NC} $1"; }
ok()   { echo -e "${GREEN}[  ok  ]${NC} $1"; }
warn() { echo -e "${YELLOW}[ warn ]${NC} $1"; }
err()  { echo -e "${RED}[error ]${NC} $1"; exit 1; }

# ─── Parse args ──────────────────────────────────────────────────
DO_EXPORT=true
DO_DEPLOY=true

case "${1:-}" in
    --export) DO_DEPLOY=false ;;
    --deploy) DO_EXPORT=false ;;
    --help|-h)
        echo "Usage: ./deploy.sh [--export|--deploy|--help]"
        echo "  (no args)  Export and deploy to Steam Deck"
        echo "  --export   Export only (build the binary)"
        echo "  --deploy   Deploy only (transfer existing build)"
        exit 0
        ;;
esac

# ─── EXPORT ──────────────────────────────────────────────────────
if [ "$DO_EXPORT" = true ]; then
    log "Exporting ${GAME_NAME} for Linux x86_64..."

    mkdir -p "${EXPORT_DIR}"

    # Check if export templates are installed
    TEMPLATE_DIR="${HOME}/.local/share/godot/export_templates"
    if [ ! -d "${TEMPLATE_DIR}" ]; then
        err "Export templates not found at ${TEMPLATE_DIR}\n  Download them: Godot Editor → Editor → Manage Export Templates"
    fi

    # Run Godot headless export
    cd "${GAME_DIR}"

    # Source display env from run.sh approach if needed
    if [ -z "${DISPLAY:-}" ]; then
        export DISPLAY=":0"
        XAUTH_FILE=$(find /tmp -maxdepth 1 -name ".Xauth*" 2>/dev/null | head -1)
        if [ -n "${XAUTH_FILE}" ]; then
            export XAUTHORITY="${XAUTH_FILE}"
        fi
    fi

    godot --headless --export-release "${EXPORT_PRESET}" "${EXPORT_DIR}/${BINARY_NAME}" 2>&1 | tail -5

    if [ -f "${EXPORT_DIR}/${BINARY_NAME}" ]; then
        SIZE=$(du -sh "${EXPORT_DIR}/${BINARY_NAME}" | cut -f1)
        ok "Export complete: ${EXPORT_DIR}/${BINARY_NAME} (${SIZE})"
    else
        err "Export failed — binary not found at ${EXPORT_DIR}/${BINARY_NAME}"
    fi
fi

# ─── DEPLOY ──────────────────────────────────────────────────────
if [ "$DO_DEPLOY" = true ]; then
    log "Deploying to Steam Deck at ${DECK_USER}@${DECK_HOST}..."

    if [ ! -f "${EXPORT_DIR}/${BINARY_NAME}" ]; then
        err "No export found at ${EXPORT_DIR}/${BINARY_NAME}\n  Run ./deploy.sh --export first"
    fi

    # Test SSH connection
    if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "${DECK_USER}@${DECK_HOST}" "echo ok" &>/dev/null; then
        err "Cannot connect to ${DECK_USER}@${DECK_HOST}\n  Check: SSH enabled? IP correct? SSH key set up?"
    fi

    # Create destination and sync
    ssh "${DECK_USER}@${DECK_HOST}" "mkdir -p '${DECK_PATH}'"

    rsync -avz --progress \
        "${EXPORT_DIR}/${BINARY_NAME}" \
        "${GAME_DIR}/francisopia.desktop" \
        "${DECK_USER}@${DECK_HOST}:${DECK_PATH}/"

    # Make executable on deck
    ssh "${DECK_USER}@${DECK_HOST}" "chmod +x '${DECK_PATH}/${BINARY_NAME}'"

    # Install desktop entry for game mode
    ssh "${DECK_USER}@${DECK_HOST}" "
        mkdir -p ~/.local/share/applications
        sed 's|GAME_PATH|${DECK_PATH}/${BINARY_NAME}|g' \
            '${DECK_PATH}/francisopia.desktop' \
            > ~/.local/share/applications/francisopia.desktop
    "

    ok "Deployed to Steam Deck!"
    echo ""
    echo -e "  ${GREEN}To play:${NC}"
    echo "    1. Add as non-Steam game in Steam → Add a Game → Browse..."
    echo "       Path: ${DECK_PATH}/${BINARY_NAME}"
    echo "    2. Or run from Desktop Mode terminal:"
    echo "       ${DECK_PATH}/${BINARY_NAME}"
    echo ""
fi

log "Done!"
