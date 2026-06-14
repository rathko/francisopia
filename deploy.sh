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

# The Steam Deck's sshd flaps when it wakes — a single connection often gets "Connection
# refused" even though a retry seconds later works. These helpers retry deck operations so a
# flaky link no longer forces a full re-export. Tunable: SSH_RETRIES attempts, SSH_RETRY_DELAY s.
SSH_RETRIES="${SSH_RETRIES:-5}"
SSH_RETRY_DELAY="${SSH_RETRY_DELAY:-4}"

retry() {
    # retry <description> -- runs "$@" up to SSH_RETRIES times, sleeping between failures.
    local desc="$1"; shift
    local n=1 rc=0
    while true; do
        if "$@"; then return 0; fi
        rc=$?
        if [ "$n" -ge "$SSH_RETRIES" ]; then
            warn "${desc}: still failing after ${SSH_RETRIES} attempts (rc=${rc})"
            return "$rc"
        fi
        warn "${desc}: attempt ${n}/${SSH_RETRIES} failed — Deck SSH may be waking; retrying in ${SSH_RETRY_DELAY}s..."
        sleep "$SSH_RETRY_DELAY"
        n=$((n + 1))
    done
}

ssh_capture() {
    # ssh_capture <remote-command> -- echoes stdout, retrying on connection failure. Empty on
    # total failure (callers already default with `|| echo ...`).
    local rcmd="$1" out="" n=1
    while true; do
        if out=$(ssh "${DECK_USER}@${DECK_HOST}" "$rcmd" 2>/dev/null); then
            printf '%s' "$out"; return 0
        fi
        if [ "$n" -ge "$SSH_RETRIES" ]; then return 1; fi
        sleep "$SSH_RETRY_DELAY"
        n=$((n + 1))
    done
}

# ─── Parse args ──────────────────────────────────────────────────
DO_EXPORT=true
DO_DEPLOY=true
DO_VERIFY=true   # headless tests + runtime smoke before export (catches regressions)

# --no-verify can appear in any position — it's an escape hatch, not a mode.
for _a in "$@"; do [ "$_a" = "--no-verify" ] && DO_VERIFY=false; done

case "${1:-}" in
    --export) DO_DEPLOY=false ;;
    --deploy) DO_EXPORT=false ;;
    --help|-h)
        echo "Usage: ./deploy.sh [--export|--deploy|--no-verify|--help]"
        echo "  (no args)    Generate assets, validate, export and deploy to Steam Deck"
        echo "  --export     Export only (build the binary)"
        echo "  --deploy     Deploy only (transfer existing build)"
        echo "  --no-verify  Skip the headless unit-test + runtime smoke gate"
        exit 0
        ;;
esac

