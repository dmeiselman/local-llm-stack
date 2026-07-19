# Reference — security & network exposure

This stack assumes a **trusted home LAN**. A couple of services bind to all interfaces on purpose.
Know what's exposed and lock it down if your network isn't trusted.

## What binds where (reference build)

| Service | Bind | Reachable from | Notes |
|---------|------|----------------|-------|
| llama-swap `:8080` | `0.0.0.0` | whole LAN | no auth of its own |
| LiteLLM `:4000` | `0.0.0.0` | whole LAN | **protected by `LITELLM_MASTER_KEY`** |
| Open WebUI `:3000` | host (`--network=host`) | whole LAN | its own login/auth |
| SearXNG `:8888` | `127.0.0.1` | localhost only | |
| Speaches `:8001`, Kokoro `:8880` | `127.0.0.1` | localhost only | (disabled by default) |

The exposed-but-unauthenticated one to notice is **llama-swap :8080** — anyone on your LAN can hit
the raw engine directly. LiteLLM in front of it *is* keyed, but the engine port is open.

## Hardening checklist

1. **Rotate the shipped placeholders.** Never run with example secrets. `./scripts/gen-secrets.sh`
   generates a fresh `LITELLM_MASTER_KEY` (and a SearXNG secret). The real key lives only in
   `config/litellm/.env` (gitignored) and wherever clients read it.
2. **Bind to localhost or a specific interface** if the LAN isn't trusted:
   - llama-swap: change `-listen 0.0.0.0:8080` to `-listen 127.0.0.1:8080` in the unit (LiteLLM
     reaches it via host networking regardless).
   - LiteLLM: change the compose `command` `--host 0.0.0.0` to `--host 127.0.0.1`, or firewall :4000.
3. **Firewall the ports** you don't want on the LAN (`ufw deny 8080`, etc.).
4. **Keep secrets out of your shell rc** if you'd rather not have the key in `~/.bashrc` — source it
   from a `chmod 600` file only when needed.
5. **Don't commit secrets.** `.gitignore` excludes `.env` and rendered configs; `scripts/scrub-check.sh`
   fails the commit if a real key or host identifier slips in. Consider wiring it as a pre-commit
   hook (see README).

## Reminder: this stack is local-only

No cloud model providers are configured. Nothing you type is sent to a third party — web search
goes through your own SearXNG. If you add a cloud backend to LiteLLM later, that changes; treat the
key and the data boundary accordingly.
