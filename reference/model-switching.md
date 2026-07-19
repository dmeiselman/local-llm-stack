# Reference — switching & adding models

## The floating alias in one picture

```
LiteLLM name     llama-swap key            what loads
------------     --------------            ----------
local-fast  ──▶  alias "llama-model"  ──▶  qwen3.6-35b-a3b   (the block that owns the alias)
local-coder ──▶  qwen3.6-27b          ──▶  qwen3.6-27b
local-gemma ──▶  gemma4-26b-qat       ──▶  gemma4-26b-qat
```

`local-fast` doesn't name a model — it names the **alias** `llama-model`, which is attached to one
model block. Move the alias, and "fast" means something else, everywhere, at once.

## Change your daily driver (no client touched)

In `config/llama-swap/config.yaml`, move the `llama-model` alias to a different block:

```yaml
models:
  qwen3.6-35b-a3b:
    # aliases:            # <- remove from here
    #   - llama-model
    ...
  gemma4-26b-qat:
    aliases:
      - llama-model        # <- add here to make Gemma the default
    ...
```

Because llama-swap runs with `-watch-config`, saving the file is enough — no restart. The next
`local-fast` request loads the new model. Open WebUI, opencode, pi, mini-swe-agent all follow.

## Add a new model

1. Download the GGUF into `MODELS_DIR`.
2. Add a block to `config/llama-swap/config.yaml`:

```yaml
  my-new-model:
    cmd: |
      ${llama-server}
      -m __MODELS_DIR__/My-New-Model-Q4_K_M.gguf
      -ngl 99 -fa on -ctk q8_0 -ctv q8_0
      -c 32768 -np 1
      --host 127.0.0.1 --port ${PORT}
```

3. (Optional) expose it under a friendly name by adding to `config/litellm/config.yaml`:

```yaml
  - model_name: local-mynew
    litellm_params:
      model: openai/my-new-model
      api_base: http://127.0.0.1:8080/v1
      api_key: "none"
```

4. Restart LiteLLM to pick up the new route: `docker restart litellm`. (llama-swap picked up its
   change automatically.)

## Handy llama-swap endpoints

```
curl http://127.0.0.1:8080/v1/models      # list configured models
curl http://127.0.0.1:8080/running        # what's loaded right now
# Web UI:
#   http://<host>:8080/ui/
```

Swap latency between models is ~15–25 s on 2×3060 (unload + load). If that bothers you and you only
use one model, run the single-model `llama-server` unit instead (no swapping).
