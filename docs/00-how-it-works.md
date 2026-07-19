# How it works: the four layers

This stack is deliberately built as **four small, swappable layers**, each speaking the
same language (the OpenAI HTTP API). You can understand — and debug — each one on its own.

```
 CLIENTS                    GATEWAY              SWAPPER               ENGINE
 what you talk to           stable names         one model warm        the actual math
┌────────────────────┐    ┌───────────┐        ┌───────────────┐    ┌──────────────────┐
│ Open WebUI  :3000  │    │           │        │               │    │ llama-server     │
│ opencode           │──▶│ LiteLLM   │  ───▶  │ llama-swap    │──▶│ (llama.cpp)      │
│ pi                 │    │  :4000    │        │  :8080        │    │  :9101+ per model│
│ mini-swe-agent     │    │ role names│        │ hot-swaps GGUF│    └──────────────────┘
└────────────────────┘    └───────────┘        └───────────────┘
      ▲                        ▲                      ▲
  SearXNG :8888            local-fast            "load the model
  (web search)             local-coder            named X, unload
                           local-gemma            the last one"
```

## The lifecycle of one chat message

1. **You send a request to a client** — you type in Open WebUI, or opencode calls a tool.
   The client makes a standard OpenAI `POST /v1/chat/completions` with `model: "local-fast"`.

2. **The client talks to LiteLLM (`:4000`), never to the engine directly.** LiteLLM is a thin
   *gateway*. Its only jobs: (a) check the API key, (b) translate the friendly role name
   (`local-fast`) into the backend model name (`llama-model`), (c) `drop_params` — quietly
   remove any OpenAI fields the engine doesn't accept — and forward the request to `:8080`.

3. **llama-swap (`:8080`) picks the model.** It looks at the requested name/alias. If that
   model is already loaded, it forwards instantly. If not, it **unloads the current model and
   loads the new one** (~15–25 s on 2×3060), then forwards. Only one model is resident at a
   time — which is exactly right when your whole VRAM budget fits one good model, not two.

4. **llama-server (llama.cpp) does the inference** and streams tokens back up the chain:
   engine → llama-swap → LiteLLM → your client.

## Why each layer exists (and when you could drop it)

| Layer | Job | Could you skip it? |
|-------|-----|--------------------|
| **llama.cpp** (`llama-server`) | The inference engine. Loads a GGUF, runs it on your GPUs, exposes an OpenAI API. | No — this is the thing that actually runs the model. |
| **llama-swap** | Keeps one model warm and hot-swaps others on demand from one port. | Yes, if you only ever want **one** model — run `llama-server` directly (see `systemd/llama-server.service.template`). |
| **LiteLLM** | Stable, role-based names + one key + one place to swap models. | Yes, for a single client — but you lose the "swap in one place, every client keeps working" property. |
| **Open WebUI / opencode / pi / …** | The things you actually use: chat, coding agents. | These *are* the point; add or remove them freely. |

## The one idea that ties it together: **role-based names**

Clients never name a model file. They ask for a **role**:

- `local-fast` → your general daily driver
- `local-coder` → a coding model with thinking turned off
- `local-gemma` → a long-context / thinking model

Those names live in LiteLLM and are backed by a **floating alias** (`llama-model`) inside
llama-swap. To change what "fast" means, you move the alias in *one file* — and Open WebUI,
opencode, pi, and mini-swe-agent all follow, unchanged. This indirection is the single most
useful design decision in the stack. See [reference/model-switching.md](../reference/model-switching.md).

## Mini-glossary

- **GGUF** — the single-file model format llama.cpp loads. Contains weights + tokenizer + a
  chat template.
- **Quantization (quant)** — compressing weights to fewer bits to fit in VRAM. `Q4_K_M` is the
  common sweet spot; `Q3_K_XL` trades a little quality for more room; `QAT` = quantization-aware
  trained (higher quality at low bits). Lower bits = smaller + faster, down to a quality floor.
- **KV cache** — per-token memory the model keeps for the conversation so far. It grows with
  **context length** and competes with the weights for VRAM. Storing it at `q8_0` roughly halves
  its size — the main lever for fitting long context. See [01-hardware-and-vram.md](01-hardware-and-vram.md).
- **Flash attention (`-fa on`)** — a faster, lower-memory attention implementation.
- **`-ngl 99`** — "offload all layers to GPU." Just use 99 and let llama.cpp place them.
- **Tensor split (`-ts 33,31`)** — how to divide layers between two GPUs when one needs a nudge
  to balance VRAM.
- **Context window (`-c`)** — max tokens (prompt + reply) the model can hold at once.
- **MoE vs dense** — a Mixture-of-Experts model (e.g. 35B-A3B) has many params but only activates
  a few billion per token, so it's fast for its size. A dense model uses all its params every token.
- **Thinking mode** — some models emit hidden reasoning before the answer. Great for hard problems,
  bad for latency-sensitive uses (voice, autocomplete).
