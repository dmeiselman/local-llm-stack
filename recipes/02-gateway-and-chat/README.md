# Recipe 02 — Gateway & chat (LiteLLM + Open WebUI + SearXNG)

**Goal:** a stable gateway on `:4000` with friendly model names, a chat UI on `:3000`, and private
web search on `:8888`.
**Prereqs:** Recipe 01 running (llama-swap answers on `:8080`); Docker installed and your user in
the `docker` group (`docker ps` works without sudo).

---

## Step 1 — Secrets

```
./scripts/gen-secrets.sh
```

This writes a fresh `LITELLM_MASTER_KEY` into `config/litellm/.env` (gitignored) and prints a
SearXNG secret. Add the key to your shell rc so CLI clients can read it:

```
echo 'export LITELLM_MASTER_KEY=<the-key-printed-above>' >> ~/.bashrc && source ~/.bashrc
```

## Step 2 — Render configs and lay out the compose stack

```
./scripts/render-configs.sh
```

Then assemble the deploy directory (`STACK_DIR`, default `~/llm-stack`):

```
mkdir -p "$STACK_DIR/litellm" "$STACK_DIR/searxng"
cp compose/docker-compose.yml   "$STACK_DIR/docker-compose.yml"
cp config/litellm/config.yaml   "$STACK_DIR/litellm/config.yaml"
cp config/litellm/.env          "$STACK_DIR/litellm/.env"
cp config/searxng/settings.yml  "$STACK_DIR/searxng/settings.yml"
```

## Step 3 — Start LiteLLM + SearXNG

```
cd "$STACK_DIR" && docker compose up -d
```

Verify the gateway:

```
curl -s -H "Authorization: Bearer $LITELLM_MASTER_KEY" http://127.0.0.1:4000/v1/models
```

You should see `local-fast`, `local-coder`, `local-gemma`. A chat call through the gateway now
transparently drives llama-swap:

```
curl -s -H "Authorization: Bearer $LITELLM_MASTER_KEY" -H 'Content-Type: application/json' \
  -d '{"model":"local-fast","messages":[{"role":"user","content":"hi"}],"max_tokens":16}' \
  http://127.0.0.1:4000/v1/chat/completions
```

## Step 4 — Open WebUI

```
./scripts/install-units.sh              # installs the rendered open-webui unit too
sudo systemctl enable --now open-webui
```

Open `http://<host>:3000`, create the first (admin) account, and pick a model. Chat should work.

### About the Open WebUI config model (read this)

This build sets `ENABLE_PERSISTENT_CONFIG=false`, which makes the **systemd env vars
authoritative** and the Admin-UI settings inert. Consequences:

- The connection to LiteLLM is defined in the unit file, not the UI.
- **Web search is enabled via env vars** in the unit (`ENABLE_WEB_SEARCH`, `WEB_SEARCH_ENGINE`,
  `SEARXNG_QUERY_URL`) — because a UI toggle would be ignored. This is the fix for the classic
  "I configured SearXNG in the UI but search does nothing" trap.
- If you'd rather configure features in the UI, remove `ENABLE_PERSISTENT_CONFIG=false` from the
  unit (and then the UI settings persist to Open WebUI's DB instead).

## Verify (end to end)

```
./scripts/healthcheck.sh
```

Checks llama-swap, the gateway (incl. a chat completion and a tool-calling probe), Open WebUI, and
a SearXNG JSON query. All green = the core stack is up.

**Next:** [Recipe 03 — Coding agents](../03-coding-agents/README.md).
