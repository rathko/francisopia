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

    # Check icon is present before export (it gets baked into the binary)
    if [ -f "${GAME_DIR}/icon.png" ]; then
        ok "Icon: icon.png found (will be embedded in binary)"
    else
        warn "Icon: icon.png NOT FOUND — binary will have no window icon"
        warn "  Fix: cp /home/shared/francisopia-icon.png ${GAME_DIR}/icon.png"
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

    # Show what we're about to transfer
    TOTAL_SIZE=0
    log "Files to transfer:"
    for f in "${EXPORT_DIR}/${BINARY_NAME}" "${GAME_DIR}/icon.png" "${GAME_DIR}/francisopia.desktop"; do
        if [ -f "$f" ]; then
            FSIZE=$(du -sh "$f" | cut -f1)
            echo -e "  ${BLUE}-${NC} $(basename "$f") (${FSIZE})"
        fi
    done

    # Test SSH connection — stream output to detect Tailscale auth prompts in real-time.
    # Tailscale SSH prints the auth URL and then BLOCKS waiting for browser approval,
    # so we can't use $(ssh ...) — it would hang without showing anything.
    log "Testing SSH connection to ${DECK_HOST}..."
    SSH_START=$(date +%s)
    SSH_LOG=$(mktemp /tmp/deploy-ssh-XXXXXX)

    # Run ssh in background, tee output to both file and a live filter
    ssh -o ConnectTimeout=10 "${DECK_USER}@${DECK_HOST}" "echo __DEPLOY_OK__" \
        >"${SSH_LOG}" 2>&1 &
    SSH_PID=$!

    # Monitor the output file for auth URLs or success, with a 120s timeout
    WAITED=0
    AUTH_SHOWN=false
    while kill -0 "$SSH_PID" 2>/dev/null; do
        # Check for Tailscale auth URL
        if [ "$AUTH_SHOWN" = false ] && grep -qi "login.tailscale.com" "${SSH_LOG}" 2>/dev/null; then
            AUTH_URL=$(grep -oE 'https://login\.tailscale\.com/[^ ]+' "${SSH_LOG}" | head -1)
            echo ""
            echo -e "  ${YELLOW}━━━ Tailscale SSH auth required ━━━${NC}"
            echo -e "  ${YELLOW}Open this URL in your browser:${NC}"
            echo ""
            echo -e "    ${GREEN}${AUTH_URL}${NC}"
            echo ""
            echo -e "  ${YELLOW}Waiting for you to approve...${NC}"
            AUTH_SHOWN=true
        fi

        sleep 1
        WAITED=$((WAITED + 1))

        # Progress dots while waiting for auth
        if [ "$AUTH_SHOWN" = true ] && [ $((WAITED % 5)) -eq 0 ]; then
            echo -ne "  ${BLUE}.${NC}"
        fi

        if [ "$WAITED" -ge 120 ]; then
            kill "$SSH_PID" 2>/dev/null || true
            echo ""
            err "SSH timed out after 120s.\n  $(cat "${SSH_LOG}")"
        fi
    done

    wait "$SSH_PID" 2>/dev/null || true
    SSH_END=$(date +%s)
    SSH_ELAPSED=$((SSH_END - SSH_START))

    if [ "$AUTH_SHOWN" = true ]; then
        echo ""
    fi

    if grep -q "__DEPLOY_OK__" "${SSH_LOG}" 2>/dev/null; then
        ok "SSH connection OK (${SSH_ELAPSED}s)"
    else
        SSH_CONTENT=$(cat "${SSH_LOG}")
        rm -f "${SSH_LOG}"
        if echo "$SSH_CONTENT" | grep -qi "Connection timed out\|No route\|Could not resolve"; then
            err "Cannot reach ${DECK_HOST} (${SSH_ELAPSED}s)\n  Is Steam Deck on? Is Tailscale running?\n  Check: tailscale status"
        else
            err "SSH failed (${SSH_ELAPSED}s)\n  Output: ${SSH_CONTENT}"
        fi
    fi
    rm -f "${SSH_LOG}"

    # Create destination and sync
    log "Creating ${DECK_PATH} on deck..."
    ssh "${DECK_USER}@${DECK_HOST}" "mkdir -p '${DECK_PATH}'"

    # Build file list: binary + icon + desktop entry
    SYNC_FILES=("${EXPORT_DIR}/${BINARY_NAME}")
    if [ -f "${GAME_DIR}/icon.png" ]; then
        SYNC_FILES+=("${GAME_DIR}/icon.png")
    fi
    SYNC_FILES+=("${GAME_DIR}/francisopia.desktop")

    log "Starting rsync transfer..."
    RSYNC_START=$(date +%s)
    rsync -avz --progress --stats --human-readable \
        "${SYNC_FILES[@]}" \
        "${DECK_USER}@${DECK_HOST}:${DECK_PATH}/"
    RSYNC_END=$(date +%s)
    RSYNC_ELAPSED=$((RSYNC_END - RSYNC_START))
    ok "Transfer complete (${RSYNC_ELAPSED}s)"

    # Make executable on deck
    ssh "${DECK_USER}@${DECK_HOST}" "chmod +x '${DECK_PATH}/${BINARY_NAME}'"

    # Install desktop entry for game mode
    ssh "${DECK_USER}@${DECK_HOST}" "
        mkdir -p ~/.local/share/applications
        sed -e 's|GAME_PATH|${DECK_PATH}/${BINARY_NAME}|g' \
            -e 's|ICON_PATH|${DECK_PATH}/icon.png|g' \
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
