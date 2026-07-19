# Hardware baseline & the VRAM budget

This is the part homelabbers underestimate: **the whole design is a VRAM budgeting exercise.**
Get this mental model and every flag in the configs makes sense.

## The reference machine

| Component | This build |
|-----------|------------|
| GPUs | **2× NVIDIA RTX 3060, 12 GB each** (~23.3 GiB usable total), compute capability **8.6** (Ampere) |
| GPU link | PCIe only — **no NVLink** (matters, see below) |
| OS / driver / CUDA | Ubuntu 24.04, recent NVIDIA driver, CUDA 12.8 toolkit |
| CPU / RAM | 12 cores / ~16 GB RAM |

Two 12 GB cards give ~24 GB, but you can't treat it as one pool. Without NVLink the GPUs talk
over PCIe, so splitting one model across both adds **capacity, not much speed** — llama.cpp uses
a *layer split* (each GPU holds a chunk of layers, pipeline-style). That's fine here: the goal is
"fit a bigger model + long context," not raw multi-GPU throughput.

## The budget: weights + KV cache must both fit

```
   ~24 GB total VRAM
   ├── model weights        (fixed once you pick the model + quant)
   ├── KV cache             (grows with context length)   ← the lever you control
   └── a little overhead    (CUDA context, buffers)
```

- **Weights** are fixed by your model + quant choice. A 35B MoE at `Q3_K_XL` ≈ 18 GB; a 27B dense
  at `Q4_K_XL` ≈ 16 GB.
- **KV cache** is what's left. It grows linearly with context length. This is where the tuning
  happens.

### The main lever: `q8_0` KV cache

The configs all use `-fa on -ctk q8_0 -ctv q8_0`. That stores the KV cache at 8-bit instead of
16-bit, **roughly halving it** — which is what lets a 35B model reach 192K context on 24 GB.

> **Important hardware note:** these cards are compute-capability 8.6, which has **no native FP8**.
> That rules out FP8 KV cache (an SM89+/Ada feature) — `q8_0` (a llama.cpp quantized KV format) is
> the equivalent lever here, and it's exactly why llama.cpp fits this box better than some
> alternatives (see [02-why-this-stack.md](02-why-this-stack.md)).

### Why the three models use different `-c` values

| Model | `-c` (context) | Why it fits |
|-------|----------------|-------------|
| `qwen3.6-35b-a3b` | 196608 (192K) | MoE with cheap attention; 256K native max was too tight (only ~23 MB free) |
| `qwen3.6-27b` | 114688 (112K) | dense, larger weights; **hybrid attention** keeps KV cheap (~34 KiB/token) |
| `gemma4-26b-qat` | 262144 (256K) | smallest weights + sliding-window attention = very cheap KV |

`-ts 33,31` on the 27B is a small nudge to balance the ~half-GB VRAM imbalance between the two
cards so neither runs out first. These numbers are **measured for this box** — re-probe on yours.

### How to re-tune on different hardware

The practical method (details in [reference/vram-tuning.md](../reference/vram-tuning.md)):
1. Start with a modest `-c` (e.g. 32768), launch, watch `nvidia-smi`.
2. Note the free VRAM per card. Roughly double `-c` while headroom allows.
3. Stop when the tightest card has only a few hundred MB free. Back off one step for safety.

## If you have different / more GPUs

llama.cpp runs GGUF on CUDA, ROCm (AMD), SYCL (Intel), Vulkan and Metal, so you're **not locked
to NVIDIA**. Rough guidance when weighing an upgrade — "does llama.cpp support it, and does it end
the no-NVLink split?":

| Option | Notes |
|--------|-------|
| **2× RTX 3060 12 GB (this build)** | ~24 GB, cheap, Ampere. The baseline. No NVLink. |
| **Single RTX 3090 24 GB** | One card = no split, big bandwidth. The clean upgrade if you can find one. |
| **2× RTX 5060 Ti 16 GB** | ~32 GB, newer (Ada/Blackwell class), more room; still PCIe-split. |
| **Modded RTX 2080 Ti 22 GB** | Turing (arch 75), runs GGUF on mainline llama.cpp; strong value per GB. |
| **AMD (e.g. W7800 / 7900-class)** | Works via ROCm builds of llama.cpp; verify your model's ops are supported. |

Set your card's arch in `scripts/lib.sh` (`CUDA_ARCH`: 86 = 30-series, 89 = 40-series, 75 = 20-series).

## Quant quick-reference (for ~24 GB total)

| Model size | Comfortable quant | Fit |
|-----------|-------------------|-----|
| 7–8B | Q4_K_M–Q8_0 | single card, lots of context |
| 13–14B | Q4_K_M–Q6_K | fully in VRAM, large context |
| 27–35B | Q3_K_XL–Q4_K_M | split across both cards; tune context to fit |
| 70B | Q2/Q3 + CPU offload | possible but slow |
