# local-llm-stack

A **recipe book + tech introduction** for running a capable, fully-local LLM stack on a
homelab-class dual-GPU box (reference build: **2× 12 GB GPUs, ~24 GB VRAM**). It's aimed at a
tech-savvy homelabber who is *not* an LLM-infra expert: enough theory to understand what you're
building, then step-by-step recipes to build it.

Everything runs **on your own hardware** — no cloud model providers, nothing leaves your network.

## What you get

```
 Open WebUI (chat + web search + docs)         opencode / pi / mini-swe-agent (coding agents)
                       \                        /
                        \                      /
                 LiteLLM gateway  (stable role-based model names, one API key)   :4000
                                   |
                 llama-swap  (keeps one model warm, hot-swaps on demand)         :8080
                                   |
                 llama.cpp / llama-server  (GGUF inference on your GPUs)
```

- **Three models on tap**, hot-swapped by name: a fast MoE daily driver, a no-thinking coder, and a
  long-context model.
- **Coding agents** (native tool-calling *and* a text-protocol fallback).
- **Private web search** via a self-hosted SearXNG.
- **Optional voice** (STT+TTS) — documented, but **off by default** to keep VRAM for context.

## Read the theory first (10 minutes)

| Doc | What it explains |
|-----|------------------|
| [docs/00-how-it-works.md](docs/00-how-it-works.md) | The four layers, the life of one request, the glossary |
| [docs/01-hardware-and-vram.md](docs/01-hardware-and-vram.md) | The VRAM budget, the KV-cache lever, tuning, GPU alternatives |
| [docs/02-why-this-stack.md](docs/02-why-this-stack.md) | Why llama.cpp/llama-swap — and honest Ollama / vLLM trade-offs |
| [docs/03-capabilities.md](docs/03-capabilities.md) | Everything the stack can do |

## Then follow the recipes (in order)

| Recipe | Builds |
|--------|--------|
| [01 — Core inference](recipes/01-core-inference/README.md) | llama.cpp build → models → llama-swap on :8080 |
| [02 — Gateway & chat](recipes/02-gateway-and-chat/README.md) | LiteLLM :4000 + Open WebUI :3000 + SearXNG :8888 |
| [03 — Coding agents](recipes/03-coding-agents/README.md) | opencode, pi, mini-swe-agent |
| [04 — Voice (optional)](recipes/04-voice-optional/README.md) | Speaches + Kokoro — *disabled by default* |

## Quick start (once, top to bottom)

```
# 0. Set your paths (edit or export): LLAMACPP_DIR, MODELS_DIR, LLAMASWAP_DIR, STACK_DIR, CUDA_ARCH
$EDITOR scripts/lib.sh

# 1. Secrets  -> writes config/litellm/.env (gitignored)
./scripts/gen-secrets.sh

# 2. Build the engine, get models
./scripts/build-llamacpp.sh
./scripts/fetch-models.sh

# 3. Fill in the templates with your paths/secrets
./scripts/render-configs.sh

# 4. Follow recipes 01 -> 02 to place configs, install units, and start services

# 5. Prove it works end to end
./scripts/healthcheck.sh
```

## Repo layout

```
docs/       tech intro (concepts)                 config/    templated configs (*.template / *.example)
recipes/    step-by-step build guides             systemd/   templated unit files (*.template)
reference/  model-switching, vram-tuning,         compose/   docker-compose for LiteLLM + SearXNG
            troubleshooting, security             scripts/   helpers (build, fetch, render, healthcheck, scrub)
```

## Values you must set (placeholders)

The tracked files are **templates**; `scripts/render-configs.sh` fills these in from `scripts/lib.sh`
+ your generated secrets:

| Placeholder | Meaning |
|-------------|---------|
| `__USER__` | Linux user that runs the services |
| `__HOME__` | that user's home directory |
| `__LLAMACPP_BIN__` | path to the built `llama-server` |
| `__MODELS_DIR__` | directory holding your `.gguf` files |
| `__LLAMASWAP_DIR__` | directory with the llama-swap binary + config |
| `__LITELLM_MASTER_KEY__` | the gateway API key (generated) |
| `__SEARXNG_SECRET__` | SearXNG secret key (generated) |

## Notes & conventions

- **Local-only.** No cloud providers are wired in. See [security](reference/security.md) for what's
  exposed on your LAN and how to lock it down.
- **Secrets never get committed.** `.gitignore` excludes `.env`, rendered configs, and `*.gguf`.
  Optionally wire the scrub gate as a pre-commit hook:
  `ln -sf ../../scripts/scrub-check.sh .git/hooks/pre-commit`
- Configs here are adapted from a working single-host deployment; the hardware-specific numbers
  (context sizes, tensor split) are **measured for ~24 GB** and should be re-tuned for your box —
  see [reference/vram-tuning.md](reference/vram-tuning.md).
