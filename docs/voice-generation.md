# Voice Generation Guide

How phoneme and word pronunciation audio files are generated for Francis-opia.

## Current Voice: Alice

- **ElevenLabs Voice ID:** `Xb7hH8MSUJpSbSDYk0k2`
- **Name:** Alice - Clear, Engaging Educator
- **Gender:** Female, middle-aged, British accent
- **Model:** `eleven_turbo_v2_5`
- **Settings:** stability 0.85-0.9, similarity_boost 0.75-0.8, style 0.1-0.15

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
| a | "ah" | short /a/ as in cat |
| b | "b" | clipped /b/ |
| c | "k" | clipped /k/ |
| d | "d" | clipped /d/ |
| e | "eh" | short /e/ as in bed |
| f | "ff" | continuant /f/ |
| g | "g" | clipped /g/ |
| h | "hh" | breathy /h/ |
| i | "ih" | short /i/ as in sit |
| j | "j" | clipped /dj/ |
| k | "k" | clipped /k/ |
| l | "ll" | continuant /l/ |
| m | "mm" | continuant /m/ |
| n | "nn" | continuant /n/ |
| o | "oh" | short /o/ as in hot |
| p | "p" | clipped /p/ |
| q | "kw" | /kw/ blend |
| r | "rr" | continuant /r/ |
| s | "ss" | continuant /s/ |
| t | "t" | clipped /t/ |
| u | "uh" | short /u/ as in cup |
| v | "vv" | continuant /v/ |
| w | "ww" | glide /w/ |
| x | "ks" | /ks/ blend |
| y | "yy" | glide /j/ |
| z | "zz" | continuant /z/ |

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
