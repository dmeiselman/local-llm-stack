# Recipe 01 — Core inference (llama.cpp + models + llama-swap)

**Goal:** a running model server on `:8080` that hot-swaps between three models.
**Prereqs:** working NVIDIA driver + CUDA (`nvidia-smi` lists your GPUs); `git`, `cmake`,
`build-essential`; `huggingface_hub` for downloads. Docker not needed for this recipe.

First, set your paths in `scripts/lib.sh` (or export them): `LLAMACPP_DIR`, `MODELS_DIR`,
`LLAMASWAP_DIR`, and `CUDA_ARCH` (86 for RTX 30-series).

---

## Step 1 — Build llama.cpp with CUDA

```
./scripts/build-llamacpp.sh
```

What it runs (verified for Ampere/arch 86, Ubuntu 24.04, CUDA 12.8):

```
cmake --preset release -DGGML_CUDA=1 -DCMAKE_CUDA_ARCHITECTURES=86
cmake --build --preset release -j6
```

Notes:
- Use `-j6`, **not** `-j$(nproc)` — parallel `nvcc` is memory-hungry and can OOM a 16 GB box.
- If `nvcc: command not found`, add it to PATH: `export PATH=/usr/local/cuda/bin:$PATH` (the script
  does this). Don't "reinstall CUDA" for a PATH issue.
- Binaries land in `build/bin/` (e.g. `build/bin/llama-server`), not the repo root.

Verify:

```
$LLAMACPP_DIR/build/bin/llama-server --version
```

## Step 2 — Download the models

```
pip install -U "huggingface_hub[cli]"
./scripts/fetch-models.sh
```

This pulls three GGUFs into `MODELS_DIR` (13–19 GB each — comment out any you don't want):

| Role | File | ~size |
|------|------|-------|
| daily driver (MoE) | `Qwen_Qwen3.6-35B-A3B-Q3_K_XL.gguf` | 18 GB |
| coder (dense, no-think) | `Qwen_Qwen3.6-27B-UD-Q4_K_XL.gguf` | 16 GB |
| long-context (MoE, QAT) | `gemma4-26b-qat-text-Q4_0.gguf` | 13 GB |

> Publisher repo paths change over time. If a download 404s, find the current GGUF repo for that
> model on Hugging Face and edit `scripts/fetch-models.sh`. Whatever filename you end up with, make
> it match the `-m` paths in the llama-swap config (next step).

## Step 3 — Configure & install llama-swap

1. Get the llama-swap binary (single Go binary) from its GitHub releases into `LLAMASWAP_DIR`.
2. Render configs (fills in your paths/secrets — run `./scripts/gen-secrets.sh` first if you
   haven't): `./scripts/render-configs.sh`
3. Copy the rendered config next to the binary:
   `cp config/llama-swap/config.yaml "$LLAMASWAP_DIR/config.yaml"`
4. Install the service: `./scripts/install-units.sh` then
   `sudo systemctl enable --now llama-swap`

The config defines the three models and the floating `llama-model` alias. See
[../../reference/model-switching.md](../../reference/model-switching.md) for how the alias works and
[../../reference/vram-tuning.md](../../reference/vram-tuning.md) to re-tune `-c` for your GPUs.

> **Single-model alternative:** if you only ever want one model, skip llama-swap and use
> `systemd/llama-server.service.template` instead — it runs one model directly on `:8080`. Don't
> enable both; they share the port.

## Verify

```
# llama-swap is up and lists your models:
curl -s http://127.0.0.1:8080/v1/models

# First real request triggers a load (watch it swap):
curl -s http://127.0.0.1:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"llama-model","messages":[{"role":"user","content":"hi"}],"max_tokens":16}'
```

Gotchas you may hit (full list in [troubleshooting](../../reference/troubleshooting.md)):
- `/health` returns **503 while a model is loading** — that's normal; poll for a 200.
- If llama-swap crashes on start with "exited prematurely," check that any JSON in a `cmd`
  (like `--chat-template-kwargs '{"enable_thinking":false}'`) is **single-quoted**.

**Next:** [Recipe 02 — Gateway & chat](../02-gateway-and-chat/README.md).
