# What you can do with it (capabilities)

Once the core is running, the same OpenAI endpoint powers a surprising range of tools. Everything
below talks to the **one** LiteLLM gateway, so adding a capability is just pointing another client
at `:4000`.

| Capability | Tool | How it connects | Status in this build |
|-----------|------|-----------------|----------------------|
| **Chat + docs + web search** | Open WebUI | → LiteLLM `:4000`; web search via SearXNG `:8888` | Core, live |
| **Coding agent — native tool-calling** | opencode, pi | → LiteLLM `:4000` | Live; recipe included |
| **Coding agent — text protocol** | mini-swe-agent | → LiteLLM `:4000` | Live; recipe included |
| **Web search backend** | SearXNG | queried by Open WebUI + agent skills | Core, live |
| **Voice — real-time STT → LLM → TTS** | Speaches + Kokoro + Open WebUI "Call" | standalone OpenAI-compatible audio services | **Documented but DISABLED** (see note) |

## Chat, documents, and web search

Open WebUI is the everyday interface: pick a model (`local-fast`/`local-coder`/`local-gemma`),
chat, upload documents for RAG, or let it **search the web** through your private SearXNG instance
(no third-party search API, nothing leaves your network). Recipe:
[recipes/02-gateway-and-chat](../recipes/02-gateway-and-chat/README.md).

## Coding agents — two philosophies

This build runs **both** kinds so you can feel the difference:

- **Native tool-calling** (`opencode`, `pi`): the model emits structured `tool_calls` and the agent
  executes them. Clean when the model's chat template supports tools well — Qwen3.6 does.
- **Text protocol** (`mini-swe-agent`): the model writes a fenced ```` ```mswea_bash_command ````
  block that's regex-parsed. Deliberately robust — it doesn't depend on tool-calling working, so
  it's a good fallback for models/templates where tool-calls are flaky.

Recipe: [recipes/03-coding-agents](../recipes/03-coding-agents/README.md).

## Voice (documented, but intentionally OFF here)

The stack *can* do real-time speech: **Speaches** (STT, faster-whisper) + **Kokoro** (TTS) as
standalone OpenAI-compatible services, driven by Open WebUI's built-in **Call** mode.

> **Why it's disabled in the reference build:** STT+TTS together hold ~4 GB of VRAM (Whisper +
> Kokoro resident on the GPU). On a 24 GB box that VRAM is more valuable as **KV cache / longer
> context** for the language model. So the units exist and are documented, but are **stopped and
> disabled** — enable them only if you want voice more than you want long context. The recipe walks
> through turning it on and the trade-off: [recipes/04-voice-optional](../recipes/04-voice-optional/README.md).

## Explicitly out of scope

- **House-audio / music control** and other home-automation tool-calling — a fun direction (LLM
  emits a tool call → a music server plays something), but not part of this recipe book.
- **NVR / camera AI** — runs on separate hardware in the source setup and isn't LLM-integrated.
- **Cloud model providers** — this stack is deliberately **local-only**. No Anthropic/OpenAI/etc.
  backends are wired in; add them to LiteLLM yourself if you want a hybrid.
