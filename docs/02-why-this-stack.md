# Why this stack (and the honest alternatives)

The reference build runs **llama-swap + llama.cpp**, fronted by **LiteLLM**, with **Open WebUI**
as the chat UI. Here's why — and where a different choice is legitimately better for you.

## The serving engine: llama.cpp (why, and the alternatives)

**Why llama.cpp is the primary path here:**

- **Best fit for this hardware.** On 2×3060 (Ampere, no NVLink, no FP8), llama.cpp's GGUF +
  quantized (`q8_0`) KV cache is what makes long context fit. It won the single-stream speed
  bake-off on this box.
- **Total control of the VRAM levers** — context, KV quant, tensor split, per-model flags.
- **Runs everywhere** — CUDA / ROCm / SYCL / Vulkan / Metal, so it isn't NVIDIA-locked.

### Alternative: Ollama — the easy on-ramp

Ollama wraps llama.cpp with a much friendlier UX. **If you're new to local LLMs, start here** —
it's the fastest way to a working chat, and you can graduate later.

| | Ollama | llama.cpp + llama-swap (this build) |
|--|--------|-------------------------------------|
| Setup | `curl \| sh`, `ollama run <model>` — minutes | Build from source, write configs |
| Model management | Excellent: `ollama pull`, a model registry, auto-templates | Manual: download GGUFs, set flags yourself |
| Hot-swap between models | Built in | Provided by llama-swap (this repo adds it) |
| Tool-calling reliability | "Just works" with **library** models (they ship correct chat templates) | Works, but raw `hf.co` GGUFs can carry a template that 400s on tool calls — you pick known-good ones |
| Fine VRAM control (context/KV) | Limited / indirect | Full and explicit |
| Peak single-stream speed here | Slightly behind | Slightly ahead |

**Bottom line:** Ollama is a great on-ramp and genuinely nicer for model management. This build
chose llama.cpp for the explicit context/performance control on constrained VRAM. A reasonable
hybrid: keep Ollama installed for quick experiments, run llama-swap for your daily driver.

> **The tool-calling gotcha worth knowing either way:** for agent use, prefer models with a
> known-good chat template. On Ollama that means `library` models (which activate the native
> tool parser); with raw GGUFs, test a tool call before trusting it. See
> [reference/troubleshooting.md](../reference/troubleshooting.md).

### Alternative: vLLM — great for concurrency, not for this box

vLLM is the production choice for **serving many users at once** (paged attention, continuous
batching). But on this hardware it's a poor fit:

- Compute-cap 8.6 has **no FP8**, so you're pushed to AWQ/GPTQ INT4 weights.
- No NVLink means tensor-parallel all-reduce is PCIe-bound, so **single-stream speed ≈ llama.cpp**
  anyway — you only win on concurrency you don't have as a single user.
- Multimodal encoders reserve worst-case VRAM, cutting your context.

Use vLLM if you're serving a team; for a single-user homelab it's more setup for no daily win.

### Alternative: ik_llama.cpp — a possible MoE speed bake-off

A performance-focused llama.cpp fork that can be faster on MoE models. Worth benchmarking against
mainline **after** verifying it supports your exact model architecture. A "later, if you're
optimizing" item, not a starting point.

## The gateway: LiteLLM (why not just point clients at the engine?)

You *could* point every client straight at llama.cpp. LiteLLM earns its place by giving you:

- **Stable role names** (`local-fast`/`local-coder`/`local-gemma`) that survive model swaps.
- **One auth key** in front of an engine that has no auth of its own.
- **`drop_params`** so a picky client can't break the backend with an unsupported field.
- A single place to later add rate limits, logging, or fallback models.

For a *single* client you can skip it. With four clients, it's the difference between changing one
file and changing four.

## The UI: Open WebUI

A polished, self-hosted ChatGPT-style front end: multi-model, RAG/document chat, and built-in
**web search** (via SearXNG here) and a voice **Call** mode. It's the "normal person" entry point
to the stack. Alternatives exist (LibreChat, plain `llama-server`'s built-in web UI), but Open
WebUI's feature breadth is why it's here.

> **One Open WebUI foot-gun baked into this build:** it's configured with
> `ENABLE_PERSISTENT_CONFIG=false`, which makes the systemd env vars authoritative and causes the
> Admin-UI settings to be ignored. That's a deliberate trade (config lives in the unit file, not a
> hidden DB) but it means **every feature must be set via env var** — which is why web search is
> turned on in the unit. See [reference/troubleshooting.md](../reference/troubleshooting.md).
