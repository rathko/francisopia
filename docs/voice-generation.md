# Voice Generation Guide

How phoneme and word pronunciation audio files are generated for Francis-opia.

## Current Voice: Alice

- **ElevenLabs Voice ID:** `Xb7hH8MSUJpSbSDYk0k2`
- **Name:** Alice - Clear, Engaging Educator
- **Gender:** Female, middle-aged, British accent
- **Model:** `eleven_turbo_v2_5`
- **Settings:** stability 0.85-0.9, similarity_boost 0.75-0.8, style 0.1-0.15

## Regenerate word audio (the easy way)

Use the project tool — it **auto-detects** which words in `data/words.json` lack a
recording and generates only those, so the normal flow after adding words is one command:

```bash
# Run on framework (needs BWS ELEVENLABS_API_KEY + internet; the claude sandbox blocks both)
bash tools/gen_missing_word_audio.sh            # fill in whatever is missing (default)
bash tools/gen_missing_word_audio.sh --all      # re-record every word (e.g. voice change)
bash tools/gen_missing_word_audio.sh hero bunny # just these words
./deploy.sh                                     # import the new .mp3s + ship to the deck
```

It validates every file is real audio (rejects tiny JSON-error blobs) and never leaves a
broken file for Godot to import. The manual recipe below is the underlying API call.

## How to Generate Phonemes

### Prerequisites
- ElevenLabs API key in BWS as `ELEVENLABS_API_KEY`
- `curl` available

### Generate a single phoneme
```bash
EL_KEY=$(cat ~/.cache/bws/secrets.json | python3 -c "import sys,json; secrets=json.load(sys.stdin)['secrets']; print([s['value'] for s in secrets if s['key']=='ELEVENLABS_API_KEY'][0])")
VOICE_ID="Xb7hH8MSUJpSbSDYk0k2"

curl -s "https://api.elevenlabs.io/v1/text-to-speech/$VOICE_ID" \
  -H "xi-api-key: $EL_KEY" -H "Content-Type: application/json" \
  -d '{"text": "ah", "model_id": "eleven_turbo_v2_5", "voice_settings": {"stability": 0.9, "similarity_boost": 0.75, "style": 0.1}}' \
  -o assets/sounds/voices/alice/phonemes/a.mp3
```

### Generate a word pronunciation
```bash
curl -s "https://api.elevenlabs.io/v1/text-to-speech/$VOICE_ID" \
  -H "xi-api-key: $EL_KEY" -H "Content-Type: application/json" \
  -d '{"text": "cat", "model_id": "eleven_turbo_v2_5", "voice_settings": {"stability": 0.85, "similarity_boost": 0.8, "style": 0.15}}' \
  -o assets/sounds/voices/alice/words/cat.mp3
```

### Phoneme text mappings (what text produces clean letter sounds)
| Letter | Text sent to API | Phoneme sound |
|--------|-----------------|---------------|
| a | "aah" | short /a/ as in cat |
| b | "buh" | clipped /b/ — NEVER send just "b" (TTS says "bee") |
| c | "kuh" | hard c = /k/ |
| d | "duh" | clipped /d/ — NEVER send just "d" (TTS says "dee") |
| e | "ehh" | short /e/ as in bed |
| f | "ffff" | sustained /f/ |
| g | "guh" | clipped /g/ — NEVER send just "g" (TTS says "gee") |
| h | "huh" | breathy /h/ with minimal vowel |
| i | "ihh" | short /i/ as in sit — NOT "ih" (sounds like "I") |
| j | "juh" | clipped /dj/ |
| k | "kuh" | clipped /k/ |
| l | "llll" | sustained /l/ |
| m | "mmmm" | sustained /m/ |
| n | "nnnn" | sustained /n/ |
| o | "aww" | short /o/ as in hot — NOT "oh" (that's long o) |
| p | "puh" | clipped /p/ — NEVER send just "p" (TTS says "pee") |
| q | "kwuh" | /kw/ blend |
| r | "rrrr" | sustained /r/ |
| s | "ssss" | sustained /s/ |
| t | "tuh" | clipped /t/ — NEVER send just "t" (TTS says "tee") |
| u | "uhh" | short /u/ as in cup |
| v | "vvvv" | sustained /v/ |
| w | "wuh" | glide /w/ |
| x | "ks" | /ks/ blend |
| y | "yuh" | glide /j/ |
| z | "zzzz" | sustained /z/ |

**CRITICAL LESSON LEARNED**: Never send a single letter to ElevenLabs TTS.
The model interprets single letters as letter NAMES ("b"→"bee", "g"→"gee"),
not phoneme SOUNDS. Always use syllable text that forces the sound.

## Adding a New Voice Persona

1. Choose a voice from ElevenLabs (or record your own)
2. Create directory: `assets/sounds/voices/{voice_name}/phonemes/` and `words/`
3. Generate all 26 phonemes using the mappings above
4. Generate word pronunciations for all words in the word bank
5. Change `VOICE_DIR` constant in `PhonemePlayer.gd` to point to new directory
6. Test with Francis to verify clarity and warmth

## Voice Settings Guide

| Parameter | Effect | Range |
|-----------|--------|-------|
| stability | Higher = more consistent, lower = more expressive | 0.0-1.0, use 0.8-0.9 for phonemes |
| similarity_boost | How closely to match the original voice | 0.0-1.0, use 0.75-0.85 |
| style | Expressiveness/emotion | 0.0-1.0, use 0.1-0.2 for educational |

**For phonemes:** High stability (0.9), moderate similarity (0.75), low style (0.1)
**For words:** Slightly lower stability (0.85), higher similarity (0.8), moderate style (0.15)

## Licensing Note

- **Free tier:** Cannot be used commercially. Must attribute ElevenLabs.
- **Starter tier ($5/mo):** Commercial use permitted. Audio is owned by you perpetually.
- **For Steam release:** Upgrade to Starter tier and re-generate all audio.
- Generated 2026-03-28 on free tier for development/testing only.

## File Structure
```
assets/sounds/voices/
  alice/                    <- Current active voice
    phonemes/
      a.mp3 ... z.mp3      <- 26 individual letter sounds
    words/
      cat.mp3, dog.mp3 ... <- Word pronunciations
  [future_voice]/           <- Swap by changing PhonemePlayer.VOICE_DIR
    phonemes/
    words/
```
