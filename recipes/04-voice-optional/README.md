# Recipe 04 — Voice (OPTIONAL, and disabled by default)

> **⚠️ Read this first — it's off on purpose.**
> This build keeps STT+TTS **stopped and disabled**. Speaches (Whisper) + Kokoro together hold
> **~4 GB of VRAM** on the GPU. On a ~24 GB box, that VRAM is worth more as **KV cache / longer
> context** for the language model than as an idle voice pipeline. Enable this **only if you want
> voice more than you want long context.** Expect to shrink your model's `-c` afterward.

**Goal:** real-time speech: talk to the stack, hear it reply.
**Prereqs:** Recipe 02 (Open WebUI running); NVIDIA Container Toolkit installed so Docker containers
can use `--gpus all`.

## Architecture

Two standalone, OpenAI-compatible audio services; Open WebUI's built-in **Call** mode is the client:

```
 mic ─▶ Open WebUI "Call" ─┬─▶ STT: Speaches (faster-whisper)  :8001  /v1/audio/transcriptions
                           ├─▶ LLM: LiteLLM :4000 (use a fast, NON-thinking model)
                           └─▶ TTS: Kokoro (kokoro-fastapi)    :8880  /v1/audio/speech
        speaker ◀──────────┘
```

## Step 1 — Start the audio services

```
./scripts/render-configs.sh    # renders the speaches/kokoro unit templates too
sudo cp systemd/speaches.service systemd/kokoro.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now speaches kokoro
```

Pull an STT model into Speaches (once):

```
curl -X POST http://127.0.0.1:8001/v1/models/deepdml/faster-whisper-large-v3-turbo-ct2
```

## Step 2 — Point Open WebUI at them

In Open WebUI → **Admin → Settings → Audio**:
- **STT**: engine = OpenAI, base URL `http://127.0.0.1:8001/v1`
- **TTS**: engine = OpenAI, base URL `http://127.0.0.1:8880/v1`, pick a voice (e.g. `af_heart`)

> If `ENABLE_PERSISTENT_CONFIG=false` is set (it is, in this build), these UI settings may not
> persist — set them via the corresponding env vars on the Open WebUI unit instead, the same way
> web search is handled in Recipe 02.

## Step 3 — Use a fast, non-thinking model for voice

Voice can't tolerate a model that "thinks" for seconds before speaking. Use a snappy model with
**thinking OFF** (e.g. `local-coder`, or a small Gemma text model). Time-to-first-token, not raw
throughput, is the metric that matters — you only need decode to stay ahead of speech (~15 tok/s).

## Verify

Open a chat, click the **Call** (phone) icon, and talk. You should get a spoken reply within about
a second.

## Gotchas

- **Crackling / robotic TTS** almost always means Open WebUI fell back to its **browser** TTS
  instead of Kokoro — re-check the TTS engine is set to **OpenAI**, not "Web/Local."
- Some Gemma GGUFs won't load if they include a vision/audio **projector**; use a **text-only**
  export for the voice LLM.
- Watch VRAM (`nvidia-smi`) after enabling — if the LLM now spills to CPU, lower its `-c`.

## To turn it back off (reclaim the VRAM)

```
sudo systemctl disable --now speaches kokoro
```
