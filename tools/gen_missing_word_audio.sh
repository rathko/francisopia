#!/usr/bin/env bash
# gen_missing_word_audio: generate ElevenLabs "alice" word pronunciations for the game.
#
# By default it AUTO-DETECTS which words in data/words.json have no recording in
# assets/sounds/voices/alice/words/ and generates only those — so the normal workflow
# is just: add words to words.json, run this, ship. Voice + settings per
# docs/voice-generation.md.
#
# USAGE (run on framework — needs BWS key + egress to api.elevenlabs.io):
#   bash tools/gen_missing_word_audio.sh            # fill in whatever is missing (default)
#   bash tools/gen_missing_word_audio.sh --all      # (re)generate every word in the bank
#   bash tools/gen_missing_word_audio.sh hero bunny # generate exactly these words
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1
OUT_DIR="assets/sounds/voices/alice/words"
VOICE_ID="Xb7hH8MSUJpSbSDYk0k2"
MODEL="eleven_turbo_v2_5"
mkdir -p "$OUT_DIR"

# --- decide which words to generate ---
MODE="missing"
case "${1:-}" in
    --all) MODE="all"; shift ;;
    --missing) MODE="missing"; shift ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
esac

if [ "$#" -gt 0 ]; then
    WORDS=("$@")   # explicit list wins
else
    mapfile -t WORDS < <(python3 -c "
import json, os
words = [w['word'].lower() for w in json.load(open('data/words.json'))['words']]
have = {f[:-4] for f in os.listdir('$OUT_DIR') if f.endswith('.mp3')}
sel = words if '$MODE' == 'all' else [w for w in words if w not in have]
print('\n'.join(dict.fromkeys(sel)))   # dedupe, preserve order
")
fi

if [ "${#WORDS[@]}" -eq 0 ]; then
    echo "Nothing to do — every word in words.json already has a recording. ($MODE mode)"
    exit 0
fi
echo "Mode: $MODE — generating ${#WORDS[@]} word(s): ${WORDS[*]}"

# --- ElevenLabs key from BWS cache (never printed) ---
EL_KEY=$(python3 -c "
import json, os
p = os.path.expanduser('~/.cache/bws/secrets.json')
try:
    d = json.load(open(p))
    print([s['value'] for s in d['secrets'] if s['key']=='ELEVENLABS_API_KEY'][0])
except Exception:
    print('')
")
if [ -z "$EL_KEY" ]; then
    echo "ERROR: ELEVENLABS_API_KEY not found in ~/.cache/bws/secrets.json"
    echo "  Run on framework (not the claude sandbox — it blocks the BWS cache),"
    echo "  or wrap with BWS: bws run -- bash tools/gen_missing_word_audio.sh"
    exit 2
fi
echo "Key loaded (${#EL_KEY} chars). Output -> $OUT_DIR"

# --- generate + validate each ---
ok=0; bad=0
for w in "${WORDS[@]}"; do
    out="$OUT_DIR/$w.mp3"
    body=$(printf '{"text": "%s", "model_id": "%s", "voice_settings": {"stability": 0.85, "similarity_boost": 0.8, "style": 0.15}}' "$w" "$MODEL")
    code=$(curl -s -w '%{http_code}' \
        "https://api.elevenlabs.io/v1/text-to-speech/$VOICE_ID" \
        -H "xi-api-key: $EL_KEY" -H "Content-Type: application/json" \
        -d "$body" -o "$out" 2>/dev/null || echo "000")
    sz=$(stat -c%s "$out" 2>/dev/null || echo 0)
    ftype=$(file -b "$out" 2>/dev/null || echo "?")
    if [ "$code" = "200" ] && [ "$sz" -gt 1500 ] && echo "$ftype" | grep -qiE "audio|mpeg|ID3"; then
        echo "  OK   $w -> $out (${sz}B)"
        ok=$((ok+1))
    else
        echo "  FAIL $w (http=$code size=${sz}B type=$ftype)"
        [ -f "$out" ] && [ "$sz" -lt 1500 ] && { head -c 200 "$out" | tr -d '\0'; echo; }
        rm -f "$out"   # never leave a broken file for Godot to import
        bad=$((bad+1))
    fi
done
echo "Done: $ok ok, $bad failed.  (then: ./deploy.sh to import + ship)"
[ "$bad" -eq 0 ]
