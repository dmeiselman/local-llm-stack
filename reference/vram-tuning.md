# Reference — VRAM & context tuning

The numbers in the configs are **measured for 2×3060 (~24 GB)**. Here's how to re-derive them for
your hardware.

## The single source of truth: keep these three in sync

For each model, three context numbers must agree, or clients stall:

| Where | Setting | Reference values (fast / coder / gemma) |
|-------|---------|------------------------------------------|
| `config/llama-swap/config.yaml` | `-c` | 196608 / 114688 / 262144 |
| `config/opencode/opencode.json` | `limit.context` | 196608 / 114688 / 262144 |
| `config/pi/models.json` | `contextWindow` | 196608 / 114688 / 262144 |

**Rule:** a client's advertised context must be **≤** the server's `-c`. If a client claims more
than llama-server allows, requests can hang. When you change `-c`, change the client values too.

## Finding the max `-c` your GPUs allow

1. Pick a starting context and launch the model directly (bypass swap while probing):

```
$LLAMACPP_BIN -m $MODELS_DIR/<model>.gguf -ngl 99 -fa on -ctk q8_0 -ctv q8_0 \
  -c 32768 -np 1 --host 127.0.0.1 --port 9099
```

2. In another terminal watch VRAM: `watch -n1 nvidia-smi`. Note free MiB on the **tightest** card.
3. Roughly double `-c` and relaunch while free VRAM allows. KV cache scales ~linearly with `-c`.
4. Stop when the tightest card has only a few hundred MB free; back off one step for headroom.
5. If the two cards are imbalanced (one fills first), nudge with `-ts A,B` (e.g. `-ts 33,31` sends
   slightly fewer layers to the tighter card).

## Why the KV levers matter so much

- `-ctk q8_0 -ctv q8_0` stores the KV cache at 8-bit ≈ **half** the size of the default 16-bit. On
  this box that's the difference between ~90K and ~190K context for the 35B model.
- These cards (compute cap 8.6) have **no FP8**, so `q8_0` is the equivalent lever — an FP8 KV
  cache (SM89+/Ada) is not available here.
- **Attention type changes the math.** Hybrid-attention (Qwen3.6-27B) and sliding-window
  (Gemma-4) models keep only a fraction of layers' KV, so they reach huge contexts cheaply — which
  is why the 26B Gemma runs at 256K while a naive dense model of that size could not.

## VRAM sanity check while running

If tokens/sec suddenly craters, you've likely spilled to CPU. Confirm with `nvidia-smi` (model
memory should be ~fully on the GPUs). Fix by lowering `-c`, choosing a smaller quant, or (last
resort) reducing `-ngl`.