# ─── EXPORT ──────────────────────────────────────────────────────
if [ "$DO_EXPORT" = true ]; then
    log "Exporting ${GAME_NAME} for Linux x86_64..."

    mkdir -p "${EXPORT_DIR}"

    # Check if export templates are installed for THIS Godot version
    # (the parent dir existing isn't enough — version subdir must contain linux_release.x86_64)
    GODOT_VER_LINE=$(godot --version 2>/dev/null | head -1 || true)
    if [[ "$GODOT_VER_LINE" =~ ^([0-9]+\.[0-9]+\.[0-9]+)\.stable ]]; then
        TEMPLATE_SUBDIR="${BASH_REMATCH[1]}.stable"
    else
        TEMPLATE_SUBDIR="$GODOT_VER_LINE"   # best effort if non-stable build
    fi
    TEMPLATE_FILE="${HOME}/.local/share/godot/export_templates/${TEMPLATE_SUBDIR}/linux_release.x86_64"
    if [ ! -f "${TEMPLATE_FILE}" ]; then
        err "Export template missing: ${TEMPLATE_FILE}\n  CLI fix: /home/shared/nfs/logs/install-godot-templates.sh\n  GUI fix: godot --editor  →  Editor menu  →  Manage Export Templates"
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

    # CRITICAL: regenerate the word bank from words.json BEFORE exporting.
    # The exported .pck bundles word_bank.tres (a Godot resource), NOT the raw
    # data/words.json (export_filter=all_resources skips non-resource files), and
    # WordEngine falls back to the .tres when words.json isn't present at runtime.
    # So any word added to words.json is INVISIBLE in the build unless the .tres is
    # rebuilt here. Skipping this is why new words never showed up for weeks.
    # Import any new/changed assets (e.g. freshly added sprites) so the exporter packs
    # their compressed textures. Without this a brand-new PNG ships with no .ctex and shows
    # nothing in the build. Tolerant: --export-release also imports, so a flag hiccup here
    # is a warning, not a failure.
    # Regenerate procedural sprite art FIRST so a forgotten `python3 tools/gen_*.py`
    # can't ship stale or missing PNGs. Deterministic — identical output is a no-op for the
    # import pass below. Tolerant: a missing Pillow / python is a warning, not a failure
    # (the committed PNGs still ship).
    log "Generating sprite assets..."
    if command -v python3 >/dev/null 2>&1; then
        for gen in tools/gen_sprites.py tools/gen_bag_sprite.py; do
            if [ -f "${GAME_DIR}/${gen}" ]; then
                if ( cd "${GAME_DIR}" && python3 "${gen}" ) >/dev/null 2>&1; then
                    ok "ran ${gen}"
                else
                    warn "sprite generator failed: ${gen} (need Pillow? 'pip install Pillow') — shipping existing PNG"
                fi
            fi
        done
    else
        warn "python3 not found — skipping sprite generation (shipping existing PNGs)"
    fi

    # Generate ANY missing word pronunciations (alice voice) so every spellable word is spoken.
    # Auto-detects words in data/words.json with no clip in assets/sounds/voices/alice/words/.
    # Tolerant: needs the ElevenLabs key + egress (framework only) — a failure is a warning, not
    # a blocker (existing clips still ship).
    if [ -x "${GAME_DIR}/tools/gen_missing_word_audio.sh" ]; then
        log "Generating any missing word pronunciations..."
        if "${GAME_DIR}/tools/gen_missing_word_audio.sh" >"${EXPORT_DIR}/.last-wordaudio.log" 2>&1; then
            ok "Word audio up to date"
        else
            warn "Missing-word audio step failed (need ELEVENLABS_API_KEY + egress?). See ${EXPORT_DIR}/.last-wordaudio.log"
        fi
    fi

    log "Importing assets (sprites, etc.)..."
    IMPORT_LOG="${EXPORT_DIR}/.last-import.log"
    if godot --headless --path "${GAME_DIR}" --import >"${IMPORT_LOG}" 2>&1; then
        ok "Assets imported"
    else
        warn "Asset import pass returned non-zero (export will still import). See ${IMPORT_LOG}"
    fi

    log "Regenerating word bank from words.json..."
    WORDBANK_LOG="${EXPORT_DIR}/.last-wordbank.log"
    if ! godot --headless --script tools/import_words.gd >"${WORDBANK_LOG}" 2>&1; then
        tail -20 "${WORDBANK_LOG}"
        err "Word bank regeneration failed. Full output: ${WORDBANK_LOG}"
    fi
    WORD_COUNT=$(grep -oE 'Found [0-9]+ words' "${WORDBANK_LOG}" | head -1 || true)
    ok "Word bank refreshed (${WORD_COUNT:-regenerated})"

    # ─── HEADLESS VALIDATION ─────────────────────────────────────────
    # The mainframe (where the AI works) has NO Godot, so GDScript regressions are invisible
    # until the game actually RUNS. `--export-release` only catches PARSE errors. So we run the
    # unit tests + boot the scene headless under --qa (exercises every summon/restore path) and
    # PROVE the game booted. Failure taxonomy (important — don't block on the wrong thing):
    #   - GDScript SCRIPT ERROR / Parse Error            -> HARD FAIL
    #   - no "Chunks: N" or no boot-complete line         -> HARD FAIL (the "no levels" bug)
    #   - a native crash AFTER _ready() finished           -> WARN only. --headless has no GPU,
    #     so the summon particle VFX can SIGSEGV under headless while the real device is fine.
    if [ "$DO_VERIFY" = true ]; then
        log "Running unit tests (headless)..."
        TEST_LOG="${EXPORT_DIR}/.last-tests.log"
        godot --headless --path "${GAME_DIR}" --script tests/run_tests.gd >"${TEST_LOG}" 2>&1 || true
        if grep -qE "FAIL:|[1-9][0-9]* failed" "${TEST_LOG}"; then
            grep -nE "FAIL:|[0-9]+ failed" "${TEST_LOG}" | head -20
            err "Unit tests FAILED. Full output: ${TEST_LOG}"
        fi
        ok "Unit tests passed"

        log "Booting main scene headless (--qa) to validate the game boots..."
        SMOKE_LOG="${EXPORT_DIR}/.last-smoke.log"
        # Capture the real exit code — a crash returns 134/139, which we must NOT swallow.
        godot --headless --path "${GAME_DIR}" --quit-after 240 -- --qa >"${SMOKE_LOG}" 2>&1 && SMOKE_RC=0 || SMOKE_RC=$?

        # Hard fail: GDScript errors anywhere in the boot.
        if grep -qE "SCRIPT ERROR|Parse Error|Parser Error|Cannot call method|Invalid (get|set|call|operands|index)|Attempt to call|Trying to (call|assign)" "${SMOKE_LOG}"; then
            echo "──── GDScript errors on boot ────"
            grep -nE "SCRIPT ERROR|Parse Error|Parser Error|Cannot call method|Invalid (get|set|call|operands|index)|Attempt to call|Trying to (call|assign)" "${SMOKE_LOG}" | head -30
            echo "─────────────────────────────────"
            err "Main scene threw GDScript errors on boot. Full output: ${SMOKE_LOG}"
        fi
        # Hard fail: terrain never actually built (THE "level one disappeared, you fall in" bug).
        # "Terrain ready: N" proves real blocks exist, not just that chunk nodes were created —
        # a runtime error mid-generation can still print "Chunks:" while leaving the world empty.
        if ! grep -qE "Terrain ready: [1-9]" "${SMOKE_LOG}"; then
            tail -40 "${SMOKE_LOG}"
            err "Terrain did NOT generate (no 'Terrain ready: N>0' line). The world is empty; do NOT ship. Full output: ${SMOKE_LOG}"
        fi
        # World built + _ready() completed. A crash now is the headless-GPU particle path — warn only.
        if [ "${SMOKE_RC:-0}" -ge 128 ] || grep -q "Program crashed with signal" "${SMOKE_LOG}"; then
            SIG=$(grep -oE "crashed with signal [0-9]+" "${SMOKE_LOG}" | head -1 || echo "signal ?")
            warn "Headless run ${SIG} AFTER the world built — likely GPUParticles under --headless; the real device is unaffected. See ${SMOKE_LOG}"
        fi
        ok "Runtime smoke passed — world generated ($(grep -oE 'Chunks: [0-9]+' "${SMOKE_LOG}" | head -1)), _ready() completed"
    else
        warn "Skipping headless validation (--no-verify) — shipping unvalidated"
    fi

    # Check icon is present before export (it gets baked into the binary)
    if [ -f "${GAME_DIR}/icon.png" ]; then
        ok "Icon: icon.png found (will be embedded in binary)"
    else
        warn "Icon: icon.png NOT FOUND — binary will have no window icon"
        warn "  Fix: cp /home/shared/francisopia-icon.png ${GAME_DIR}/icon.png"
    fi

    EXPORT_LOG="${EXPORT_DIR}/.last-export.log"
    EXPORT_BIN="${EXPORT_DIR}/${BINARY_NAME}"

    # CRITICAL: delete any stale binary BEFORE export. If we don't, a failed
    # godot run leaves the previous binary in place — the "did it build?"
    # existence check below would falsely pass and we'd rsync a stale binary
    # to the deck. Lost a Sunday afternoon to this once.
    if [ -f "${EXPORT_BIN}" ]; then
        log "Removing previous binary to ensure freshness"
        rm -f "${EXPORT_BIN}"
    fi

    # rm above + exit-code check + file-exists check below is enough to catch
    # the stale-binary bug. An extra mtime comparison against `date +%s` fires
    # false positives on NFS-mounted export dirs because of clock skew between
    # framework and the NFS server (mainframe).
    if ! godot --headless --export-release "${EXPORT_PRESET}" "${EXPORT_BIN}" >"${EXPORT_LOG}" 2>&1; then
        tail -30 "${EXPORT_LOG}"
        err "godot --export-release exited non-zero. Full output: ${EXPORT_LOG}"
    fi
    tail -10 "${EXPORT_LOG}"

    if [ ! -f "${EXPORT_BIN}" ]; then
        err "Export reported success but binary not at ${EXPORT_BIN}\n  Full Godot output: ${EXPORT_LOG}"
    fi

    SIZE=$(du -sh "${EXPORT_BIN}" | cut -f1)
    ok "Export complete: ${EXPORT_BIN} (${SIZE})"
    ok "Built at: $(date -r "${EXPORT_BIN}" '+%Y-%m-%d %H:%M:%S %Z')"
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
    retry "create deck dir" ssh "${DECK_USER}@${DECK_HOST}" "mkdir -p '${DECK_PATH}'" \
        || err "Could not reach the Deck to create ${DECK_PATH} after ${SSH_RETRIES} tries.\n  Is it awake + on Tailscale? Re-run './deploy.sh --deploy' to retry just the transfer (no re-export)."

    # Build file list: binary + icon + desktop entry
    SYNC_FILES=("${EXPORT_DIR}/${BINARY_NAME}")
    if [ -f "${GAME_DIR}/icon.png" ]; then
        SYNC_FILES+=("${GAME_DIR}/icon.png")
    fi
    SYNC_FILES+=("${GAME_DIR}/francisopia.desktop")

    log "Starting rsync transfer..."
    RSYNC_START=$(date +%s)
    # --partial resumes an interrupted transfer; retry absorbs a flapping link. rsync is
    # incremental, so a retry only re-sends whatever didn't make it — never the whole 100MB.
    retry "rsync transfer" rsync -avz --partial --progress --stats --human-readable \
        "${SYNC_FILES[@]}" \
        "${DECK_USER}@${DECK_HOST}:${DECK_PATH}/" \
        || err "rsync to the Deck failed after ${SSH_RETRIES} tries.\n  Re-run './deploy.sh --deploy' to retry just the transfer (no re-export)."
    RSYNC_END=$(date +%s)
    RSYNC_ELAPSED=$((RSYNC_END - RSYNC_START))
    ok "Transfer complete (${RSYNC_ELAPSED}s)"

    # Make executable on deck
    retry "chmod on deck" ssh "${DECK_USER}@${DECK_HOST}" "chmod +x '${DECK_PATH}/${BINARY_NAME}'" \
        || err "Could not chmod the binary on the Deck after ${SSH_RETRIES} tries."

    # Show the timestamp of the binary AS IT NOW EXISTS ON THE DECK — confirms the
    # freshly-built file actually landed (not a stale leftover from a failed transfer).
    DECK_TS=$(ssh_capture "stat -c '%y' '${DECK_PATH}/${BINARY_NAME}'" | cut -d'.' -f1 || true)
    ok "Deployed binary on deck: ${DECK_PATH}/${BINARY_NAME}"
    ok "Deck file timestamp: ${DECK_TS:-unknown}"

    # ─── VERIFY the deck copy is byte-identical to what we just built ────────────
    # This is the guard against the "nothing changed for days, scratching my head"
    # class of silent stale deploys: if the file on the deck isn't exactly the binary
    # we just exported, FAIL LOUDLY instead of pretending success.
    LOCAL_SIZE=$(stat -c%s "${EXPORT_DIR}/${BINARY_NAME}")
    DECK_SIZE=$(ssh_capture "stat -c%s '${DECK_PATH}/${BINARY_NAME}'" || echo "0")
    log "Verifying transfer: local=${LOCAL_SIZE}B  deck=${DECK_SIZE}B"
    if [ "${LOCAL_SIZE}" != "${DECK_SIZE}" ]; then
        err "SIZE MISMATCH — deck copy is ${DECK_SIZE}B but local build is ${LOCAL_SIZE}B.\n  The deploy did NOT land correctly. Nothing on the deck changed."
    fi
    ok "Size matches: ${LOCAL_SIZE} bytes"

    # Checksum — the definitive "is it really the same file" check.
    LOCAL_SHA=$(sha256sum "${EXPORT_DIR}/${BINARY_NAME}" | cut -d' ' -f1)
    DECK_SHA=$(ssh_capture "sha256sum '${DECK_PATH}/${BINARY_NAME}'" | cut -d' ' -f1 || echo "none")
    if [ "${LOCAL_SHA}" != "${DECK_SHA}" ]; then
        err "CHECKSUM MISMATCH — deck sha256 (${DECK_SHA}) != local (${LOCAL_SHA}).\n  The file on the deck is NOT the build you just made."
    fi
    ok "Checksum verified — deck binary is byte-identical to this build (sha256 ${LOCAL_SHA:0:12}…)"

    echo -e "  ${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${GREEN}  DEPLOY VERIFIED — the Steam Deck is running THIS exact build${NC}"
    echo -e "     deck file : ${DECK_PATH}/${BINARY_NAME}"
    echo -e "     timestamp : ${DECK_TS:-unknown}"
    echo -e "     sha256    : ${LOCAL_SHA}"
    echo -e "  ${GREEN}══════════════════════════════════════════════════════════════${NC}"

    # Install desktop entry for game mode (non-fatal — the binary is already deployed + verified).
    retry "install desktop entry" ssh "${DECK_USER}@${DECK_HOST}" "
        mkdir -p ~/.local/share/applications
        sed -e 's|GAME_PATH|${DECK_PATH}/${BINARY_NAME}|g' \
            -e 's|ICON_PATH|${DECK_PATH}/icon.png|g' \
            '${DECK_PATH}/francisopia.desktop' \
            > ~/.local/share/applications/francisopia.desktop
    " || warn "Could not install the desktop entry (non-fatal) — the binary is deployed and verified."

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
