# Reference — troubleshooting (the gotcha catalog)

Real problems hit while building this stack, and the fixes.

## Open WebUI

**"I configured web search / a setting in the Admin UI but it does nothing."**
This build runs Open WebUI with `ENABLE_PERSISTENT_CONFIG=false`, which makes the **systemd env
vars authoritative** and causes Admin-UI settings to be ignored. Every feature must be declared as
an env var on the unit. That's why web search is enabled in `open-webui.service` with:

```
-e ENABLE_WEB_SEARCH=true
-e WEB_SEARCH_ENGINE=searxng
-e "SEARXNG_QUERY_URL=http://127.0.0.1:8888/search?q=<query>"
```

If you'd rather use the UI to configure things, remove `ENABLE_PERSISTENT_CONFIG=false` from the
unit (settings then persist to Open WebUI's DB).

**Chat picker shows stale/old models.** With Ollama disabled (`ENABLE_OLLAMA_API=false`) and the
OpenAI base pointed at LiteLLM, the picker should show only `local-*`. A stale list usually means
the DB-persisted config is winning — see the persistent-config note above.

## llama-swap / llama.cpp

**llama-swap exits immediately: "exited prematurely."** The `cmd` is parsed with shell-word rules.
Any JSON argument must be **single-quoted**, e.g.
`--chat-template-kwargs '{"enable_thinking":false}'`. Unquoted braces crash it.

**`/health` returns 503.** Normal *while a model is loading*. Poll for HTTP 200, don't treat the
initial 503 as failure. Swaps take ~15–25 s on 2×3060.

**Port :8080 already in use.** `llama-swap.service` and `llama-server.service` both bind :8080 and
are **mutually exclusive**. Enable exactly one.

**`nvcc: command not found` during build.** CUDA is installed but not on PATH. `export
PATH=/usr/local/cuda/bin:$PATH`. Don't reinstall drivers/CUDA for this.

**Build gets OOM-killed.** Parallel `nvcc` is memory-hungry. Use `-j6` (or `-j4`), not
`-j$(nproc)`.

**Model spills to CPU / suddenly slow.** Context too large for VRAM. Lower `-c`, use a smaller
quant, or reduce `-ngl`. See [vram-tuning.md](vram-tuning.md).

## Tool-calling / agents

**Every tool call returns 400 but plain chat works.** The model's GGUF chat template is aborting
the tool parser (common with raw `hf.co` GGUFs whose Jinja template raises on a missing/misplaced
system message). Fixes: use a known-good/library build of the model, or switch that task to the
text-protocol agent (mini-swe-agent) which doesn't rely on tool-calls.

**Disabling "thinking" on Qwen3.6.** `--reasoning-budget 0` does **not** work on Qwen3.6's template.
Use `--jinja --chat-template-kwargs '{"enable_thinking":false}'` (as `local-coder` does).

**pi says "No models available."** Its schema requires **all four** `cost` keys
(`input`,`output`,`cacheRead`,`cacheWrite`) per model; a missing one is rejected silently.

**mini-swe-agent aborts on start / raises a cost RuntimeError.** Set `MSWEA_CONFIGURED=true` (skips
the TTY-only wizard) and `MSWEA_COST_TRACKING=ignore_errors` (LiteLLM reports $0, which the default
mode treats as an error).

**A client hangs on long prompts.** The client's advertised context exceeds the server `-c`. Keep
client context ≤ server `-c`. See [vram-tuning.md](vram-tuning.md).

**A thinking model returns an empty/cut-off answer (`finish_reason=length`).** Its reasoning ate the
whole output budget before it reached the answer. Raise the client's `max_tokens` / `output` /
`maxTokens` (the reference `local-coder-think` uses 16384). Reasoning is emitted on a separate
`reasoning_content` channel, so it won't leak into `content` or tool-call arguments — it just costs
tokens and time.

## Voice (if enabled)

**Crackling / robotic speech.** Open WebUI fell back to browser TTS. Set the TTS engine to
**OpenAI** (pointing at Kokoro), not "Web/Local."

**Gemma won't load for voice.** Some GGUFs include a vision/audio projector that trips the loader;
use a **text-only** export.
