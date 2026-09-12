# Buddy AI Worker

Cloudflare Worker backend for Nova. **All API keys live here — never in the mobile app.**

## Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/health` | GET | Health check |
| `/chat` | POST | Gemini / Llama chat |
| `/tts` | POST | Cartesia speech (voice IDs from env) |
| `/stt/ws` | WebSocket | Sarvam streaming STT proxy |

## Secrets (set on Cloudflare)

```bash
cd worker
npx wrangler secret put GOOGLE_AI_API_KEY
npx wrangler secret put CARTESIA_API_KEY
npx wrangler secret put SARVAM_API_KEY
# optional
npx wrangler secret put BRAVE_API_KEY
```

## Vars (in `wrangler.toml` or dashboard)

- `CARTESIA_VOICE_ID` — default female voice UUID
- `CARTESIA_MALE_VOICE_ID` — male voice UUID
- `CARTESIA_MODEL` — e.g. `sonic-3.6`
- `CARTESIA_LANGUAGE` — default `en-IN`
- `SARVAM_MODEL` — e.g. `saaras:v3`
- `SARVAM_LANGUAGE_CODE` — `unknown` for auto-detect
- `GOOGLE_AI_MODEL` — e.g. `gemini-3.5-flash-lite`

## Deploy

```bash
cd worker
npm install
npx wrangler deploy
```

If Wrangler warns that local config differs from the dashboard, update `wrangler.toml`
to match the dashboard values, then deploy again. Secrets (`*_API_KEY`) are never
stored in `wrangler.toml` — only in Cloudflare secrets.

### Dashboard vars (must match `wrangler.toml`)

| Name | Example |
|------|---------|
| `GOOGLE_AI_MODEL` | `gemini-3.5-flash-lite` |
| `CARTESIA_MODEL` | `sonic-3.6` |
| `CARTESIA_VOICE_ID` | female voice UUID |
| `CARTESIA_MALE_VOICE_ID` | male voice UUID (optional) |
| `SARVAM_MODEL` | `saaras:v3` |
| `SARVAM_MODE` | `transcribe` |
| `SARVAM_LANGUAGE_CODE` | `unknown` |

Also enable **Workers AI** binding `AI` in `wrangler.toml` for Llama fallback.

## STT WebSocket

App connects to:

```
wss://buddy-ai-worker.anilgithubd.workers.dev/stt/ws?installationId=<uuid>&language_code=en-IN
```

Worker proxies to `wss://api.sarvam.ai/speech-to-text/ws` with `SARVAM_API_KEY`.

Client sends Sarvam audio messages (base64 PCM). Worker relays both directions.

## TTS request

```json
POST /tts
{
  "installationId": "uuid",
  "text": "Hello",
  "language": "en-IN",
  "gender": "female"
}
```

Voice ID is chosen from `CARTESIA_VOICE_ID` / `CARTESIA_MALE_VOICE_ID` on the worker.
